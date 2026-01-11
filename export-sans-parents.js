const admin = require('firebase-admin');
const fs = require('fs');

admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json'))
});

const db = admin.firestore();

(async () => {
  console.log('🔍 Extraction (SANS les parents)...\n');
  
  const allData = [];
  
  // Users (sauf role: parent)
  console.log('📧 Users...');
  const users = await db.collection('users').get();
  let parentCount = 0;
  
  users.forEach(doc => {
    const d = doc.data();
    
    // SKIP si role = parent
    if (d.role === 'parent') {
      parentCount++;
      return;
    }
    
    if (d.email) {
      allData.push({
        email: d.email,
        telephone: d.phone || d.phoneNumber || d.telephone || '',
        prenom: d.firstName || '',
        nom: d.lastName || '',
        role: d.role || '',
        source: 'user',
        id: doc.id
      });
    }
  });
  console.log(`✅ ${users.size} users traités (${parentCount} parents exclus)`);
  
  // Structures (sauf role: parent)
  console.log('🏢 Structures...');
  const structures = await db.collection('structures').get();
  
  for (const structDoc of structures.docs) {
    const d = structDoc.data();
    
    // Owner (sauf si parent)
    if (d.ownerEmail && d.role !== 'parent') {
      allData.push({
        email: d.ownerEmail,
        telephone: d.ownerPhone || d.phone || '',
        prenom: d.ownerFirstName || '',
        nom: d.ownerLastName || '',
        role: d.role || '',
        source: 'structure-owner',
        id: structDoc.id
      });
    }
    
    // Members (sauf role: parent)
    const members = await structDoc.ref.collection('members').get();
    members.forEach(m => {
      const md = m.data();
      
      // SKIP si role = parent
      if (md.role === 'parent') {
        parentCount++;
        return;
      }
      
      if (md.email) {
        allData.push({
          email: md.email,
          telephone: md.phone || md.phoneNumber || md.telephone || '',
          prenom: md.firstName || '',
          nom: md.lastName || '',
          role: md.role || '',
          source: 'member',
          id: m.id
        });
      }
    });
  }
  console.log(`✅ ${structures.size} structures traitées\n`);
  
  // Export CSV
  const csv = [
    'email;telephone;prenom;nom;role;source;id',
    ...allData.map(row => 
      `${row.email};${row.telephone};${row.prenom};${row.nom};${row.role};${row.source};${row.id}`
    )
  ].join('\n');
  
  fs.writeFileSync('emails_sans_parents.csv', csv);
  
  // Liste simple (emails uniques)
  const uniqueEmails = [...new Set(allData.map(d => d.email))];
  fs.writeFileSync('emails_uniques_sans_parents.txt', uniqueEmails.join('\n'));
  
  console.log('═══════════════════════════════════════');
  console.log(`✅ ${allData.length} lignes exportées`);
  console.log(`✅ ${uniqueEmails.length} emails uniques`);
  console.log(`🚫 ${parentCount} parents exclus`);
  console.log('═══════════════════════════════════════');
  console.log('\n📂 Fichiers créés:');
  console.log('  - emails_sans_parents.csv');
  console.log('  - emails_uniques_sans_parents.txt');
  console.log('\n🎉 Terminé !');
  
  process.exit(0);
})().catch(err => {
  console.error('❌ Erreur:', err);
  process.exit(1);
});
