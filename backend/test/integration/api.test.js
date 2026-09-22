const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { randomBytes } = require('node:crypto');

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Both Firebase emulators are required; production is forbidden.');
}
process.env.NODE_ENV = 'test';
process.env.IOT_SHARED_SECRET = '11'.repeat(32);
// Nunca enviar correos reales desde las pruebas: con la configuracion vacia el
// servicio falla rapido y la API responde con activation_pending.
for (const name of ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM']) process.env[name] = '';
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

// Igual que response_frame() de la Jetson: completed solo existe en estados finales.
function signResponse(requestId, session, status, count, completedAt = null, stampOverride = null) {
    const stamp = stampOverride ?? Math.floor(Date.now() / 1000);
    const terminal = status === 'STOPPED' || status === 'RESULT';
    const completed = completedAt ?? (terminal ? stamp : '-');
    const payload = `R1|${requestId}|${session}|${status}|${count}|${stamp}|${completed}`;
    return { payload, frame: `${payload}|${sign(payload)}`, stamp };
}

async function issueCommand(token, command, extra = {}) {
    const id = requestId();
    const ticket = await call('/api/ganadero/iot/comandos', token, 'POST', { request_id: id, command, ...extra });
    assert.equal(ticket.status, 200, `ticket ${command}`);
    return ticket.body;
}

function verifyFrame(token, frame) {
    return call('/api/ganadero/iot/respuestas', token, 'POST', { frame });
}

// Guarda un conteo completo usando una fecha de inicio explicita, para poder
// crear varios con fechas distintas en la misma prueba.
async function saveCount(token, count, stamp) {
    const start = await issueCommand(token, 'INICIARCONTEO');
    await verifyFrame(token, signResponse(start.request_id, start.session_id, 'STARTED', '-', null, stamp).frame);
    const stop = await issueCommand(token, 'DETENERCONTEO', { session_id: start.session_id });
    const stopped = signResponse(stop.request_id, start.session_id, 'STOPPED', count, null, stamp + 1);
    await verifyFrame(token, stopped.frame);
    const saved = await call('/api/ganadero/conteos', token, 'POST', { session_id: start.session_id, proof: stopped.frame });
    assert.equal(saved.status, 201, 'guardo el conteo');
    return start.session_id;
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

// Este recorrido reproduce, contra los emuladores, la mitad servidor del flujo
// completo documentado en AGENTS.md: estado, inicio, consulta, detencion,
// prueba final, guardado, historial y alerta. La Jetson real solo aporta las
// tramas R1 firmadas.
test('full count session issues, verifies and saves a signed result', async () => {
    const flowToken = await account('flow-test');
    const deviceId = process.env.IOT_DEVICE_ID || 'jetson-01';
    await call('/api/ganadero/configuracion', flowToken, 'PUT', { nombre_finca: 'Campo Norte', cantidad_esperada: 40 });

    // H: el equipo todavia no tiene sesion de conteo.
    const statusTicket = await issueCommand(flowToken, 'ESTADO');
    assert.equal(statusTicket.session_id, '-');
    const status = await verifyFrame(flowToken, signResponse(statusTicket.request_id, '-', 'IDLE', '-').frame);
    assert.equal(status.status, 200);
    assert.equal(status.body.status, 'IDLE');
    assert.equal(status.body.proof, null);

    // S: abre la sesion y reserva el dispositivo para ese usuario.
    const startTicket = await issueCommand(flowToken, 'INICIARCONTEO');
    const sessionId = startTicket.session_id;
    assert.equal(sessionId, startTicket.request_id);
    const started = await verifyFrame(flowToken, signResponse(startTicket.request_id, sessionId, 'STARTED', '-').frame);
    assert.equal(started.body.status, 'STARTED');
    assert.equal(started.body.proof, null);
    const lease = await db.doc(`IotDevices/${deviceId}`).get();
    assert.equal(lease.data().session_id, sessionId);
    assert.ok(lease.data().lease_until > Math.floor(Date.now() / 1000));

    // Una sesion ajena no puede consultar ni detener el equipo.
    const foreign = await call('/api/ganadero/iot/comandos', otherToken, 'POST', {
        request_id: requestId(), command: 'ESTADOCONTEO', session_id: sessionId,
    });
    assert.equal(foreign.status, 403);

    // Q: conteo parcial sin prueba final.
    const pollTicket = await issueCommand(flowToken, 'ESTADOCONTEO', { session_id: sessionId });
    const running = await verifyFrame(flowToken, signResponse(pollTicket.request_id, sessionId, 'RUNNING', 12).frame);
    assert.equal(running.body.status, 'RUNNING');
    assert.equal(running.body.count, '12');
    assert.equal(running.body.proof, null);

    // Un conteo parcial no puede guardarse como resultado final.
    const partialTicket = await issueCommand(flowToken, 'ESTADOCONTEO', { session_id: sessionId });
    const partial = signResponse(partialTicket.request_id, sessionId, 'RUNNING', 12);
    assert.equal((await call('/api/ganadero/conteos', flowToken, 'POST', {
        session_id: sessionId, proof: partial.frame,
    })).status, 400);

    // T: cierre de sesion con prueba final firmada.
    const stopTicket = await issueCommand(flowToken, 'DETENERCONTEO', { session_id: sessionId });
    const stopped = signResponse(stopTicket.request_id, sessionId, 'STOPPED', 27);
    const stoppedResult = await verifyFrame(flowToken, stopped.frame);
    assert.equal(stoppedResult.body.status, 'STOPPED');
    assert.equal(stoppedResult.body.count, '27');
    assert.equal(stoppedResult.body.proof, stopped.frame);
    assert.equal((await db.doc(`IotDevices/${deviceId}`).get()).data().lease_until, 0);

    // Guardado del resultado autenticado, historial y alerta por diferencia.
    const saved = await call('/api/ganadero/conteos', flowToken, 'POST', { session_id: sessionId, proof: stopped.frame });
    assert.equal(saved.status, 201);
    assert.equal(saved.body.conteo.cantidad_detectada, 27);
    assert.equal(saved.body.conteo.cantidad_esperada, 40);
    assert.equal(saved.body.conteo.diferencia, -13);
    assert.equal(saved.body.conteo.estado_conteo, 'finalizado');
    assert.equal((await call(`/api/ganadero/conteos/${sessionId}`, flowToken)).status, 200);
    assert.equal((await call('/api/ganadero/conteos', flowToken)).body.conteos.length, 1);

    const alerts = await call('/api/ganadero/alertas', flowToken);
    assert.equal(alerts.body.alertas.length, 1);
    assert.equal(alerts.body.alertas[0].tipo, 'faltante');
    assert.equal(alerts.body.alertas[0].nivel, 'alta');
    assert.equal((await call(`/api/ganadero/alertas/${sessionId}/leer`, flowToken, 'PUT')).status, 200);

    const dashboard = await call('/api/ganadero/dashboard', flowToken);
    assert.equal(dashboard.body.cantidad_conteos, 1);
    assert.equal(dashboard.body.alertas_pendientes, 0);
    assert.equal(dashboard.body.ultimo_conteo.diferencia, -13);
});

// Caso real reportado en campo: la Jetson se reinicia y pierde la sesion en
// memoria, pero el backend conserva el lease. Antes, el siguiente INICIARCONTEO
// se convertia en ESTADOCONTEO contra la sesion muerta y la app mostraba
// "Falla del equipo" sin forma de salir.
test('count history paginates with a real cursor', async () => {
    const token = await account('history-test');
    await call('/api/ganadero/configuracion', token, 'PUT', { nombre_finca: 'Campo Este', cantidad_esperada: 10 });

    const base = Math.floor(Date.now() / 1000) - 4;
    const expected = [];
    for (let index = 0; index < 5; index += 1) {
        expected.push(await saveCount(token, 8 + index, base + index * 20));
    }

    const first = await call('/api/ganadero/conteos?limit=2', token);
    assert.equal(first.body.conteos.length, 2);
    assert.ok(first.body.next_cursor, 'la primera pagina debe traer cursor');

    const second = await call(`/api/ganadero/conteos?limit=2&cursor=${encodeURIComponent(first.body.next_cursor)}`, token);
    assert.equal(second.body.conteos.length, 2);
    assert.ok(second.body.next_cursor, 'la segunda pagina debe traer cursor');

    const third = await call(`/api/ganadero/conteos?limit=2&cursor=${encodeURIComponent(second.body.next_cursor)}`, token);
    assert.equal(third.body.conteos.length, 1);
    assert.equal(third.body.next_cursor, null, 'la ultima pagina cierra la paginacion');

    const ids = [...first.body.conteos, ...second.body.conteos, ...third.body.conteos].map((conteo) => conteo.id);
    assert.equal(ids.length, 5, 'no se repiten ni se pierden conteos');
    assert.equal(new Set(ids).size, 5);
    assert.deepEqual([...ids].sort(), [...expected].sort());

    // Orden descendente: el conteo mas reciente primero.
    assert.equal(first.body.conteos[0].id, expected[4]);
    assert.equal(first.body.conteos[1].id, expected[3]);

    const alertas = await call('/api/ganadero/alertas?limit=50', token);
    assert.equal(alertas.body.alertas.length, 4, 'los conteos exactos no generan alerta');
    assert.equal(alertas.body.next_cursor, null);
});

test('admin user list is alphabetical, reports a summary and paginates', async () => {
    const createdNames = ['Ana', 'Bruno', 'Zoe'];
    for (let index = 0; index < createdNames.length; index += 1) {
        const response = await call('/api/admin/usuarios', adminToken, 'POST', {
            request_id: requestId(),
            nombre: createdNames[index],
            apellidos: 'Prueba',
            cedula_identidad: 30000000 + index,
            correo: `${createdNames[index].toLowerCase()}@example.test`,
            telefono: 70000000 + index,
            rol: 'usuario',
            estado: 'activo',
        });
        assert.equal(response.status, 201, `alta de ${createdNames[index]}`);
        // Sin SMTP configurado la cuenta queda recuperable por correo.
        assert.equal(response.body.activation_pending, true);
    }

    const listado = await call('/api/admin/usuarios?limit=100', adminToken);
    const nombres = listado.body.usuarios.map(usuario => usuario.nombre);
    assert.deepEqual([...nombres].sort(), nombres, 'orden alfabetico ascendente');
    for (const nombre of createdNames) assert.ok(nombres.includes(nombre), nombre);

    const resumen = listado.body.resumen;
    assert.equal(resumen.total, listado.body.usuarios.length);
    assert.equal(resumen.activos + resumen.inactivos, resumen.total);
    assert.ok(resumen.activos >= 3);
    assert.ok(resumen.administradores >= 1);

    // Paginacion: cada pagina sigue el mismo orden y el resumen va solo en la primera.
    const primera = await call('/api/admin/usuarios?limit=2', adminToken);
    const segunda = await call(`/api/admin/usuarios?limit=2&cursor=${encodeURIComponent(primera.body.next_cursor)}`, adminToken);
    assert.equal(segunda.body.resumen, undefined);
    const encadenado = [...primera.body.usuarios, ...segunda.body.usuarios].map(usuario => usuario.nombre);
    assert.deepEqual([...encadenado].sort(), encadenado);
});

test('a pending operation blocks access with a distinguishable message', async () => {
    await db.doc('Usuarios/user-test').update({ operacion_pendiente: 'update' });
    const bloqueado = await call('/api/ganadero/dashboard', userToken);
    assert.equal(bloqueado.status, 403);
    assert.match(bloqueado.body.message, /operación pendiente/);

    await db.doc('Usuarios/user-test').update({ operacion_pendiente: FieldValue.delete() });
    assert.equal((await call('/api/ganadero/dashboard', userToken)).status, 200);
});

test('an alert from the legacy collection can be marked as read', async () => {
    const token = await account('legacy-alert-test');
    await db.doc('Alertas/legacy-alert').set({
        uid: 'legacy-alert-test',
        mensaje: 'Se detectó un faltante de 5 animales respecto a la cantidad esperada.',
        tipo: 'faltante',
        nivel: 'media',
        leida: false,
        fecha_hora: FieldValue.serverTimestamp(),
    });

    const lista = await call('/api/ganadero/alertas', token);
    assert.equal(lista.body.alertas.length, 1);
    assert.equal(lista.body.alertas[0].leida, false);

    const marcada = await call('/api/ganadero/alertas/legacy-alert/leer', token, 'PUT');
    assert.equal(marcada.status, 200);
    assert.equal(marcada.body.alerta.leida, true);

    // La alerta de otro usuario no se puede modificar.
    assert.equal((await call('/api/ganadero/alertas/legacy-alert/leer', otherToken, 'PUT')).status, 404);
    assert.equal((await call('/api/ganadero/alertas', otherToken)).body.alertas.length, 0);
});

test('a device that lost its session releases the lease and can start again', async () => {
    const token = await account('restart-test');
    const deviceId = process.env.IOT_DEVICE_ID || 'jetson-01';
    await call('/api/ganadero/configuracion', token, 'PUT', { nombre_finca: 'Campo Sur', cantidad_esperada: 15 });

    const startTicket = await issueCommand(token, 'INICIARCONTEO');
    const sessionId = startTicket.session_id;
    await verifyFrame(token, signResponse(startTicket.request_id, sessionId, 'STARTED', '-').frame);
    assert.equal((await db.doc(`IotDevices/${deviceId}`).get()).data().session_id, sessionId);

    // Un segundo INICIARCONTEO del mismo usuario se reutiliza como consulta.
    const reused = await issueCommand(token, 'INICIARCONTEO');
    assert.equal(reused.command, 'Q');
    assert.equal(reused.session_id, sessionId);

    // La Jetson reiniciada responde IDLE: no conoce esa sesion.
    const idle = await verifyFrame(token, signResponse(reused.request_id, sessionId, 'IDLE', '-').frame);
    assert.equal(idle.body.status, 'IDLE');
    assert.equal(idle.body.proof, null);

    const device = await db.doc(`IotDevices/${deviceId}`).get();
    assert.equal(device.data().lease_until, 0);
    assert.equal(device.data().session_id, undefined);

    // Con el equipo liberado, el conteo nuevo si arranca una sesion nueva.
    const restarted = await issueCommand(token, 'INICIARCONTEO');
    assert.equal(restarted.command, 'S');
    assert.notEqual(restarted.session_id, sessionId);
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
