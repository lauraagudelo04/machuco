import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, serverTimestamp, setDoc } from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();

const notification = (overrides = {}) => ({
  eventType: 'system',
  actorUid: 'admin',
  target: 'specificUser',
  recipientUid: 'client',
  recipientName: 'Cliente de prueba',
  recipientEmail: 'client@machuco.test',
  title: 'Aviso',
  message: 'Mensaje de prueba',
  createdAt: serverTimestamp(),
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-machuco',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin'), {
      role: 'admin', accountStatus: 'active',
    });
    await setDoc(doc(ctx.firestore(), 'users/client'), {
      role: 'client', accountStatus: 'active',
    });
  });
});

describe('notification recipient snapshots', () => {
  test('un administrador puede crear un aviso específico con snapshot visible', async () => {
    await assertSucceeds(setDoc(
      doc(as('admin'), 'notifications/manual-1'), notification(),
    ));
  });

  test('no permite snapshots incompletos para un aviso específico', async () => {
    const { recipientEmail, ...withoutEmail } = notification();
    await assertFails(setDoc(
      doc(as('admin'), 'notifications/manual-1'), withoutEmail,
    ));
  });
});
