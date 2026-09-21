const nodemailer = require('nodemailer');

async function enviarActivacion({ correo, nombreCompleto, enlace }) {
    for (const name of ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS', 'SMTP_FROM']) {
        if (!process.env[name]) throw new Error('mail/configuration-missing');
    }
    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_SECURE === 'true',
        requireTLS: true,
        auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS.replace(/\s+/g, '') },
        connectionTimeout: 5000,
        greetingTimeout: 5000,
        socketTimeout: 10000,
        logger: false,
        debug: false,
    });
    try {
        const result = await transporter.sendMail({
            from: process.env.SMTP_FROM,
            to: correo,
            subject: 'Establece tu contrasena - BoviSense',
            text: `Hola ${nombreCompleto},\n\nTu cuenta de BoviSense esta disponible. Establece tu contrasena en este enlace de Firebase:\n${enlace}\n\nSi el enlace vence, usa Recuperar contrasena en la aplicacion.`,
        });
        if (!result.accepted?.length) throw new Error('mail/not-accepted');
    } finally {
        transporter.close();
    }
}

module.exports = { enviarActivacion };
