const { createHmac, timingSafeEqual } = require('node:crypto');
const { HttpError, hexId, integer } = require('../utils/validation');

const COMMANDS = { ESTADO: 'H', PREPARARCONTEO: 'P', INICIARCONTEO: 'S', DETENERCONTEO: 'T', ESTADOCONTEO: 'Q', RESULTADOCONTEO: 'R' };
const STATES = new Set(['READY', 'STARTED', 'RUNNING', 'STOPPED', 'RESULT', 'ERROR', 'BUSY', 'IDLE']);

function secretKey() {
    const secret = process.env.IOT_SHARED_SECRET || '';
    if (!/^[a-fA-F0-9]{64}$/.test(secret)) {
        throw new HttpError(503, 'El equipo de conteo no esta configurado en el servidor.');
    }
    return Buffer.from(secret, 'hex');
}

function sign(payload, key = secretKey()) {
    return createHmac('sha256', key).update(payload, 'ascii').digest('hex').slice(0, 32);
}

function commandFrame({ requestId, expires, command, sessionId }, key = secretKey()) {
    hexId(requestId);
    if (!Object.values(COMMANDS).includes(command)) throw new HttpError(400, 'Comando invalido.');
    if (sessionId !== '-') hexId(sessionId);
    integer(expires, 'Expiracion', 1, Number.MAX_SAFE_INTEGER);
    const payload = `C1|${requestId}|${expires}|${command}|${sessionId}`;
    return `${payload}|${sign(payload, key)}`;
}

function responseFrame(raw, key = secretKey()) {
    if (typeof raw !== 'string' || raw.length > 200 || /[^\x20-\x7e]/.test(raw)) {
        throw new HttpError(400, 'Respuesta del equipo invalida.');
    }
    const parts = raw.split('|');
    if (parts.length !== 8 || parts[0] !== 'R1' || !/^[a-f0-9]{32}$/.test(parts[7])) {
        throw new HttpError(400, 'Formato de respuesta invalido.');
    }
    const expected = Buffer.from(sign(parts.slice(0, 7).join('|'), key), 'hex');
    if (!timingSafeEqual(expected, Buffer.from(parts[7], 'hex'))) throw new HttpError(403, 'No se pudo autenticar el resultado del equipo.');
    const requestId = hexId(parts[1]);
    const sessionId = parts[2] === '-' ? '-' : hexId(parts[2]);
    if (!STATES.has(parts[3])) throw new HttpError(400, 'Estado del equipo invalido.');
    return {
        requestId, sessionId, status: parts[3],
        count: parts[4] === '-' ? null : integer(parts[4], 'Conteo'),
        timestamp: integer(parts[5], 'Fecha', 1, Number.MAX_SAFE_INTEGER),
        completedAt: parts[6] === '-' ? null : integer(parts[6], 'Finalizacion', 1, Number.MAX_SAFE_INTEGER),
        raw,
    };
}

module.exports = { COMMANDS, secretKey, sign, commandFrame, responseFrame };
