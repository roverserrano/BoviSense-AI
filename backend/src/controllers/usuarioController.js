const { auth, db, FieldValue } = require('../config/firebaseAdmin');
const { enviarActivacion } = require('../services/mailService');
const { createUserService } = require('../services/userService');
const { object, text, integer, documentId, hexId, HttpError, respondError } = require('../utils/validation');
const { page } = require('../utils/pagination');

const service = createUserService({ db, auth, FieldValue, enviarActivacion });

function normalizeUsuario(uid, data = {}) {
    const date = value => value?.toDate ? value.toDate().toISOString() : value || null;
    return {
        uid, nombre: data.nombre || '', apellidos: data.apellidos || data.apellido || '',
        correo: data.correo || '', cedula_identidad: data.cedula_identidad || data.CI || 0,
        telefono: data.telefono || 0, rol: data.rol || 'usuario', estado: data.estado || 'inactivo',
        fecha_registro: date(data.fecha_registro || data.fechaRegistro),
        fecha_actualizacion: date(data.fecha_actualizacion),
        operacion_pendiente: data.operacion_pendiente || null,
    };
}

function validarPayload(input) {
    const body = object(input);
    const result = {
        nombre: text(body.nombre, 'Nombre', 60),
        apellidos: text(body.apellidos ?? body.apellido, 'Apellidos', 80),
        cedula_identidad: integer(body.cedula_identidad ?? body.CI, 'Cedula', 1000000, 99999999),
        correo: text(body.correo, 'Correo', 254).toLowerCase(),
        telefono: integer(body.telefono, 'Telefono', 10000000, 99999999),
        rol: text(body.rol || 'usuario', 'Rol', 20).toLowerCase(),
        estado: text(body.estado || 'activo', 'Estado', 20).toLowerCase(),
    };
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result.correo)) throw new HttpError(400, 'Correo invalido.');
    if (!['administrador', 'usuario'].includes(result.rol)) throw new HttpError(400, 'Rol invalido.');
    if (!['activo', 'inactivo'].includes(result.estado)) throw new HttpError(400, 'Estado invalido.');
    return result;
}

async function listarUsuarios(req, res) {
    try {
        // Orden alfabetico por nombre: el administrador busca personas, no
        // identificadores. El resumen solo se calcula en la primera pagina.
        const result = await page(db.collection('Usuarios'), req.query, 'nombre', 'asc');
        const body = {
            usuarios: result.docs.map(doc => normalizeUsuario(doc.id, doc.data())),
            next_cursor: result.next_cursor,
        };
        if (!req.query.cursor) {
            const [total, activos, inactivos, administradores] = await Promise.all([
                db.collection('Usuarios').count().get(),
                db.collection('Usuarios').where('estado', '==', 'activo').count().get(),
                db.collection('Usuarios').where('estado', '==', 'inactivo').count().get(),
                db.collection('Usuarios').where('rol', '==', 'administrador').count().get(),
            ]);
            body.resumen = {
                total: total.data().count,
                activos: activos.data().count,
                inactivos: inactivos.data().count,
                administradores: administradores.data().count,
            };
        }
        return res.json(body);
    } catch (error) { return respondError(res, error); }
}

async function crearUsuario(req, res) {
    try {
        const payload = validarPayload(req.body);
        const uid = hexId(req.body.request_id);
        const result = await service.execute(uid, 'create', payload, req.user.uid);
        return res.status(201).json({
            usuario: normalizeUsuario(uid, result.user),
            activation_pending: result.activationPending,
            message: result.activationPending
                ? 'Cuenta creada. No se pudo enviar el enlace; el usuario puede usar Recuperar contrasena.'
                : 'Cuenta creada. Se envio un enlace para establecer la contrasena.',
        });
    } catch (error) { return respondError(res, error); }
}

async function actualizarUsuario(req, res) {
    try {
        const uid = documentId(req.params.uid);
        const payload = validarPayload(req.body);
        if (uid === req.user.uid && (payload.rol !== 'administrador' || payload.estado !== 'activo')) {
            throw new HttpError(400, 'No puedes quitar tu propio acceso administrativo.');
        }
        const result = await service.execute(uid, 'update', payload, req.user.uid);
        return res.json({ usuario: normalizeUsuario(uid, result.user), message: 'Usuario actualizado.' });
    } catch (error) { return respondError(res, error); }
}

async function eliminarUsuario(req, res) {
    try {
        const uid = documentId(req.params.uid);
        if (uid === req.user.uid) throw new HttpError(400, 'No puedes eliminar tu propio usuario.');
        await service.execute(uid, 'delete', null, req.user.uid);
        return res.json({ message: 'Usuario eliminado.' });
    } catch (error) { return respondError(res, error); }
}

module.exports = { listarUsuarios, crearUsuario, actualizarUsuario, eliminarUsuario };
