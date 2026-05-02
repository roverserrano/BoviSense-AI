const path = require('path');
require('dotenv').config({
    path: path.resolve(__dirname, '../.env'),
});

const express = require('express');
const cors = require('cors');

const usuarioRoutes = require('./routes/usuarioRoutes');
const ganaderoRoutes = require('./routes/ganaderoRoutes');

const app = express();

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
    console.log(`[REQ] ${req.method} ${req.originalUrl}`);
    next();
});

app.get('/health', (_, res) => {
    return res.status(200).json({
        ok: true,
        service: 'bobisense-ai-backend',
    });
});

app.use('/api/admin/usuarios', usuarioRoutes);
app.use('/api/ganadero', ganaderoRoutes);

app.use((_, res) => {
    return res.status(404).json({
        message: 'Ruta no encontrada.',
    });
});

const PORT = Number(process.env.PORT || 3000);

if (process.env.VERCEL !== '1') {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Servidor corriendo en http://0.0.0.0:${PORT}`);
        console.log(
            'GOOGLE_APPLICATION_CREDENTIALS =',
            process.env.GOOGLE_APPLICATION_CREDENTIALS || 'NO DEFINIDO',
        );
    });
}

module.exports = app;
