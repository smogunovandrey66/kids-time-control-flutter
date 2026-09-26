// Security rules tests. Run: `npm test` (starts the Firestore emulator).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
} from 'firebase/firestore';

const PIN_HASH =
  'pbkdf2-sha256$10000$a3RjLXRlc3Qtc2FsdA==$LxrtrmK164FUMoBkx/0kVzkUUXAlTlK3MCyFqTb7Tsc=';

// Denied requests are expected in these tests; keep the SDK quiet about them.
setLogLevel('silent');

let env;

// Parents sign in with Google; PCs sign in anonymously.
const parent = () => env.authenticatedContext('parent', { firebase: { sign_in_provider: 'google.com' } }).firestore();
const stranger = () => env.authenticatedContext('stranger', { firebase: { sign_in_provider: 'google.com' } }).firestore();
const pc = () => env.authenticatedContext('pc', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const otherPc = () => env.authenticatedContext('other-pc', { firebase: { sign_in_provider: 'anonymous' } }).firestore();

const child = {
  name: 'Ivan',
  pinHash: PIN_HASH,
  limits: { weekdaySeconds: 3600, weekendSeconds: 7200 },
  archived: false,
};

const usage = {
  childId: 'ivan',
  date: '2026-09-26',
  totalSeconds: 600,
  apps: { minecraft: 600 },
  sessions: [],
};

async function seedFamily({ deviceUids = ['pc'] } = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'families/f1'), {
      name: 'Family',
      parents: ['parent'],
      deviceUids,
      timeZone: 'Europe/Moscow',
    });
    await setDoc(doc(db, 'families/f1/children/ivan'), child);
    await setDoc(doc(db, 'families/f1/apps/minecraft'), {
      name: 'Minecraft',
      match: { exeName: 'javaw.exe' },
      archived: false,
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-kids-time-control',
    firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});

beforeEach(() => env.clearFirestore());

after(() => env.cleanup());

describe('families', () => {
  test('a parent creates a family with only themselves as parent', async () => {
    const family = { name: 'F', parents: ['parent'], deviceUids: [], timeZone: 'Europe/Moscow' };
    await assertSucceeds(setDoc(doc(parent(), 'families/new'), family));
    await assertFails(setDoc(doc(parent(), 'families/bad'), { ...family, parents: ['parent', 'stranger'] }));
    await assertFails(setDoc(doc(parent(), 'families/bad2'), { ...family, deviceUids: ['pc'] }));
  });

  test('an anonymous device cannot create a family', async () => {
    await assertFails(
      setDoc(doc(pc(), 'families/f2'), { name: 'F', parents: ['pc'], deviceUids: [], timeZone: 'UTC' }),
    );
  });

  test('a device cannot add itself to a family', async () => {
    await seedFamily({ deviceUids: [] });
    await assertFails(updateDoc(doc(otherPc(), 'families/f1'), { deviceUids: arrayUnion('other-pc') }));
  });

  test('parents and devices find their family by query; strangers do not', async () => {
    await seedFamily();
    const byParent = query(collection(parent(), 'families'), where('parents', 'array-contains', 'parent'));
    const byDevice = query(collection(pc(), 'families'), where('deviceUids', 'array-contains', 'pc'));
    await assertSucceeds(getDocs(byParent));
    await assertSucceeds(getDocs(byDevice));
    await assertFails(getDoc(doc(stranger(), 'families/f1')));
    await assertFails(getDocs(collection(stranger(), 'families')));
  });
});

describe('children and games', () => {
  test('the parent manages children; the device only reads them', async () => {
    await seedFamily();
    await assertSucceeds(setDoc(doc(parent(), 'families/f1/children/marina'), { ...child, name: 'Marina' }));
    await assertSucceeds(getDoc(doc(pc(), 'families/f1/children/ivan')));
    // The key guarantee: the PC (a child at the keyboard) cannot raise a limit.
    await assertFails(
      updateDoc(doc(pc(), 'families/f1/children/ivan'), { 'limits.weekdaySeconds': 86400 }),
    );
    await assertFails(setDoc(doc(pc(), 'families/f1/apps/minecraft'), { name: 'x', match: {} }));
  });

  test('a child document needs a valid PIN hash and name', async () => {
    await seedFamily();
    await assertFails(setDoc(doc(parent(), 'families/f1/children/x'), { ...child, pinHash: '1234' }));
    await assertFails(setDoc(doc(parent(), 'families/f1/children/x'), { ...child, name: '' }));
  });

  test('strangers and unpaired devices see nothing', async () => {
    await seedFamily();
    await assertFails(getDoc(doc(stranger(), 'families/f1/children/ivan')));
    await assertFails(getDoc(doc(otherPc(), 'families/f1/children/ivan')));
  });
});

describe('usage and devices', () => {
  test('only a paired device reports usage, under {childId}_{date}', async () => {
    await seedFamily();
    await assertSucceeds(setDoc(doc(pc(), 'families/f1/usage/ivan_2026-09-26'), usage));
    await assertFails(setDoc(doc(pc(), 'families/f1/usage/ivan_2026-09-27'), usage));
    await assertFails(setDoc(doc(otherPc(), 'families/f1/usage/ivan_2026-09-26'), usage));
    await assertFails(setDoc(doc(parent(), 'families/f1/usage/ivan_2026-09-26'), usage));
    await assertSucceeds(getDoc(doc(parent(), 'families/f1/usage/ivan_2026-09-26')));
  });

  test('a device writes only its own status document', async () => {
    await seedFamily({ deviceUids: ['pc', 'other-pc'] });
    const status = { name: 'PC', appVersion: '0.1.0', lastSeen: '2026-09-26T10:00:00Z' };
    await assertSucceeds(setDoc(doc(pc(), 'families/f1/devices/pc'), status));
    await assertFails(setDoc(doc(pc(), 'families/f1/devices/other-pc'), status));
  });
});

describe('pairing', () => {
  test('the full pairing flow', async () => {
    await seedFamily({ deviceUids: [] });

    // 1. The PC publishes a code.
    await assertSucceeds(
      setDoc(doc(pc(), 'pairingRequests/ABCD2345'), { uid: 'pc', deviceName: 'Home PC', createdAt: serverTimestamp() }),
    );
    // 2. Codes cannot be listed or read by other devices.
    await assertFails(getDocs(collection(parent(), 'pairingRequests')));
    await assertFails(getDoc(doc(otherPc(), 'pairingRequests/ABCD2345')));
    // 3. The parent reads it by code, adds the device and deletes the code.
    const request = await assertSucceeds(getDoc(doc(parent(), 'pairingRequests/ABCD2345')));
    await assertSucceeds(updateDoc(doc(parent(), 'families/f1'), { deviceUids: arrayUnion(request.data().uid) }));
    await assertSucceeds(
      setDoc(doc(parent(), 'families/f1/devices/pc'), { name: 'Home PC', appVersion: '', lastSeen: '' }),
    );
    await assertSucceeds(deleteDoc(doc(parent(), 'pairingRequests/ABCD2345')));
    // 4. Now the PC can read the family configuration.
    await assertSucceeds(getDoc(doc(pc(), 'families/f1/children/ivan')));
  });

  test('a code must belong to its creator and look like a code', async () => {
    await assertFails(
      setDoc(doc(pc(), 'pairingRequests/ABCD2345'), { uid: 'someone-else', deviceName: 'PC', createdAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(pc(), 'pairingRequests/abc'), { uid: 'pc', deviceName: 'PC', createdAt: serverTimestamp() }),
    );
  });
});
