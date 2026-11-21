#!/usr/bin/env node
/**
 * Balance audit / repair: recomputes every client's and supplier's
 * per-currency balance from its transaction history and compares it with the
 * denormalized `balance` (USD) / `balanceSyp` (SYP) fields the app shows.
 * Soft-deleted entries (`deleted: true`) don't count; soft-deleted parties
 * keep their balance and are still checked, tagged [deleted].
 *
 * Read-only by default. With --fix, each mismatched balance is rewritten
 * inside a Firestore transaction (re-reading the party and its history), so
 * a write landing mid-repair can't be clobbered.
 *
 * Setup: same as create_business.js (tool/serviceAccountKey.json + npm install).
 *
 * Usage:
 *   node audit_balances.js            # audit business "F@del"
 *   node audit_balances.js "F@del"    # audit a specific business
 *   node audit_balances.js --fix      # audit, then repair mismatches
 */
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
const fix = args.includes('--fix');
const businessId = args.find((a) => !a.startsWith('--')) || 'F@del';

// Against the emulator (FIRESTORE_EMULATOR_HOST set) no key is needed.
initializeApp(
  process.env.FIRESTORE_EMULATOR_HOST
    ? { projectId: process.env.GCLOUD_PROJECT || 'demo-fadel' }
    : {
        credential: cert(
          require(path.join(__dirname, 'serviceAccountKey.json'))
        ),
      }
);

const db = getFirestore();

// Mirrors AppCurrency.balanceField in lib/core/constants/currency_config.dart.
const BALANCE_FIELDS = { usd: 'balance', syp: 'balanceSyp' };

// Per ledger: which transaction type raises the balance (the other lowers it).
const LEDGERS = [
  { collection: 'clients', label: 'Client', increaseType: 'debt' },
  { collection: 'suppliers', label: 'Supplier', increaseType: 'cargo' },
];

const round2 = (n) => Math.round(n * 100) / 100;

/** Expected balances from a transactions snapshot, keyed by Firestore field. */
function expectedBalances(txSnapshot, increaseType) {
  const totals = { balance: 0, balanceSyp: 0 };
  for (const doc of txSnapshot.docs) {
    const tx = doc.data();
    if (tx.deleted === true) continue; // soft-deleted: no longer counts
    // Missing/unknown currency = USD, as in AppCurrency.fromName.
    const field = BALANCE_FIELDS[tx.currency === 'syp' ? 'syp' : 'usd'];
    const amount = Number(tx.amount) || 0;
    totals[field] += tx.type === increaseType ? amount : -amount;
  }
  return { balance: round2(totals.balance), balanceSyp: round2(totals.balanceSyp) };
}

/** Fields whose stored value differs from [expected] (to the cent). */
function mismatches(data, expected) {
  return Object.keys(expected).filter(
    (field) => round2(Number(data[field]) || 0) !== expected[field]
  );
}

async function auditLedger({ collection, label, increaseType }) {
  const parties = await db
    .collection('businesses')
    .doc(businessId)
    .collection(collection)
    .get();
  const bad = [];
  for (const party of parties.docs) {
    const txs = await party.ref.collection('transactions').get();
    const expected = expectedBalances(txs, increaseType);
    const data = party.data();
    const fields = mismatches(data, expected);
    if (fields.length === 0) continue;
    bad.push(party.ref);
    const tag = data.deleted === true ? ' [deleted]' : '';
    console.log(`\n${label}: ${data.name}${tag} (${party.id}) — ${txs.size} transactions`);
    for (const field of fields) {
      const stored = round2(Number(data[field]) || 0);
      const diff = round2(stored - expected[field]);
      console.log(
        `  ${field.padEnd(10)} stored ${stored}  expected ${expected[field]}` +
          `  (off by ${diff > 0 ? '+' : ''}${diff})`
      );
    }
  }
  console.log(`\n${label}s checked: ${parties.size}, mismatched: ${bad.length}`);
  return bad;
}

async function repair(ref, increaseType) {
  await db.runTransaction(async (t) => {
    const party = await t.get(ref);
    if (!party.exists) return;
    const txs = await t.get(ref.collection('transactions'));
    const expected = expectedBalances(txs, increaseType);
    const fields = mismatches(party.data(), expected);
    if (fields.length === 0) return;
    const update = { updatedAt: FieldValue.serverTimestamp() };
    for (const field of fields) update[field] = expected[field];
    t.update(ref, update);
  });
}

(async () => {
  console.log(`Auditing business "${businessId}"${fix ? ' (FIX mode)' : ''}`);
  let total = 0;
  for (const ledger of LEDGERS) {
    const bad = await auditLedger(ledger);
    total += bad.length;
    if (fix) {
      for (const ref of bad) await repair(ref, ledger.increaseType);
      if (bad.length) console.log(`  → repaired ${bad.length}`);
    }
  }
  if (total === 0) {
    console.log('\nAll balances match their history.');
  } else if (!fix) {
    console.log('\nRun again with --fix to rewrite the mismatched balances.');
  }
})().catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
