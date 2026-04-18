const { auth, db } = require('../config/firebaseAdmin');

function getBearerToken(req) {
    const authorization = req.headers.authorization || '';

    if (!authorization.startsWith('Bearer ')) {
        return null;
    }

    return authorization.replace('Bearer ', '').trim();
}

async function verifyRequestToken(req, res) {
    const idToken = getBearerToken(req);

    if (!idToken) {
        res.status(401).json({
            message: 'Token no proporcionado.',
        });
        return null;
    }

    try {
        return await auth.verifyIdToken(idToken);
    } catch (error) {
        console.error('[AUTH] Error verificando ID token:', {
            code: error.code,
            message: error.message,
        });

        res.status(401).json({
            message: 'Token inválido o expirado.',
        });
        return null;
    }
}

async function loadUserProfile(uid, res) {
    try {
        return await db.collection('Usuarios').doc(uid).get();
    } catch (error) {
        console.error('[FIRESTORE] Error cargando perfil de usuario:', {
            code: error.code,
            message: error.message,
            details: error.details,
        });

        res.status(500).json({
            message:
                'No se pudo validar el perfil del usuario. Revisa las credenciales de Firebase Admin en el backend.',
        });
        return null;
    }
}

function normalizeRole(value) {
    return (value || '').toString().toLowerCase().trim();
}

function requireRoles(allowedRoles = []) {
    return async (req, res, next) => {
        const decodedToken = await verifyRequestToken(req, res);
        if (!decodedToken) return;

        const userDoc = await loadUserProfile(decodedToken.uid, res);
        if (!userDoc) return;

        if (!userDoc.exists) {
            return res.status(403).json({
                message: 'El usuario autenticado no tiene perfil en Firestore.',
            });
        }

        const userData = userDoc.data() || {};
        const rol = normalizeRole(userData.rol);
        const estado = normalizeRole(userData.estado);

        if (estado !== 'activo') {
            return res.status(403).json({
                message: 'El usuario está inactivo.',
            });
        }

        const normalizedAllowedRoles = allowedRoles.map(normalizeRole);

        if (normalizedAllowedRoles.length > 0 && !normalizedAllowedRoles.includes(rol)) {
            return res.status(403).json({
                message: 'No tienes permisos para acceder a este recurso.',
            });
        }

        req.user = {
            uid: decodedToken.uid,
            email: decodedToken.email || '',
            ...userData,
        };

        next();
    };
}

async function requireAdmin(req, res, next) {
    return requireRoles(['administrador'])(req, res, next);
}

module.exports = {
    requireAdmin,
    requireRoles,
};
