const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

require('dotenv').config({
    path: path.resolve(__dirname, '../../.env'),
});

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!serviceAccountPath) {
    throw new Error(
        'GOOGLE_APPLICATION_CREDENTIALS no está definido. Revisa el archivo .env',
    );
}

const absoluteServiceAccountPath = path.isAbsolute(serviceAccountPath)
    ? serviceAccountPath
    : path.resolve(__dirname, '../../', serviceAccountPath);

if (!fs.existsSync(absoluteServiceAccountPath)) {
    throw new Error(
        `No existe el archivo de cuenta de servicio en: ${absoluteServiceAccountPath}`,
    );
}

const serviceAccount = require(absoluteServiceAccountPath);

if (!serviceAccount.project_id || !serviceAccount.client_email || !serviceAccount.private_key) {
    throw new Error(
        'El archivo de cuenta de servicio de Firebase Admin está incompleto.',
    );
}

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id,
    });
}

const auth = admin.auth();
const db = admin.firestore();

console.log('[FIREBASE ADMIN] projectId:', serviceAccount.project_id);
console.log('[FIREBASE ADMIN] clientEmail:', serviceAccount.client_email);

module.exports = {
    admin,
    auth,
    db,
    FieldValue: admin.firestore.FieldValue,
};
