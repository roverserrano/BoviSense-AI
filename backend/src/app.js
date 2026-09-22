const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env'), quiet: true });
const os = require('os');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');
const { auth, db } = require('./config/firebaseAdmin');
const { HttpError, respondError } = require('./utils/validation');
const app = express();
const serverHostname = os.hostname();

if (process.env.VERCEL === '1') app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(helmet());
const origins = (process.env.CORS_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean);
app.use(cors({ origin: (origin, callback) => callback(null, !origin || origins.includes(origin)) }));
app.use(rateLimit({
    windowMs: 60000, limit: 120, standardHeaders: 'draft-7', legacyHeaders: false,
    message: { message: 'Demasiadas solicitudes. Intenta nuevamente en un minuto.' },
}));
app.use(express.json({ limit: '16kb', strict: true }));
app.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
});
app.use((req, res, next) => {
    const startedAt = process.hrtime.bigint();
    const requestId = req.get('x-request-id') || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
    req.requestId = requestId;
    res.set('X-Request-Id', requestId);
    console.log(`[${new Date().toISOString()}] [${serverHostname}] [${requestId}] -> ${req.method} ${req.originalUrl}`);
    res.on('finish', () => {
        const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1000000;
        console.log(`[${new Date().toISOString()}] [${serverHostname}] [${requestId}] <- ${res.statusCode} ${req.method} ${req.originalUrl} ${elapsedMs.toFixed(1)}ms`);
    });
    next();
});

let healthCheck;
let checkedAt = 0;
app.get('/health', async (_, res) => {
    if (!healthCheck || Date.now() - checkedAt > 15000) {
        checkedAt = Date.now();
        healthCheck = Promise.all([
            db.collection('Health').doc('probe').get(),
            auth.listUsers(1),
        ]).then(() => true, () => false);
    }
    let timer;
    const ok = await Promise.race([
        healthCheck,
        new Promise(resolve => { timer = setTimeout(() => resolve(false), 5000); }),
    ]);
    clearTimeout(timer);
    return res.status(ok ? 200 : 503).json({ ok, service: 'bovisense-ai-backend', hostname: serverHostname, firebase: ok ? 'ready' : 'unavailable' });
});

app.use('/api/admin/usuarios', require('./routes/usuarioRoutes'));
app.use('/api/ganadero', require('./routes/ganaderoRoutes'));
app.use((_, res) => res.status(404).json({ message: 'Ruta no encontrada.' }));
app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    console.error(`[${new Date().toISOString()}] [${serverHostname}] [${req.requestId || 'no-request-id'}] ERROR ${req.method} ${req.originalUrl}:`, error);
    if (error.type === 'entity.too.large') return respondError(res, new HttpError(413, 'Solicitud demasiado grande.'));
    if (error.type === 'entity.parse.failed') return respondError(res, new HttpError(400, 'JSON invalido.'));
    return respondError(res, error);
});

if (require.main === module) {
    const port = Number(process.env.PORT || 3000);
    const host = '0.0.0.0';
    const server = app.listen(port, host, () => {
        const iotSecretReady = /^[a-fA-F0-9]{64}$/.test(process.env.IOT_SHARED_SECRET || '');
        console.log(`[${new Date().toISOString()}] Backend BoviSense iniciado en http://${host}:${port}`);
        console.log(`[${new Date().toISOString()}] Hostname del servidor: ${serverHostname}`);
        console.log(`[${new Date().toISOString()}] Health check: http://127.0.0.1:${port}/health`);
        console.log(`[${new Date().toISOString()}] IoT device id: ${process.env.IOT_DEVICE_ID || 'jetson-01'}`);
        console.log(`[${new Date().toISOString()}] IoT shared secret: ${iotSecretReady ? 'configurado' : 'NO CONFIGURADO'}`);
    });
    const shutdown = () => {
        server.close(() => process.exit(0));
        setTimeout(() => process.exit(1), 10000).unref();
    };
    process.once('SIGTERM', shutdown);
    process.once('SIGINT', shutdown);
}

module.exports = app;
