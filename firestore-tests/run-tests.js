// Tests des règles Firestore contre l'émulateur local — JAMAIS contre la prod.
//
// Comment lancer (depuis la racine du repo) :
//   firebase emulators:exec --only firestore "cd firestore-tests && npm test"
//
// À faire avant TOUT déploiement de firestore.rules, sans exception — c'est
// exactement le test qui aurait attrapé la panne du 10/07/2026 (une erreur
// d'évaluation à l'exécution sur `documentPath[0]`, invisible à la simple
// compilation `firebase deploy --dry-run`, qui a bloqué l'app pour tout le
// monde pendant plusieurs heures).

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');

async function seed(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Structure A : assistante maternelle solo (propriétaire = uid = docId)
    await db.doc('structures/assmatA').set({
      structureName: 'Chez Martine',
      structureType: 'assistante_maternelle',
    });
    await db.doc('structures/assmatA/children/enfant1').set({ firstName: 'Léo' });
    await db.doc('users/assmat-a@test.fr').set({ structureId: 'assmatA', role: 'structure' });

    // Structure B : MAM (propriétaire = uid = docId 'mamOwnerB'), avec un membre et un parent liés
    await db.doc('structures/mamOwnerB').set({
      structureName: 'MAM Les Bouts de Choux',
      structureType: 'MAM',
    });
    await db.doc('structures/mamOwnerB/children/enfant2').set({ firstName: 'Nina' });
    await db.doc('users/mam-member-b@test.fr').set({ structureId: 'mamOwnerB', role: 'mamMember' });
    await db.doc('users/parent-b@test.fr').set({ structureId: 'mamOwnerB', role: 'parent' });

    // Un utilisateur qui n'a aucun lien avec la structure B
    await db.doc('users/etranger@test.fr').set({ structureId: 'uneAutreStructure', role: 'parent' });

    // Admin applicatif (diffusion notifications)
    await db.doc('users/cbeylet06@gmail.com').set({ structureId: 'adminUid', role: 'admin' });
  });
}

async function run(testEnv) {
  let failures = 0;

  const check = async (label, fn) => {
    try {
      await fn();
      console.log(`  ✅ ${label}`);
    } catch (e) {
      failures += 1;
      console.error(`  ❌ ${label}`);
      console.error(`     ${e.message.split('\n')[0]}`);
    }
  };

  const asAssmatOwner = testEnv.authenticatedContext('assmatA', { email: 'assmat-a@test.fr' }).firestore();
  const asMamMember = testEnv.authenticatedContext('mamMemberUid', { email: 'mam-member-b@test.fr' }).firestore();
  const asParent = testEnv.authenticatedContext('parentUid', { email: 'parent-b@test.fr' }).firestore();
  const asStranger = testEnv.authenticatedContext('strangerUid', { email: 'etranger@test.fr' }).firestore();
  const asAdmin = testEnv.authenticatedContext('adminUid', { email: 'cbeylet06@gmail.com' }).firestore();

  console.log('\n--- Usage quotidien normal (le coeur de l\'app, ne doit JAMAIS casser) ---');

  await check('Assistante solo lit la fiche de son propre enfant', () =>
    assertSucceeds(asAssmatOwner.doc('structures/assmatA/children/enfant1').get()));

  await check('Assistante solo ajoute un repas pour son enfant', () =>
    assertSucceeds(asAssmatOwner.collection('structures/assmatA/children/enfant1/repas').add({ heure: '12:00' })));

  await check('Membre MAM lit une fiche enfant de sa structure', () =>
    assertSucceeds(asMamMember.doc('structures/mamOwnerB/children/enfant2').get()));

  await check('Membre MAM ajoute une sieste pour un enfant de sa structure', () =>
    assertSucceeds(asMamMember.collection('structures/mamOwnerB/children/enfant2/sieste').add({ debut: '13:00' })));

  await check('Parent lié lit la fiche de son enfant', () =>
    assertSucceeds(asParent.doc('structures/mamOwnerB/children/enfant2').get()));

  console.log('\n--- Frontières de sécurité (ne doivent JAMAIS s\'ouvrir) ---');

  await check('Un étranger à la structure NE PEUT PAS lire ses enfants', () =>
    assertFails(asStranger.doc('structures/mamOwnerB/children/enfant2').get()));

  await check('Un étranger à la structure NE PEUT PAS écrire dans ses enfants', () =>
    assertFails(asStranger.collection('structures/mamOwnerB/children/enfant2/repas').add({ heure: '12:00' })));

  console.log('\n--- Fonctionnalités corrigées cette semaine ---');

  await check('Diffusion notification admin fonctionne sur une structure qui n\'est PAS la sienne', () =>
    assertSucceeds(asAdmin.collection('structures/mamOwnerB/notifications').add({ title: 'x', body: 'y' })));

  await check('Un non-membre ET non-admin NE PEUT PAS diffuser de notification dans une structure qui n\'est pas la sienne', () =>
    assertFails(asStranger.collection('structures/mamOwnerB/notifications').add({ title: 'x', body: 'y' })));

  await check('Le propriétaire d\'un avenant peut sauvegarder son brouillon', () =>
    assertSucceeds(asAssmatOwner.doc('users/assmatA/avenants/brouillon').set({ isDraft: true })));

  await check('Un étranger NE PEUT PAS lire les avenants d\'un autre', () =>
    assertFails(asStranger.doc('users/assmatA/avenants/brouillon').get()));

  return failures;
}

(async () => {
  const testEnv = await initializeTestEnvironment({
    projectId: 'poppins-rules-test',
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });

  try {
    await seed(testEnv);
    const failures = await run(testEnv);
    await testEnv.cleanup();

    if (failures > 0) {
      console.error(`\n🚨 ${failures} test(s) en échec — NE PAS DÉPLOYER.`);
      process.exit(1);
    }
    console.log('\n✅ Tous les tests passent — sûr de déployer.');
    process.exit(0);
  } catch (err) {
    console.error('\n🚨 Erreur inattendue pendant les tests — NE PAS DÉPLOYER.', err);
    await testEnv.cleanup();
    process.exit(1);
  }
})();
