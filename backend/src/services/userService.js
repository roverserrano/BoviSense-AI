const { createHash, randomUUID } = require('node:crypto');
const { HttpError } = require('../utils/validation');
const { generarPasswordInicial } = require('../utils/passwordGenerator');

function createUserService({ db, auth, FieldValue, enviarActivacion }) {
    const users = db.collection('Usuarios');
    const cedulas = db.collection('CedulasUsuarios');
    const operations = db.collection('OperacionesUsuarios');

    // Auth and Firestore cannot share a transaction. A durable operation blocks
    // access during partial changes and lets the same request resume safely.
    async function execute(uid, action, payload, actor) {
        const lease = randomUUID();
        const fingerprint = createHash('sha256').update(JSON.stringify({ action, payload })).digest('hex');
        const opRef = operations.doc(uid);
        const userRef = users.doc(uid);
        const operation = await db.runTransaction(async tx => {
            const op = await tx.get(opRef);
            const user = await tx.get(userRef);
            const previous = op.data();
            if (previous?.status === 'done' && previous.fingerprint === fingerprint) return previous;
            if (previous?.status === 'pending' && previous.lease_until > Date.now()) throw new HttpError(409, 'Hay una operacion en curso. Intenta nuevamente en unos minutos.');
            if (previous?.status === 'pending' && previous.fingerprint !== fingerprint) throw new HttpError(409, 'Reintenta primero la operacion pendiente con los mismos datos.');
            if (action !== 'create' && !user.exists && previous?.status !== 'pending') throw new HttpError(404, 'Usuario no encontrado.');
            if (action === 'create' && user.exists && previous?.status !== 'pending') throw new HttpError(409, 'La solicitud de alta ya existe.');
            const original = previous?.status === 'pending' ? previous.original : user.data() || null;
            const targetCedula = action === 'delete' ? original.cedula_identidad : payload.cedula_identidad;
            const index = await tx.get(cedulas.doc(String(targetCedula)));
            if (index.exists && index.data().uid !== uid) throw new HttpError(409, 'Ya existe un usuario registrado con esa cedula.');
            const data = { action, payload, fingerprint, original, actor, status: 'pending', lease, lease_until: Date.now() + 300000 };
            tx.set(opRef, data);
            if (action !== 'delete') tx.set(index.ref, { uid, correo: payload.correo });
            if (user.exists) tx.update(userRef, { operacion_pendiente: action });
            return data;
        });
        if (operation.status === 'done') return { user: operation.result, activationPending: operation.activation_pending || false };

        let authChanged = false;
        try {
            if (action === 'delete') {
                await auth.deleteUser(uid).catch(error => { if (error.code !== 'auth/user-not-found') throw error; });
                // Also remove counts/configuration: deleting only the parent leaves orphans.
                await db.recursiveDelete(userRef);
                for (const collection of ['IotSessions', 'IotCommands']) {
                    while (true) {
                        const owned = await db.collection(collection).where('uid', '==', uid).limit(200).get();
                        if (owned.empty) break;
                        const batch = db.batch();
                        owned.docs.forEach(doc => batch.delete(doc.ref));
                        await batch.commit();
                    }
                }
            } else if (action === 'create') {
                try {
                    await auth.createUser({ uid, email: payload.correo, password: generarPasswordInicial(), displayName: `${payload.nombre} ${payload.apellidos}`, disabled: payload.estado !== 'activo' });
                } catch (error) {
                    if (error.code !== 'auth/uid-already-exists') throw error;
                    const existing = await auth.getUser(uid);
                    if (existing.email !== payload.correo) throw new HttpError(409, 'El identificador ya pertenece a otra cuenta.');
                }
            } else {
                await auth.updateUser(uid, { email: payload.correo, displayName: `${payload.nombre} ${payload.apellidos}`, disabled: payload.estado !== 'activo' });
                await auth.revokeRefreshTokens(uid);
            }
            authChanged = true;

            const result = action === 'delete' ? null : {
                ...payload,
                fecha_registro: operation.original?.fecha_registro || FieldValue.serverTimestamp(),
                fecha_actualizacion: FieldValue.serverTimestamp(),
            };
            await db.runTransaction(async tx => {
                const op = await tx.get(opRef);
                if (op.data()?.lease !== lease) throw new HttpError(409, 'La operacion fue retomada por otra solicitud.');
                const oldCedula = operation.original?.cedula_identidad;
                const oldIndex = oldCedula ? await tx.get(cedulas.doc(String(oldCedula))) : null;
                if (oldIndex?.data()?.uid === uid && (action === 'delete' || oldCedula !== payload.cedula_identidad)) tx.delete(oldIndex.ref);
                if (result) tx.set(userRef, result);
                tx.update(opRef, { status: 'done', lease_until: 0, original: null, result, activation_pending: action === 'create' });
            });
            if (action === 'create') {
                try {
                    const enlace = await auth.generatePasswordResetLink(payload.correo);
                    await enviarActivacion({ correo: payload.correo, nombreCompleto: `${payload.nombre} ${payload.apellidos}`, enlace });
                    await opRef.update({ activation_pending: false });
                } catch (error) {
                    console.error(JSON.stringify({ event: 'activation_mail_pending', code: error.code || 'mail/error' }));
                    // Account remains usable via Firebase's password recovery flow.
                    return { user: (await userRef.get()).data(), activationPending: true };
                }
            }
            return { user: result ? (await userRef.get()).data() : null, activationPending: false };
        } catch (error) {
            await db.runTransaction(async tx => {
                const op = await tx.get(opRef);
                if (op.data()?.lease !== lease || op.data()?.status !== 'pending') return;
                const permanent = ['auth/email-already-exists', 'auth/invalid-email', 'auth/invalid-password'].includes(error.code);
                if (!authChanged && permanent) {
                    const reserved = payload ? await tx.get(cedulas.doc(String(payload.cedula_identidad))) : null;
                    if (reserved?.data()?.uid === uid && operation.original?.cedula_identidad !== payload.cedula_identidad) tx.delete(reserved.ref);
                    if (operation.original) tx.set(userRef, operation.original);
                    tx.delete(opRef);
                } else {
                    tx.update(opRef, { lease_until: 0 });
                }
            }).catch(() => {});
            throw error;
        }
    }
    return { execute };
}

module.exports = { createUserService };
