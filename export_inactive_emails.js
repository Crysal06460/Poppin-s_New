const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json"))
});

const db = admin.firestore();

(async () => {
  const snap = await db.collection("structures").get();
  const emails = [];

  snap.forEach(doc => {
    const data = doc.data();

    const active = data.subscriptionActive === true;

    // Si la structure n'est PAS active → on ajoute le mail
    if (!active && data.email) {
      emails.push(data.email);
    }
  });

  fs.writeFileSync("emails_inactifs.csv", emails.join("\n"), "utf8");

  console.log("Export terminé :", emails.length, "emails trouvés.");
})();

