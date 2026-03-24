const express = require('express');

const { requireRoles } = require('../middlewares/profileAuthMiddleware');
const ganaderoController = require('../controllers/ganaderoController');

const router = express.Router();

router.use(requireRoles(['usuario', 'ganadero']));

router.get('/dashboard', ganaderoController.obtenerDashboard);
router.get('/configuracion', ganaderoController.obtenerConfiguracion);
router.put('/configuracion', ganaderoController.guardarConfiguracion);
router.get('/dispositivo', ganaderoController.obtenerDispositivo);
router.post('/conteos', ganaderoController.iniciarConteo);
router.get('/conteos', ganaderoController.listarConteos);
router.get('/conteos/:id', ganaderoController.obtenerConteoDetalle);
router.get('/alertas', ganaderoController.listarAlertas);
router.put('/alertas/:id/leer', ganaderoController.marcarAlertaLeida);

module.exports = router;