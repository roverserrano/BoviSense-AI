const nodemailer = require('nodemailer');

async function enviarActivacion({ correo, nombreCompleto, contrasenaInicial }) {
    if (typeof contrasenaInicial !== 'string' || !contrasenaInicial.trim()) throw new Error('mail/initial-password-missing');
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
            subject: 'Tus credenciales de acceso - BoviSense',
            text: `Hola ${nombreCompleto},\n\nTu cuenta de BoviSense está lista. Ingresa a la aplicación con estas credenciales:\n\nUsuario (correo): ${correo}\nContraseña inicial: ${contrasenaInicial}\n\nUna vez dentro, abre Opciones de sesión > Cambiar contraseña para elegir tu propia contraseña. Usa la contraseña inicial como contraseña actual.\n\nConserva estas credenciales en privado. Si olvidas tu contraseña, utiliza Recuperar contraseña en la aplicación.`,
        });
        if (!result.accepted?.length) throw new Error('mail/not-accepted');
    } finally {
        transporter.close();
    }
}

module.exports = { enviarActivacion };
