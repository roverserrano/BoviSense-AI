const { randomBytes } = require('node:crypto');

function generarPasswordInicial() {
    return randomBytes(32).toString('base64url');
}

module.exports = {
    generarPasswordInicial,
};
