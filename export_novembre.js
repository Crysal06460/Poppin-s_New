const admin = require("firebase-admin");
const fs = require("fs");

// CHARGE LA CLÉ FIREBASE
admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json"))
});

const db = admin.firestore();

(async () => {
  const ref = db
    .collection("structures")
    .doc("KV5UNpUfnGaHWR0gKyjYWQjMFIz1")
    .collection("horaires_history");

  const snap = await ref
    .where("timestamp", ">=", new Date("2025-11-01T00:00:00"))
    .where("timestamp", "<=", new Date("2025-11-30T23:59:59"))
    .get();

  const rows = [];

  snap.forEach(doc => {
    rows.push({
      id: doc.id,
      ...doc.data()
    });
  });

  if (rows.length === 0) {
    console.log("Aucun document trouvé.");
    return;
  }

  // Génère un CSV simple
  const csv = [
    Object.keys(rows[0]).join(";"),
    ...rows.map(row =>
      Object.values(row)
        .map(v => JSON.stringify(v)) // nettoie le contenu
        .join(";")
    )
  ].join("\n");

  fs.writeFileSync("horaires_novembre.csv", csv, "utf8");

  console.log("Export terminé : horaires_novembre.csv créé avec succès !");
})();

