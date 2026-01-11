const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixEmailQueue() {
    console.log('🔍 Recherche des emails bloqués (processing) ou échoués (failed)...');

    // Chercher les emails en 'processing'
    const processingSnapshot = await db.collection('emailQueue')
        .where('status', '==', 'processing')
        .get();

    // Chercher les emails en 'failed'
    const failedSnapshot = await db.collection('emailQueue')
        .where('status', '==', 'failed')
        .get();

    const docs = [...processingSnapshot.docs, ...failedSnapshot.docs];

    if (docs.length === 0) {
        console.log('✅ Aucun email bloqué trouvé.');
        return;
    }

    console.log(`Trouvé ${docs.length} emails à relancer.`);

    const batch = db.batch();
    let count = 0;

    for (const doc of docs) {
        const data = doc.data();
        console.log(`Préparation du reset pour ${doc.id} (Pour: ${data.to})...`);

        const updateData = {
            status: 'pending',
            retryCount: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Suppression des champs d'erreur et de processing pour repartir propre
            processingStartedAt: admin.firestore.FieldValue.delete(),
            error: admin.firestore.FieldValue.delete(),
            lastError: admin.firestore.FieldValue.delete(),
            lastErrorAt: admin.firestore.FieldValue.delete(),
            errorStack: admin.firestore.FieldValue.delete(),
            sentAt: admin.firestore.FieldValue.delete(),
            mailjetResponse: admin.firestore.FieldValue.delete(),
            messageId: admin.firestore.FieldValue.delete()
        };

        batch.update(doc.ref, updateData);
        count++;

        // Firestore batch limit is 500
        if (count >= 400) {
            console.log('Commit partiel...');
            await batch.commit();
            count = 0;
        }
    }

    if (count > 0) {
        await batch.commit();
    }

    console.log('✅ Tous les emails ont été remis en statut "pending".');
    console.log('🚀 La Cloud Function devrait les traiter automatiquement maintenant.');
}

fixEmailQueue()
    .then(() => {
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Erreur:', error);
        process.exit(1);
    });
