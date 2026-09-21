class HttpError extends Error {
    constructor(status, message) {
        super(message);
        this.status = status;
    }
}

function object(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        throw new HttpError(400, 'Se requiere un objeto JSON.');
    }
    return value;
}

function text(value, name, max = 120) {
    if (typeof value !== 'string' || !value.trim() || value.trim().length > max || /[\x00-\x1f]/.test(value)) {
        throw new HttpError(400, `${name} no es valido (maximo ${max} caracteres).`);
    }
    return value.trim();
}

function integer(value, name, min = 0, max = 1000000) {
    if (typeof value === 'string' && /^\d+$/.test(value)) value = Number(value);
    if (!Number.isSafeInteger(value) || value < min || value > max) {
        throw new HttpError(400, `${name} debe ser un entero entre ${min} y ${max}.`);
    }
    return value;
}

function documentId(value) {
    const result = text(value, 'Identificador', 128);
    if (!/^[a-zA-Z0-9_-]+$/.test(result)) throw new HttpError(400, 'Identificador invalido.');
    return result;
}

function hexId(value) {
    if (typeof value !== 'string' || !/^[a-f0-9]{32}$/.test(value)) {
        throw new HttpError(400, 'Identificador de solicitud invalido.');
    }
    return value;
}

function respondError(res, error) {
    const authErrors = {
        'auth/email-already-exists': [409, 'El correo ya esta registrado.'],
        'auth/user-not-found': [404, 'Usuario no encontrado.'],
        'auth/invalid-email': [400, 'Correo invalido.'],
    };
    const known = authErrors[error.code];
    const status = error instanceof HttpError ? error.status : known?.[0] || 503;
    const message = error instanceof HttpError ? error.message : known?.[1] || 'No se pudo completar la operacion. Intenta nuevamente.';
    console.error(JSON.stringify({ event: 'request_failed', status, code: error.code || error.name || 'error' }));
    return res.status(status).json({ message });
}

module.exports = { HttpError, object, text, integer, documentId, hexId, respondError };
