const fs = require('fs');
const path = require('path');
const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env'), quiet: true });

if (!getApps().length) {
    const emulator = process.env.NODE_ENV === 'test'
        && process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST;
    if (emulator) {
        initializeApp({ projectId: 'demo-bovisense' });
    } else {
        let account;
        if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
            account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        } else {
            const configured = process.env.GOOGLE_APPLICATION_CREDENTIALS;
            if (!configured) throw new Error('Firebase Admin credentials are not configured.');
            const file = path.isAbsolute(configured) ? configured : path.resolve(__dirname, '../../', configured);
            account = JSON.parse(fs.readFileSync(file, 'utf8'));
        }
        if (!account.project_id || !account.client_email || !account.private_key) throw new Error('Invalid Firebase Admin credentials.');
        initializeApp({ credential: cert(account), projectId: account.project_id });
    }
}
const auth = getAuth();
const db = getFirestore();
module.exports = { auth, db, FieldValue };
