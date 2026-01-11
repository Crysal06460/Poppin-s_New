const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function forceRetry() {
    console.log('🔍 Recherche des emails en attente (pending)...');

    // Chercher TOUS les emails en 'pending' (pas d'index requis)
    // On suppose qu'il y en a peu (< 100)
    const pendingSnapshot = await db.collection('emailQueue')
        .where('status', '==', 'pending')
        .get();

    console.log(`Trouvé ${pendingSnapshot.size} emails pending au total.`);

    const docs = pendingSnapshot.docs.filter(d => {
        const data = d.data();
        // On ne veut traiter QUE ceux qui sont coincés (donc qui n'ont PAS de processingStartedAt récent)
        // Si processingStartedAt existe, c'est qu'il est en cours (ou planté en cours, mais ici on cherche ceux qui n'ont meme pas démarré)
        if (data.processingStartedAt) return false;

        // On valide ceux qui ont 'updatedAt' (marqueur de notre script de reset)
        // OU ceux qui semblent vieux (> 1 min)
        if (data.updatedAt) return true;

        const createdAt = data.createdAt ? data.createdAt.toDate() : new Date(0);
        const age = Date.now() - createdAt.getTime();
        return age > 60 * 1000; // Plus vieux d'1 minute
    });

    if (docs.length === 0) {
        console.log('✅ Aucun email à forcer.');
        return;
    }

    console.log(`> ${docs.length} emails identifiés à forcer.`);

    const batch = db.batch();

    // On les passe d'abord à 'failed_temp' pour générer un changement d'état
    for (const doc of docs) {
        batch.update(doc.ref, { status: 'failed_temp' });
    }
    await batch.commit();
    console.log('Fait: pending -> failed_temp');

    // Attendre 2 secondes
    console.log('Attente 2s...');
    await new Promise(r => setTimeout(r, 2000));

    const batch2 = db.batch();
    for (const doc of docs) {
        batch2.update(doc.ref, { status: 'pending' });
    }
    await batch2.commit();
    console.log('Fait: failed_temp -> pending');

    console.log('🚀 Trigger forcé envoyé.');
}

forceRetry()
    .then(() => {
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Erreur:', error);
        process.exit(1);
    });
