const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const { createUserService } = require('../src/services/userService');

function createHarness({ failProfileCommit = false, failMail = false } = {}) {
    const documents = new Map();
    const accounts = new Map();
    const sent = [];
    const snapshot = ref => ({ ref, exists: documents.has(ref.path), data: () => structuredClone(documents.get(ref.path)) });
    const document = path => ({
        path,
        get: async () => snapshot(document(path)),
        update: async data => documents.set(path, { ...documents.get(path), ...structuredClone(data) }),
    });
    const db = {
        collection: name => ({ doc: uid => document(`${name}/${uid}`) }),
        runTransaction: async callback => {
            const changes = [];
            const result = await callback({
                get: async ref => snapshot(ref),
                set: (ref, data) => changes.push({ action: 'set', path: ref.path, data }),
                update: (ref, data) => changes.push({ action: 'update', path: ref.path, data }),
                delete: ref => changes.push({ action: 'delete', path: ref.path }),
            });
            if (failProfileCommit && changes.some(change => change.data?.status === 'done')) {
                failProfileCommit = false;
                throw new Error('firestore unavailable');
            }
            for (const change of changes) {
                if (change.action === 'delete') documents.delete(change.path);
                else documents.set(change.path, {
                    ...(change.action === 'update' ? documents.get(change.path) : {}),
                    ...structuredClone(change.data),
                });
            }
            return result;
        },
    };
    const auth = {
        createUser: mock.fn(async input => {
            if (accounts.has(input.uid)) throw Object.assign(new Error('uid exists'), { code: 'auth/uid-already-exists' });
            accounts.set(input.uid, { ...input });
        }),
        getUser: async uid => accounts.get(uid),
        updateUser: mock.fn(async (uid, data) => accounts.set(uid, { ...accounts.get(uid), ...data })),
        revokeRefreshTokens: mock.fn(async () => {}),
        generatePasswordResetLink: mock.fn(async () => assert.fail('Account creation must not generate a reset link')),
    };
    const service = createUserService({
        db, auth,
        FieldValue: { serverTimestamp: () => new Date('2026-10-31T12:00:00Z') },
        enviarActivacion: async message => {
            if (failMail) throw Object.assign(new Error('SMTP authentication failed'), { code: 'EAUTH' });
            sent.push(message);
        },
    });
    return { service, documents, accounts, auth, sent };
}

const uid = 'a'.repeat(32);
const profile = {
    nombre: 'Pedro', apellidos: 'Carbon', correo: 'pedro@example.test',
    cedula_identidad: 1234567, telefono: 76543210, rol: 'usuario', estado: 'activo',
};

test('new users receive the same initial password configured in Authentication', async () => {
    const harness = createHarness();
    const result = await harness.service.execute(uid, 'create', profile, 'admin');
    const password = harness.accounts.get(uid).password;
    assert.equal(password, 'pcarbon');
    assert.equal(harness.sent.length, 1);
    assert.deepEqual(harness.sent[0], {
        correo: profile.correo, nombreCompleto: 'Pedro Carbon', contrasenaInicial: password,
    });
    assert.equal(result.activationPending, false);
    assert.equal(harness.documents.get(`OperacionesUsuarios/${uid}`).activation_pending, false);
    assert.equal(JSON.stringify(result).includes(password), false);
    assert.equal(JSON.stringify([...harness.documents]).includes(password), false);
    assert.equal(harness.auth.generatePasswordResetLink.mock.callCount(), 0);
});

test('retrying a completed creation preserves the password chosen by the user', async () => {
    const harness = createHarness();
    await harness.service.execute(uid, 'create', profile, 'admin');
    await harness.auth.updateUser(uid, { password: 'User-chosen-Password-123!' });
    const result = await harness.service.execute(uid, 'create', profile, 'admin');
    assert.equal(harness.accounts.get(uid).password, 'User-chosen-Password-123!');
    assert.equal(harness.auth.updateUser.mock.callCount(), 1);
    assert.equal(harness.sent.length, 1);
    assert.equal(result.activationPending, false);
});

test('SMTP failure preserves the account and reports pending credentials without exposing the password', async context => {
    const logs = [];
    context.mock.method(console, 'error', message => logs.push(message));
    const harness = createHarness({ failMail: true });
    const result = await harness.service.execute(uid, 'create', profile, 'admin');
    const password = harness.accounts.get(uid).password;
    assert.equal(result.activationPending, true);
    assert.deepEqual(result.user, harness.documents.get(`Usuarios/${uid}`));
    assert.equal(harness.documents.get(`OperacionesUsuarios/${uid}`).activation_pending, true);
    assert.equal(JSON.stringify([...harness.documents]).includes(password), false);
    assert.equal(JSON.stringify(result).includes(password), false);
    assert.equal(JSON.stringify(logs).includes(password), false);
    assert.deepEqual(JSON.parse(logs[0]), { event: 'activation_mail_pending', code: 'EAUTH' });
});

test('resuming an incomplete creation restores the name-based initial password before mailing credentials', async () => {
    const harness = createHarness({ failProfileCommit: true });
    await assert.rejects(harness.service.execute(uid, 'create', profile, 'admin'), /firestore unavailable/);
    const firstPassword = harness.accounts.get(uid).password;
    assert.equal(harness.sent.length, 0);
    harness.accounts.get(uid).password = 'Unsent-password-123!';
    const result = await harness.service.execute(uid, 'create', profile, 'admin');
    const currentPassword = harness.accounts.get(uid).password;
    assert.equal(currentPassword, firstPassword);
    assert.equal(harness.sent[0].contrasenaInicial, currentPassword);
    assert.equal(harness.auth.updateUser.mock.callCount(), 1);
    assert.equal(result.activationPending, false);
    assert.equal(JSON.stringify([...harness.documents]).includes(currentPassword), false);
});

test('resumed creation does not change credentials belonging to another email', async () => {
    const harness = createHarness();
    harness.accounts.set(uid, { email: 'other@example.test', password: 'Existing-Password-123!' });
    await assert.rejects(harness.service.execute(uid, 'create', profile, 'admin'), error => error.status === 409);
    assert.equal(harness.auth.updateUser.mock.callCount(), 0);
    assert.equal(harness.sent.length, 0);
    assert.equal(harness.accounts.get(uid).password, 'Existing-Password-123!');
});

test('profile updates do not reset passwords or send initial credentials again', async () => {
    const harness = createHarness();
    await harness.service.execute(uid, 'create', profile, 'admin');
    const password = harness.accounts.get(uid).password;
    await harness.service.execute(uid, 'update', { ...profile, nombre: 'Pedro Jose' }, 'admin');
    assert.equal(harness.accounts.get(uid).password, password);
    assert.equal(harness.sent.length, 1);
    assert.equal(harness.auth.updateUser.mock.calls[0].arguments[1].password, undefined);
});

test('invalid names fail before reserving an identity or creating an account', async () => {
    const harness = createHarness();
    await assert.rejects(harness.service.execute(uid, 'create', { ...profile, nombre: '!!!' }, 'admin'), error => error.status === 400);
    assert.equal(harness.documents.size, 0);
    assert.equal(harness.auth.createUser.mock.callCount(), 0);
    assert.equal(harness.sent.length, 0);
});
