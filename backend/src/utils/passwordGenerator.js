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

    const password = `${firstName[0]}${firstLastName}`;

    if (!password || password.length < 4) {
        throw new Error('No se pudo generar la contraseña inicial.');
    }

    return password;
}

module.exports = {
    generarPasswordInicial,
};
