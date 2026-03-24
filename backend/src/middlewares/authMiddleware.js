const { auth, db } = require('../config/firebaseAdmin');

async function requireAdmin(req, res, next) {
    try {
        const authorization = req.headers.authorization || '';

        if (!authorization.startsWith('Bearer ')) {
            return res.status(401).json({
                message: 'Token no proporcionado.',
            });
        }

        const idToken = authorization.replace('Bearer ', '').trim();
        const decodedToken = await auth.verifyIdToken(idToken);

        const userDoc = await db.collection('Usuarios').doc(decodedToken.uid).get();

        if (!userDoc.exists) {
            return res.status(403).json({
                message: 'El usuario autenticado no tiene perfil en Firestore.',
            });
        }

        const userData = userDoc.data() || {};
        const rol = (userData.rol || '').toString().toLowerCase();

        if (rol !== 'administrador') {
            return res.status(403).json({
                message: 'Acceso denegado. Solo administradores.',
            });
        }

        req.user = {
            uid: decodedToken.uid,
            ...userData,
        };

        next();
    } catch (error) {
        console.error('Error verificando token:', error.message);
        return res.status(401).json({
            message: 'Token inválido o expirado.',
        });
    }
}

module.exports = {
    requireAdmin,
};