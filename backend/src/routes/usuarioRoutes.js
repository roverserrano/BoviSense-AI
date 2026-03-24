const express = require('express');
const { requireAdmin } = require('../middlewares/authMiddleware');
const {
    listarUsuarios,
    crearUsuario,
    actualizarUsuario,
    eliminarUsuario,
} = require('../controllers/usuarioController');

const router = express.Router();

router.use(requireAdmin);

router.get('/', listarUsuarios);
router.post('/', crearUsuario);
router.put('/:uid', actualizarUsuario);
router.delete('/:uid', eliminarUsuario);

module.exports = router;