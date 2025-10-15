const {onDocumentCreated, onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall} = require('firebase-functions/v2/https'); // AJOUT pour la nouvelle fonction
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {getAuth} = require('firebase-admin/auth'); // AJOUT pour l'authentification

const PDFDocument = require('pdfkit');
const {DateTime} = require('luxon');

// ===== IMPORTS POUR LES EMAILS AVEC MAILJET =====
const Mailjet = require('node-mailjet');
const fs = require('fs');
const handlebars = require('handlebars');
const path = require('path');

// Initialiser Firebase Admin
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ===== CONFIGURATION MAILJET =====
const mailjet = Mailjet.apiConnect(
  '47ce0aca4cc62f625096a6af3fa5cb8a', // Votre clé API Mailjet
  '22096ea903efc5beb1e190890b870f97'  // Votre clé secrète Mailjet
);

// ===== NOUVELLE FONCTION : Envoyer un email depuis l'app =====
exports.sendEmailToParent = onCall({
    region: 'europe-west1' // Même région que vos autres fonctions
}, async (request) => {
    console.log('📧 NOUVEAU: sendEmailToParent appelée');
    
    // Vérification authentification
    if (!request.auth) {
        console.error('❌ Utilisateur non authentifié');
        throw new Error('unauthenticated');
    }

    const {
        recipientEmail,
        recipientName,
        subject,
        message,
        templateType,
        childId,
        childName,
        sendFromApp
    } = request.data;

    console.log('📧 Données reçues:', {
        recipientEmail,
        recipientName,
        subject,
        templateType,
        childId,
        childName,
        sendFromApp
    });

    // Validation des données
    if (!recipientEmail || !recipientName || !subject || !message) {
        console.error('❌ Données manquantes');
        throw new Error('invalid-argument');
    }

    try {
        // Récupération des infos utilisateur pour signature
        const userRecord = await getAuth().getUser(request.auth.uid);
        const senderName = userRecord.displayName || 'Équipe Poppins';
        const senderEmail = 'noreply@poppin-s.app'; // Votre email vérifié

        console.log(`📧 Envoi email de ${senderName} vers ${recipientEmail}`);

        // Construction du contenu email avec votre style existant
        const emailContent = {
            senderName,
            recipientName,
            subject,
            message: message,
            childName: childName || '',
            sentFromApp: sendFromApp || false,
            templateType: templateType || 'custom',
            timestamp: new Date().toLocaleString('fr-FR', { 
                timeZone: 'Europe/Paris',
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            })
        };

        // Génération du HTML avec votre style (réutilise votre logique)
        const htmlContent = generateEmailHtml(emailContent);

        // Configuration email Mailjet (identique à votre logique existante)
        const mailjetMessage = {
            From: {
                Email: senderEmail,
                Name: senderName
            },
            To: [{
                Email: recipientEmail,
                Name: recipientName
            }],
            Subject: subject,
            HTMLPart: htmlContent,
            TextPart: `${message}\n\n---\nEnvoyé depuis l'application Poppins\nPar: ${senderName}\nLe: ${emailContent.timestamp}`
        };

        console.log('📧 Envoi via Mailjet...');

        // Envoi via Mailjet (utilise votre configuration existante)
        const request_mailjet = mailjet.post('send', { version: 'v3.1' }).request({
            Messages: [mailjetMessage]
        });

        const result = await request_mailjet;

        console.log('✅ Email envoyé avec succès via Mailjet');
        console.log('📊 Réponse Mailjet:', JSON.stringify(result.body, null, 2));

        // Sauvegarde dans Firestore pour historique
        await db.collection('email_history').add({
            recipientEmail,
            recipientName,
            subject,
            message: message,
            templateType: templateType || 'custom',
            childId: childId || null,
            childName: childName || null,
            sentBy: request.auth.uid,
            senderName,
            sentAt: FieldValue.serverTimestamp(),
            sentFromApp: sendFromApp || false,
            mailjetResponse: result.body?.Messages?.[0]?.Status || 'sent',
            messageId: result.body?.Messages?.[0]?.MessageID || 'unknown',
            status: 'sent'
        });

        console.log('✅ Email sauvegardé dans l\'historique');

        return {
            success: true,
            messageId: result.body?.Messages?.[0]?.MessageID || 'unknown',
            message: 'Email envoyé avec succès'
        };

    } catch (error) {
        console.error('❌ Erreur envoi email:', error);
        
        // Sauvegarde de l'erreur dans l'historique
        try {
            const userRecord = await getAuth().getUser(request.auth.uid);
            await db.collection('email_history').add({
                recipientEmail,
                recipientName,
                subject,
                message,
                templateType: templateType || 'custom',
                childId: childId || null,
                childName: childName || null,
                sentBy: request.auth.uid,
                senderName: userRecord.displayName || 'Équipe Poppins',
                sentAt: FieldValue.serverTimestamp(),
                sentFromApp: sendFromApp || false,
                error: error.message,
                status: 'failed'
            });
        } catch (saveError) {
            console.error('❌ Erreur sauvegarde historique:', saveError);
        }

        throw new Error('internal');
    }
});

// ===== FONCTION HELPER : Générer le HTML de l'email =====
function generateEmailHtml(content) {
    return `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>${content.subject}</title>
            <style>
                body { 
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                    line-height: 1.6; 
                    color: #333333; 
                    background-color: #f8f9fa;
                    margin: 0;
                    padding: 20px;
                }
                .container { 
                    max-width: 600px; 
                    margin: 0 auto; 
                    background-color: white;
                    border-radius: 12px;
                    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                    overflow: hidden;
                }
                .header { 
                    background: linear-gradient(135deg, #3D9DF2 0%, #05C7F2 100%); 
                    color: white; 
                    padding: 30px 20px; 
                    text-align: center; 
                }
                .header h1 { 
                    margin: 0; 
                    font-size: 24px; 
                    font-weight: 600; 
                }
                .content { 
                    padding: 30px 20px; 
                }
                .recipient-info {
                    background-color: #DFE9F2;
                    border-left: 4px solid #3D9DF2;
                    padding: 15px;
                    margin-bottom: 20px;
                    border-radius: 0 8px 8px 0;
                }
                .message-content {
                    background-color: #f8f9fa;
                    padding: 20px;
                    border-radius: 8px;
                    margin: 20px 0;
                    white-space: pre-wrap;
                }
                .footer { 
                    background-color: #f1f3f4; 
                    padding: 20px; 
                    text-align: center; 
                    font-size: 12px; 
                    color: #666666; 
                    border-top: 1px solid #e0e0e0;
                }
                .app-badge {
                    display: inline-block;
                    background-color: #3D9DF2;
                    color: white;
                    padding: 4px 12px;
                    border-radius: 16px;
                    font-size: 11px;
                    font-weight: 500;
                    margin-top: 10px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>📧 ${content.subject}</h1>
                </div>
                
                <div class="content">
                    <div class="recipient-info">
                        <strong>👋 Bonjour ${content.recipientName},</strong>
                        ${content.childName ? `<br><small>Concernant: <strong>${content.childName}</strong></small>` : ''}
                    </div>
                    
                    <div class="message-content">
                        ${content.message}
                    </div>
                    
                    <p style="margin-top: 30px; color: #666;">
                        Cordialement,<br>
                        <strong>${content.senderName}</strong>
                    </p>
                </div>
                
                <div class="footer">
                    <p>
                        Envoyé le ${content.timestamp}
                        ${content.sentFromApp ? '<br><span class="app-badge">📱 Depuis l\'application Poppins</span>' : ''}
                    </p>
                    <p style="margin-top: 15px;">
                        Cet email a été envoyé automatiquement. Pour toute question, 
                        contactez directement votre structure.
                    </p>
                </div>
            </div>
        </body>
        </html>
    `;
}

// ======= DÉLÉGATIONS MAM =======
exports.acceptDelegation = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) {
    throw new Error('unauthenticated');
  }
  const { delegationId } = request.data || {};
  if (!delegationId) throw new Error('invalid-argument');

  const delSnap = await db.collectionGroup('delegations').where('__name__', '==', delegationId).get();
  // collectionGroup on __name__ doesn't work; fetch needs structureId. Fallback: client provides structureId in doc path.
  // Simpler: try common path from request.data.structureId if provided
  let delegationDoc = null;
  if (delSnap && delSnap.docs && delSnap.docs.length > 0) {
    delegationDoc = delSnap.docs[0];
  } else if (request.data.structureId) {
    delegationDoc = await db
      .collection('structures')
      .doc(request.data.structureId)
      .collection('delegations')
      .doc(delegationId)
      .get();
  } else {
    throw new Error('invalid-argument');
  }

  if (!delegationDoc.exists) throw new Error('not-found');
  const d = delegationDoc.data();
  if (d.status !== 'proposed') return { success: false, message: 'Already processed' };
  // Vérifier que l'appelant correspond bien au membre délégué
  const userRec = await getAuth().getUser(request.auth.uid);
  const email = (userRec.email || '').toLowerCase();
  let allowed = false;
  if (d.amDelegateId === request.auth.uid) allowed = true; // compat
  if (!allowed && email) {
    const memSnap = await db.collection('structures').doc(d.structureId).collection('members')
      .where('email', '==', email).limit(5).get();
    memSnap.forEach(m => { if (m.id === d.amDelegateId) allowed = true; });
  }
  if (!allowed) throw new Error('permission-denied');

  const structureId = d.structureId;
  const date = d.date.toDate ? d.date.toDate() : new Date(d.date);
  const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  // Map weekday: JS 0=Sun..6=Sat => Flutter 1=Mon..7=Sun
  const jsDay = start.getDay();
  const jourSemaine = jsDay === 0 ? 7 : jsDay; // 1..7

  // Compter enfants pour l'AM déléguée ce jour
  const gardesRef = db.collection('structures').doc(structureId).collection('gardes');
  const recSnap = await gardesRef
    .where('recurrent', '==', true)
    .where('jourSemaine', '==', jourSemaine)
    .where('membreId', '==', d.amDelegateId)
    .get();
  const excSnap = await gardesRef
    .where('recurrent', '==', false)
    .where('membreId', '==', d.amDelegateId)
    .where('dateException', '>=', start)
    .where('dateException', '<', end)
    .get();

  const enfantSet = new Set();
  recSnap.forEach((doc) => enfantSet.add(doc.data().enfantId));
  excSnap.forEach((doc) => enfantSet.add(doc.data().enfantId));

  // Ajouter délégations acceptées existantes de ce jour
  const acceptedSnap = await db
    .collection('structures')
    .doc(structureId)
    .collection('delegations')
    .where('status', '==', 'accepted')
    .where('amDelegateId', '==', d.amDelegateId)
    .where('date', '>=', start)
    .where('date', '<', end)
    .get();
  acceptedSnap.forEach((doc) => enfantSet.add(doc.data().childId));

  // Si l'enfant à déléguer est déjà dans le set, ne pas compter deux fois
  const currentCount = enfantSet.has(d.childId) ? enfantSet.size : enfantSet.size + 1;
  if (currentCount > 4) {
    return { success: false, message: 'capacity-exceeded' };
  }

  await delegationDoc.ref.update({
    status: 'accepted',
    acceptedBy: request.auth.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { success: true };
});

exports.declineDelegation = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) throw new Error('unauthenticated');
  const { delegationId, structureId } = request.data || {};
  if (!delegationId || !structureId) throw new Error('invalid-argument');
  const ref = db.collection('structures').doc(structureId).collection('delegations').doc(delegationId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('not-found');
  const d = snap.data();
  const userRec = await getAuth().getUser(request.auth.uid);
  const email = (userRec.email || '').toLowerCase();
  let allowed = [d.createdBy].includes(request.auth.uid) || [d.amDelegateId, d.amOriginId].includes(request.auth.uid);
  if (!allowed && email) {
    const memSnap = await db.collection('structures').doc(structureId).collection('members')
      .where('email', '==', email).limit(10).get();
    const ids = memSnap.docs.map(d => d.id);
    if (ids.includes(d.amDelegateId) || ids.includes(d.amOriginId)) allowed = true;
  }
  if (!allowed) throw new Error('permission-denied');
  await ref.update({ status: 'declined', updatedAt: FieldValue.serverTimestamp() });
  return { success: true };
});

exports.cancelDelegation = onCall({ region: 'europe-west1' }, async (request) => {
  if (!request.auth) throw new Error('unauthenticated');
  const { delegationId, structureId } = request.data || {};
  if (!delegationId || !structureId) throw new Error('invalid-argument');
  const ref = db.collection('structures').doc(structureId).collection('delegations').doc(delegationId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error('not-found');
  const d = snap.data();
  const userRec = await getAuth().getUser(request.auth.uid);
  const email = (userRec.email || '').toLowerCase();
  let allowed = [d.createdBy, d.amOriginId].includes(request.auth.uid);
  if (!allowed && email) {
    const memSnap = await db.collection('structures').doc(structureId).collection('members')
      .where('email', '==', email).limit(10).get();
    const ids = memSnap.docs.map(d => d.id);
    if (ids.includes(d.amOriginId)) allowed = true;
  }
  if (!allowed) throw new Error('permission-denied');
  await ref.update({ status: 'canceled', updatedAt: FieldValue.serverTimestamp() });
  return { success: true };
});

// 🔔 Notifier le membre destinataire lors d'une nouvelle délégation proposée
exports.onDelegationCreated = onDocumentCreated({
  document: 'structures/{structureId}/delegations/{delegationId}',
  region: 'europe-west1'
}, async (event) => {
  try {
    const data = event.data.data();
    if (!data || data.status !== 'proposed') return;
    const structureId = event.params.structureId;

    // Récupérer l'email du membre délégué
    const delegateMemberRef = db.collection('structures').doc(structureId).collection('members').doc(data.amDelegateId);
    const delegateMemberSnap = await delegateMemberRef.get();
    if (!delegateMemberSnap.exists) return;
    const delegateEmail = (delegateMemberSnap.data().email || '').toLowerCase();
    if (!delegateEmail) return;

    // Récupérer le prénom de l'enfant pour le message
    let childName = 'un enfant';
    try {
      const childSnap = await db.collection('structures').doc(structureId).collection('children').doc(data.childId).get();
      if (childSnap.exists) {
        const cd = childSnap.data();
        childName = `${cd.firstName || ''} ${cd.lastName || ''}`.trim() || childName;
      }
    } catch (_) {}

    const title = 'Nouvelle délégation à traiter';
    const body = `Vous avez une demande de délégation pour ${childName}`;
    await createNotificationDoc(db, {
      recipientUserId: delegateEmail,
      title,
      body,
      childId: data.childId,
      messageId: event.params.delegationId,
      senderType: 'assistante'
    });
  } catch (e) {
    console.error('❌ Erreur onDelegationCreated:', e);
  }
});

// ===== NOUVELLE FONCTION : Traiter la queue d'emails avec Mailjet =====
exports.processEmailQueue = onDocumentCreated({
    document: 'emailQueue/{emailId}',
    region: 'europe-west1' // Même région que vos autres fonctions
}, async (event) => {
    const emailData = event.data.data();
    const emailId = event.params.emailId;
    
    console.log(`📧 Traitement de l'email ${emailId}:`, JSON.stringify(emailData, null, 2));
    
    try {
        // Vérifier que le statut est bien 'pending'
        if (emailData.status !== 'pending') {
            console.log(`📧 Email ${emailId} ignoré - statut: ${emailData.status}`);
            return null;
        }
        
        // Vérifier si toutes les données nécessaires sont présentes
        if (!emailData.to || !emailData.templateData) {
            console.error('❌ Données d\'email insuffisantes:', emailData);
            await event.data.ref.update({
                status: 'failed',
                error: 'Données insuffisantes',
                lastErrorAt: FieldValue.serverTimestamp()
            });
            return null;
        }
        
        // Marquer comme 'processing'
        await event.data.ref.update({
            status: 'processing',
            processingStartedAt: FieldValue.serverTimestamp()
        });
        
        console.log(`📧 Début traitement email pour: ${emailData.to}`);
        console.log(`📧 Template demandé: ${emailData.template}`);
        
        // Charger et compiler le template d'email
        let templatePath = 'templates/parent-invitation.html'; // Template par défaut
        if (emailData.template && typeof emailData.template === 'string') {
            const requestedTemplate = `templates/${emailData.template}.html`;
            try {
                // Vérifier si le fichier existe
                fs.accessSync(path.join(__dirname, requestedTemplate), fs.constants.R_OK);
                templatePath = requestedTemplate;
                console.log(`✅ Utilisation du template: ${templatePath}`);
            } catch (e) {
                console.warn(`⚠️ Template '${requestedTemplate}' non trouvé, utilisation du template par défaut`);
                templatePath = 'templates/parent-invitation.html';
            }
        }

        console.log(`📄 Chargement du template: ${templatePath}`);
        const templateSource = fs.readFileSync(path.join(__dirname, templatePath), 'utf8');
        console.log('✅ Template chargé avec succès');
        
        const compiledTemplate = handlebars.compile(templateSource);
        
        // Générer le contenu HTML avec les données du template
        const htmlContent = compiledTemplate(emailData.templateData);
        console.log('✅ Template compilé avec succès');
        
        // Préparer le message Mailjet
        const mailjetMessage = {
            From: {
                Email: "noreply@poppin-s.app",
                Name: "Application Poppins"
            },
            To: [
                {
                    Email: emailData.to
                }
            ],
            Subject: emailData.subject || 'Invitation à l\'application Poppins',
            HTMLPart: htmlContent
        };
        
        // Ajouter la pièce jointe PDF si elle existe
        if (emailData.pdfAttachment && emailData.pdfFilename) {
            console.log(`📎 Ajout pièce jointe PDF: ${emailData.pdfFilename}`);
            mailjetMessage.Attachments = [
                {
                    ContentType: 'application/pdf',
                    Filename: emailData.pdfFilename,
                    Base64Content: emailData.pdfAttachment
                }
            ];
        }
        
        // Envoyer l'email via Mailjet
        console.log(`📧 Envoi email vers: ${emailData.to} via Mailjet...`);
        
        const request = mailjet.post('send', { version: 'v3.1' }).request({
            Messages: [mailjetMessage]
        });
        
        const result = await request;
        
        console.log(`✅ Email ${emailId} envoyé avec succès via Mailjet`);
        console.log('📊 Réponse Mailjet:', JSON.stringify(result.body, null, 2));
        
        // Marquer comme 'sent'
        await event.data.ref.update({
            status: 'sent',
            sentAt: FieldValue.serverTimestamp(),
            messageId: result.body?.Messages?.[0]?.MessageID || 'unknown',
            mailjetResponse: result.body
        });
        
        console.log(`✅ Email ${emailId} marqué comme envoyé dans Firestore`);
        
    } catch (error) {
        console.error(`❌ Erreur lors de l'envoi de l'email ${emailId}:`, error);
        console.error('❌ Stack trace:', error.stack);
        console.error('❌ Détails de l\'erreur:', JSON.stringify(error, null, 2));
        
        // Marquer comme 'failed' et incrémenter le retry count
        const retryCount = (emailData.retryCount || 0) + 1;
        const maxRetries = 3;
        
        await event.data.ref.update({
            status: retryCount >= maxRetries ? 'failed' : 'pending',
            retryCount: retryCount,
            lastError: error.message,
            lastErrorAt: FieldValue.serverTimestamp(),
            errorStack: error.stack
        });
        
        // Si on a atteint le max de tentatives, log l'erreur finale
        if (retryCount >= maxRetries) {
            console.error(`❌ Email ${emailId} définitivement échoué après ${maxRetries} tentatives`);
        } else {
            console.log(`🔄 Email ${emailId} remis en queue - tentative ${retryCount}/${maxRetries}`);
        }
    }
    
    return null;
});

// ===== NOUVELLE FONCTION : Retry des emails failed =====
exports.retryFailedEmails = onSchedule({
    schedule: 'every 2 hours',
    region: 'europe-west1'
}, async (event) => {
    try {
        const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
        
        console.log('🔄 Recherche des emails échoués à retry...');
        
        const failedEmails = await db
            .collection('emailQueue')
            .where('status', '==', 'failed')
            .where('lastErrorAt', '<', twoHoursAgo)
            .where('retryCount', '<', 3)
            .limit(10)
            .get();
        
        if (failedEmails.empty) {
            console.log('✅ Aucun email échoué à retry');
            return null;
        }
        
        const batch = db.batch();
        
        failedEmails.docs.forEach(doc => {
            console.log(`🔄 Remise en queue de l'email: ${doc.id}`);
            batch.update(doc.ref, {
                status: 'pending',
                retryCount: 0,
                lastError: null,
                lastErrorAt: null,
                errorStack: null
            });
        });
        
        await batch.commit();
        console.log(`✅ ${failedEmails.size} emails remis en queue pour retry`);
        
    } catch (error) {
        console.error('❌ Erreur lors du retry des emails:', error);
    }
    
    return null;
});

// ==========================================
// ===== FONCTIONS NOTIFICATIONS CORRIGÉES =====
// ==========================================

// 🔥 FONCTION PRINCIPALE CORRIGÉE : Notifications Push
exports.sendNotification = onDocumentCreated({
    document: 'notifications/{notificationId}',
    region: 'europe-west1'
}, async (event) => {
    try {
        const notification = event.data.data();
        const notificationId = event.params.notificationId;
        
        console.log(`📤 Nouvelle notification à traiter: ${notificationId}`);
        console.log('📋 Données notification:', JSON.stringify(notification, null, 2));

        // Vérifier si déjà envoyée
        if (notification.sent) {
            console.log('⚠️ Notification déjà envoyée');
            return;
        }

        const recipientUserId = notification.recipientUserId;
        
        if (!recipientUserId) {
            console.error('❌ recipientUserId manquant');
            await event.data.ref.update({
                sent: false,
                error: 'recipientUserId manquant',
                errorAt: FieldValue.serverTimestamp(),
            });
            return;
        }

        console.log(`🎯 Recherche utilisateur: ${recipientUserId}`);
        
        // Rechercher l'utilisateur par email (ID du document)
        const userDoc = await db.collection('users').doc(recipientUserId.toLowerCase()).get();

        if (!userDoc.exists) {
            console.error(`❌ Utilisateur non trouvé: ${recipientUserId}`);
            await event.data.ref.update({
                sent: false,
                error: 'Utilisateur non trouvé',
                errorAt: FieldValue.serverTimestamp(),
            });
            return;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
            console.error(`❌ Token FCM manquant pour: ${recipientUserId}`);
            await event.data.ref.update({
                sent: false,
                error: 'Token FCM manquant',
                errorAt: FieldValue.serverTimestamp(),
            });
            return;
        }

        console.log(`✅ Token FCM trouvé: ${fcmToken.substring(0, 30)}...`);

        // 🛡️ Anti auto-notif: si l'assistante envoie et que le token destinataire == token assistante, ignorer
        try {
            const senderType = (notification.data && notification.data.senderType) || '';
            const childId = (notification.data && notification.data.childId) || null;
            if ((senderType === 'assistante' || senderType === 'staff') && childId) {
                const assistantEmail = await getAssistantEmail(childId);
                if (assistantEmail) {
                    const assDoc = await db.collection('users').doc(assistantEmail.toLowerCase()).get();
                    const assistantToken = assDoc.exists ? (assDoc.data().fcmToken || null) : null;
                    if (assistantToken && assistantToken === fcmToken) {
                        console.log('🛑 Même token que l\'assistante détecté — notification non envoyée pour éviter l\'auto-notif');
                        await event.data.ref.update({
                            sent: true,
                            skipped: true,
                            skipReason: 'same_token_as_assistant'
                        });
                        return;
                    }
                }
            }
        } catch (guardErr) {
            console.warn('⚠️ Erreur anti auto-notif (guard):', guardErr);
        }

        // 🛡️ Anti auto-notif 2: si le document de notif contient un suppressToken égal au token destinataire, ignorer
        try {
            const suppressToken = (notification.data && notification.data.suppressToken) || '';
            if (suppressToken && suppressToken === fcmToken) {
                console.log('🛑 suppressToken == destinataire token — notification ignorée');
                await event.data.ref.update({
                    sent: true,
                    skipped: true,
                    skipReason: 'suppressToken_match'
                });
                return;
            }
        } catch (guard2Err) {
            console.warn('⚠️ Erreur anti auto-notif (suppressToken):', guard2Err);
        }

        // 🔥 CORRECTION CRITIQUE : Structure de message pour iOS/Android
        const message = {
            token: fcmToken,
            notification: {
                title: notification.title || 'Nouveau message',
                body: notification.body || 'Vous avez reçu un nouveau message',
            },
            data: {
                ...(notification.data || {}),
                notificationId: notificationId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            // 🍎 Configuration spécifique iOS (APNs)
            apns: {
  headers: {
    'apns-priority': '10',
    'apns-push-type': 'alert',
    'apns-topic': 'com.beylet.poppinsApp', // IMPORTANT: doit correspondre au bundle iOS
  },
  payload: {
    aps: {
      alert: {
        title: notification.title || 'Nouveau message',
        body: notification.body || 'Vous avez reçu un nouveau message',
      },
      badge: 1,
      sound: 'default',
      'content-available': 1, // Pour background
    }
  },
},
            // 🤖 Configuration spécifique Android (FCM)
            android: {
                priority: 'high',
                notification: {
                    title: notification.title || 'Nouveau message',
                    body: notification.body || 'Vous avez reçu un nouveau message',
                    channel_id: 'messages_channel',
                    priority: 'high',
                    default_sound: true,
                    visibility: 'public',
                    icon: 'ic_launcher',
                    color: '#3D9DF2',
                },
                data: {
                    ...(notification.data || {}),
                    notificationId: notificationId,
                }
            },
        };

        console.log('📱 Structure message final:', JSON.stringify(message, null, 2));

        // 🚀 ENVOYER LA NOTIFICATION
        const response = await messaging.send(message);
        console.log('✅ Notification envoyée avec succès:', response);

        // Marquer comme envoyée
        await event.data.ref.update({
            sent: true,
            sentAt: FieldValue.serverTimestamp(),
            messageId: response,
            fcmTokenUsed: fcmToken.substring(0, 20) + '...', // Pour debug
        });

        console.log(`✅ Notification ${notificationId} marquée comme envoyée`);

    } catch (error) {
        console.error('❌ Erreur envoi notification:', error);
        console.error('📋 Stack trace:', error.stack);
        
        // Analyser le type d'erreur
        let errorType = 'unknown';
        if (error.code === 'messaging/invalid-registration-token') {
            errorType = 'invalid_token';
        } else if (error.code === 'messaging/registration-token-not-registered') {
            errorType = 'token_not_registered';
        } else if (error.code === 'messaging/invalid-argument') {
            errorType = 'invalid_argument';
        }

        await event.data.ref.update({
            sent: false,
            error: error.message,
            errorCode: error.code || 'unknown',
            errorType: errorType,
            errorAt: FieldValue.serverTimestamp(),
            errorStack: error.stack,
        });
    }
});

// 🔥 FONCTION CORRIGÉE : Gérer les nouveaux messages
exports.onNewMessage = onDocumentCreated({
    document: 'exchanges/{messageId}',
    region: 'europe-west1'
}, async (event) => {
    console.log('🔥 DEBUT onNewMessage - Nouveau message détecté !');
    
    try {
        const messageData = event.data.data();
        const messageId = event.params.messageId;
        
        console.log(`📋 Message ${messageId}:`, JSON.stringify(messageData, null, 2));

        const { childId, senderType, content, targetParent, senderFcmToken } = messageData;

        // Éviter le double traitement
        if (messageData.notificationSent) {
            console.log('⚠️ Notification déjà traitée');
            return;
        }

        let recipientEmail = null;
        let title = '';
        let body = content || 'Nouveau message';

        if (senderType === 'parent') {
            // 👨‍👩‍👧‍👦 MESSAGE PARENT → ASSISTANTE
            console.log('👪 Message du parent vers assistante');
            title = 'Nouveau message d\'un parent';
            recipientEmail = await getAssistantEmail(childId);
            
        } else if (senderType === 'assistante' || senderType === 'staff') {
            // 👩‍⚕️ MESSAGE ASSISTANTE → PARENT
            console.log('👩‍⚕️ Message de l\'assistante vers parent');
            title = 'Nouveau message de votre assistante';
            // Respecter le ciblage si présent
            if (targetParent && typeof targetParent === 'string') {
                if (targetParent === 'both') {
                    const emails = await getParentsEmails(childId);
                    for (const email of emails) {
                        await createNotificationDoc(db, { recipientUserId: email, title, body, childId, messageId, senderType, suppressToken: senderFcmToken });
                    }
                    // Marquer et terminer
                    await event.data.ref.update({ notificationSent: true });
                    console.log('✅ Notifications envoyées aux deux parents');
                    return;
                } else if (targetParent.includes('@')) {
                    recipientEmail = targetParent.toLowerCase().trim();
                }
            }
            if (!recipientEmail) {
                recipientEmail = await getParentEmail(childId);
            }

            // Ne jamais notifier l'expéditeur (assistante)
            const assistantEmail = await getAssistantEmail(childId);
            if (assistantEmail && recipientEmail && assistantEmail.toLowerCase() === recipientEmail.toLowerCase()) {
                console.log('⚠️ Destinataire détecté égal à l\'assistante – notification ignorée');
                await event.data.ref.update({ notificationSent: true });
                return;
            }
        }

        if (!recipientEmail) {
            console.error('❌ AUCUN destinataire trouvé !');
            console.error('🔍 Debug info:', {
                senderType,
                childId,
                messageId
            });
            return;
        }

        console.log(`✅ Destinataire trouvé: ${recipientEmail}`);

        // 🔔 CRÉER LA NOTIFICATION (un destinataire)
        const notificationId = await createNotificationDoc(db, {
            recipientUserId: recipientEmail,
            title,
            body,
            childId,
            messageId,
            senderType,
            suppressToken: senderFcmToken,
        });

        // Marquer le message comme traité
        await event.data.ref.update({
            notificationSent: true,
            notificationId,
            notificationCreatedAt: FieldValue.serverTimestamp(),
        });

        console.log(`✅ Message ${messageId} traité avec succès`);

    } catch (error) {
        console.error('❌ Erreur dans onNewMessage:', error);
        console.error('📋 Stack trace:', error.stack);
    }
});

// 🔍 FONCTION HELPER CORRIGÉE : Trouver email assistante
async function getAssistantEmail(childId) {
    try {
        console.log(`🔍 Recherche assistante pour enfant: ${childId}`);
        
        // Chercher dans toutes les structures
        const structuresSnapshot = await db.collection('structures').get();

        for (const structureDoc of structuresSnapshot.docs) {
            console.log(`🏢 Vérification structure: ${structureDoc.id}`);
            
            const childDoc = await db
                .collection('structures')
                .doc(structureDoc.id)
                .collection('children')
                .doc(childId)
                .get();

            if (childDoc.exists) {
                console.log(`👶 Enfant trouvé dans structure: ${structureDoc.id}`);
                
                const childData = childDoc.data();
                const assignedMemberEmail = childData.assignedMemberEmail;

                // Si assigné à un membre MAM spécifique
                if (assignedMemberEmail && assignedMemberEmail.trim() !== '') {
                    const email = assignedMemberEmail.toLowerCase().trim();
                    console.log(`👥 Membre MAM assigné trouvé: ${email}`);
                    return email;
                }

                // Sinon, propriétaire de la structure
                const structureData = structureDoc.data();
                // Priorité : champ assistantEmail (parent employeur)
                if (structureData.assistantEmail && structureData.assistantEmail.trim() !== '') {
                    const email = structureData.assistantEmail.toLowerCase().trim();
                    console.log(`👩‍⚕️ Assistante liée trouvée (assistantEmail): ${email}`);
                    return email;
                }

                // Si on a un assistantLinkedUserId mais pas l'email directement
                if (structureData.assistantLinkedUserId && structureData.assistantLinkedUserId.trim() !== '') {
                    const linkedUid = structureData.assistantLinkedUserId.trim();
                    const userQuery = await db
                        .collection('users')
                        .where('firebaseUid', '==', linkedUid)
                        .limit(1)
                        .get();
                    if (!userQuery.empty) {
                        const email = userQuery.docs[0].id.toLowerCase().trim();
                        console.log(`👩‍⚕️ Assistante retrouvée via firebaseUid: ${email}`);
                        return email;
                    }
                }

                // Essayer d'abord ownerEmail
                if (structureData.ownerEmail && structureData.ownerEmail.trim() !== '') {
                    const email = structureData.ownerEmail.toLowerCase().trim();
                    console.log(`👤 Propriétaire structure trouvé (ownerEmail): ${email}`);
                    return email;
                }

                // Fallback: email du document structure
                if (structureData.email && structureData.email.trim() !== '') {
                    const email = structureData.email.toLowerCase().trim();
                    console.log(`👤 Propriétaire structure trouvé (email): ${email}`);
                    return email;
                }
            }
        }

        console.error(`❌ Aucune assistante trouvée pour childId: ${childId}`);
        return null;
    } catch (error) {
        console.error('❌ Erreur recherche assistante:', error);
        return null;
    }
}

// 🔍 FONCTION HELPER CORRIGÉE : Trouver email parent
async function getParentEmail(childId) {
    try {
        console.log(`🔍 Recherche parent pour enfant: ${childId}`);
        
        // Méthode 1: Chercher directement les parents qui ont cet enfant
        const parentQuery = await db
            .collection('users')
            .where('children', 'array-contains', childId)
            .limit(1)
            .get();

        if (!parentQuery.empty) {
            const doc = parentQuery.docs[0];
            const data = doc.data() || {};
            if ((data.role || '').toLowerCase() === 'parent') {
                const parentEmail = doc.id.toLowerCase();
                console.log(`👪 Parent trouvé via array-contains (role=parent): ${parentEmail}`);
                return parentEmail;
            } else {
                console.log('ℹ️ Utilisateur trouvé mais role != parent, on continue la recherche');
            }
        }

        // Méthode 2: Chercher dans les documents enfants pour récupérer parentId
        console.log('🔍 Recherche dans les documents enfants...');
        const structuresSnapshot = await db.collection('structures').get();
        
        for (const structureDoc of structuresSnapshot.docs) {
            const childDoc = await db
                .collection('structures')
                .doc(structureDoc.id)
                .collection('children')
                .doc(childId)
                .get();

            if (childDoc.exists) {
                const childData = childDoc.data();
                
                // Chercher dans parent1 et parent2
                if (childData.parent1 && childData.parent1.email) {
                    const email = childData.parent1.email.toLowerCase().trim();
                    console.log(`👪 Parent trouvé via parent1: ${email}`);
                    return email;
                }

                if (childData.parent2 && childData.parent2.email) {
                    const email = childData.parent2.email.toLowerCase().trim();
                    console.log(`👪 Parent trouvé via parent2: ${email}`);
                    return email;
                }

                // Fallback: parentId direct (si c'est un email)
                if (childData.parentId && childData.parentId.includes('@')) {
                    const email = childData.parentId.toLowerCase().trim();
                    console.log(`👪 Parent trouvé via parentId: ${email}`);
                    return email;
                }
            }
        }

        console.error(`❌ Aucun parent trouvé pour childId: ${childId}`);
        return null;
    } catch (error) {
        console.error('❌ Erreur recherche parent:', error);
        return null;
    }
}

// Récupérer tous les emails des parents d'un enfant
async function getParentsEmails(childId) {
    const emails = new Set();
    try {
        const parentQuery = await db
            .collection('users')
            .where('children', 'array-contains', childId)
            .get();
        parentQuery.forEach(doc => {
            const data = doc.data() || {};
            if ((data.role || '').toLowerCase() === 'parent') {
                emails.add(doc.id.toLowerCase().trim());
            }
        });

        const structuresSnapshot = await db.collection('structures').get();
        for (const structureDoc of structuresSnapshot.docs) {
            const childDoc = await db
                .collection('structures')
                .doc(structureDoc.id)
                .collection('children')
                .doc(childId)
                .get();
            if (childDoc.exists) {
                const childData = childDoc.data();
                if (childData.parent1 && childData.parent1.email) emails.add(childData.parent1.email.toLowerCase().trim());
                if (childData.parent2 && childData.parent2.email) emails.add(childData.parent2.email.toLowerCase().trim());
                if (childData.parentId && childData.parentId.includes('@')) emails.add(childData.parentId.toLowerCase().trim());
                break;
            }
        }
    } catch (e) {
        console.error('❌ Erreur getParentsEmails:', e);
    }
    return Array.from(emails);
}

// Helper: créer un document de notification
async function createNotificationDoc(db, { recipientUserId, title, body, childId, messageId, senderType, suppressToken }) {
    const notificationData = {
        recipientUserId,
        title,
        body,
        data: { childId, messageId, type: 'message', senderType, suppressToken: suppressToken || '' },
        timestamp: FieldValue.serverTimestamp(),
        sent: false,
        platform: 'multi',
    };
    console.log('📬 Création notification:', JSON.stringify(notificationData, null, 2));
    const ref = await db.collection('notifications').add(notificationData);
    console.log(`📬 Notification créée avec ID: ${ref.id}`);
    return ref.id;
}

// 🧪 FONCTION TEST : Tester les notifications
exports.testNotification = onCall({
    region: 'europe-west1'
}, async (request) => {
    try {
        if (!request.auth) {
            throw new Error('unauthenticated');
        }

        const userEmail = request.auth.token.email?.toLowerCase();
        console.log('🧪 Test notification pour:', userEmail);

        // Créer une notification de test
        const notificationData = {
            recipientUserId: userEmail,
            title: '🧪 Test Notification Push',
            body: 'Ceci est un test des notifications push depuis Firebase Functions !',
            data: { 
                type: 'test',
                timestamp: Date.now().toString(),
            },
            timestamp: FieldValue.serverTimestamp(),
            sent: false,
            platform: 'multi',
        };

        const notificationRef = await db.collection('notifications').add(notificationData);

        return { 
            success: true, 
            message: 'Notification de test créée',
            notificationId: notificationRef.id,
        };
    } catch (error) {
        console.error('❌ Erreur test notification:', error);
        throw new Error('internal');
    }
});

// 🗑️ NETTOYAGE : Supprimer anciennes notifications
exports.cleanupOldNotifications = onSchedule({
    schedule: 'every 24 hours',
    region: 'europe-west1'
}, async (event) => {
    try {
        const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // 7 jours
        
        console.log('🗑️ Nettoyage des notifications anciennes...');
        
        const snapshot = await db
            .collection('notifications')
            .where('timestamp', '<', cutoff)
            .get();

        if (snapshot.empty) {
            console.log('✅ Aucune notification ancienne à supprimer');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        
        await batch.commit();
        console.log(`🗑️ ${snapshot.size} anciennes notifications supprimées`);
    } catch (error) {
        console.error('❌ Erreur nettoyage:', error);
    }
    
    return null;
});

// ================================
// ===== STOCK NOTIF TRIGGER  =====
// ================================
// Crée une notification pour les parents lorsqu'un pro ajoute des besoins de stock
exports.onStockNeedsUpdated = onDocumentWritten({
    document: 'structures/{structureId}/children/{childId}/stocks/current',
    region: 'europe-west1'
}, async (event) => {
    try {
        const beforeData = event.data.before.exists ? event.data.before.data() : {};
        const afterData = event.data.after.exists ? event.data.after.data() : {};

        // Sécurité: si le doc est supprimé ou vide -> rien à faire
        if (!event.data.after.exists || !afterData) {
            console.log('ℹ️ Stock supprimé ou vide, aucune notif créée');
            return null;
        }

        // Détecter les nouveaux items passés à true
        let newlyActivated = [];
        Object.keys(afterData || {}).forEach((key) => {
            const afterVal = !!afterData[key];
            const beforeVal = !!(beforeData ? beforeData[key] : false);
            if (afterVal === true && beforeVal !== true) {
                newlyActivated.push(key);
            }
        });

        // Cas initial: avant aucun besoin actif et après ≥1 besoin actif
        if (newlyActivated.length === 0) {
            const beforeTrue = Object.keys(beforeData || {}).filter(k => !!beforeData[k]);
            const afterTrue = Object.keys(afterData || {}).filter(k => !!afterData[k]);
            if (beforeTrue.length === 0 && afterTrue.length > 0) {
                newlyActivated = afterTrue; // notifier la première fois
                console.log('ℹ️ Activation initiale des besoins, items:', newlyActivated);
            } else {
                console.log('ℹ️ Aucun nouveau besoin de stock activé');
                return null;
            }
        }

        const { childId } = event.params;

        // Charger les infos enfant pour le prénom (optionnel)
        let childName = '';
        try {
            const childRef = db
                .collection('structures')
                .doc(event.params.structureId)
                .collection('children')
                .doc(childId);
            const childSnap = await childRef.get();
            if (childSnap.exists) {
                const c = childSnap.data() || {};
                childName = c.prenom || c.name || '';
            }
        } catch (e) {
            console.warn('⚠️ Impossible de charger les infos enfant:', e.message || e);
        }

        const title = 'Demande de stock';
        const body = childName
            ? `Nouveaux besoins pour ${childName} : ${newlyActivated.join(', ')}`
            : `Nouveaux besoins : ${newlyActivated.join(', ')}`;

        // Destinataires: tous les parents liés à l'enfant
        const recipients = await getParentsEmails(childId);
        if (!recipients || recipients.length === 0) {
            console.warn('⚠️ Aucun parent trouvé pour childId:', childId);
            return null;
        }

        console.log(`📬 Création de ${recipients.length} notification(s) de type stock`);

        // Créer un document de notification par parent
        const batchOps = [];
        for (const email of recipients) {
            const notificationData = {
                recipientUserId: email.toLowerCase().trim(),
                title,
                body,
                data: {
                    type: 'stock',
                    childId,
                    items: newlyActivated,
                },
                timestamp: FieldValue.serverTimestamp(),
                sent: false,
                platform: 'multi',
            };
            console.log('📦 Notification stock →', email, newlyActivated);
            batchOps.push(db.collection('notifications').add(notificationData));
        }

        await Promise.all(batchOps);
        console.log('✅ Notifications stock créées');
        return null;
    } catch (error) {
        console.error('❌ Erreur onStockNeedsUpdated:', error);
        return null;
    }
});

// ===== RAPPORTS MENSUELS POUR ASSISTANTES =====
const CHILD_EVENT_COLLECTIONS = ['repas', 'activites', 'siestes', 'changes', 'sante', 'transmissions'];
const DAY_CATEGORY_KEYS = ['horaires', ...CHILD_EVENT_COLLECTIONS];
const CATEGORY_LABELS = {
    horaires: 'Horaires',
    repas: 'Repas',
    activites: 'Activités',
    siestes: 'Siestes',
    changes: 'Changes',
    sante: 'Santé',
    transmissions: 'Transmissions',
};

exports.sendMonthlyAssistantRecaps = onSchedule({
    schedule: '0 6 1 * *',
    timeZone: 'Europe/Paris',
    region: 'europe-west1',
}, async () => {
    const nowParis = DateTime.now().setZone('Europe/Paris');
    const periodEnd = nowParis.startOf('month');
    const periodStart = periodEnd.minus({ months: 1 });
    const startDate = periodStart.toJSDate();
    const endDate = periodEnd.toJSDate();
    const periodLabel = periodStart.setLocale('fr').toFormat('LLLL yyyy');

    console.log('📅 Lancement envoi récap mensuel assistantes');
    console.log(`🗓️ Période: ${periodStart.toISODate()} → ${periodEnd.toISODate()} (${periodLabel})`);

    const structuresSnapshot = await db.collection('structures').get();
    console.log(`🏢 Structures trouvées: ${structuresSnapshot.size}`);

    for (const structureDoc of structuresSnapshot.docs) {
        const structureId = structureDoc.id;
        const structureData = structureDoc.data() || {};
        const structureName = getStructureDisplayName(structureData);
        const normalizedType = (structureData.structureType || '').toString().toLowerCase();

        try {
            const childrenSnapshot = await structureDoc.ref.collection('children').get();
            if (childrenSnapshot.empty) {
                console.log(`ℹ️ ${structureId}: aucun enfant, récap ignoré.`);
                continue;
            }

            if (normalizedType === 'mam') {
                await processMamStructure({
                    structureDoc,
                    structureName,
                    periodStart,
                    periodEnd,
                    periodLabel,
                    startDate,
                    endDate,
                    childrenSnapshot,
                });
            } else {
                await processSingleAssistantStructure({
                    structureDoc,
                    structureData,
                    structureName,
                    periodStart,
                    periodEnd,
                    periodLabel,
                    startDate,
                    endDate,
                    childrenSnapshot,
                });
            }
        } catch (error) {
            console.error(`❌ Erreur lors du traitement de la structure ${structureId}:`, error);
        }
    }

    console.log('✅ Fin traitement récap mensuel assistantes');
});

async function processSingleAssistantStructure({
    structureDoc,
    structureData,
    structureName,
    periodStart,
    periodEnd,
    periodLabel,
    startDate,
    endDate,
    childrenSnapshot,
}) {
    const assistantInfo = resolveStructureAssistant(structureDoc, structureData);
    if (!assistantInfo) {
        console.log(`⚠️ ${structureDoc.id}: aucune assistante identifiable, envoi annulé.`);
        return;
    }

    const childrenReports = [];
    for (const childDoc of childrenSnapshot.docs) {
        const report = await collectChildMonthlyData({
            structureId: structureDoc.id,
            childDoc,
            startDate,
            endDate,
        });
        childrenReports.push(report);
    }

    const pdfBuffer = await generateMonthlyPdf({
        assistant: assistantInfo,
        structureName,
        period: { start: periodStart, end: periodEnd, label: periodLabel },
        childrenReports,
    });

    if (!pdfBuffer) {
        console.log(`⚠️ ${structureDoc.id}: génération PDF impossible, pas d'envoi.`);
        return;
    }

    await enqueueMonthlyEmail({
        assistant: assistantInfo,
        structureName,
        period: { start: periodStart, end: periodEnd, label: periodLabel },
        pdfBuffer,
        childCount: childrenReports.length,
    });
}

async function processMamStructure({
    structureDoc,
    structureName,
    periodStart,
    periodEnd,
    periodLabel,
    startDate,
    endDate,
    childrenSnapshot,
}) {
    const membersSnapshot = await structureDoc.ref.collection('members').get();
    if (membersSnapshot.empty) {
        console.log(`⚠️ ${structureDoc.id}: structure MAM sans membres, envoi impossible.`);
        return;
    }

    const membersByEmail = new Map();
    membersSnapshot.forEach((memberDoc) => {
        const data = memberDoc.data() || {};
        const email = normalizeEmail(data.email);
        if (!email) return;
        const firstName = (data.firstName || '').toString().trim();
        const lastName = (data.lastName || '').toString().trim();
        const displayName = [firstName, lastName].filter(Boolean).join(' ').trim() || data.fullName || 'Assistante';
        membersByEmail.set(email, {
            email,
            name: displayName,
        });
    });

    if (membersByEmail.size === 0) {
        console.log(`⚠️ ${structureDoc.id}: aucun membre avec email valide.`);
        return;
    }

    const childrenByMember = new Map();
    childrenSnapshot.forEach((childDoc) => {
        const childData = childDoc.data() || {};
        const assignedEmail = normalizeEmail(childData.assignedMemberEmail);
        if (!assignedEmail || !membersByEmail.has(assignedEmail)) {
            return;
        }
        if (!childrenByMember.has(assignedEmail)) {
            childrenByMember.set(assignedEmail, []);
        }
        childrenByMember.get(assignedEmail).push(childDoc);
    });

    for (const [email, childDocs] of childrenByMember.entries()) {
        const assistantInfo = membersByEmail.get(email);
        if (!assistantInfo) continue;

        const childrenReports = [];
        for (const childDoc of childDocs) {
            const report = await collectChildMonthlyData({
                structureId: structureDoc.id,
                childDoc,
                startDate,
                endDate,
            });
            childrenReports.push(report);
        }

        const pdfBuffer = await generateMonthlyPdf({
            assistant: assistantInfo,
            structureName,
            period: { start: periodStart, end: periodEnd, label: periodLabel },
            childrenReports,
        });

        if (!pdfBuffer) {
            console.log(`⚠️ ${structureDoc.id}/${email}: PDF vide, envoi ignoré.`);
            continue;
        }

        await enqueueMonthlyEmail({
            assistant: assistantInfo,
            structureName,
            period: { start: periodStart, end: periodEnd, label: periodLabel },
            pdfBuffer,
            childCount: childrenReports.length,
        });
    }
}

async function collectChildMonthlyData({structureId, childDoc, startDate, endDate}) {
    const childData = childDoc.data() || {};
    const childId = childDoc.id;
    const childRef = db.collection('structures').doc(structureId).collection('children').doc(childId);
    const startTs = Timestamp.fromDate(startDate);
    const endTs = Timestamp.fromDate(endDate);

    const days = {};

    for (const collectionName of CHILD_EVENT_COLLECTIONS) {
        try {
            const snapshot = await childRef.collection(collectionName)
                .where('date', '>=', startTs)
                .where('date', '<', endTs)
                .get();

            snapshot.forEach((doc) => {
                const data = doc.data() || {};
                const eventDate = extractEventDate(data);
                if (!eventDate) return;
                const dateKey = DateTime.fromJSDate(eventDate, { zone: 'Europe/Paris' }).toISODate();
                const day = ensureDay(days, dateKey);
                day[collectionName].push({...data});
            });
        } catch (error) {
            console.error(`⚠️ Erreur collecte ${collectionName} pour ${childId}:`, error);
        }
    }

    const structureRef = db.collection('structures').doc(structureId);
    let horairesDocs = [];
    try {
        const horairesSnapshot = await structureRef.collection('horaires_history')
            .where('childId', '==', childId)
            .where('timestamp', '>=', startTs)
            .where('timestamp', '<', endTs)
            .get();
        horairesDocs = horairesSnapshot.docs;
    } catch (error) {
        console.warn(`ℹ️ Fallback horaires_history pour ${childId}: ${error.message}`);
        try {
            const fallbackSnapshot = await structureRef.collection('horaires_history')
                .where('childId', '==', childId)
                .get();
            horairesDocs = fallbackSnapshot.docs.filter((doc) => {
                const data = doc.data() || {};
                const eventDate = extractEventDate(data);
                if (!eventDate) return false;
                return eventDate >= startDate && eventDate < endDate;
            });
        } catch (fallbackError) {
            console.error(`❌ Impossible de récupérer horaires_history pour ${childId}:`, fallbackError);
        }
    }

    horairesDocs.forEach((doc) => {
        const data = doc.data() || {};
        const eventDate = extractEventDate(data) || parseDateString(data.date);
        if (!eventDate) return;
        const dateKey = DateTime.fromJSDate(eventDate, { zone: 'Europe/Paris' }).toISODate();
        const day = ensureDay(days, dateKey);
        day.horaires.push({...data});
    });

    return {
        childId,
        firstName: (childData.firstName || childData.prenom || '').toString(),
        lastName: (childData.lastName || childData.nom || '').toString(),
        days,
    };
}

function ensureDay(days, dateKey) {
    if (!days[dateKey]) {
        days[dateKey] = {
            horaires: [],
            repas: [],
            activites: [],
            siestes: [],
            changes: [],
            sante: [],
            transmissions: [],
        };
    }
    return days[dateKey];
}

function extractEventDate(data) {
    if (!data) return null;
    const dateField = data.date;
    if (dateField) {
        if (typeof dateField.toDate === 'function') {
            return dateField.toDate();
        }
        const parsed = parseDateString(dateField);
        if (parsed) return parsed;
    }
    const timestampField = data.timestamp || data.exactTime;
    if (timestampField && typeof timestampField.toDate === 'function') {
        return timestampField.toDate();
    }
    return null;
}

function parseDateString(raw) {
    if (!raw || typeof raw !== 'string') return null;
    const dt = DateTime.fromISO(raw, { zone: 'Europe/Paris' });
    if (dt.isValid) return dt.toJSDate();
    return null;
}

async function generateMonthlyPdf({assistant, structureName, period, childrenReports}) {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const buffers = [];
    return new Promise((resolve, reject) => {
        doc.on('data', (chunk) => buffers.push(chunk));
        doc.on('end', () => {
            const pdfBuffer = Buffer.concat(buffers);
            resolve(pdfBuffer);
        });
        doc.on('error', (error) => {
            console.error('❌ Erreur génération PDF:', error);
            reject(error);
        });

        const startLabel = period.start.setLocale('fr').toFormat('dd/LL/yyyy');
        const endLabel = period.end.minus({ days: 1 }).setLocale('fr').toFormat('dd/LL/yyyy');

        doc.font('Helvetica-Bold').fontSize(20).text('Récapitulatif mensuel', { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(14).text(`Période : ${startLabel} au ${endLabel}`, { align: 'center' });
        doc.moveDown(0.5);
        doc.fontSize(12).font('Helvetica').text(`Structure : ${structureName}`);
        doc.text(`Assistante : ${assistant.name || assistant.email}`);
        doc.text(`Mois : ${period.label}`);
        doc.moveDown(1);

        if (!childrenReports.length) {
            doc.font('Helvetica-Italic').text('Aucun enfant associé durant cette période.');
            doc.end();
            return;
        }

        let firstChild = true;
        for (const report of childrenReports) {
            if (!firstChild) {
                doc.addPage();
            }
            firstChild = false;

            const childName = [report.firstName, report.lastName].filter(Boolean).join(' ').trim() || `Enfant ${report.childId}`;
            doc.font('Helvetica-Bold').fontSize(16).text(childName);
            doc.moveDown(0.3);

            const dayKeys = Object.keys(report.days).sort();
            if (dayKeys.length === 0) {
                doc.font('Helvetica-Italic').fontSize(12).text('Aucune donnée enregistrée pour cette période.');
                continue;
            }

            for (const dayKey of dayKeys) {
                const dayData = report.days[dayKey];
                const displayDate = DateTime.fromISO(dayKey, { zone: 'Europe/Paris' })
                    .setLocale('fr')
                    .toFormat('cccc dd LLLL yyyy');

                doc.moveDown(0.4);
                doc.font('Helvetica-Bold').fontSize(13).fillColor('#3D9DF2').text(displayDate);
                doc.fillColor('black');
                doc.moveDown(0.2);

                for (const category of DAY_CATEGORY_KEYS) {
                    const events = dayData[category];
                    if (!events || events.length === 0) continue;

                    doc.font('Helvetica-Bold').fontSize(12).text(CATEGORY_LABELS[category]);
                    doc.moveDown(0.1);
                    for (const entry of events) {
                        const lines = formatEventLines(category, entry);
                        if (!lines.length) continue;
                        doc.font('Helvetica').fontSize(11).text(`• ${lines[0]}`);
                        for (let i = 1; i < lines.length; i++) {
                            doc.text(`  ${lines[i]}`);
                        }
                        doc.moveDown(0.05);
                    }
                    doc.moveDown(0.2);
                }
            }
        }

        doc.end();
    }).catch((error) => {
        console.error('❌ Génération PDF échouée:', error);
        return null;
    });
}

function formatEventLines(category, entry) {
    const lines = [];
    const baseTime = formatTimeValue(entry.heure || entry.time || entry.date || entry.timestamp || entry.exactTime);

    switch (category) {
        case 'horaires': {
            if (entry.absent) {
                lines.push('Enfant absent.');
                break;
            }
            if (Array.isArray(entry.segments) && entry.segments.length > 0) {
                entry.segments.forEach((segment) => {
                    const arrivee = formatTimeValue(segment.arrivee);
                    const depart = formatTimeValue(segment.depart);
                    if (arrivee) {
                        lines.push(`Arrivée : ${arrivee}`);
                    }
                    if (depart) {
                        let departLine = `Départ : ${depart}`;
                        if (segment.km !== undefined && segment.km !== null && segment.km !== '') {
                            departLine += ` (km : ${segment.km})`;
                        }
                        lines.push(departLine);
                    }
                });
            } else {
                if (entry.arrivee) {
                    lines.push(`Arrivée : ${entry.arrivee}`);
                }
                if (entry.depart) {
                    lines.push(`Départ : ${entry.depart}`);
                }
                if (entry.km) {
                    lines.push(`Kilomètres déclarés : ${entry.km}`);
                }
            }
            break;
        }
        case 'repas': {
            const rawMoment = (entry.moment || '').toString();
            const momentLabel = rawMoment || (entry.gouter ? 'Goûter' : '');
            const rawType = (entry.typeAlimentation || '').toString();
            const isBiberon = entry.biberon || rawType === 'Biberon';
            const isAllaitement = entry.allaitement || rawType === 'Allaitement';
            const isSolide = rawType === 'Solide';
            const isMixte = rawType === 'Mixte';
            const typeLabel = rawType || (entry.biberon
                ? 'Biberon'
                : entry.allaitement
                    ? 'Allaitement'
                    : momentLabel || 'Repas');
            const descriptionAlim = (entry.alimentationDescription || '').toString();
            const qualite = (entry.qualite || '').toString();

            let description = baseTime ? `${baseTime} - ` : '';
            let detail;
            if (isBiberon) {
                detail = `Biberon ${entry.ml ? `${entry.ml} ml` : ''}`.trim();
            } else if (isAllaitement) {
                detail = 'Allaitement';
            } else if (isSolide || isMixte) {
                const descOrQualite = descriptionAlim || qualite;
                detail = descOrQualite
                    ? `${typeLabel} - ${descOrQualite}`
                    : typeLabel;
            } else if (qualite) {
                detail = qualite;
            } else {
                detail = typeLabel || 'Repas';
            }

            if (momentLabel && !detail.startsWith(momentLabel)) {
                description += `${momentLabel} - ${detail}`;
            } else {
                description += detail;
            }
            lines.push(description.trim());
            if (entry.observations) {
                lines.push(`Observations : ${entry.observations}`);
            }
            break;
        }
        case 'activites': {
            const type = entry.type || 'Activité';
            const participation = entry.participation || entry.attitude;
            let description = baseTime ? `${baseTime} - ${type}` : type;
            if (participation) {
                description += ` (${participation})`;
            }
            lines.push(description);
            if (entry.observations) {
                lines.push(`Observations : ${entry.observations}`);
            }
            break;
        }
        case 'siestes': {
            let description = baseTime ? `${baseTime} - Sieste` : 'Sieste';
            if (entry.duration) {
                description += `, durée : ${entry.duration}`;
            }
            if (entry.qualite) {
                description += `, qualité : ${entry.qualite}`;
            }
            lines.push(description);
            if (entry.observations) {
                lines.push(`Observations : ${entry.observations}`);
            }
            break;
        }
        case 'changes': {
            let description = baseTime ? `${baseTime} - Change ${entry.type || ''}`.trim() : `Change ${entry.type || ''}`.trim();
            const details = [];
            if (entry.pipi) details.push('pipi');
            if (entry.selles) details.push('selles');
            if (details.length) {
                description += ` (${details.join(', ')})`;
            }
            lines.push(description);
            if (Array.isArray(entry.soins) && entry.soins.length) {
                lines.push(`Soins : ${entry.soins.join(', ')}`);
            }
            if (entry.observations) {
                lines.push(`Observations : ${entry.observations}`);
            }
            break;
        }
        case 'sante': {
            let description = baseTime ? `${baseTime} - ${entry.type || 'Suivi santé'}` : (entry.type || 'Suivi santé');
            if (entry.type === 'Température' && entry.temperature) {
                description += ` : ${entry.temperature}°`;
                if (entry.route) description += ` (${entry.route})`;
            } else if (entry.type === 'Poids' && entry.weight) {
                description += ` : ${entry.weight} kg`;
            } else if (entry.type === 'Médicaments' && entry.medicationType) {
                description += ` : ${entry.medicationType}`;
            }
            lines.push(description);
            if (entry.observations) {
                lines.push(`Observations : ${entry.observations}`);
            }
            break;
        }
        case 'transmissions': {
            let description = baseTime ? `${baseTime} - ${entry.category || 'Transmission'}` : (entry.category || 'Transmission');
            if (entry.content) {
                description += ` : ${entry.content}`;
            }
            lines.push(description);
            break;
        }
        default:
            break;
    }

    return lines.filter((line) => line && line.toString().trim().length > 0);
}

function formatTimeValue(value) {
    if (!value) return '';
    if (typeof value === 'string') {
        return value;
    }
    if (typeof value.toDate === 'function') {
        const dt = DateTime.fromJSDate(value.toDate(), { zone: 'Europe/Paris' });
        if (dt.isValid) {
            return dt.toFormat('HH:mm');
        }
    }
    if (value instanceof Date) {
        const dt = DateTime.fromJSDate(value, { zone: 'Europe/Paris' });
        if (dt.isValid) {
            return dt.toFormat('HH:mm');
        }
    }
    return '';
}

async function enqueueMonthlyEmail({assistant, structureName, period, pdfBuffer, childCount}) {
    const pdfBase64 = pdfBuffer.toString('base64');
    const startLabel = period.start.setLocale('fr').toFormat('dd/MM/yyyy');
    const endLabel = period.end.minus({ days: 1 }).setLocale('fr').toFormat('dd/MM/yyyy');
    const pdfFilename = buildPdfFilename(structureName, assistant.name || assistant.email, period.label);

    const templateData = {
        assistantName: assistant.name || assistant.email,
        structureName,
        monthLabel: period.label,
        childCount,
        periodStart: startLabel,
        periodEnd: endLabel,
    };

    await db.collection('emailQueue').add({
        to: assistant.email,
        subject: `Récapitulatif ${period.label} - ${structureName}`,
        template: 'monthly-assistant-recap',
        templateData,
        pdfAttachment: pdfBase64,
        pdfFilename,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
    });

    console.log(`📧 Email mensuel en file pour ${assistant.email} (${structureName})`);
}

function buildPdfFilename(structureName, assistantName, periodLabel) {
    const structureSlug = toSlug(structureName);
    const assistantSlug = toSlug(assistantName);
    const periodSlug = toSlug(periodLabel);
    return `Recap_${structureSlug}_${assistantSlug}_${periodSlug}.pdf`;
}

function toSlug(value) {
    if (!value) return 'recap';
    return value
        .toString()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-zA-Z0-9]+/g, '_')
        .replace(/^_+|_+$/g, '')
        .toLowerCase()
        || 'recap';
}

function normalizeEmail(email) {
    if (!email || typeof email !== 'string') return '';
    return email.trim().toLowerCase();
}

function getStructureDisplayName(structureData) {
    if (!structureData) return 'Ma structure';
    const primary = (structureData.structureName || structureData.name || '').toString().trim();
    if (primary) return primary;
    const ownerFirst = (structureData.ownerFirstName || structureData.firstName || '').toString().trim();
    const ownerLast = (structureData.ownerLastName || structureData.lastName || '').toString().trim();
    const combined = [ownerFirst, ownerLast].filter(Boolean).join(' ').trim();
    return combined || 'Ma structure';
}

function resolveStructureAssistant(structureDoc, structureData = {}) {
    const candidates = [
        structureData.assistantEmail,
        structureData.ownerEmail,
        structureData.email,
    ];
    let email = '';
    for (const candidate of candidates) {
        const normalized = normalizeEmail(candidate);
        if (normalized) {
            email = normalized;
            break;
        }
    }
    if (!email) return null;

    const firstName = (structureData.ownerFirstName || structureData.firstName || '').toString().trim();
    const lastName = (structureData.ownerLastName || structureData.lastName || '').toString().trim();
    const displayName = [firstName, lastName].filter(Boolean).join(' ').trim() || structureData.assistantName || '';

    return {
        email,
        name: displayName || email,
    };
}
