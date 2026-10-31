const { HttpError } = require('./validation');

function normalizarParte(value) {
    if (typeof value !== 'string') return '';
    return value.trim().split(/\s+/)[0].normalize('NFD')
        .replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
}

function generarPasswordInicial(nombre, apellidos) {
    const primerNombre = normalizarParte(nombre);
    const primerApellido = normalizarParte(apellidos);
    if (!primerNombre || !primerApellido) throw new HttpError(400, 'Nombre y apellidos no son validos.');
    return `${Array.from(primerNombre)[0]}${primerApellido}`.padEnd(6, '0');
}

module.exports = {
    generarPasswordInicial,
};
