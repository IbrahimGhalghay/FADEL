/**
 * Security-rules tests for ledger integrity, soft delete and the activity
 * log (firestore.rules), run against the Firestore emulator with the same
 * batches the app sends.
 *
 * Usage (from tool/):
 *   npm install
 *   npm run test:rules
 */
const { test, before, beforeEach, after } = require('node:test');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
  increment,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

const BIZ = 'F@del';
let env;
let db;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-fadel',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
  db = env.authenticatedContext('alice').firestore();
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, `businesses/${BIZ}`), {});
    await setDoc(doc(admin, `businesses/${BIZ}/members/alice`), {});
  });
});

const party = (kind, id) => doc(db, `businesses/${BIZ}/${kind}/${id}`);
const entry = (kind, id, txId) =>
  doc(db, `businesses/${BIZ}/${kind}/${id}/transactions/${txId}`);
const newLog = () => doc(collection(db, `businesses/${BIZ}/logs`));

/** Seeds a party and its entries directly, bypassing rules. */
async function seed(kind, id, partyData, entries = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, `businesses/${BIZ}/${kind}/${id}`), { name: id, ...partyData });
    for (const [txId, data] of Object.entries(entries)) {
      await setDoc(doc(admin, `businesses/${BIZ}/${kind}/${id}/transactions/${txId}`), data);
    }
  });
}

async function read(kind, id, txId) {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const p = `businesses/${BIZ}/${kind}/${id}` + (txId ? `/transactions/${txId}` : '');
    data = (await getDoc(doc(ctx.firestore(), p))).data();
  });
  return data;
}

// --- Batches shaped exactly like the app's repositories + ActivityLog ---

const log = (action) => ({
  action,
  uid: 'alice',
  appVersion: 'test',
  deviceTime: Timestamp.now(),
  at: serverTimestamp(),
});

const stamp = () => ({
  deleted: true,
  deletedAt: serverTimestamp(),
  deletedBy: 'alice',
  deletedByName: 'Alice',
});

function softDeleteBatch(kind, id, txId, field, signed) {
  const b = writeBatch(db);
  b.update(entry(kind, id, txId), stamp());
  b.update(party(kind, id), { [field]: increment(-signed) });
  b.set(newLog(), log('entry.delete'));
  return b;
}

function updateBatch(kind, id, txId, data, balanceUpdate) {
  const b = writeBatch(db);
  b.update(entry(kind, id, txId), data);
  b.update(party(kind, id), balanceUpdate);
  b.set(newLog(), log('entry.update'));
  return b;
}

const debt = (amount, currency = 'usd') => ({ type: 'debt', amount, currency });
const payment = (amount, currency = 'usd') => ({ type: 'payment', amount, currency });
const live = { balance: 0, balanceSyp: 0 };

// --- Creates ---

test('recording a debt, and a pay-directly pair, works with their log', async () => {
  await seed('clients', 'c1', live);
  const b = writeBatch(db);
  b.set(entry('clients', 'c1', 't1'), debt(170));
  b.update(party('clients', 'c1'), { balance: increment(170) });
  b.set(newLog(), log('entry.create'));
  await assertSucceeds(b.commit());

  const pair = writeBatch(db);
  pair.set(entry('clients', 'c1', 't2'), debt(40));
  pair.set(entry('clients', 'c1', 't3'), payment(40));
  pair.update(party('clients', 'c1'), { balance: increment(0) });
  pair.set(newLog(), log('entry.create'));
  await assertSucceeds(pair.commit());
});

test('an entry cannot be created already deleted', async () => {
  await seed('clients', 'c1', live);
  await assertFails(setDoc(entry('clients', 'c1', 't1'), { ...debt(5), deleted: true }));
});

// --- Soft delete of entries ---

test('soft-deleting an entry keeps the doc, stamped, and fixes the balance', async () => {
  await seed('clients', 'c1', { balance: 100, balanceSyp: 0 }, { t1: debt(100) });
  await assertSucceeds(softDeleteBatch('clients', 'c1', 't1', 'balance', 100).commit());
  const tx = await read('clients', 'c1', 't1');
  assert(tx.deleted === true && tx.amount === 100 && tx.deletedBy === 'alice');
  assert((await read('clients', 'c1')).balance === 0);
});

test('soft-deleting the same entry twice is rejected (the reported bug)', async () => {
  await seed('clients', 'c1', { balance: 153, balanceSyp: 0 }, { t1: debt(100) });
  await assertSucceeds(softDeleteBatch('clients', 'c1', 't1', 'balance', 100).commit());
  // Second device, stale list: same delete again.
  await assertFails(softDeleteBatch('clients', 'c1', 't1', 'balance', 100).commit());
  assert((await read('clients', 'c1')).balance === 53);
});

test('hard-deleting an entry is rejected, even with the right balance move', async () => {
  await seed('clients', 'c1', { balance: 100, balanceSyp: 0 }, { t1: debt(100) });
  const b = writeBatch(db);
  b.delete(entry('clients', 'c1', 't1'));
  b.update(party('clients', 'c1'), { balance: increment(-100) });
  await assertFails(b.commit());
});

test('soft-deleting without moving the balance is rejected', async () => {
  await seed('clients', 'c1', { balance: 100, balanceSyp: 0 }, { t1: debt(100) });
  await assertFails(updateDoc(entry('clients', 'c1', 't1'), stamp()));
});

test('soft delete cannot also change the amount', async () => {
  await seed('clients', 'c1', { balance: 100, balanceSyp: 0 }, { t1: debt(100) });
  const b = writeBatch(db);
  b.update(entry('clients', 'c1', 't1'), { ...stamp(), amount: 1 });
  b.update(party('clients', 'c1'), { balance: increment(-100) });
  await assertFails(b.commit());
});

test('soft-deleting a payment moves the balance back up', async () => {
  await seed('clients', 'c1', { balance: -50, balanceSyp: 0 }, { t1: payment(50) });
  await assertSucceeds(softDeleteBatch('clients', 'c1', 't1', 'balance', -50).commit());
});

test('legacy client (no balanceSyp) and legacy entry (no currency) work', async () => {
  await seed('clients', 'c1', { balance: 70 }, { t1: { type: 'debt', amount: 70 } });
  await assertSucceeds(softDeleteBatch('clients', 'c1', 't1', 'balance', 70).commit());
});

test('SYP entries move balanceSyp, not balance', async () => {
  await seed('clients', 'c1', { balance: 0, balanceSyp: 50000 }, { t1: debt(50000, 'syp') });
  await assertFails(softDeleteBatch('clients', 'c1', 't1', 'balance', 50000).commit());
  await assertSucceeds(softDeleteBatch('clients', 'c1', 't1', 'balanceSyp', 50000).commit());
});

test('float rounding in increments is tolerated', async () => {
  await seed('clients', 'c1', { balance: 0.1, balanceSyp: 0 }, { t1: debt(0.2) });
  await assertSucceeds(softDeleteBatch('clients', 'c1', 't1', 'balance', 0.2).commit());
});

// --- Edits ---

test('editing an entry with the right delta succeeds', async () => {
  await seed('clients', 'c1', { balance: 170, balanceSyp: 0 }, { t1: debt(170) });
  await assertSucceeds(
    updateBatch('clients', 'c1', 't1', debt(70), { balance: increment(-100) }).commit()
  );
});

test('a stale edit (delta from an outdated copy) is rejected', async () => {
  await seed('clients', 'c1', { balance: 153, balanceSyp: 0 }, { t1: debt(170) });
  // Device A: 170 → 70.
  await assertSucceeds(
    updateBatch('clients', 'c1', 't1', debt(70), { balance: increment(-100) }).commit()
  );
  // Device B still sees 170 and "saves" 170 with a zero delta.
  await assertFails(
    updateBatch('clients', 'c1', 't1', debt(170), { balance: increment(0) }).commit()
  );
  assert((await read('clients', 'c1')).balance === 53);
});

test('a deleted entry cannot be edited', async () => {
  await seed('clients', 'c1', { balance: 0, balanceSyp: 0 }, { t1: { ...debt(10), deleted: true } });
  await assertFails(
    updateBatch('clients', 'c1', 't1', debt(10), { balance: increment(0) }).commit()
  );
});

test('editing only the note/date passes with a zero move', async () => {
  await seed('clients', 'c1', { balance: 33, balanceSyp: 0 }, { t1: debt(33) });
  await assertSucceeds(
    updateBatch('clients', 'c1', 't1', { ...debt(33), note: 'x' }, { balance: increment(0) }).commit()
  );
});

test('switching type debt → payment needs a 2× move', async () => {
  await seed('clients', 'c1', { balance: 50, balanceSyp: 0 }, { t1: debt(50) });
  await assertFails(
    updateBatch('clients', 'c1', 't1', payment(50), { balance: increment(-50) }).commit()
  );
  await assertSucceeds(
    updateBatch('clients', 'c1', 't1', payment(50), { balance: increment(-100) }).commit()
  );
});

test('switching currency moves the amount between balance fields', async () => {
  await seed('clients', 'c1', { balance: 10, balanceSyp: 0 }, { t1: debt(10) });
  await assertSucceeds(
    updateBatch('clients', 'c1', 't1', debt(150000, 'syp'), {
      balance: increment(-10),
      balanceSyp: increment(150000),
    }).commit()
  );
  const c = await read('clients', 'c1');
  assert(c.balance === 0 && c.balanceSyp === 150000);
});

// --- Parties ---

test('soft-deleting a client works; hard delete does not', async () => {
  await seed('clients', 'c1', { balance: 203, balanceSyp: 0 }, { t1: debt(203) });
  await assertFails(deleteDoc(party('clients', 'c1')));
  const b = writeBatch(db);
  b.update(party('clients', 'c1'), { ...stamp(), updatedAt: serverTimestamp() });
  b.set(newLog(), log('party.delete'));
  await assertSucceeds(b.commit());
  const c = await read('clients', 'c1');
  assert(c.deleted === true && c.balance === 203);
  assert((await read('clients', 'c1', 't1')).amount === 203);
});

test('a deleted client is frozen: no edits, no new entries', async () => {
  await seed('clients', 'c1', { balance: 0, balanceSyp: 0, deleted: true });
  await assertFails(updateDoc(party('clients', 'c1'), { name: 'renamed' }));
  const b = writeBatch(db);
  b.set(entry('clients', 'c1', 't1'), debt(10));
  b.update(party('clients', 'c1'), { balance: increment(10) });
  await assertFails(b.commit());
});

test('a client cannot be created already deleted', async () => {
  await assertFails(setDoc(party('clients', 'c1'), { name: 'x', balance: 0, deleted: true }));
});

test('soft delete of a client cannot sneak in a balance change', async () => {
  await seed('clients', 'c1', { balance: 50, balanceSyp: 0 });
  await assertFails(updateDoc(party('clients', 'c1'), { ...stamp(), balance: 0 }));
});

// --- Activity log ---

test('logs: append-only, server-timestamped, members only', async () => {
  const ref = newLog();
  await assertSucceeds(setDoc(ref, log('entry.create')));
  await assertFails(updateDoc(ref, { action: 'tampered' }));
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(newLog(), { ...log('x'), at: Timestamp.now() }));
  const stranger = env.authenticatedContext('mallory').firestore();
  await assertFails(setDoc(doc(collection(stranger, `businesses/${BIZ}/logs`)), log('x')));
});

// --- Suppliers use the same guards ---

test('supplier: double delete, hard delete and stale edit are rejected', async () => {
  await seed('suppliers', 's1', { balance: 500, balanceSyp: 0 }, {
    e1: { type: 'cargo', amount: 300, currency: 'usd' },
    e2: { type: 'cargo', amount: 200, currency: 'usd' },
  });
  await assertSucceeds(softDeleteBatch('suppliers', 's1', 'e1', 'balance', 300).commit());
  await assertFails(softDeleteBatch('suppliers', 's1', 'e1', 'balance', 300).commit());
  await assertFails(deleteDoc(entry('suppliers', 's1', 'e2')));
  await assertSucceeds(
    updateBatch('suppliers', 's1', 'e2', { type: 'cargo', amount: 250, currency: 'usd' },
      { balance: increment(50) }).commit()
  );
  await assertFails(
    updateBatch('suppliers', 's1', 'e2', { type: 'cargo', amount: 220, currency: 'usd' },
      { balance: increment(20) }).commit()
  );
  assert((await read('suppliers', 's1')).balance === 250);
});

function assert(ok) {
  if (!ok) throw new Error('assertion failed');
}
