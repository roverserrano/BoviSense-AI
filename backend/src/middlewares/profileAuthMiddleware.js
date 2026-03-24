const { auth, db } = require('../config/firebaseAdmin');

function requireRoles(allowedRoles = []) {
  return async (req, res, next) => {
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
      const estado = (userData.estado || '').toString().toLowerCase();

      if (estado !== 'activo') {
        return res.status(403).json({
          message: 'El usuario está inactivo.',
        });
      }

      const normalizedAllowedRoles = allowedRoles.map((item) =>
        item.toString().toLowerCase().trim(),
      );

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
    } catch (error) {
      console.error('Error verificando token:', error.message);
      return res.status(401).json({
        message: error.message || 'Token inválido o expirado.',
      });
    }
  };
}

module.exports = {
  requireRoles,
};