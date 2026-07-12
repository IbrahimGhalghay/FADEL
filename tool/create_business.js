#!/usr/bin/env node
/**
 * Admin provisioning script: creates a new business document in Firestore.
 * This is the ONLY sanctioned way to create a business (besides the Firebase
 * Console) — the mobile app can only JOIN existing businesses.
 *
 * One-time setup:
 *   1. Firebase Console → Project settings → Service accounts
 *      → "Generate new private key" → save as tool/serviceAccountKey.json
 *      (gitignored — NEVER commit this file)
 *   2. cd tool && npm install
 *
 * Usage:
 *   node create_business.js "F@del"
 */
const path = require('path');
const admin = require('firebase-admin');

const businessId = process.argv[2];
if (!businessId) {
  console.error('Usage: node create_business.js <businessId>');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, 'serviceAccountKey.json'))
  ),
});

const db = admin.firestore();

(async () => {
  const ref = db.collection('businesses').doc(businessId);
  const existing = await ref.get();
  if (existing.exists) {
    console.log(`Business "${businessId}" already exists — nothing to do.`);
    return;
  }
  await ref.set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Business "${businessId}" created successfully.`);
  console.log('Employees can now join it from the app using this ID.');
})().catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
