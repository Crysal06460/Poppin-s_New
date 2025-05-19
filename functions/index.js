const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const fs = require('fs');
const handlebars = require('handlebars');
const path = require('path');
const Mailjet = require('node-mailjet');

// Initialiser Firebase Admin
admin.initializeApp();

// Configurer Mailjet
const mailjet = Mailjet.apiConnect(
  '47ce0aca4cc62f625096a6af3fa5cb8a', // Remplacez par votre clé API Mailjet
  '22096ea903efc5beb1e190890b870f97' // Remplacez par votre clé secrète Mailjet
);

// Fonction déclenchée à chaque nouvel élément dans la collection emailQueue
exports.sendEmail = onDocumentCreated({
  region: 'europe-west1',
  document: 'emailQueue/{docId}'
}, async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log('Pas de données trouvées dans l\'événement');
    return null;
  }
  
  const emailData = snap.data();
  console.log('Données entrantes:', JSON.stringify(emailData));
  
  // Vérifier si toutes les données nécessaires sont présentes
  if (!emailData.to || !emailData.templateData) {
    console.error('Données d\'email insuffisantes:', emailData);
    return snap.ref.update({
      status: 'error',
      error: 'Données insuffisantes',
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  try {
    // Charger et compiler le template d'email
    let templatePath = 'templates/parent-invitation.html'; // Template par défaut
    if (emailData.template && typeof emailData.template === 'string') {
      // Si un template spécifique est demandé, utilisez-le (mais vérifiez qu'il existe)
      const requestedTemplate = `templates/${emailData.template}.html`;
      try {
        // Vérifier si le fichier existe
        fs.accessSync(path.join(__dirname, requestedTemplate), fs.constants.R_OK);
        templatePath = requestedTemplate;
        console.log(`Utilisation du template demandé: ${templatePath}`);
      } catch (e) {
        console.warn(`Le template demandé '${requestedTemplate}' n'existe pas, utilisation du template par défaut`);
      }
    }

    const templateSource = fs.readFileSync(path.join(__dirname, templatePath), 'utf8');
    console.log('Template chargé avec succès');
    
    const compiledTemplate = handlebars.compile(templateSource);
    
    // Générer le contenu HTML avec les données du template
    const htmlContent = compiledTemplate(emailData.templateData);
    
    // Envoyer l'email via Mailjet
    const request = mailjet.post('send', { version: 'v3.1' }).request({
      Messages: [
        {
          From: {
            Email: "noreply@poppin-s.app", // Utilisez votre domaine vérifié
            Name: "Les Lutins - Application Poppins"
          },
          To: [
            {
              Email: emailData.to
            }
          ],
          Subject: emailData.subject || 'Invitation à l\'application Poppins',
          HTMLPart: htmlContent
        }
      ]
    });
    
    const result = await request;
    
    // Mettre à jour le statut dans Firestore
    await snap.ref.update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`Email envoyé avec succès à ${emailData.to}`);
    return null;
  } catch (error) {
    console.error('Erreur lors de l\'envoi de l\'email:', error);
    console.error('Détails de l\'erreur:', JSON.stringify(error));
    
    // Mettre à jour le statut avec l'erreur
    await snap.ref.update({
      status: 'error',
      error: error.message,
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return null;
  }
});

// NOUVELLE FONCTION: Duplication automatique des plannings de ménage
// S'exécute tous les dimanches à minuit (00:00)
exports.duplicateCleaningSchedules = onSchedule({
  schedule: '0 0 * * 0', // Format cron: minute heure jour-du-mois mois jour-de-la-semaine (0 = dimanche)
  timeZone: 'Europe/Paris', // Fuseau horaire français
  region: 'europe-west1' // Même région que votre autre fonction
}, async (event) => {
  const db = admin.firestore();
  console.log('Démarrage de la duplication automatique des plannings de ménage');
  
  try {
    // Récupérer toutes les structures (MAMs)
    const structuresSnapshot = await db.collection('structures').get();
    console.log(`Nombre de structures trouvées: ${structuresSnapshot.size}`);
    
    let duplicatedCount = 0; // Compteur pour les statistiques
    
    for (const structureDoc of structuresSnapshot.docs) {
      const structureId = structureDoc.id;
      
      try {
        // Calculer les dates
        const today = new Date();
        
        // Calculer le début de la semaine actuelle (lundi précédent)
        const currentWeekStart = new Date(today);
        currentWeekStart.setDate(today.getDate() - today.getDay() + 1); // Lundi de cette semaine (today.getDay() retourne 0 pour dimanche)
        if (today.getDay() === 0) { // Si aujourd'hui est dimanche
          currentWeekStart.setDate(currentWeekStart.getDate() - 7); // On prend le lundi de la semaine qui vient de s'écouler
        }
        
        // Calculer le début de la semaine suivante
        const nextWeekStart = new Date(currentWeekStart);
        nextWeekStart.setDate(nextWeekStart.getDate() + 7); // Lundi de la semaine prochaine
        
        // Formater les dates pour les IDs de documents
        const currentWeekId = formatDate(currentWeekStart);
        const nextWeekId = formatDate(nextWeekStart);
        
        console.log(`Structure ${structureId}: Tentative de duplication du planning ${currentWeekId} vers ${nextWeekId}`);
        
        // Vérifier si un planning existe déjà pour la semaine suivante
        const nextWeekPlanningRef = db
          .collection('structures')
          .doc(structureId)
          .collection('cleaningSchedules')
          .doc(nextWeekId);
        
        const nextWeekPlanningDoc = await nextWeekPlanningRef.get();
        
        // Si aucun planning n'existe pour la semaine suivante
        if (!nextWeekPlanningDoc.exists) {
          // Récupérer le planning de la semaine actuelle
          const currentPlanningRef = db
            .collection('structures')
            .doc(structureId)
            .collection('cleaningSchedules')
            .doc(currentWeekId);
          
          const currentPlanningDoc = await currentPlanningRef.get();
          
          // Si un planning existe pour la semaine actuelle, le dupliquer
          if (currentPlanningDoc.exists && currentPlanningDoc.data()) {
            await nextWeekPlanningRef.set(currentPlanningDoc.data());
            console.log(`Planning dupliqué pour la structure ${structureId} pour la semaine du ${nextWeekId}`);
            duplicatedCount++;
          } else {
            console.log(`Aucun planning trouvé pour la structure ${structureId} pour la semaine actuelle ${currentWeekId}`);
          }
        } else {
          console.log(`Un planning existe déjà pour la structure ${structureId} pour la semaine ${nextWeekId}`);
        }
      } catch (structureError) {
        console.error(`Erreur lors du traitement de la structure ${structureId}:`, structureError);
        // Continuer avec la structure suivante
      }
    }
    
    console.log(`Duplication terminée. ${duplicatedCount} plannings dupliqués sur ${structuresSnapshot.size} structures.`);
    return null;
  } catch (error) {
    console.error('Erreur globale lors de la duplication des plannings:', error);
    return null;
  }
});

// Fonction utilitaire pour formater la date au format YYYY-MM-DD
function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}