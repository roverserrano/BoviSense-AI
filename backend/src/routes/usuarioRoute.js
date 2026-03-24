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