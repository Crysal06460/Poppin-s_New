const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

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
                Name: "Les Lutins - Application Poppins"
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
// ===== VOS FONCTIONS EXISTANTES INTACTES =====
// ==========================================

// Fonction pour envoyer des notifications push
exports.sendNotification = onDocumentCreated('notifications/{notificationId}', async (event) => {
    try {
        const notification = event.data.data();
        console.log('📤 Nouvelle notification à envoyer:', notification);

        // Vérifier si la notification a déjà été envoyée
        if (notification.sent) {
            console.log('⚠️ Notification déjà envoyée');
            return;
        }

        const recipientUserId = notification.recipientUserId;
        console.log('🎯 Recherche utilisateur:', recipientUserId);
        
        // CORRECTION: Rechercher directement par email (ID du document)
        const userDoc = await db
            .collection('users')
            .doc(recipientUserId)
            .get();

        if (!userDoc.exists) {
            console.log('❌ Utilisateur non trouvé:', recipientUserId);
            // Marquer comme échoué
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
            console.log('❌ Token FCM non trouvé pour:', recipientUserId);
            // Marquer comme échoué
            await event.data.ref.update({
                sent: false,
                error: 'Token FCM non trouvé',
                errorAt: FieldValue.serverTimestamp(),
            });
            return;
        }

        console.log('🎯 Token FCM trouvé:', fcmToken.substring(0, 20) + '...');

        // Préparer le message
        const message = {
            notification: {
                title: notification.title,
                body: notification.body,
            },
            data: {
                ...notification.data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: fcmToken,
            apns: {
                payload: {
                    aps: {
                        badge: 1,
                        sound: 'default',
                        'content-available': 1,
                    },
                },
            },
            android: {
                priority: 'high',
                notification: {
                    channel_id: 'messages_channel',
                    priority: 'high',
                    visibility: 'public',
                },
            },
        };

        // Envoyer la notification
        const response = await messaging.send(message);
        console.log('✅ Notification envoyée avec succès:', response);

        // Marquer la notification comme envoyée
        await event.data.ref.update({
            sent: true,
            sentAt: FieldValue.serverTimestamp(),
            messageId: response,
        });

    } catch (error) {
        console.error('❌ Erreur lors de l\'envoi de la notification:', error);
        
        // Marquer la notification comme échouée
        await event.data.ref.update({
            sent: false,
            error: error.message,
            errorAt: FieldValue.serverTimestamp(),
        });
    }
});

// 🔥 FONCTION PRINCIPALE CORRIGÉE : Gérer TOUS les messages (avec ou sans parentId)
exports.onNewMessage = onDocumentCreated('exchanges/{messageId}', async (event) => {
    console.log('🔥 DEBUT onNewMessage - Message détecté !');
    
    try {
        const messageData = event.data.data();
        console.log('📋 Message data:', JSON.stringify(messageData, null, 2));

        const { childId, senderType, content } = messageData;

        // Skip si déjà traité
        if (messageData.notificationSent) {
            console.log('⚠️ Notification déjà traitée');
            return;
        }

        let recipientEmail = null;
        let title = '';

        if (senderType === 'parent') {
            // 🟢 MESSAGE PARENT → ASSISTANTE (ça marche déjà)
            console.log('👨‍👩‍👧‍👦 Message du parent vers assistante');
            title = 'Nouveau message d\'un parent';
            recipientEmail = await getAssistantEmail(childId);
            
        } else if (senderType === 'assistante') {
            // 🔴 MESSAGE ASSISTANTE → PARENT (à corriger)
            console.log('👩‍⚕️ Message de l\'assistante vers parent');
            title = 'Nouveau message de Poppin\'s';
            
            // 🔥 CORRECTION : Ne pas utiliser parentId du message, le chercher dynamiquement
            console.log('🔍 Recherche parent pour childId:', childId);
            
            // Chercher directement les parents qui ont cet enfant
            const parentQuery = await db
                .collection('users')
                .where('children', 'array-contains', childId)
                .get();

            console.log('👪 Nombre de parents trouvés:', parentQuery.size);

            if (!parentQuery.empty) {
                recipientEmail = parentQuery.docs[0].id; // ID = email
                console.log('📧 Email parent trouvé:', recipientEmail);
            } else {
                console.log('❌ Aucun parent trouvé pour childId:', childId);
                
                // FALLBACK : Chercher dans les documents enfants pour récupérer parentId
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
                        const parentId = childData.parentId;
                        
                        if (parentId && parentId.includes('@')) {
                            recipientEmail = parentId.toLowerCase();
                            console.log('📧 Email parent trouvé via document enfant:', recipientEmail);
                            break;
                        }
                    }
                }
            }
        }

        if (recipientEmail) {
            console.log('✅ Destinataire trouvé:', recipientEmail);
            
            // Créer la notification
            const notificationData = {
                recipientUserId: recipientEmail,
                title: title,
                body: content || 'Nouveau message',
                data: {
                    childId: childId,
                    messageId: event.params.messageId,
                    type: 'message'
                },
                timestamp: FieldValue.serverTimestamp(),
                sent: false,
                platform: 'ios'
            };

            console.log('📬 Création notification:', JSON.stringify(notificationData, null, 2));

            await db.collection('notifications').add(notificationData);

            // Marquer le message comme traité
            await event.data.ref.update({
                notificationSent: true
            });

            console.log('✅ Notification créée avec succès pour:', recipientEmail);
        } else {
            console.log('❌ AUCUN destinataire trouvé !');
            console.log('📋 Debug info:', {
                senderType: senderType,
                childId: childId,
                parentId: messageData.parentId
            });
        }

    } catch (error) {
        console.error('❌ Erreur dans onNewMessage:', error);
    }
});

// 🔥 FONCTION HELPER : Trouver l'email de l'assistante
async function getAssistantEmail(childId) {
    try {
        console.log('🔍 Recherche assistante pour enfant:', childId);
        
        // Chercher dans toutes les structures
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
                const assignedMemberEmail = childData.assignedMemberEmail;

                // Si assigné à un membre MAM
                if (assignedMemberEmail) {
                    console.log('📧 Membre MAM assigné trouvé:', assignedMemberEmail);
                    return assignedMemberEmail.toLowerCase();
                } else {
                    // Sinon, propriétaire de la structure
                    const structureData = structureDoc.data();
                    const ownerEmail = structureData.ownerEmail;
                    
                    if (ownerEmail) {
                        console.log('📧 Propriétaire structure trouvé:', ownerEmail);
                        return ownerEmail.toLowerCase();
                    }
                }
            }
        }

        console.log('❌ Aucune assistante trouvée pour childId:', childId);
        return null;
    } catch (error) {
        console.error('❌ Erreur recherche assistante:', error);
        return null;
    }
}

// Fonction pour nettoyer les anciennes notifications
exports.cleanupOldNotifications = onSchedule('every 24 hours', async (event) => {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // 7 jours
    
    const snapshot = await db
        .collection('notifications')
        .where('timestamp', '<', cutoff)
        .get();

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    
    await batch.commit();
    console.log(`🗑️ ${snapshot.size} anciennes notifications supprimées`);
});