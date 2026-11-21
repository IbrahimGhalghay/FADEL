#!/usr/bin/env node
/**
 * Activity-log viewer: prints the audit trail the app writes to
 * businesses/{id}/logs (see lib/core/services/activity_log.dart), oldest
 * first, in Damascus time.
 *
 * Each line shows when the server applied the write, how long it sat queued
 * on the device (offline), who did it from which app version, and what the
 * device believed before/after plus the balance increment it sent. Rejected
 * writes (refused by security rules, then rolled back) are marked REJECTED.
 *
 * Setup: same as create_business.js (tool/serviceAccountKey.json + npm install).
 *
 * Usage:
 *   node activity_log.js                       # latest 100 records
 *   node activity_log.js --party "عبد الرحمن"  # one client/supplier (name part or id)
 *   node activity_log.js --since 2026-10-01    # from a date (Damascus time)
 *   node activity_log.js --rejected            # rejected writes only
 *   node activity_log.js --limit 500 --json    # raw records
 */
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const businessId = opt('--business') || 'F@del';
const partyQuery = opt('--party');
const since = opt('--since');
const limit = Number(opt('--limit') || 100);
const onlyRejected = args.includes('--rejected');
const asJson = args.includes('--json');

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
const biz = db.collection('businesses').doc(businessId);

const TZ = 'Asia/Damascus';
const fmtTime = (ts) =>
  ts ? ts.toDate().toLocaleString('en-GB', { timeZone: TZ, hour12: false }) : '(pending)';
const fmtDate = (ts) =>
  ts ? ts.toDate().toLocaleDateString('en-GB', { timeZone: TZ }) : '?';

function fmtDuration(ms) {
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m${s % 60}s`;
  const h = Math.floor(m / 60);
  return h < 48 ? `${h}h${m % 60}m` : `${Math.floor(h / 24)}d${h % 24}h`;
}

function fmtEntry(e) {
  if (!e) return '—';
  if (e.name !== undefined) {
    // Party snapshot.
    const bal = [
      e.balance !== undefined ? `USD ${e.balance}` : null,
      e.balanceSyp ? `SYP ${e.balanceSyp}` : null,
    ].filter(Boolean);
    return `"${e.name}"${e.phone ? ` ${e.phone}` : ''}${bal.length ? ` [${bal.join(', ')}]` : ''}`;
  }
  const note = e.note ? ` "${e.note}"` : '';
  return `${e.type} ${e.amount} ${(e.currency || 'usd').toUpperCase()} on ${fmtDate(e.date)}${note}`;
}

const fmtDelta = (d) =>
  d
    ? Object.entries(d)
        .map(([k, v]) => `${k === 'balanceSyp' ? 'SYP' : 'USD'} ${v > 0 ? '+' : ''}${v}`)
        .join(', ')
    : '';

/** {id → {name, ledger, deleted}} for every client and supplier. */
async function loadParties() {
  const parties = {};
  for (const ledger of ['clients', 'suppliers']) {
    const snap = await biz.collection(ledger).get();
    for (const d of snap.docs) {
      parties[d.id] = { name: d.data().name, ledger, deleted: d.data().deleted === true };
    }
  }
  return parties;
}

async function loadLogs(parties) {
  const logs = biz.collection('logs');
  let docs;
  if (partyQuery) {
    const ids = Object.keys(parties).filter(
      (id) => id === partyQuery || (parties[id].name || '').includes(partyQuery)
    );
    if (ids.length === 0) throw new Error(`No client/supplier matches "${partyQuery}"`);
    if (ids.length > 1) {
      console.log(`Matches ${ids.length} parties: ${ids.map((id) => parties[id].name).join(', ')}`);
    }
    // Equality-only queries need no composite index; sort in memory.
    const snaps = await Promise.all(ids.map((id) => logs.where('partyId', '==', id).get()));
    docs = snaps.flatMap((s) => s.docs);
  } else if (onlyRejected) {
    docs = (await logs.where('rejected', '==', true).get()).docs;
  } else if (since) {
    const from = new Date(`${since}T00:00:00+03:00`);
    docs = (await logs.where('at', '>=', from).orderBy('at').get()).docs;
  } else {
    docs = (await logs.orderBy('at', 'desc').limit(limit).get()).docs;
  }
  let records = docs.map((d) => ({ id: d.id, ...d.data() }));
  if (since) {
    const from = new Date(`${since}T00:00:00+03:00`).getTime();
    records = records.filter((r) => r.at && r.at.toMillis() >= from);
  }
  if (onlyRejected) records = records.filter((r) => r.rejected === true);
  records.sort((a, b) => (a.at?.toMillis() ?? 0) - (b.at?.toMillis() ?? 0));
  return records.slice(-limit);
}

(async () => {
  const parties = await loadParties();
  const records = await loadLogs(parties);
  if (asJson) {
    console.log(JSON.stringify(records, null, 2));
    return;
  }
  if (records.length === 0) {
    console.log('No activity-log records match.');
    return;
  }
  for (const r of records) {
    const p = parties[r.partyId];
    const who = `${r.userName || '?'} (${(r.uid || '').slice(0, 6)}, v${r.appVersion || '?'})`;
    const queued =
      r.at && r.deviceTime ? r.at.toMillis() - r.deviceTime.toMillis() : 0;
    const where = `${r.ledger === 'suppliers' ? 'Supplier' : 'Client'} ${
      p ? `"${p.name}"${p.deleted ? ' [deleted]' : ''}` : r.partyId
    }`;
    console.log(
      `\n${fmtTime(r.at)}  ${r.action.padEnd(13)} ${where}` +
        (r.rejected ? `  ✖ REJECTED (${r.error})` : '')
    );
    console.log(
      `  by ${who}` +
        (queued > 5000 ? `  ⏳ queued on device ${fmtDuration(queued)}` : '')
    );
    if (r.entryId) console.log(`  entry ${r.entryId}${r.pairedPaymentId ? ` (+ payment ${r.pairedPaymentId})` : ''}`);
    if (r.before || r.after) {
      console.log(`  ${fmtEntry(r.before)}  →  ${r.action.endsWith('.delete') ? 'deleted' : fmtEntry(r.after)}`);
    }
    if (r.balanceDelta) console.log(`  balance Δ ${fmtDelta(r.balanceDelta)}`);
  }
  console.log(`\n${records.length} record(s).`);
})().catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
