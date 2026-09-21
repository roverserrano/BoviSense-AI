const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { randomBytes } = require('node:crypto');

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Both Firebase emulators are required; production is forbidden.');
}
process.env.NODE_ENV = 'test';
process.env.IOT_SHARED_SECRET = '11'.repeat(32);
const { auth, db, FieldValue } = require('../../src/config/firebaseAdmin');
const { sign } = require('../../src/services/iotProtocol');
const { createUserService } = require('../../src/services/userService');
const app = require('../../src/app');
let server, base, adminToken, userToken, otherToken;
const requestId = () => randomBytes(16).toString('hex');
const profile = (correo, cedula) => ({
    nombre: 'Prueba', apellidos: 'Local', correo,
    cedula_identidad: cedula, telefono: 76543210,
    estado: 'activo', rol: 'usuario',
});

async function account(uid, rol = 'usuario') {
    const email = `${uid}@example.test`;
    await auth.createUser({ uid, email, password: 'Emulator-only-123!' });
    await db.doc(`Usuarios/${uid}`).set({ nombre: 'Prueba', apellidos: 'Local', correo: email, cedula_identidad: 1234567, telefono: 76543210, estado: 'activo', rol });
    const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password: 'Emulator-only-123!', returnSecureToken: true }),
    });
    return (await response.json()).idToken;
}

async function call(path, token = userToken, method = 'GET', data) {
    const response = await fetch(base + path, {
        method,
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(data === undefined ? {} : { body: JSON.stringify(data) }),
    });
    return { status: response.status, body: await response.json() };
}

before(async () => {
    await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-bovisense/databases/(default)/documents`, { method: 'DELETE' });
    await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/demo-bovisense/accounts`, { method: 'DELETE' });
    adminToken = await account('admin-test', 'administrador');
    userToken = await account('user-test');
    otherToken = await account('other-test');
    server = app.listen(0, '127.0.0.1');
    await once(server, 'listening');
    base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
    if (server) await new Promise(resolve => server.close(resolve));
    await db.terminate();
    const { deleteApp, getApp } = require('firebase-admin/app');
    await deleteApp(getApp());
});

test('health, authentication, roles and pagination', async () => {
    assert.equal((await call('/health', null)).status, 200);
    assert.equal((await call('/api/admin/usuarios', null)).status, 401);
    assert.equal((await call('/api/admin/usuarios', userToken)).status, 403);
    const first = await call('/api/admin/usuarios?limit=2', adminToken);
    assert.equal(first.body.usuarios.length, 2);
    const next = await call(`/api/admin/usuarios?limit=2&cursor=${first.body.next_cursor}`, adminToken);
    assert.equal(next.body.usuarios.length, 1);
    assert.equal((await call('/api/admin/usuarios?limit=2abc', adminToken)).status, 400);
});

test('signed counting is idempotent and isolated', async () => {
    await call('/api/ganadero/configuracion', userToken, 'PUT', { nombre_finca: 'Campo', cantidad_esperada: 30 });
    assert.equal((await call('/api/ganadero/conteos', userToken, 'POST', { cantidad_detectada: 27 })).status, 400);
    const id = requestId();
    const ticket = await call('/api/ganadero/iot/comandos', userToken, 'POST', { request_id: id, command: 'INICIARCONTEO' });
    assert.equal(ticket.status, 200);
    const now = Math.floor(Date.now() / 1000);
    const raw = `R1|${id}|${id}|RESULT|27|${now}|${now}`;
    const proof = `${raw}|${sign(raw)}`;
    assert.equal((await call('/api/ganadero/iot/respuestas', otherToken, 'POST', { frame: proof })).status, 403);
    const saved = await call('/api/ganadero/conteos', userToken, 'POST', { session_id: id, proof });
    assert.equal(saved.status, 201);
    assert.equal(saved.body.conteo.diferencia, -3);
    assert.equal((await call('/api/ganadero/conteos', userToken, 'POST', { session_id: id, proof })).status, 200);
    assert.equal((await db.collection('Usuarios/user-test/Conteos').get()).size, 1);
    assert.equal((await call(`/api/ganadero/conteos/${id}`, otherToken)).status, 404);
});

test('Firestore rules deny enumeration, foreign reads and writes', async () => {
    const url = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/demo-bovisense/databases/(default)/documents/`;
    const headers = { Authorization: `Bearer ${userToken}`, 'Content-Type': 'application/json' };
    assert.equal((await fetch(url + 'Usuarios/user-test', { headers })).status, 200);
    assert.equal((await fetch(url + 'Usuarios/other-test', { headers })).status, 403);
    assert.equal((await fetch(url + 'Usuarios', { headers })).status, 403);
    assert.equal((await fetch(url + 'Usuarios/user-test?updateMask.fieldPaths=rol', {
        method: 'PATCH', headers, body: JSON.stringify({ fields: { rol: { stringValue: 'administrador' } } }),
    })).status, 403);
    await db.doc('Usuarios/user-test').update({ operacion_pendiente: 'update' });
    assert.equal((await fetch(url + 'Usuarios/user-test', { headers })).status, 403);
    await db.doc('Usuarios/user-test').update({ operacion_pendiente: FieldValue.delete() });
});

test('user operations serialize cedulas, survive SMTP failure and delete children', async () => {
    const service = createUserService({
        db, auth, FieldValue,
        enviarActivacion: async () => { throw new Error('smtp unavailable'); },
    });
    const first = requestId();
    const second = requestId();
    const candidates = [
        [first, profile('first@example.test', 2345678)],
        [second, profile('second@example.test', 2345678)],
    ];
    const results = await Promise.allSettled(candidates.map(([uid, data]) =>
        service.execute(uid, 'create', data, 'admin-test')));
    assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
    const winnerIndex = results.findIndex(result => result.status === 'fulfilled');
    const [winner, data] = candidates[winnerIndex];
    assert.equal(results[winnerIndex].value.activationPending, true);
    await db.doc(`Usuarios/${winner}/Conteos/child`).set({ count: 1 });
    await service.execute(winner, 'delete', null, 'admin-test');
    await service.execute(winner, 'delete', null, 'admin-test');
    assert.equal((await db.doc(`Usuarios/${winner}/Conteos/child`).get()).exists, false);
    assert.equal((await db.doc(`CedulasUsuarios/${data.cedula_identidad}`).get()).exists, false);
});
