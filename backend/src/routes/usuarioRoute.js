// Duplicado historico sin montar: la API registra `usuarioRoutes.js` (plural)
// en `app.js` como `/api/admin/usuarios`. No agregar rutas nuevas aqui; este
// archivo se conserva solo como referencia (ver InformeAuditoria, BOV-LOW-002).
const express = require('express');

const { requireRoles } = require('../middlewares/profileAuthMiddleware');
const {
    listarUsuarios,
    crearUsuario,
    actualizarUsuario,
    eliminarUsuario,
} = require('../controllers/usuarioController');

const router = express.Router();

router.use(requireRoles(['administrador']));

router.get('/', listarUsuarios);
router.post('/', crearUsuario);
router.put('/:uid', actualizarUsuario);
router.delete('/:uid', eliminarUsuario);

module.exports = router;