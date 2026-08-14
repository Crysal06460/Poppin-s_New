// Vérification ponctuelle (pas un test permanent) : reproduit contre l'émulateur
// le cas réel de Marie Fayolle (dimimarie59@hotmail.fr) AVANT et APRÈS le fix
// (role/structureId ajoutés sur son doc users), pour confirmer que les 2 lectures
// qui échouaient (lookup email parent pour ajout enfant, lecture message parent)
// passent bien maintenant — sans toucher à son vrai compte.
//
// Lancer : firebase emulators:exec --only firestore "cd firestore-tests && node verif_marie.js"

const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');

const MARIE_UID = '3L97m1V2nvbQKSOjPY8rL8xYbgs2';
const MARIE_EMAIL = 'dimimarie59@hotmail.fr';
const PARENT_EMAIL = 'lise.roquejoffre@hotmail.fr';
const CHILD_ID = '22j7kwFPbT4sOn99Is4e';
const MESSAGE_ID = '8D1H3Ctk2oixzrydvMlD';
const PARENT_UID = 'GBbb0JXxNLbZFnIxvZ36a86Hlui1';

async function seed(testEnv, { withFix }) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc(`structures/${MARIE_UID}`).set({
      structureName: 'Marie',
      structureType: 'AssistanteMaternelle',
      email: MARIE_EMAIL,
    });
    await db.doc(`structures/${MARIE_UID}/children/${CHILD_ID}`).set({ firstName: 'Enfant test' });
    await db.doc(`users/${MARIE_EMAIL}`).set(
      withFix
        ? { role: 'structure', structureId: MARIE_UID, email: MARIE_EMAIL, platform: 'android' }
        : { platform: 'android' } // état réel AVANT le fix : ni role ni structureId
    );
    await db.doc(`users/${PARENT_EMAIL}`).set({ role: 'parent', structureId: MARIE_UID });
    await db.doc(`exchanges/${MESSAGE_ID}`).set({
      childId: CHILD_ID,
      senderId: PARENT_UID,
      senderEmail: PARENT_EMAIL,
      message: 'Bonjour, message de test',
    });
  });
}

async function run(testEnv) {
  const marie = testEnv.authenticatedContext(MARIE_UID, { email: MARIE_EMAIL }).firestore();

  const check = async (label, fn) => {
    try {
      await fn();
      console.log(`  ✅ ${label}`);
      return true;
    } catch (e) {
      console.log(`  ❌ ${label} — ${e.message.split('\n')[0]}`);
      return false;
    }
  };

  console.log('\n=== AVANT le fix (état réel jusqu\'à aujourd\'hui) ===');
  await seed(testEnv, { withFix: false });
  const before1 = await check(
    'Ajout enfant — lookup users/{emailParent} (doit ÉCHOUER, reproduit le bug)',
    () => assertFails(marie.doc(`users/${PARENT_EMAIL}`).get())
  );
  const before2 = await check(
    'Messages — lecture exchanges/{message du parent} (doit ÉCHOUER, reproduit le bug)',
    () => assertFails(marie.doc(`exchanges/${MESSAGE_ID}`).get())
  );

  console.log('\n=== APRÈS le fix (role + structureId ajoutés, comme fait en prod) ===');
  await seed(testEnv, { withFix: true });
  const after1 = await check(
    'Ajout enfant — lookup users/{emailParent} (doit RÉUSSIR)',
    () => assertSucceeds(marie.doc(`users/${PARENT_EMAIL}`).get())
  );
  const after2 = await check(
    'Messages — lecture exchanges/{message du parent} (doit RÉUSSIR)',
    () => assertSucceeds(marie.doc(`exchanges/${MESSAGE_ID}`).get())
  );

  console.log('');
  if (before1 && before2 && after1 && after2) {
    console.log('✅ CONFIRMÉ : le bug est bien reproduit avant le fix, et bien résolu après.');
    process.exitCode = 0;
  } else {
    console.log('⚠️ Résultat inattendu — à examiner avant de dire que c\'est corrigé.');
    process.exitCode = 1;
  }
}

(async () => {
  const testEnv = await initializeTestEnvironment({
    projectId: 'poppins-rules-verif',
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  try {
    await run(testEnv);
  } finally {
    await testEnv.cleanup();
  }
})();
