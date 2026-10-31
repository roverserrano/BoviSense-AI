const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');

function loadMailService({ accepted = ['ana@example.test'], error, configured = true } = {}) {
    const transport = {
        sendMail: mock.fn(async () => {
            if (error) throw error;
            return { accepted };
        }),
        close: mock.fn(),
    };
    const createTransport = mock.fn(() => transport);
    const module = { exports: {} };
    runInNewContext(readFileSync(require.resolve('../src/services/mailService'), 'utf8'), {
        module,
        require: name => {
            assert.equal(name, 'nodemailer');
            return { createTransport };
        },
        process: { env: configured ? {
            SMTP_HOST: 'smtp.example.test', SMTP_USER: 'sender@example.test',
            SMTP_PASS: 'test-only-password', SMTP_FROM: 'BoviSense <sender@example.test>',
        } : {} },
    });
    return { enviarActivacion: module.exports.enviarActivacion, transport, createTransport };
}

const credentials = {
    correo: 'ana@example.test', nombreCompleto: 'Ana Prueba',
    contrasenaInicial: 'Test-only-Initial-Password-123!',
};

test('welcome email contains login credentials and in-app password change instructions without reset links', async () => {
    const mail = loadMailService();
    await mail.enviarActivacion(credentials);
    const message = mail.transport.sendMail.mock.calls[0].arguments[0];
    assert.equal(message.to, credentials.correo);
    assert.equal(message.subject, 'Tus credenciales de acceso - BoviSense');
    assert.ok(message.text.includes(`Usuario (correo): ${credentials.correo}`));
    assert.ok(message.text.includes(`Contraseña inicial: ${credentials.contrasenaInicial}`));
    assert.ok(message.text.includes('Opciones de sesión > Cambiar contraseña'));
    assert.equal(/https?:\/\/|resetPassword|oobCode|enlace de Firebase/i.test(message.text), false);
    const options = mail.createTransport.mock.calls[0].arguments[0];
    assert.equal(options.requireTLS, true);
    assert.equal(options.logger, false);
    assert.equal(options.debug, false);
    assert.equal(mail.transport.close.mock.callCount(), 1);
});

test('SMTP authentication failures propagate and always close the transport', async () => {
    const error = Object.assign(new Error('Authentication failed'), { code: 'EAUTH' });
    const mail = loadMailService({ error });
    await assert.rejects(mail.enviarActivacion(credentials), failure => failure === error);
    assert.equal(mail.transport.close.mock.callCount(), 1);
});

test('an unaccepted email is reported as a failure and closes the transport', async () => {
    const mail = loadMailService({ accepted: [] });
    await assert.rejects(mail.enviarActivacion(credentials), /mail\/not-accepted/);
    assert.equal(mail.transport.close.mock.callCount(), 1);
});

test('missing credentials or SMTP settings fail before creating a transport', async () => {
    const mail = loadMailService();
    for (const password of [undefined, null, '', '   ']) {
        await assert.rejects(mail.enviarActivacion({ ...credentials, contrasenaInicial: password }), /mail\/initial-password-missing/);
    }
    assert.equal(mail.createTransport.mock.callCount(), 0);
    const unconfigured = loadMailService({ configured: false });
    await assert.rejects(unconfigured.enviarActivacion(credentials), /mail\/configuration-missing/);
    assert.equal(unconfigured.createTransport.mock.callCount(), 0);
});
