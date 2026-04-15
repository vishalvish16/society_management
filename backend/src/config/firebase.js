/**
 * Firebase Admin SDK initializer.
 *
 * Setup:
 *  1. Go to Firebase Console → Project Settings → Service Accounts
 *  2. Click "Generate new private key" → download the JSON file
 *  3. Save it as: backend/firebase-service-account.json
 *     OR set env var FIREBASE_SERVICE_ACCOUNT_JSON with the JSON string
 *
 * The app works without Firebase — push notifications are silently skipped.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let _initialized = false;

function getFirebaseAdmin() {
  if (_initialized) return admin;

  try {
    // Option A: JSON string in env var (production / CI)
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      _initialized = true;
      console.log('[Firebase] Initialized from env var');
      return admin;
    }

    // Option B: JSON file next to backend root
    const filePath = path.join(__dirname, '../../firebase-service-account.json');
    if (fs.existsSync(filePath)) {
      const serviceAccount = require(filePath);
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      _initialized = true;
      console.log('[Firebase] Initialized from firebase-service-account.json');
      return admin;
    }

    console.warn('[Firebase] No service account found — push notifications disabled.');
    console.warn('[Firebase] Add backend/firebase-service-account.json to enable FCM.');
    return null;
  } catch (err) {
    console.error('[Firebase] Init failed:', err.message);
    return null;
  }
}

module.exports = { getFirebaseAdmin };
