const admin = require('firebase-admin');

// Initialiser Firebase Admin avec votre clé de service
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json'))
});

const db = admin.firestore();

async function getAllEmails() {
  const allEmails = new Set(); // Utiliser Set pour éviter les doublons
  const emailsBySource = {
    structures: [],
    users: [],
    members: [],
    subscriptions: []
  };

  console.log('🔍 Début de l\'extraction des emails...\n');

  // 1. Récupérer les emails depuis la collection "users"
  console.log('📧 Extraction depuis users...');
  const usersSnapshot = await db.collection('users').get();
  usersSnapshot.forEach(doc => {
    const data = doc.data();
    if (data.email) {
      allEmails.add(data.email);
      emailsBySource.users.push({
        email: data.email,
        firstName: data.firstName || '',
        lastName: data.lastName || '',
        userId: doc.id
      });
    }
  });
  console.log(`✅ ${emailsBySource.users.length} emails trouvés dans users\n`);

  // 2. Récupérer les emails depuis la collection "structures"
  console.log('🏢 Extraction depuis structures...');
  const structuresSnapshot = await db.collection('structures').get();
  
  for (const structDoc of structuresSnapshot.docs) {
    const structData = structDoc.data();
    
    // Email du propriétaire de la structure
    if (structData.ownerEmail) {
      allEmails.add(structData.ownerEmail);
      emailsBySource.structures.push({
        email: structData.ownerEmail,
        firstName: structData.ownerFirstName || '',
        lastName: structData.ownerLastName || '',
        structureId: structDoc.id,
        type: 'owner'
      });
    }
    
    if (structData.email) {
      allEmails.add(structData.email);
      emailsBySource.structures.push({
        email: structData.email,
        structureId: structDoc.id,
        type: 'structure'
      });
    }

    // 3. Récupérer les emails des membres de chaque structure
    const membersSnapshot = await structDoc.ref.collection('members').get();
    membersSnapshot.forEach(memberDoc => {
      const memberData = memberDoc.data();
      if (memberData.email) {
        allEmails.add(memberData.email);
        emailsBySource.members.push({
          email: memberData.email,
          firstName: memberData.firstName || '',
          lastName: memberData.lastName || '',
          structureId: structDoc.id,
          memberId: memberDoc.id
        });
      }
    });
  }
  console.log(`✅ ${emailsBySource.structures.length} emails trouvés dans structures`);
  console.log(`✅ ${emailsBySource.members.length} emails trouvés dans members\n`);

  // 4. Récupérer les emails depuis les subscriptions (si vous avez cette collection)
  console.log('💳 Extraction depuis subscriptions...');
  try {
    const subscriptionsSnapshot = await db.collection('subscriptions').get();
    subscriptionsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.email) {
        allEmails.add(data.email);
        emailsBySource.subscriptions.push({
          email: data.email,
          status: data.status,
          subscriptionId: doc.id
        });
      }
    });
    console.log(`✅ ${emailsBySource.subscriptions.length} emails trouvés dans subscriptions\n`);
  } catch (error) {
    console.log('⚠️ Pas de collection subscriptions trouvée\n');
  }

  // Résumé
  console.log('═══════════════════════════════════════');
  console.log('📊 RÉSUMÉ');
  console.log('═══════════════════════════════════════');
  console.log(`Total emails uniques: ${allEmails.size}`);
  console.log(`- Users: ${emailsBySource.users.length}`);
  console.log(`- Structures: ${emailsBySource.structures.length}`);
  console.log(`- Members: ${emailsBySource.members.length}`);
  console.log(`- Subscriptions: ${emailsBySource.subscriptions.length}`);
  console.log('═══════════════════════════════════════\n');

  return {
    uniqueEmails: Array.from(allEmails),
    detailedData: emailsBySource,
    total: allEmails.size
  };
}

// Export en CSV
async function exportToCSV() {
  const data = await getAllEmails();
  const fs = require('fs');
  
  // CSV simple avec tous les emails uniques
  const simpleCSV = 'email\n' + data.uniqueEmails.join('\n');
  fs.writeFileSync('emails_uniques.csv', simpleCSV);
  console.log('✅ Fichier emails_uniques.csv créé');

  // CSV détaillé avec toutes les infos
  const detailedRows = [
    'email,source,firstName,lastName,status,id'
  ];

  data.detailedData.users.forEach(u => {
    detailedRows.push(`${u.email},user,${u.firstName},${u.lastName},,${u.userId}`);
  });

  data.detailedData.structures.forEach(s => {
    detailedRows.push(`${s.email},structure-${s.type},${s.firstName || ''},${s.lastName || ''},,${s.structureId}`);
  });

  data.detailedData.members.forEach(m => {
    detailedRows.push(`${m.email},member,${m.firstName},${m.lastName},,${m.structureId}`);
  });

  data.detailedData.subscriptions.forEach(sub => {
    detailedRows.push(`${sub.email},subscription,,,${sub.status},${sub.subscriptionId}`);
  });

  fs.writeFileSync('emails_detailles.csv', detailedRows.join('\n'));
  console.log('✅ Fichier emails_detailles.csv créé\n');
}

// Exécution
getAllEmails()
  .then(data => {
    console.log('🎉 Extraction terminée !');
    console.log('\nPremiers emails trouvés:');
    data.uniqueEmails.slice(0, 10).forEach(email => console.log(`  - ${email}`));
    
    // Décommenter pour exporter en CSV
    return exportToCSV();
  })
  .catch(error => {
    console.error('❌ Erreur:', error);
  });

