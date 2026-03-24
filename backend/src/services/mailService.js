const nodemailer = require('nodemailer');

function getTransportConfig() {
    return {
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
        },
        connectionTimeout: 10000,
        greetingTimeout: 10000,
        socketTimeout: 15000,
        logger: true,
        debug: true,
    };
}

function validateMailEnv() {
    const missing = [];

    if (!process.env.SMTP_HOST) missing.push('SMTP_HOST');
    if (!process.env.SMTP_PORT) missing.push('SMTP_PORT');
    if (!process.env.SMTP_USER) missing.push('SMTP_USER');
    if (!process.env.SMTP_PASS) missing.push('SMTP_PASS');
    if (!process.env.SMTP_FROM) missing.push('SMTP_FROM');

    if (missing.length > 0) {
        throw new Error(
            `Faltan variables SMTP en .env: ${missing.join(', ')}`,
        );
    }
}

async function enviarCredenciales({ correo, nombreCompleto, password }) {
    validateMailEnv();

    const transporter = nodemailer.createTransport(getTransportConfig());

    console.log('[MAIL] Verificando conexión SMTP...');
    await transporter.verify();
    console.log('[MAIL] SMTP verificado correctamente.');

    const info = await transporter.sendMail({
        from: process.env.SMTP_FROM,
        to: correo,
        subject: 'Credenciales de acceso - Bobisense AI',
        html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #2E7D32;">Bienvenido a Bobisense AI</h2>
        <p>Hola <strong>${nombreCompleto}</strong>,</p>
        <p>Tu cuenta fue creada correctamente.</p>
        <p><strong>Usuario:</strong> ${correo}</p>
        <p><strong>Contraseña inicial:</strong> ${password}</p>
        <p>Te recomendamos cambiar tu contraseña después del primer ingreso.</p>
        <p>Equipo Bobisense AI</p>
      </div>
    `,
        text: `
Hola ${nombreCompleto},

Tu cuenta fue creada correctamente.

Usuario: ${correo}
Contraseña inicial: ${password}

Te recomendamos cambiar tu contraseña después del primer ingreso.

Equipo Bobisense AI
`,
    });

    console.log('[MAIL] Correo enviado correctamente.');
    console.log('[MAIL] messageId:', info.messageId);
    console.log('[MAIL] accepted:', info.accepted);
    console.log('[MAIL] rejected:', info.rejected);

    return info;
}

module.exports = {
    enviarCredenciales,
};