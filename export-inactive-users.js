const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp({
  credential: admin.credential.cert('./serviceAccountKey.json')
});

const db = admin.firestore();

async function exportInactiveEmails() {
  const inactiveEmails = [];
  let nextPageToken;
  let stats = {
    total: 0,
    noDocument: 0,
    noStructure: 0,
    noSubscription: 0
  };

  console.log('Début de l\'export...\n');

  do {
    const result = await admin.auth().listUsers(1000, nextPageToken);
    stats.total += result.users.length;
    
    for (const user of result.users) {
      if (!user.email) continue;
      
      try {
        const userDoc = await db.collection('users').doc(user.email).get();
        
        if (!userDoc.exists) {
          inactiveEmails.push({
            email: user.email,
            reason: 'no_profile'
          });
          stats.noDocument++;
          console.log(`✓ ${user.email} - Pas de profil`);
        } else {
          const userData = userDoc.data();
          
          if (!userData.structureId) {
            inactiveEmails.push({
              email: user.email,
              reason: 'no_structure'
            });
            stats.noStructure++;
            console.log(`✓ ${user.email} - Pas de structure`);
          } else {
            const structureDoc = await db.collection('structures').doc(userData.structureId).get();
            
            if (structureDoc.exists) {
              const structureData = structureDoc.data();
              
              if (!structureData.subscriptionActive) {
                inactiveEmails.push({
                  email: user.email,
                  reason: 'no_active_subscription',
                  structureName: structureData.structureName
                });
                stats.noSubscription++;
                console.log(`✓ ${user.email} - Abonnement inactif`);
              }
            }
          }
        }
      } catch (error) {
        console.error(`Erreur pour ${user.email}:`, error.message);
      }
    }
    
    nextPageToken = result.pageToken;
  } while (nextPageToken);

  const emailsList = inactiveEmails.map(u => u.email).join('\n');
  fs.writeFileSync('emails_inactifs.txt', emailsList);
  fs.writeFileSync('emails_inactifs_detail.json', JSON.stringify(inactiveEmails, null, 2));

  console.log('\n=====================================');
  console.log('RÉSULTATS :');
  console.log('=====================================');
  console.log(`Total utilisateurs Auth : ${stats.total}`);
  console.log(`Sans profil Firestore : ${stats.noDocument}`);
  console.log(`Sans structure : ${stats.noStructure}`);
  console.log(`Sans abonnement actif : ${stats.noSubscription}`);
  console.log(`TOTAL INACTIFS : ${inactiveEmails.length}`);
  console.log('=====================================');
}

exportInactiveEmails().catch(console.error);
