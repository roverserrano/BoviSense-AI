const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

require('dotenv').config({
    path: path.resolve(__dirname, '../../.env'),
});

let serviceAccount;
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (serviceAccountJson) {
    try {
        serviceAccount = JSON.parse(serviceAccountJson);
    } catch (error) {
        throw new Error(
            'FIREBASE_SERVICE_ACCOUNT_JSON no es un JSON válido.',
        );
    }
} else {
    if (!serviceAccountPath) {
        throw new Error(
            'Define FIREBASE_SERVICE_ACCOUNT_JSON o GOOGLE_APPLICATION_CREDENTIALS en el entorno.',
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

    serviceAccount = require(absoluteServiceAccountPath);
}

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
