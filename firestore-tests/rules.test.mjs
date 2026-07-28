// Real Firebase Emulator Suite tests for firestore.rules — specifically the
// new isAdmin()/playtests-read/actions-read/admins-collection rules added
// for the admin dashboard (section 4/25). `fake_firebase_security_rules`
// (used by the Dart-side fake_cloud_firestore tests) cannot parse
// `function`/`get`/`exists`/`request.resource`, so it cannot literally
// verify these rules — this file exercises the real rules engine via the
// Firestore emulator instead, per the task's own guidance to prefer the
// Emulator CLI when the fake library falls short.
//
// Run with the Firestore emulator (from the repo root):
//   npx firebase-tools emulators:exec --only firestore \
//     "cd firestore-tests && npm install && npm test"
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test, before, beforeEach, after } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-nine-verdicts-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

async function seed(callback) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

test('anonymous user can create their own playtest (firebaseUid == auth.uid)', async () => {
  const db = testEnv.authenticatedContext('user-1').firestore();
  await assertSucceeds(
    db.collection('playtests').doc('g1').set({
      firebaseUid: 'user-1',
      gameId: 'g1',
      startedAt: new Date().toISOString(),
    }),
  );
});

test('create is rejected when firebaseUid does not match the caller', async () => {
  const db = testEnv.authenticatedContext('user-1').firestore();
  await assertFails(
    db.collection('playtests').doc('g2').set({
      firebaseUid: 'someone-else',
      gameId: 'g2',
    }),
  );
});

test('a non-owner cannot read another user\'s playtest', async () => {
  await seed((db) =>
    db.collection('playtests').doc('g3').set({ firebaseUid: 'owner', gameId: 'g3' }),
  );
  const db = testEnv.authenticatedContext('someone-else').firestore();
  await assertFails(db.collection('playtests').doc('g3').get());
});

test('the owner can read their own playtest', async () => {
  await seed((db) =>
    db.collection('playtests').doc('g4').set({ firebaseUid: 'owner', gameId: 'g4' }),
  );
  const db = testEnv.authenticatedContext('owner').firestore();
  await assertSucceeds(db.collection('playtests').doc('g4').get());
});

test('an enabled admin can read any playtest', async () => {
  await seed(async (db) => {
    await db.collection('admins').doc('admin-1').set({ enabled: true });
    await db.collection('playtests').doc('g5').set({ firebaseUid: 'owner', gameId: 'g5' });
  });
  const db = testEnv.authenticatedContext('admin-1').firestore();
  await assertSucceeds(db.collection('playtests').doc('g5').get());
});

test('a disabled admin doc does NOT grant read access', async () => {
  await seed(async (db) => {
    await db.collection('admins').doc('admin-2').set({ enabled: false });
    await db.collection('playtests').doc('g6').set({ firebaseUid: 'owner', gameId: 'g6' });
  });
  const db = testEnv.authenticatedContext('admin-2').firestore();
  await assertFails(db.collection('playtests').doc('g6').get());
});

test('an admin can list the playtests collection without a where clause', async () => {
  await seed(async (db) => {
    await db.collection('admins').doc('admin-1').set({ enabled: true });
    await db.collection('playtests').doc('g7').set({ firebaseUid: 'owner-a', gameId: 'g7' });
    await db.collection('playtests').doc('g8').set({ firebaseUid: 'owner-b', gameId: 'g8' });
  });
  const db = testEnv.authenticatedContext('admin-1').firestore();
  const snapshot = await assertSucceeds(db.collection('playtests').get());
  assert.equal(snapshot.size, 2);
});

test('a non-admin cannot list the playtests collection', async () => {
  await seed(async (db) => {
    await db.collection('playtests').doc('g9').set({ firebaseUid: 'owner-a', gameId: 'g9' });
  });
  const db = testEnv.authenticatedContext('random-user').firestore();
  await assertFails(db.collection('playtests').get());
});

test('an admin can read a game\'s actions subcollection', async () => {
  await seed(async (db) => {
    await db.collection('admins').doc('admin-1').set({ enabled: true });
    await db.collection('playtests').doc('g10').set({ firebaseUid: 'owner', gameId: 'g10' });
    await db
      .collection('playtests')
      .doc('g10')
      .collection('actions')
      .doc('000')
      .set({ actionIndex: 0, actionType: 'eye' });
  });
  const db = testEnv.authenticatedContext('admin-1').firestore();
  await assertSucceeds(
    db.collection('playtests').doc('g10').collection('actions').doc('000').get(),
  );
});

test('a non-owner, non-admin cannot read a game\'s actions subcollection', async () => {
  await seed(async (db) => {
    await db.collection('playtests').doc('g11').set({ firebaseUid: 'owner', gameId: 'g11' });
    await db
      .collection('playtests')
      .doc('g11')
      .collection('actions')
      .doc('000')
      .set({ actionIndex: 0 });
  });
  const db = testEnv.authenticatedContext('random-user').firestore();
  await assertFails(
    db.collection('playtests').doc('g11').collection('actions').doc('000').get(),
  );
});

test('no client can create an admins doc for themselves', async () => {
  const db = testEnv.authenticatedContext('user-1').firestore();
  await assertFails(db.collection('admins').doc('user-1').set({ enabled: true }));
});

test('update/delete on playtests stays owner-only, even for an admin', async () => {
  await seed(async (db) => {
    await db.collection('admins').doc('admin-1').set({ enabled: true });
    await db.collection('playtests').doc('g12').set({ firebaseUid: 'owner', gameId: 'g12' });
  });
  const db = testEnv.authenticatedContext('admin-1').firestore();
  await assertFails(db.collection('playtests').doc('g12').update({ notes: 'changed' }));
  await assertFails(db.collection('playtests').doc('g12').delete());
});

test('rooms rules are unaffected: host can create their own room', async () => {
  const db = testEnv.authenticatedContext('host-1').firestore();
  await assertSucceeds(
    db.collection('rooms').doc('r1').set({
      hostUid: 'host-1',
      playerUids: ['host-1'],
      status: 'waiting',
    }),
  );
});

test('rooms rules are unaffected: only the host can delete their room', async () => {
  await seed((db) =>
    db.collection('rooms').doc('r2').set({ hostUid: 'host-1', playerUids: ['host-1'] }),
  );
  const other = testEnv.authenticatedContext('other-user').firestore();
  await assertFails(other.collection('rooms').doc('r2').delete());
  const host = testEnv.authenticatedContext('host-1').firestore();
  await assertSucceeds(host.collection('rooms').doc('r2').delete());
});
