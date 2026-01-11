const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function requeueStuckEmails() {
  console.log('🔍 Recherche des emails bloqués...');
  
  // Chercher les emails en 'processing' (bloqués)
  const processingSnapshot = await db.collection('emailQueue')
    .where('status', '==', 'processing')
    .get();

  // Chercher les emails en 'failed' (au cas où)
  const failedSnapshot = await db.collection('emailQueue')
    .where('status', '==', 'failed')
    .get();

  const docs = [...processingSnapshot.docs, ...failedSnapshot.docs];
  
  if (docs.length === 0) {
    console.log('✅ Aucun email bloqué trouvé.');
    return;
  }

  console.log(`Trouvé ${docs.length} emails à relancer.`);

  for (const doc of docs) {
    const data = doc.data();
    console.log(`Traitement de ${doc.id} (Pour: ${data.to})...`);

    // Préparer les données pour le nouvel email
    const newData = {
      ...data,
      status: 'pending',
      retryCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      requeuedFrom: doc.id
    };

    // Nettoyer les champs liés à l'état précédent
    delete newData.processingStartedAt;
    delete newData.error;
    delete newData.lastError;
    delete newData.lastErrorAt;
    delete newData.errorStack;
    delete newData.sentAt;
    delete newData.mailjetResponse;
    delete newData.messageId;

    // Créer un NOUVEAU document (ce qui déclenchera la Cloud Function 'onDocumentCreated')
    const newRef = await db.collection('emailQueue').add(newData);
    console.log(`✨ Nouvel email créé: ${newRef.id}`);
    
    // Supprimer l'ANCIEN document pour ne pas le laisser traîner
    await doc.ref.delete();
    console.log(`🗑️ Ancien email supprimé: ${doc.id}`);
  }

  console.log('✅ Tous les emails ont été remis dans la file d\'attente.');
}

requeueStuckEmails()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Erreur:', error);
    process.exit(1);
  });
