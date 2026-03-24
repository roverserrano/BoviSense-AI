function normalizeText(value = '') {
    return value
        .toString()
        .trim()
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function generarPasswordInicial(nombre, apellidos) {
    const firstName = normalizeText(nombre).split(' ').filter(Boolean)[0] || 'u';
    const firstLastName = normalizeText(apellidos).split(' ').filter(Boolean)[0] || 'usuario';

    return `${firstName[0]}${firstLastName}`;
}

module.exports = {
    generarPasswordInicial,
};