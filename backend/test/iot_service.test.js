// Firestore en memoria: sin credenciales, emuladores ni peticiones externas.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { FieldValue } = require('firebase-admin/firestore');
const { createIotService } = require('../src/services/iotService');
const { sign } = require('../src/services/iotProtocol');
const oldSecret = process.env.IOT_SHARED_SECRET;
const oldDevice = process.env.IOT_DEVICE_ID;
before(() => { process.env.IOT_SHARED_SECRET = '11'.repeat(32); process.env.IOT_DEVICE_ID = 'test-jetson'; });
after(() => {
    for (const [name, value] of [['IOT_SHARED_SECRET', oldSecret], ['IOT_DEVICE_ID', oldDevice]]) {
        if (value === undefined) delete process.env[name]; else process.env[name] = value;
    }
});

function harness() {
    const docs = new Map();
    const devicePath = 'IotDevices/test-jetson';
    let next = 1;
    const collection = path => ({ doc: id => document(`${path}/${id}`) });
    const document = path => ({ path, collection: name => collection(`${path}/${name}`) });
    const snapshot = ref => ({ ref, exists: docs.has(ref.path), data: () => docs.get(ref.path) });
    const db = {
        collection,
        runTransaction: async callback => {
            const writes = [];
            const value = await callback({
                get: async ref => {
                    assert.equal(writes.length, 0, 'Firestore exige lecturas antes de escrituras');
                    return snapshot(ref);
                },
                create: (ref, data) => { assert.ok(!docs.has(ref.path)); writes.push([ref, data, false]); },
                set: (ref, data) => writes.push([ref, data, false]),
                update: (ref, data) => { assert.ok(docs.has(ref.path)); writes.push([ref, data, true]); },
            });
            for (const [ref, data, merge] of writes) {
                const result = merge ? { ...docs.get(ref.path) } : {};
                for (const [key, item] of Object.entries(data)) {
                    if (typeof item?.isEqual === 'function' && item.isEqual(FieldValue.delete())) delete result[key];
                    else if (item instanceof Date) result[key] = { toDate: () => item };
                    else result[key] = item;
                }
                docs.set(ref.path, result);
            }
            return value;
        },
    };
    docs.set('Usuarios/user/ConfiguracionSistema/general', { cantidad_esperada: 30, nombre_finca: 'Campo' });
    const service = createIotService(db);
    return {
        docs, service, devicePath,
        issue: (command, session_id) => service.issue('user', { command, request_id: (next++).toString(16).padStart(32, '0'), ...(session_id ? { session_id } : {}) }),
        reply: (ticket, status, count = '-') => {
            const now = Math.floor(Date.now() / 1000);
            const completed = ['STOPPED', 'RESULT'].includes(status) ? now : '-';
            const payload = `R1|${ticket.request_id}|${ticket.session_id}|${status}|${count}|${now}|${completed}`;
            return `${payload}|${sign(payload, Buffer.alloc(32, 17))}`;
        },
    };
}

test('signed H/P/S/Q/T/R flow preserves final proof and rejects a foreign user', async () => {
    const h = harness();
    for (const [command, state] of [['ESTADO', 'IDLE'], ['PREPARARCONTEO', 'READY']]) {
        const ticket = await h.issue(command);
        assert.equal((await h.service.verify('user', h.reply(ticket, state))).proof, null);
    }
    const start = await h.issue('INICIARCONTEO');
    const started = h.reply(start, 'STARTED');
    await assert.rejects(h.service.verify('other', started), error => error.status === 403);
    await h.service.verify('user', started);
    const repeatedStart = await h.issue('INICIARCONTEO');
    assert.equal(repeatedStart.command, 'Q');
    assert.equal(repeatedStart.session_id, start.session_id);
    const progress = await h.service.verify('user', h.reply(repeatedStart, 'RUNNING', 12));
    assert.equal(progress.count, '12');
    assert.equal(progress.proof, null);
    const stop = await h.issue('DETENERCONTEO', start.session_id);
    const proof = h.reply(stop, 'STOPPED', 27);
    const final = await h.service.verify('user', proof);
    assert.equal(final.proof, proof);
    assert.equal(h.docs.get(h.devicePath).lease_until, 0);
    assert.deepEqual(await h.service.verify('user', proof), final);
    const result = await h.issue('RESULTADOCONTEO', start.session_id);
    assert.equal((await h.service.verify('user', h.reply(result, 'RESULT', 27))).count, '27');
    const altered = h.reply(result, 'RESULT', 28);
    await assert.rejects(h.service.verify('user', altered), error => error.status === 409);
});

test('late H/IDLE issued before a count cannot release its new lease', async () => {
    const h = harness();
    const old = await h.issue('ESTADO');
    const start = await h.issue('INICIARCONTEO');
    await h.service.verify('user', h.reply(start, 'STARTED'));
    await h.service.verify('user', h.reply(old, 'IDLE'));
    assert.equal(h.docs.get(h.devicePath).session_id, start.session_id);
    assert.ok(h.docs.get(h.devicePath).lease_until > 0);
});

test('H/IDLE only releases the lease that existed when H was issued', async () => {
    const h = harness();
    const first = await h.issue('INICIARCONTEO');
    const old = await h.issue('ESTADO');
    assert.equal(old.lease_session_id, first.session_id);
    h.docs.get(h.devicePath).lease_until = 0;
    const second = await h.issue('INICIARCONTEO');
    await h.service.verify('user', h.reply(old, 'IDLE'));
    assert.equal(h.docs.get(h.devicePath).session_id, second.session_id);
    const fresh = await h.issue('ESTADO');
    await h.service.verify('user', h.reply(fresh, 'IDLE'));
    assert.equal(h.docs.get(h.devicePath).session_id, undefined);
    assert.equal(h.docs.get(h.devicePath).lease_until, 0);
});

test('late session poll cannot overwrite a more recent response or release its lease', async () => {
    const h = harness();
    const start = await h.issue('INICIARCONTEO');
    const old = await h.issue('ESTADOCONTEO', start.session_id);
    const recent = await h.issue('ESTADOCONTEO', start.session_id);
    // Simular orden de emision distinto sin sleeps ni depender del reloj real.
    h.docs.get(`IotCommands/${old.request_id}`).issued_at_ms = 1000;
    h.docs.get(`IotCommands/${recent.request_id}`).issued_at_ms = 2000;
    await h.service.verify('user', h.reply(recent, 'RUNNING', 4));
    await h.service.verify('user', h.reply(old, 'IDLE'));
    assert.equal(h.docs.get(`IotSessions/${start.session_id}`).status, 'RUNNING');
    assert.equal(h.docs.get(h.devicePath).session_id, start.session_id);
    assert.ok(h.docs.get(h.devicePath).lease_until > 0);
});

test('late H cannot release the same lease after a newer RUNNING confirmation', async () => {
    const h = harness();
    const start = await h.issue('INICIARCONTEO');
    const old = await h.issue('ESTADO');
    const recent = await h.issue('ESTADOCONTEO', start.session_id);
    h.docs.get(`IotCommands/${old.request_id}`).issued_at_ms = 1000;
    h.docs.get(`IotCommands/${recent.request_id}`).issued_at_ms = 2000;
    await h.service.verify('user', h.reply(recent, 'RUNNING', 4));
    await h.service.verify('user', h.reply(old, 'IDLE'));
    assert.equal(h.docs.get(h.devicePath).session_id, start.session_id);
    assert.ok(h.docs.get(h.devicePath).lease_until > 0);
    const fresh = await h.issue('ESTADO');
    await h.service.verify('user', h.reply(fresh, 'IDLE'));
    assert.equal(h.docs.get(h.devicePath).session_id, undefined);
});

test('worker ERROR never produces proof and frees only its own lease', async () => {
    const h = harness();
    const start = await h.issue('INICIARCONTEO');
    const result = await h.service.verify('user', h.reply(start, 'ERROR'));
    assert.equal(result.count, 'unknown');
    assert.equal(result.proof, null);
    assert.equal(h.docs.get(h.devicePath).lease_until, 0);
});
