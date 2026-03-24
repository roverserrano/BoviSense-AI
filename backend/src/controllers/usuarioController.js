const { auth, db, FieldValue } = require('../config/firebaseAdmin');
const { enviarCredenciales } = require('../services/mailService');
const { generarPasswordInicial } = require('../utils/passwordGenerator');

const usuariosCollection = db.collection('Usuarios');
const cedulasCollection = db.collection('CedulasUsuarios');

function cleanText(value = '') {
    return value.toString().trim();
}

function normalizeEmail(value = '') {
    return cleanText(value).toLowerCase();
}

function toInt(value) {
    if (typeof value === 'number') return Math.trunc(value);
    return Number.parseInt(value, 10);
}

function mapFirebaseError(error) {
    switch (error?.code) {
        case 'auth/email-already-exists':
            return 'El correo ya está registrado en Authentication.';
        case 'auth/user-not-found':
            return 'Usuario no encontrado.';
        case 'auth/invalid-email':
            return 'Correo inválido.';
        case 'auth/invalid-password':
            return 'La contraseña generada no es válida.';
        default:
            return error?.message || 'Error interno del servidor.';
    }
}

function normalizeUsuario(uid, data = {}) {
    const nombre = data.nombre ?? '';
    const apellidos = data.apellidos ?? data.apellido ?? '';
    const cedula = data.cedula_identidad ?? data.CI ?? 0;
    const fechaRegistro = data.fecha_registro ?? data.fechaRegistro ?? null;

    return {
        uid,
        nombre: nombre.toString(),
        apellidos: apellidos.toString(),
        cedula_identidad: toInt(cedula) || 0,
        correo: (data.correo ?? '').toString(),
        telefono: toInt(data.telefono) || 0,
        rol: (data.rol ?? 'usuario').toString().toLowerCase(),
        estado: (data.estado ?? 'activo').toString().toLowerCase(),
        fecha_registro: fechaRegistro && typeof fechaRegistro.toDate === 'function'
            ? fechaRegistro.toDate().toISOString()
            : fechaRegistro instanceof Date
                ? fechaRegistro.toISOString()
                : fechaRegistro,
        fecha_actualizacion: data.fecha_actualizacion && typeof data.fecha_actualizacion.toDate === 'function'
            ? data.fecha_actualizacion.toDate().toISOString()
            : data.fecha_actualizacion instanceof Date
                ? data.fecha_actualizacion.toISOString()
                : data.fecha_actualizacion ?? null,
    };
}

function validarPayload(body) {
    const nombre = cleanText(body.nombre);
    const apellidos = cleanText(body.apellidos ?? body.apellido);
    const cedula_identidad = toInt(body.cedula_identidad ?? body.CI);
    const correo = normalizeEmail(body.correo);
    const telefono = toInt(body.telefono);
    const rol = cleanText(body.rol || 'usuario').toLowerCase();
    const estado = cleanText(body.estado || 'activo').toLowerCase();

    if (!nombre) {
        throw new Error('El nombre es obligatorio.');
    }

    if (!apellidos) {
        throw new Error('Los apellidos son obligatorios.');
    }

    if (!Number.isInteger(cedula_identidad) || cedula_identidad <= 0) {
        throw new Error('La cédula de identidad no es válida.');
    }

    if (!Number.isInteger(telefono) || telefono <= 0) {
        throw new Error('El teléfono no es válido.');
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(correo)) {
        throw new Error('El correo no es válido.');
    }

    if (!['administrador', 'usuario'].includes(rol)) {
        throw new Error('El rol debe ser administrador o usuario.');
    }

    if (!['activo', 'inactivo'].includes(estado)) {
        throw new Error('El estado debe ser activo o inactivo.');
    }

    return {
        nombre,
        apellidos,
        cedula_identidad,
        correo,
        telefono,
        rol,
        estado,
    };
}

enviarCredenciales

async function listarUsuarios(req, res) {
    try {
        const snapshot = await usuariosCollection.get();

        const usuarios = snapshot.docs
            .map((doc) => normalizeUsuario(doc.id, doc.data()))
            .sort((a, b) => {
                const dateA = a.fecha_registro ? new Date(a.fecha_registro).getTime() : 0;
                const dateB = b.fecha_registro ? new Date(b.fecha_registro).getTime() : 0;
                return dateB - dateA;
            });

        return res.status(200).json({ usuarios });
    } catch (error) {
        console.error('Error listando usuarios:', error);
        return res.status(500).json({
            message: mapFirebaseError(error),
        });
    }
}

async function crearUsuario(req, res) {
    let createdUid = null;
    let createdCedulaDoc = null;

    try {
        const payload = validarPayload(req.body);

        const cedulaRef = cedulasCollection.doc(String(payload.cedula_identidad));
        const cedulaDoc = await cedulaRef.get();

        if (cedulaDoc.exists) {
            return res.status(400).json({
                message: 'Ya existe un usuario registrado con esa cédula.',
            });
        }

        const password = generarPasswordInicial(payload.nombre, payload.apellidos);
        const nombreCompleto = `${payload.nombre} ${payload.apellidos}`.trim();

        const userRecord = await auth.createUser({
            email: payload.correo,
            password,
            displayName: nombreCompleto,
            disabled: payload.estado !== 'activo',
        });

        createdUid = userRecord.uid;
        createdCedulaDoc = String(payload.cedula_identidad);

        await usuariosCollection.doc(createdUid).set({
            nombre: payload.nombre,
            apellidos: payload.apellidos,
            cedula_identidad: payload.cedula_identidad,
            correo: payload.correo,
            telefono: payload.telefono,
            rol: payload.rol,
            estado: payload.estado,
            fecha_registro: FieldValue.serverTimestamp(),
            fecha_actualizacion: FieldValue.serverTimestamp(),
        });

        await cedulasCollection.doc(String(payload.cedula_identidad)).set({
            uid: createdUid,
            correo: payload.correo,
            fecha_registro: FieldValue.serverTimestamp(),
        });

        const savedDoc = await usuariosCollection.doc(createdUid).get();

        try {
            await enviarCredenciales({
                correo: payload.correo,
                nombreCompleto,
                password,
            });
        } catch (error) {
            console.error('[MAIL] Error enviando credenciales:', error);
        }

        return res.status(201).json({
            message: 'Usuario creado correctamente.',
            usuario: normalizeUsuario(savedDoc.id, savedDoc.data()),
        });
    } catch (error) {
        console.error('Error creando usuario:', error);

        if (createdUid) {
            await auth.deleteUser(createdUid).catch(() => null);
            await usuariosCollection.doc(createdUid).delete().catch(() => null);
        }

        if (createdCedulaDoc) {
            await cedulasCollection.doc(createdCedulaDoc).delete().catch(() => null);
        }

        return res.status(400).json({
            message: mapFirebaseError(error),
        });
    }
}

async function actualizarUsuario(req, res) {
    try {
        const { uid } = req.params;
        const payload = validarPayload(req.body);

        const currentDoc = await usuariosCollection.doc(uid).get();

        if (!currentDoc.exists) {
            return res.status(404).json({
                message: 'Usuario no encontrado.',
            });
        }

        const currentData = normalizeUsuario(uid, currentDoc.data());

        if (currentData.cedula_identidad !== payload.cedula_identidad) {
            const newCedulaDoc = await cedulasCollection.doc(String(payload.cedula_identidad)).get();
            if (newCedulaDoc.exists) {
                return res.status(400).json({
                    message: 'Ya existe un usuario registrado con esa cédula.',
                });
            }
        }

        await auth.updateUser(uid, {
            email: payload.correo,
            displayName: `${payload.nombre} ${payload.apellidos}`.trim(),
            disabled: payload.estado !== 'activo',
        });

        await usuariosCollection.doc(uid).update({
            nombre: payload.nombre,
            apellidos: payload.apellidos,
            cedula_identidad: payload.cedula_identidad,
            correo: payload.correo,
            telefono: payload.telefono,
            rol: payload.rol,
            estado: payload.estado,
            fecha_actualizacion: FieldValue.serverTimestamp(),
        });

        if (currentData.cedula_identidad !== payload.cedula_identidad) {
            await cedulasCollection.doc(String(currentData.cedula_identidad)).delete().catch(() => null);
            await cedulasCollection.doc(String(payload.cedula_identidad)).set({
                uid,
                correo: payload.correo,
                fecha_registro: FieldValue.serverTimestamp(),
            });
        } else {
            await cedulasCollection.doc(String(payload.cedula_identidad)).set({
                uid,
                correo: payload.correo,
                fecha_registro: FieldValue.serverTimestamp(),
            });
        }

        const updatedDoc = await usuariosCollection.doc(uid).get();

        return res.status(200).json({
            message: 'Usuario actualizado correctamente.',
            usuario: normalizeUsuario(updatedDoc.id, updatedDoc.data()),
        });
    } catch (error) {
        console.error('Error actualizando usuario:', error);
        return res.status(400).json({
            message: mapFirebaseError(error),
        });
    }
}

async function eliminarUsuario(req, res) {
    try {
        const { uid } = req.params;

        if (req.user.uid === uid) {
            return res.status(400).json({
                message: 'No puedes eliminar tu propio usuario.',
            });
        }

        const userDoc = await usuariosCollection.doc(uid).get();

        if (!userDoc.exists) {
            return res.status(404).json({
                message: 'Usuario no encontrado.',
            });
        }

        const userData = normalizeUsuario(uid, userDoc.data());

        await auth.deleteUser(uid).catch((error) => {
            throw error;
        });

        await usuariosCollection.doc(uid).delete();
        await cedulasCollection.doc(String(userData.cedula_identidad)).delete().catch(() => null);

        return res.status(200).json({
            message: 'Usuario eliminado correctamente.',
        });
    } catch (error) {
        console.error('Error eliminando usuario:', error);
        return res.status(400).json({
            message: mapFirebaseError(error),
        });
    }
}

module.exports = {
    listarUsuarios,
    crearUsuario,
    actualizarUsuario,
    eliminarUsuario,
};