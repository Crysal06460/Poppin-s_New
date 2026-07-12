const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https'); // AJOUT pour la nouvelle fonction
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth'); // AJOUT pour l'authentification

const Stripe = require('stripe');
const PDFDocument = require('pdfkit');
const { DateTime } = require('luxon');

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
const MAILJET_API_KEY = defineSecret('MAILJET_API_KEY');
const MAILJET_SECRET_KEY = defineSecret('MAILJET_SECRET_KEY');

// ===== CONFIGURATION DeepSeek — Assistant Calculs IA =====
const DEEPSEEK_API_KEY = defineSecret('DEEPSEEK_API_KEY');
let mailjetClient;
function getMailjet() {
    if (!mailjetClient) {
        mailjetClient = Mailjet.apiConnect(
            MAILJET_API_KEY.value(),
            MAILJET_SECRET_KEY.value()
        );
    }
    return mailjetClient;
}

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
// App-Specific Shared Secret (App Store Connect > Mon app > Achats intégrés en app)
// À définir avant déploiement : firebase functions:secrets:set APPSTORE_SHARED_SECRET
const APPSTORE_SHARED_SECRET = defineSecret('APPSTORE_SHARED_SECRET');
let stripeClient;
function getStripe() {
    if (!stripeClient) {
        stripeClient = new Stripe(STRIPE_SECRET_KEY.value());
    }
    return stripeClient;
}

// Limiter l'empreinte CPU globale (évite de saturer le quota Cloud Run)
setGlobalOptions({
    cpu: 0.08,
    maxInstances: 1,
    concurrency: 1,
});

// Finaliser un signup Stripe (création user + structure)
// Finaliser un signup Stripe (création user + structure)
exports.finalizeStripeSignup = onRequest(
    {
        region: 'europe-west1',
        cors: true,
        secrets: [STRIPE_SECRET_KEY, MAILJET_API_KEY, MAILJET_SECRET_KEY],
    },
    async (req, res) => {
        try {
            const {
                sessionId,
                firstName,
                lastName,
                phone,
                address,
                postalCode,
                city,
                structureName,
                password,
                email,
            } = req.body;

            if (!sessionId) {
                return res.status(400).json({ error: 'SessionId manquant' });
            }

            const session = await getStripe().checkout.sessions.retrieve(
                sessionId,
                { expand: ['line_items'] },
            );

            const accountEmail = session.customer_email || email;

            if (!session || !accountEmail) {
                return res.status(400).json({
                    error: 'Session Stripe invalide (email manquant)',
                    details: 'L\'email n\'a pas été trouvé ni dans la session Stripe ni dans le formulaire.'
                });
            }

            const emailFinal = accountEmail;
            const priceId = session.line_items.data[0].price.id;

            // Déterminer le type de structure et les limites
            let structureType = 'AssistanteMaternelle';
            let maxMemberCount = 1; // Assmat seule = 1 membre

            if (priceId === 'price_1SfkUILID2pA5i1C75uu1TCH' || priceId === 'price_1SflCBPpvDnoE6wk9jqNDsWP') {
                // MAM 2 et 3 membres
                structureType = 'MAM';
                maxMemberCount = 3;
            } else if (priceId === 'price_1SfkWULID2pA5i1CmSdrRF0c') {
                // MAM 4 membres et + (Illimité)
                structureType = 'MAM';
                maxMemberCount = 50;
            }

            // 1. Créer ou Récupérer l'utilisateur Auth
            let userRecord;
            try {
                userRecord = await getAuth().createUser({
                    email: emailFinal,
                    password: password || undefined,
                    displayName: `${firstName} ${lastName}`,
                });
            } catch (error) {
                if (error.code === 'auth/email-already-exists') {
                    console.log('⚠️ Utilisateur déjà existant (auth), récupération du profil...');
                    userRecord = await getAuth().getUserByEmail(emailFinal);
                } else {
                    throw error;
                }
            }

            // 2. Créer ou Mettre à jour le document Utilisateur
            await db.collection('users').doc(emailFinal.toLowerCase()).set({
                email: emailFinal,
                role: 'structure',
                structureId: userRecord.uid,
                updatedAt: FieldValue.serverTimestamp(),
            }, { merge: true });

            // 3. Gérer la Structure
            const structureRef = db.collection('structures').doc(userRecord.uid);
            const structureDoc = await structureRef.get();

            if (structureDoc.exists) {
                console.log(`ℹ️ Structure existante pour ${userRecord.uid}, mise à jour de l'abonnement uniquement.`);
                // CAS MIGRATION / RÉABONNEMENT
                await structureRef.update({
                    subscriptionPlatform: 'stripe',
                    subscriptionSource: 'stripe',
                    subscriptionStatus: 'active',
                    subscriptionActive: true,
                    maxMemberCount: maxMemberCount,
                    subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                    ...(firstName ? { ownerFirstName: firstName } : {}),
                    ...(lastName ? { ownerLastName: lastName } : {}),
                });
            } else {
                console.log(`✨ Nouvelle structure pour ${userRecord.uid}, création complète.`);
                // CAS CRÉATION INITIALE
                await structureRef.set({
                    structureType,
                    structureName: structureName || null,
                    address: address || null,
                    postalCode: postalCode || null,
                    city: city || null,
                    phone: phone || null,
                    ownerUid: userRecord.uid,
                    ownerEmail: emailFinal,
                    ownerFirstName: firstName,
                    ownerLastName: lastName,
                    email: emailFinal,
                    firstName: firstName,
                    lastName: lastName,
                    memberCount: 1,
                    maxMemberCount: maxMemberCount,
                    subscriptionPlatform: 'stripe',
                    subscriptionSource: 'stripe',
                    subscriptionStatus: 'active',
                    subscriptionActive: true,
                    trialStatus: 'converted',
                    createdAt: FieldValue.serverTimestamp(),
                });

                // 4. Ajouter le membre Owner (seulement si nouvelle structure)
                await structureRef.collection('members').doc('member_1').set({
                    uid: userRecord.uid,
                    email: emailFinal,
                    firstName,
                    lastName,
                    phone: phone || null,
                    role: 'owner',
                    isFounder: true,
                    createdAt: FieldValue.serverTimestamp(),
                });
            }

            // 5. Lier l'abonnement Stripe
            if (session.subscription) {
                const subId = typeof session.subscription === 'string' ? session.subscription : session.subscription.id;
                console.log(`🔗 Liaison de l'abonnement Stripe ${subId} à la structure ${userRecord.uid}`);

                const subscription = await getStripe().subscriptions.retrieve(subId);

                await getStripe().subscriptions.update(subId, {
                    metadata: {
                        structureId: userRecord.uid,
                        email: emailFinal,
                        source: 'web_signup'
                    }
                });

                await db.collection('subscriptions').doc(subId).set({
                    structureId: userRecord.uid,
                    structureType,
                    status: subscription.status,
                    platform: 'stripe',
                    source: 'web',
                    planId: priceId,
                    email: emailFinal,
                    trialEndsAt: subscription.trial_end ? Timestamp.fromMillis(subscription.trial_end * 1000) : null,
                    trialStartedAt: subscription.trial_start ? Timestamp.fromMillis(subscription.trial_start * 1000) : null,
                    createdAt: FieldValue.serverTimestamp(),
                    updatedAt: FieldValue.serverTimestamp(),
                }, { merge: true });

                await structureRef.update({
                    subscriptionDocId: subId,
                    stripeSubscriptionId: subId,
                    subscriptionStatus: subscription.status,
                    subscriptionPlatform: 'stripe',
                });
            }

            // 6. ENVOI EMAIL BIENVENUE + PASSWORD RESET (Uniquement pour les nouvelles structures)
            if (!structureDoc.exists) {
                try {
                    console.log(`📧 Génération lien mot de passe pour ${emailFinal}...`);
                    const actionLink = await getAuth().generatePasswordResetLink(emailFinal);

                    const welcomeHtml = `
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset="utf-8">
                        <style>
                            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; background-color: #f8f9fa; padding: 20px; }
                            .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                            .header { background: linear-gradient(135deg, #3D9DF2 0%, #05C7F2 100%); color: white; padding: 30px; text-align: center; }
                            .content { padding: 30px; line-height: 1.6; }
                            .btn { display: inline-block; background-color: #3D9DF2; color: white; padding: 12px 24px; border-radius: 25px; text-decoration: none; font-weight: bold; margin-top: 20px; }
                            .footer { background: #f1f3f4; padding: 20px; text-align: center; font-size: 12px; color: #666; }
                        </style>
                    </head>
                    <body>
                        <div class="container">
                            <div class="header">
                                <h1>Bienvenue sur Poppin's ! ☂️</h1>
                            </div>
                            <div class="content">
                                <h2>Bonjour ${firstName},</h2>
                                <p>Votre compte a été créé avec succès suite à votre abonnement.</p>
                                <p>Pour finaliser votre inscription et accéder à votre espace, veuillez définir votre mot de passe en cliquant sur le bouton ci-dessous :</p>
                                <center>
                                    <a href="${actionLink}" class="btn">Créer mon mot de passe</a>
                                </center>
                                <p style="margin-top: 30px; font-size: 14px; color: #666;">Ce lien est unique et sécurisé. Une fois votre mot de passe créé, revenez sur l'application pour vous connecter.</p>
                            </div>
                            <div class="footer">
                                <p>À très vite sur Poppin's !</p>
                            </div>
                        </div>
                    </body>
                    </html>
                    `;

                    await getMailjet().post('send', { version: 'v3.1' }).request({
                        Messages: [{
                            From: { Email: "noreply@poppin-s.fr", Name: "Équipe Poppins" },
                            To: [{ Email: emailFinal, Name: `${firstName} ${lastName}` }],
                            Subject: "Bienvenue sur Poppin's - Créez votre mot de passe",
                            HTMLPart: welcomeHtml
                        }]
                    });
                    console.log('✅ Email de bienvenue envoyé.');
                } catch (emailError) {
                    console.error('❌ Erreur envoi email bienvenue:', emailError);
                    // On ne bloque pas le retour success car le compte est déjà créé
                }
            }

            return res.json({ success: true, isMigration: structureDoc.exists });
        } catch (error) {
            console.error('finalizeStripeSignup error:', error);
            return res.status(500).json({ error: error.message });
        }
    },
);

// 7. Récupérer les infos de la session Checkout (pour le Frontend)
exports.getCheckoutInfo = onCall({
    region: 'europe-west1',
}, async (request) => {
    try {
        const sessionId = request.data.sessionId;
        if (!sessionId) {
            throw new HttpsError('invalid-argument', 'sessionId manquant');
        }

        const session = await getStripe().checkout.sessions.retrieve(
            sessionId,
            { expand: ['line_items'] },
        );

        const lineItems = (session.line_items && session.line_items.data) || [];
        const priceId = lineItems[0] && lineItems[0].price && lineItems[0].price.id;

        console.log(`🔍 getCheckoutInfo: Session=${sessionId} -> Price=${priceId}`);

        let structureType = 'AssistanteMaternelle';

        // Vérification des IDs de plan MAM
        if (priceId === 'price_1SfkUILID2pA5i1C75uu1TCH' || priceId === 'price_1SflCBPpvDnoE6wk9jqNDsWP') {
            structureType = 'MAM';
        } else if (priceId === 'price_1SfkWULID2pA5i1CmSdrRF0c' || priceId === 'price_1SflCjPpvDnoE6wkfD6BliGn') {
            structureType = 'MAM';
        }

        return { structureType };
    } catch (error) {
        console.error("getCheckoutInfo error:", error);
        throw new HttpsError('internal', error.message);
    }
});

// ===== WEBHOOK STRIPE : Gérer les événements Stripe (Souscriptions) =====
exports.stripeWebhook = onRequest(
    {
        secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
        region: 'europe-west1'
    },
    async (req, res) => {
        const sig = req.headers["stripe-signature"];
        const webhookSecret = STRIPE_WEBHOOK_SECRET.value();

        let event;
        try {
            event = getStripe().webhooks.constructEvent(
                req.rawBody,
                sig,
                webhookSecret,
            );
        } catch (err) {
            console.error("Webhook signature verification failed:", err.message);
            return res.status(400).send(`Webhook Error: ${err.message}`);
        }

        const subEvents = [
            "customer.subscription.created",
            "customer.subscription.updated",
            "customer.subscription.deleted",
            // ✅ AJOUT : événements de facturation critiques
            "invoice.payment_failed",
            "invoice.payment_succeeded",
        ];

        // ✅ GESTION INVOICE : paiement échoué ou réussi
        if (event.type === 'invoice.payment_failed' || event.type === 'invoice.payment_succeeded') {
            const invoice = event.data.object;
            const invoiceSubId = typeof invoice.subscription === 'string' ? invoice.subscription : invoice.subscription?.id;
            if (invoiceSubId) {
                try {
                    const subSnap = await db.collection('subscriptions').doc(invoiceSubId).get();
                    let invoiceStructureId = subSnap.exists ? subSnap.data().structureId : null;

                    if (!invoiceStructureId && invoice.customer_email) {
                        const userDoc = await db.collection('users').doc(invoice.customer_email.toLowerCase()).get();
                        if (userDoc.exists) invoiceStructureId = userDoc.data().structureId;
                    }

                    if (event.type === 'invoice.payment_failed') {
                        console.warn(`⚠️ Paiement échoué pour subscription ${invoiceSubId} (structure: ${invoiceStructureId})`);
                        await db.collection('subscriptions').doc(invoiceSubId).set({
                            lastPaymentFailed: true,
                            lastPaymentFailedAt: FieldValue.serverTimestamp(),
                            updatedAt: FieldValue.serverTimestamp(),
                        }, { merge: true });
                        // Mettre le statut past_due sur la structure si on l'a
                        if (invoiceStructureId) {
                            await db.collection('structures').doc(invoiceStructureId).set({
                                subscriptionStatus: 'past_due',
                                subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                            }, { merge: true });
                        }
                    } else if (event.type === 'invoice.payment_succeeded') {
                        console.log(`✅ Paiement réussi pour subscription ${invoiceSubId}`);
                        await db.collection('subscriptions').doc(invoiceSubId).set({
                            lastPaymentFailed: false,
                            lastPaymentSucceededAt: FieldValue.serverTimestamp(),
                            updatedAt: FieldValue.serverTimestamp(),
                        }, { merge: true });
                        if (invoiceStructureId) {
                            await db.collection('structures').doc(invoiceStructureId).set({
                                subscriptionActive: true,
                                subscriptionStatus: 'active',
                                subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                            }, { merge: true });
                        }
                    }
                } catch (invoiceErr) {
                    console.error('❌ Erreur traitement invoice event:', invoiceErr);
                }
            }
            return res.json({ received: true });
        }

        if (subEvents.includes(event.type)) {
            const sub = event.data.object;
            const subId = sub.id;
            const status = sub.status;
            const trialEnd = sub.trial_end;
            const trialStart = sub.trial_start || sub.start_date;
            const periodEnd = sub.current_period_end;

            // Extraire le Plan ID (Price ID)
            const priceId = sub.items?.data?.[0]?.price?.id || sub.plan?.id;
            const priceAmount = sub.items?.data?.[0]?.price?.unit_amount;

            console.log(`🔔 Event ${event.type} pour sub ${subId} (Plan: ${priceId}, Status: ${status})`);

            const trialEndsAtMs = trialEnd ? trialEnd * 1000 : null;
            const trialStartsAtMs = trialStart ? trialStart * 1000 : null;
            const expiresAtMs = periodEnd ? periodEnd * 1000 : null;

            let trialEndsAt = null;
            if (trialEndsAtMs != null) {
                trialEndsAt = Timestamp.fromMillis(trialEndsAtMs);
            }

            let trialStartsAt = null;
            if (trialStartsAtMs != null) {
                trialStartsAt = Timestamp.fromMillis(trialStartsAtMs);
            }

            let expiresAt = null;
            if (expiresAtMs != null) {
                expiresAt = Timestamp.fromMillis(expiresAtMs);
            }

            const subscriptionActive = status === "active" || status === "trialing";

            let structureId = "";
            if (sub.metadata && sub.metadata.structureId) {
                structureId = sub.metadata.structureId;
            } else if (sub.metadata && sub.metadata.structure_id) {
                structureId = sub.metadata.structure_id;
            }

            let customerEmail = "";
            if (sub.customer_email) {
                customerEmail = sub.customer_email;
            } else if (sub.metadata && sub.metadata.email) {
                customerEmail = sub.metadata.email;
            }
            if (customerEmail) {
                customerEmail = customerEmail.toLowerCase();
            }

            try {
                if (!customerEmail && sub.customer) {
                    const customer = await getStripe().customers.retrieve(sub.customer);
                    if (customer && customer.email) {
                        customerEmail = customer.email.toLowerCase();
                    }
                }
            } catch (err) {
                console.error("Erreur récupération customer Stripe :", err);
            }

            // 🔧 FALLBACK: Si structureId absent des métadonnées, le résoudre via Firestore
            if (!structureId && customerEmail) {
                try {
                    // 1. Chercher dans users/{email}
                    const userDoc = await db.collection("users").doc(customerEmail).get();
                    if (userDoc.exists && userDoc.data().structureId) {
                        structureId = userDoc.data().structureId;
                        console.log(`🔧 structureId résolu via users pour ${customerEmail}: ${structureId}`);
                    }
                } catch (err) {
                    console.error("Erreur résolution structureId via users:", err);
                }
            }

            if (!structureId && customerEmail) {
                try {
                    // 2. Chercher dans structures par ownerEmail
                    const structQuery = await db.collection("structures")
                        .where("ownerEmail", "==", customerEmail)
                        .limit(1)
                        .get();
                    if (!structQuery.empty) {
                        structureId = structQuery.docs[0].id;
                        console.log(`🔧 structureId résolu via structures.ownerEmail pour ${customerEmail}: ${structureId}`);
                    }
                } catch (err) {
                    console.error("Erreur résolution structureId via structures:", err);
                }
            }

            if (!structureId && customerEmail) {
                try {
                    // 3. Chercher dans subscriptions existantes par email
                    const existingSub = await db.collection("subscriptions")
                        .where("email", "==", customerEmail)
                        .where("structureId", "!=", "")
                        .limit(1)
                        .get();
                    if (!existingSub.empty) {
                        structureId = existingSub.docs[0].data().structureId;
                        console.log(`🔧 structureId résolu via subscriptions existantes pour ${customerEmail}: ${structureId}`);
                    }
                } catch (err) {
                    console.error("Erreur résolution structureId via subscriptions:", err);
                }
            }

            if (!structureId) {
                console.warn(`⚠️ WEBHOOK: structureId introuvable pour sub ${subId} (email: ${customerEmail}). Subscription sauvegardée sans structureId.`);
            }

            try {
                const subscriptionUpdate = {
                    status,
                    trialEndsAt,
                    trialStartedAt: trialStartsAt,
                    expiresAt,
                    platform: "stripe",
                    source: "stripe",
                    email: customerEmail,
                    stripeCustomerId: sub.customer,
                    planId: priceId,
                    priceAmount: priceAmount,
                    updatedAt: FieldValue.serverTimestamp(),
                };

                if (structureId) {
                    subscriptionUpdate.structureId = structureId;
                }

                await db.collection("subscriptions").doc(subId).set(
                    subscriptionUpdate,
                    { merge: true },
                );
                console.log(`✅ Subscription ${subId} updated in Firestore (structureId: ${structureId || 'non résolu'}).`);

                // 🔧 Mettre à jour la structure si on a un structureId et que le statut est actif
                if (structureId && subscriptionActive) {
                    try {
                        await db.collection("structures").doc(structureId).update({
                            subscriptionActive: true,
                            subscriptionStatus: status,
                            subscriptionDocId: subId,
                            subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                        });
                        console.log(`✅ Structure ${structureId} mise à jour avec subscriptionActive:true`);
                    } catch (structErr) {
                        console.error(`⚠️ Erreur mise à jour structure ${structureId}:`, structErr);
                    }
                } else if (structureId && !subscriptionActive) {
                    try {
                        await db.collection("structures").doc(structureId).update({
                            subscriptionActive: false,
                            subscriptionStatus: status,
                            subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                        });
                        console.log(`✅ Structure ${structureId} mise à jour avec subscriptionActive:false (status: ${status})`);
                    } catch (structErr) {
                        console.error(`⚠️ Erreur mise à jour structure ${structureId}:`, structErr);
                    }
                }

            } catch (err) {
                console.error("Erreur mise à jour Stripe webhook :", err);
            }
        }

        return res.json({ received: true });
    },
);

// ===== NOUVELLE FONCTION : Envoyer un email depuis l'app =====
exports.sendEmailToParent = onCall({
    region: 'europe-west1',
    secrets: [MAILJET_API_KEY, MAILJET_SECRET_KEY],
}, async (request) => {
    console.log('📧 NOUVEAU: sendEmailToParent appelée');

    // Vérification authentification
    if (!request.auth) {
        console.error('❌ Utilisateur non authentifié');
        throw new HttpsError('unauthenticated', 'Utilisateur non authentifié');
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
        throw new HttpsError('invalid-argument', 'Données manquantes (recipientEmail, recipientName, subject, message)');
    }

    try {
        // Récupération des infos utilisateur pour signature
        const userRecord = await getAuth().getUser(request.auth.uid);
        const senderName = userRecord.displayName || 'Équipe Poppins';
        const senderEmail = 'noreply@poppin-s.fr'; // Votre email vérifié

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
        const request_mailjet = getMailjet().post('send', { version: 'v3.1' }).request({
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

        throw new HttpsError('internal', error.message);
    }
});

exports.purgeIncompleteAccount = onCall({
    region: 'europe-west1',
    memory: '128MiB',
    cpu: 0.08,
    maxInstances: 1,
    minInstances: 0,
}, async (request) => {
    const rawEmail = request.data?.email;
    if (!rawEmail || typeof rawEmail !== 'string') {
        throw new HttpsError('invalid-argument', 'email-required');
    }

    const email = rawEmail.trim().toLowerCase();
    console.log(`🧹 purgeIncompleteAccount demandé pour ${email}`);

    let userRecord;
    try {
        userRecord = await getAuth().getUserByEmail(email);
    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.log(`ℹ️ Aucun utilisateur Firebase Auth pour ${email}`);
            return { purged: false, reason: 'user-not-found' };
        }
        console.error('❌ Erreur récupération utilisateur pour purge:', error);
        throw new HttpsError('internal', 'auth-lookup-failed');
    }

    const uid = userRecord.uid;
    const structureRef = db.collection('structures').doc(uid);
    const structureSnapshot = await structureRef.get();

    const blockingReasons = await collectBlockingReasons(uid, structureSnapshot);
    if (blockingReasons.length > 0) {
        console.log(
            `⛔️ purge refusée pour ${email} (${uid}) - données détectées: ${blockingReasons.join(', ')}`
        );
        throw new HttpsError('failed-precondition', 'account-has-data', {
            reasons: blockingReasons
        });
    }

    // Nettoyer les sous-collections basiques (au cas où)
    await deleteCollection(structureRef.collection('notifications'));
    await deleteCollection(structureRef.collection('children'));
    await deleteCollection(structureRef.collection('members'));
    await deleteCollection(structureRef.collection('horaires'));

    const batch = db.batch();

    if (structureSnapshot.exists) {
        batch.delete(structureRef);
    }

    const userDocRef = db.collection('users').doc(email);
    const userDoc = await userDocRef.get();
    if (userDoc.exists) {
        batch.delete(userDocRef);
    }

    await batch.commit().catch((error) => {
        console.error('❌ Erreur lors de la suppression Firestore pour purge:', error);
        throw new HttpsError('internal', 'firestore-cleanup-failed');
    });

    try {
        await getAuth().deleteUser(uid);
        console.log(`✅ Compte Firebase Auth supprimé pour ${email} (${uid})`);
    } catch (error) {
        console.error('❌ Erreur suppression utilisateur Firebase Auth:', error);
        throw new HttpsError('internal', 'auth-delete-failed');
    }

    return { purged: true };
});

// ============================================
// ========== CHANGEMENT D'EMAIL SELF-SERVICE ==========
// ============================================
// Migre l'email utilisé comme clé/identifiant à travers Firestore puis Firebase Auth.
// Ordre volontaire : Firestore d'abord (toutes les lectures avant le batch d'écriture),
// Auth en tout dernier (la plus petite étape, la plus facile à annuler en cas d'échec).
// Pendant toute la préparation, request.auth.token.email reste l'ancien email, donc les
// règles Firestore (isStructureMember, isProfessional, etc.) continuent de résoudre
// correctement users/{oldEmail} pour toute autre requête en vol de cet utilisateur.
exports.updateUserEmail = onCall({
    region: 'europe-west1',
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const uid = request.auth.uid;
    const rawNewEmail = request.data?.newEmail;
    if (!rawNewEmail || typeof rawNewEmail !== 'string') {
        throw new HttpsError('invalid-argument', 'newEmail-required');
    }

    const newEmail = rawNewEmail.trim().toLowerCase();
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(newEmail)) {
        throw new HttpsError('invalid-argument', 'invalid-email');
    }

    // 1. Résoudre l'identité via l'UID authentifié (jamais via un oldEmail fourni par le client)
    let currentUserRecord;
    try {
        currentUserRecord = await getAuth().getUser(uid);
    } catch (error) {
        console.error('❌ updateUserEmail: impossible de récupérer l\'utilisateur courant:', error);
        throw new HttpsError('internal', 'auth-lookup-failed');
    }

    const oldEmail = (currentUserRecord.email || '').trim().toLowerCase();
    if (!oldEmail) {
        throw new HttpsError('failed-precondition', 'current-user-has-no-email');
    }
    if (newEmail === oldEmail) {
        throw new HttpsError('invalid-argument', 'same-email');
    }

    // 2. Rejeter si le nouvel email est déjà pris
    try {
        await getAuth().getUserByEmail(newEmail);
        // Si ça résout, l'email existe déjà
        throw new HttpsError('already-exists', 'email-already-used');
    } catch (error) {
        if (error instanceof HttpsError) throw error;
        if (error.code !== 'auth/user-not-found') {
            console.error('❌ updateUserEmail: erreur vérification email cible:', error);
            throw new HttpsError('internal', 'auth-lookup-failed');
        }
        // auth/user-not-found : c'est le cas attendu, on continue
    }

    // 2b. Rejeter aussi si un document Firestore existe déjà à users/{newEmail}, même sans
    // compte Auth associé — ex: placeholder d'invitation créé par parent_home_screen.dart quand
    // un parent invite une assistante qui n'a pas encore de compte (role: 'assistantFromParent',
    // invitedByParent, structureId). Le batch plus bas fait un set() sans merge : sans ce garde-fou,
    // il écraserait silencieusement cette invitation en cours, sans erreur ni log.
    const newUserDocPreCheck = await db.collection('users').doc(newEmail).get();
    if (newUserDocPreCheck.exists) {
        console.warn(`⚠️ updateUserEmail: users/${newEmail} existe déjà en Firestore (uid ${uid} ne peut pas migrer vers cet email)`);
        throw new HttpsError('already-exists', 'target-email-firestore-doc-exists');
    }

    // 3. Lire users/{oldEmail}, résoudre structureId, vérifier si propriétaire
    const oldUserRef = db.collection('users').doc(oldEmail);
    const oldUserSnap = await oldUserRef.get();
    if (!oldUserSnap.exists) {
        throw new HttpsError('not-found', 'user-doc-not-found');
    }
    const oldUserData = oldUserSnap.data() || {};
    const structureId = oldUserData.structureId || null;

    let structureRef = null;
    let structureSnap = null;
    let structureData = null;
    if (structureId) {
        structureRef = db.collection('structures').doc(structureId);
        structureSnap = await structureRef.get();
        if (structureSnap.exists) {
            structureData = structureSnap.data() || {};
        }
    }

    const isOwnerOfEmail = (value) => (value || '').toString().trim().toLowerCase() === oldEmail;
    const structureOwnerEmailMatches = structureData ? isOwnerOfEmail(structureData.ownerEmail) : false;
    const structureEmailMatches = structureData ? isOwnerOfEmail(structureData.email) : false;
    // structureData.assistantEmail : écrit par parent_home_screen.dart quand un parent-employeur
    // invite son assistante ; lu ensuite par getAssistantEmail() (notifications), memoResolveAssistant()
    // (Calculs IA) et parent_messages_screen.dart (compteur non lus). Sans cette migration, ces 3
    // chemins continuent de pointer vers users/{oldEmail}, supprimé par ce même batch.
    const structureAssistantEmailMatches = structureData ? isOwnerOfEmail(structureData.assistantEmail) : false;

    // 4. Toutes les lectures nécessaires AVANT de construire le batch (un batch ne peut pas requêter)
    let membersSnap = { docs: [] };
    let assistantSnap = null;
    let childrenDocsMap = new Map(); // path -> { ref, updates: {}, original: {} }

    if (structureId) {
        membersSnap = await structureRef.collection('members').where('email', '==', oldEmail).get();

        const assistantRef = structureRef.collection('assistants').doc(oldEmail);
        const assistantDocSnap = await assistantRef.get();
        if (assistantDocSnap.exists) {
            assistantSnap = assistantDocSnap;
        }

        const [byAssigned, byParent1, byParent2] = await Promise.all([
            structureRef.collection('children').where('assignedMemberEmail', '==', oldEmail).get(),
            structureRef.collection('children').where('parent1.email', '==', oldEmail).get(),
            structureRef.collection('children').where('parent2.email', '==', oldEmail).get(),
        ]);

        const registerChildUpdate = (doc, field) => {
            const path = doc.ref.path;
            if (!childrenDocsMap.has(path)) {
                childrenDocsMap.set(path, { ref: doc.ref, updates: {}, original: {} });
            }
            const entry = childrenDocsMap.get(path);
            const data = doc.data() || {};
            if (field === 'assignedMemberEmail') {
                entry.updates.assignedMemberEmail = newEmail;
                entry.original.assignedMemberEmail = data.assignedMemberEmail;
            } else if (field === 'parent1') {
                entry.updates['parent1.email'] = newEmail;
                entry.original['parent1.email'] = (data.parent1 || {}).email;
            } else if (field === 'parent2') {
                entry.updates['parent2.email'] = newEmail;
                entry.original['parent2.email'] = (data.parent2 || {}).email;
            }
        };

        byAssigned.docs.forEach((doc) => registerChildUpdate(doc, 'assignedMemberEmail'));
        byParent1.docs.forEach((doc) => registerChildUpdate(doc, 'parent1'));
        byParent2.docs.forEach((doc) => registerChildUpdate(doc, 'parent2'));
    }

    // 5. Construire UN SEUL batch avec toutes les écritures Firestore
    const newUserRef = db.collection('users').doc(newEmail);
    const assistantOldRef = assistantSnap ? assistantSnap.ref : null;
    const assistantNewRef = assistantSnap ? structureRef.collection('assistants').doc(newEmail) : null;
    const assistantData = assistantSnap ? (assistantSnap.data() || {}) : null;

    const structureUpdates = {};
    if (structureOwnerEmailMatches) structureUpdates.ownerEmail = newEmail;
    if (structureEmailMatches) structureUpdates.email = newEmail;
    if (structureAssistantEmailMatches) structureUpdates.assistantEmail = newEmail;

    const buildBatch = (forward) => {
        const batch = db.batch();

        if (forward) {
            batch.set(newUserRef, {
                ...oldUserData,
                email: newEmail,
                updatedAt: FieldValue.serverTimestamp(),
            });
            batch.delete(oldUserRef);
        } else {
            batch.set(oldUserRef, oldUserData);
            batch.delete(newUserRef);
        }

        if (structureRef && Object.keys(structureUpdates).length > 0) {
            if (forward) {
                batch.update(structureRef, structureUpdates);
            } else {
                const revert = {};
                if (structureOwnerEmailMatches) revert.ownerEmail = structureData.ownerEmail;
                if (structureEmailMatches) revert.email = structureData.email;
                if (structureAssistantEmailMatches) revert.assistantEmail = structureData.assistantEmail;
                batch.update(structureRef, revert);
            }
        }

        membersSnap.docs.forEach((doc) => {
            batch.update(doc.ref, { email: forward ? newEmail : oldEmail });
        });

        if (assistantSnap) {
            if (forward) {
                batch.set(assistantNewRef, {
                    ...assistantData,
                    email: newEmail,
                    updatedAt: FieldValue.serverTimestamp(),
                });
                batch.delete(assistantOldRef);
            } else {
                batch.set(assistantOldRef, assistantData);
                batch.delete(assistantNewRef);
            }
        }

        childrenDocsMap.forEach(({ ref, updates, original }) => {
            batch.update(ref, forward ? updates : original);
        });

        return batch;
    };

    try {
        await buildBatch(true).commit();
    } catch (error) {
        console.error('❌ updateUserEmail: échec du batch Firestore, aucune écriture appliquée:', error);
        throw new HttpsError('internal', 'firestore-migration-failed');
    }

    console.log(`✅ updateUserEmail: migration Firestore ${oldEmail} → ${newEmail} effectuée (uid: ${uid})`);

    // 6. Seulement après succès du batch : mettre à jour Firebase Auth (dernière étape)
    try {
        await getAuth().updateUser(uid, { email: newEmail });
    } catch (authError) {
        console.error('❌ updateUserEmail: échec de la mise à jour Auth après migration Firestore, rollback:', authError);
        try {
            await buildBatch(false).commit();
            console.log(`↩️ updateUserEmail: rollback Firestore réussi pour ${oldEmail}`);
        } catch (rollbackError) {
            console.error('🚨 updateUserEmail: ÉCHEC DU ROLLBACK, nécessite une reprise manuelle:', rollbackError);
            try {
                await db.collection('emailChangeFailures').doc(uid).set({
                    uid,
                    oldEmail,
                    newEmail,
                    structureId,
                    authErrorMessage: authError.message || String(authError),
                    rollbackErrorMessage: rollbackError.message || String(rollbackError),
                    createdAt: FieldValue.serverTimestamp(),
                });
            } catch (logError) {
                console.error('🚨 updateUserEmail: impossible même de logger l\'échec critique:', logError);
            }
            throw new HttpsError('internal', 'critical-failure-manual-fixup-required');
        }
        // Rollback Firestore réussi : l'utilisateur est revenu à son état d'avant l'appel.
        throw new HttpsError('internal', 'auth-update-failed-rolled-back');
    }

    console.log(`✅ updateUserEmail: changement d'email complet ${oldEmail} → ${newEmail} (uid: ${uid})`);

    return { success: true, oldEmail, newEmail };
});

async function collectBlockingReasons(uid, structureSnapshot) {
    const reasons = [];

    const data = structureSnapshot.exists ? structureSnapshot.data() : null;
    if (hasMeaningfulStructureData(data)) {
        reasons.push('structure_fields');
    }

    const structureRef = db.collection('structures').doc(uid);

    if (await collectionHasDocuments(structureRef.collection('children'))) {
        reasons.push('children');
    }

    if (await collectionHasDocuments(structureRef.collection('members'))) {
        reasons.push('members');
    }

    if (await hasBlockingSubscription(uid)) {
        reasons.push('subscription');
    }

    return reasons;
}

function hasMeaningfulStructureData(data) {
    if (!data) return false;

    const fields = ['structureName', 'name', 'nom', 'city', 'ville', 'town', 'ownerFirstName', 'ownerLastName', 'address', 'phone'];
    const hasTextField = fields.some((field) => {
        const value = data[field];
        return typeof value === 'string' && value.trim().length > 0;
    });

    const hasMemberCount =
        (typeof data.memberCount === 'number' && data.memberCount > 0) ||
        (typeof data.maxMemberCount === 'number' && data.maxMemberCount > 0);

    return hasTextField || hasMemberCount;
}

async function collectionHasDocuments(collectionRef) {
    try {
        const snapshot = await collectionRef.limit(1).get();
        return !snapshot.empty;
    } catch (error) {
        console.error('⚠️ Erreur lors de la vérification de collection:', error);
        return false;
    }
}

async function hasBlockingSubscription(uid) {
    try {
        const snapshot = await db
            .collection('subscriptions')
            .where('structureId', '==', uid)
            .limit(1)
            .get();

        if (snapshot.empty) return false;

        const status = (snapshot.docs[0].data().status || '').toString().toLowerCase();
        const blockingStatuses = new Set(['active', 'purchased', 'past_due']);

        return blockingStatuses.has(status);
    } catch (error) {
        console.error('⚠️ Erreur lors de la vérification des abonnements:', error);
        return false;
    }
}

async function deleteCollection(collectionRef, batchSize = 50) {
    try {
        const snapshot = await collectionRef.limit(batchSize).get();
        if (snapshot.empty) {
            return;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();

        if (snapshot.size === batchSize) {
            await deleteCollection(collectionRef, batchSize);
        }
    } catch (error) {
        console.error('⚠️ Erreur lors de la suppression de collection:', error);
    }
}

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
        throw new HttpsError('unauthenticated', 'Authentification requise');
    }
    const { delegationId } = request.data || {};
    if (!delegationId) throw new HttpsError('invalid-argument', 'delegationId manquant');

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
        throw new HttpsError('invalid-argument', 'structureId requis pour résoudre la délégation');
    }

    if (!delegationDoc.exists) throw new HttpsError('not-found', 'Délégation introuvable');
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
    if (!allowed) throw new HttpsError('permission-denied', 'Accès non autorisé');

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
    if (!request.auth) throw new HttpsError('unauthenticated', 'Authentification requise');
    const { delegationId, structureId } = request.data || {};
    if (!delegationId || !structureId) throw new HttpsError('invalid-argument', 'delegationId et structureId requis');
    const ref = db.collection('structures').doc(structureId).collection('delegations').doc(delegationId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Délégation introuvable');
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
    if (!allowed) throw new HttpsError('permission-denied', 'Accès non autorisé');
    await ref.update({ status: 'declined', updatedAt: FieldValue.serverTimestamp() });
    return { success: true };
});

exports.cancelDelegation = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Authentification requise');
    const { delegationId, structureId } = request.data || {};
    if (!delegationId || !structureId) throw new HttpsError('invalid-argument', 'delegationId et structureId requis');
    const ref = db.collection('structures').doc(structureId).collection('delegations').doc(delegationId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Délégation introuvable');
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
    if (!allowed) throw new HttpsError('permission-denied', 'Accès non autorisé');
    await ref.update({ status: 'canceled', updatedAt: FieldValue.serverTimestamp() });
    return { success: true };
});

// 🔔 Notifier le membre destinataire lors d'une nouvelle délégation proposée
exports.onDelegationCreated = onDocumentCreated({
    document: 'structures/{structureId}/delegations/{delegationId}',
    region: 'europe-west1',
    cpu: 0.08,
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
        } catch (_) { }

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

// ===== NOUVELLE FONCTION : Vérifier une invitation par email =====
exports.lookupInvitationByEmail = onCall({
    region: 'europe-west1'
}, async (request) => {
    const rawEmail = (request.data?.email || '').toString().trim().toLowerCase();

    if (!rawEmail) {
        throw new HttpsError('invalid-argument', 'Veuillez fournir une adresse email.');
    }

    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(rawEmail)) {
        throw new HttpsError('invalid-argument', 'Format d\'email invalide.');
    }

    try {
        const snapshot = await db
            .collection('invitations')
            .where('email', '==', rawEmail)
            .get();

        if (snapshot.empty) {
            throw new HttpsError('not-found', 'Aucune invitation trouvée pour cet email.');
        }

        const docs = snapshot.docs.sort((a, b) => {
            const extractTs = (doc) => {
                const value = doc.get('createdAt');
                if (value instanceof Timestamp) return value;
                if (value?.toDate) return Timestamp.fromDate(value.toDate());
                if (value instanceof Date) return Timestamp.fromDate(value);
                return Timestamp.fromMillis(0);
            };
            return extractTs(b).toMillis() - extractTs(a).toMillis();
        });

        let selectedDoc = docs.find((doc) => {
            const status = (doc.get('status') || '').toString().toLowerCase().trim();
            return status === 'active' || status === 'pending';
        });
        if (!selectedDoc) {
            selectedDoc = docs[0];
        }

        const invitationData = selectedDoc.data();
        const normalizedStatus = (invitationData.status || '').toString().toLowerCase().trim();

        if (normalizedStatus === 'completed') {
            throw new HttpsError(
                'failed-precondition',
                'Cette invitation a déjà été utilisée. Vous pouvez vous connecter depuis l\'écran de connexion.'
            );
        }

        if (['revoked', 'deleted', 'cancelled'].includes(normalizedStatus)) {
            throw new HttpsError(
                'failed-precondition',
                'Cette invitation a été annulée. Demandez une nouvelle invitation à l\'administrateur.'
            );
        }

        const expiresValue = invitationData.expiresAt;
        let expiresDate = null;
        if (expiresValue instanceof Timestamp) {
            expiresDate = expiresValue.toDate();
        } else if (expiresValue instanceof Date) {
            expiresDate = expiresValue;
        } else if (expiresValue?.toDate) {
            expiresDate = expiresValue.toDate();
        }

        if (expiresDate && expiresDate < new Date()) {
            throw new HttpsError('failed-precondition', 'Cette invitation a expiré.');
        }

        const structureId = invitationData.structureId || '';
        let structureName = invitationData.structureName || 'la structure';
        if ((!structureName || structureName === '') && structureId) {
            try {
                const structureSnap = await db.collection('structures').doc(structureId).get();
                if (structureSnap.exists) {
                    structureName = structureSnap.data().structureName || structureName;
                }
            } catch (_) {
                // ignorer et garder le nom par défaut
            }
        }

        return {
            invitationId: selectedDoc.id,
            email: rawEmail,
            invitationType: invitationData.type || 'unknown',
            structureId,
            structureName,
            childName: invitationData.childName || '',
            childId: invitationData.childId || '',
            assistantFirstName: invitationData.assistantFirstName || '',
            assistantLastName: invitationData.assistantLastName || '',
            assistantPhone: invitationData.assistantPhone || '',
            parentFullName: invitationData.parentFullName || '',
            status: normalizedStatus,
        };
    } catch (error) {
        console.error('❌ lookupInvitationByEmail error:', error);
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError(
            'internal',
            'Une erreur est survenue lors de la validation de votre invitation.'
        );
    }
});

// ================================================================
// ===== REMPLACEMENTS (accès temporaire délégué, date-bornés) =====
// ================================================================
// Mécanisme : la remplaçante s'authentifie avec SON PROPRE mot de passe.
// Si une fenêtre de remplacement est active pour son email, on lui délivre
// un custom token pour l'UID de la PROPRIÉTAIRE (getAuth().createCustomToken),
// et son client se reconnecte avec ce jeton. Elle devient alors littéralement
// l'UID de la propriétaire pour Firestore → aucune règle de sécurité à
// modifier (engagements_reciproques/contrats_cdi/contrats_cdd exigent
// request.auth.uid == userId exactement ; ce mécanisme le satisfait tel quel).
//
// Regex email partagée avec lookupInvitationByEmail.
const REMPLACEMENT_EMAIL_REGEX = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;

function remplacementToDate(value) {
    if (!value) return null;
    if (value instanceof Timestamp) return value.toDate();
    if (value?.toDate) return value.toDate();
    if (value instanceof Date) return value;
    const d = new Date(value);
    return isNaN(d.getTime()) ? null : d;
}

// ===== 1. createRemplacement — propriétaire uniquement =====
// Crée une invitation (même format que les autres), un doc `remplacements`
// (status: 'invited') et une entrée emailQueue avec le template dédié.
exports.createRemplacement = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const {
        structureId,
        replacementEmail,
        replacementFirstName,
        replacementLastName,
        startDate,
        endDate,
    } = request.data || {};

    if (!structureId || typeof structureId !== 'string') {
        throw new HttpsError('invalid-argument', 'structureId manquant');
    }

    // V1 : seule la propriétaire de la structure peut créer un remplacement pour elle-même.
    if (request.auth.uid !== structureId) {
        throw new HttpsError('permission-denied', 'Seule la propriétaire de la structure peut créer un remplacement.');
    }

    const emailNormalized = (replacementEmail || '').toString().trim().toLowerCase();
    if (!emailNormalized || !REMPLACEMENT_EMAIL_REGEX.test(emailNormalized)) {
        throw new HttpsError('invalid-argument', "Adresse email de la remplaçante invalide.");
    }

    const start = remplacementToDate(startDate);
    const end = remplacementToDate(endDate);
    if (!start || !end) {
        throw new HttpsError('invalid-argument', 'Dates de début et de fin invalides.');
    }

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    if (start < todayStart) {
        throw new HttpsError('invalid-argument', 'La date de début ne peut pas être dans le passé.');
    }
    if (start >= end) {
        throw new HttpsError('invalid-argument', 'La date de début doit être antérieure à la date de fin.');
    }

    const ownerRecord = await getAuth().getUser(request.auth.uid);
    const ownerEmail = (ownerRecord.email || '').toLowerCase();
    if (ownerEmail && ownerEmail === emailNormalized) {
        throw new HttpsError('invalid-argument', 'Vous ne pouvez pas vous désigner vous-même comme remplaçante.');
    }

    const structureSnap = await db.collection('structures').doc(structureId).get();
    if (!structureSnap.exists) {
        throw new HttpsError('not-found', 'Structure introuvable.');
    }
    const structureData = structureSnap.data() || {};
    const structureName = structureData.structureName || structureData.name || 'ma structure';
    const ownerName = [
        structureData.ownerFirstName || structureData.firstName || '',
        structureData.ownerLastName || structureData.lastName || '',
    ].map((s) => (s || '').toString().trim()).filter(Boolean).join(' ').trim() || ownerEmail || 'La structure';

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    const invitationRef = db.collection('invitations').doc();
    const remplacementRef = db.collection('structures').doc(structureId).collection('remplacements').doc();

    const batch = db.batch();

    batch.set(invitationRef, {
        email: emailNormalized,
        type: 'remplacement',
        structureId,
        structureName,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromDate(expiresAt),
    });

    batch.set(remplacementRef, {
        replacementEmail: emailNormalized,
        replacementFirstName: (replacementFirstName || '').toString().trim(),
        replacementLastName: (replacementLastName || '').toString().trim(),
        replacementUid: null,
        ownerUid: request.auth.uid,
        structureId,
        structureName,
        ownerName,
        startDate: Timestamp.fromDate(start),
        endDate: Timestamp.fromDate(end),
        status: 'invited',
        invitationId: invitationRef.id,
        createdBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        cancelledAt: null,
        cancelledBy: null,
        lastActivatedAt: null,
    });

    await batch.commit();

    // Email hors batch (comme pour les autres invitations) : un échec d'envoi
    // ne doit pas faire échouer la création du remplacement lui-même.
    try {
        await db.collection('emailQueue').add({
            to: emailNormalized,
            template: 'remplacement-invitation',
            subject: `Invitation à remplacer ${ownerName} sur Poppins`,
            status: 'pending',
            createdAt: FieldValue.serverTimestamp(),
            retryCount: 0,
            priority: 'high',
            templateData: {
                firstName: (replacementFirstName || '').toString().trim(),
                lastName: (replacementLastName || '').toString().trim(),
                ownerName,
                structureName,
                startDate: start.toLocaleDateString('fr-FR'),
                endDate: end.toLocaleDateString('fr-FR'),
                androidLink: 'https://play.google.com/store/apps/details?id=com.beylet.poppinsapp',
                iosLink: 'https://apps.apple.com/us/app/poppins/id6744274953',
                year: new Date().getFullYear().toString(),
                to: emailNormalized,
            },
        });
    } catch (err) {
        console.error('❌ Erreur création emailQueue remplacement:', err);
    }

    console.log(`✅ Remplacement créé: ${remplacementRef.id} pour ${emailNormalized} (structure ${structureId})`);

    return { success: true, remplacementId: remplacementRef.id, invitationId: invitationRef.id };
});

// ===== 2. activateRemplacementSession — appelée par le client remplaçant =====
// Juste après signInWithEmailAndPassword (avant tout routing) — donc à CHAQUE
// connexion normale de N'IMPORTE QUEL utilisateur, pas seulement au moment de
// la redemption de l'invitation. Cherche un remplacement actif via l'index
// collectionGroup (replacementEmail, status), vérifie la fenêtre de dates, et
// renvoie un custom token pour l'UID propriétaire si tout correspond. Ne doit
// jamais faire échouer un login normal : toute erreur inattendue renvoie
// simplement { active: false }.
//
// ⚠️ GARDE-FOU DE SÉCURITÉ INDISPENSABLE : puisqu'un email Firebase Auth est
// unique et peut donc déjà appartenir à un compte Poppins totalement étranger
// (coïncidence, faute de frappe de la propriétaire en créant le remplacement,
// etc.), on ne peut PAS activer/lier un remplacement sur la seule base d'une
// correspondance d'email lors d'une connexion ordinaire : cela donnerait accès
// aux données de la propriétaire (enfants, santé, contrats) à une personne
// réelle qui n'a jamais consulté ni accepté l'invitation. On exige donc que
// l'invitation associée (invitations/{invitationId}) ait déjà été marquée
// `completed` — ce qui ne se produit QUE dans le flux explicite de redemption
// (invitation_signup_screen.dart, après avoir suivi le lien/code d'invitation
// et s'être authentifié dans cet écran dédié), jamais lors d'une connexion
// normale. Un compte préexistant qui n'a jamais suivi ce flux garde son
// invitation à `pending` pour toujours et ne sera donc jamais activé ici.
exports.activateRemplacementSession = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const email = (request.auth.token.email || '').toString().trim().toLowerCase();
    if (!email) {
        return { active: false };
    }

    try {
        const snap = await db.collectionGroup('remplacements')
            .where('replacementEmail', '==', email)
            .where('status', 'in', ['invited', 'active'])
            .get();

        if (snap.empty) {
            return { active: false };
        }

        const now = new Date();
        let matchDoc = null;
        for (const doc of snap.docs) {
            const d = doc.data();
            const start = remplacementToDate(d.startDate);
            const end = remplacementToDate(d.endDate);
            if (start && end && start <= now && now <= end) {
                matchDoc = doc;
                break;
            }
        }

        if (!matchDoc) {
            return { active: false };
        }

        const data = matchDoc.data();

        // Défense en profondeur : si un replacementUid est déjà lié, seul ce
        // même uid peut réactiver (empêche un cas résiduel où l'email aurait
        // pu être réattribué entre-temps côté Firebase Auth).
        if (data.replacementUid && data.replacementUid !== request.auth.uid) {
            return { active: false };
        }

        // Garde-fou principal : exiger que l'invitation ait été explicitement
        // complétée via l'écran de redemption avant toute liaison/activation.
        if (!data.invitationId) {
            console.warn(`⚠️ activateRemplacementSession: remplacement ${matchDoc.id} sans invitationId, refus`);
            return { active: false };
        }
        const invitationSnap = await db.collection('invitations').doc(data.invitationId).get();
        const invitationStatus = invitationSnap.exists ? invitationSnap.data().status : null;
        if (invitationStatus !== 'completed') {
            return { active: false };
        }

        const updates = {
            status: 'active',
            lastActivatedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
        };
        if (!data.replacementUid) {
            updates.replacementUid = request.auth.uid;
        }
        await matchDoc.ref.update(updates);

        const customToken = await getAuth().createCustomToken(data.ownerUid);
        const endDate = remplacementToDate(data.endDate) || new Date();

        console.log(`✅ activateRemplacementSession: session active pour ${email} → owner ${data.ownerUid}`);

        return {
            active: true,
            customToken,
            remplacementId: matchDoc.id,
            structureId: data.structureId,
            structureName: data.structureName || '',
            ownerName: data.ownerName || '',
            endDate: endDate.toISOString(),
        };
    } catch (error) {
        console.error('❌ activateRemplacementSession error:', error);
        // Ne jamais casser une connexion normale à cause de cette fonctionnalité optionnelle.
        return { active: false };
    }
});

// ===== 3. cancelRemplacement — propriétaire uniquement =====
exports.cancelRemplacement = onCall({ region: 'europe-west1' }, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentification requise');
    }
    const { structureId, remplacementId } = request.data || {};
    if (!structureId || !remplacementId) {
        throw new HttpsError('invalid-argument', 'structureId et remplacementId requis');
    }
    if (request.auth.uid !== structureId) {
        throw new HttpsError('permission-denied', 'Seule la propriétaire de la structure peut annuler un remplacement.');
    }

    const ref = db.collection('structures').doc(structureId).collection('remplacements').doc(remplacementId);
    const snap = await ref.get();
    if (!snap.exists) {
        throw new HttpsError('not-found', 'Remplacement introuvable.');
    }
    const data = snap.data();
    if (!['invited', 'active'].includes(data.status)) {
        return { success: false, message: 'already-processed' };
    }

    await ref.update({
        status: 'cancelled',
        cancelledAt: FieldValue.serverTimestamp(),
        cancelledBy: request.auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
    });

    // ⚠️ Effet de bord volontaire et documenté : revokeRefreshTokens invalide
    // TOUTES les sessions actives de la propriétaire (uid == structureId),
    // y compris ses propres connexions en cours ailleurs. C'est nécessaire
    // pour couper l'accès de la remplaçante immédiatement, puisque sa session
    // est littéralement l'UID de la propriétaire (mécanisme du custom token).
    // La propriétaire devra simplement se reconnecter.
    try {
        await getAuth().revokeRefreshTokens(data.ownerUid);
    } catch (err) {
        console.error('❌ Erreur revokeRefreshTokens (cancelRemplacement):', err);
    }

    console.log(`🛑 Remplacement ${remplacementId} annulé par ${request.auth.uid}`);
    return { success: true };
});

// ===== 4. expireRemplacements — onSchedule toutes les 15 min =====
// Même principe que cleanupExpiredInvitations, mais en collectionGroup car
// `remplacements` est une sous-collection de `structures`. Ne fait QUE
// marquer 'expired' : contrairement à cancelRemplacement, on n'appelle PAS
// revokeRefreshTokens ici pour ne pas déconnecter la propriétaire à chaque
// expiration naturelle — la coupure précise à l'heure est gérée côté client
// (RemplacementSessionService.checkStillActive, minuteur + AuthCheckScreen).
exports.expireRemplacements = onSchedule({
    schedule: 'every 15 minutes',
    region: 'europe-west1',
    memory: '128MiB',
    cpu: 0.08,
    maxInstances: 1,
    minInstances: 0,
    concurrency: 1,
}, async (event) => {
    try {
        const now = Timestamp.now();
        console.log('⏳ Vérification des remplacements expirés...');

        const snapshot = await db.collectionGroup('remplacements')
            .where('status', 'in', ['invited', 'active'])
            .where('endDate', '<', now)
            .get();

        if (snapshot.empty) {
            console.log('✅ Aucun remplacement expiré');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.update(doc.ref, {
                status: 'expired',
                updatedAt: FieldValue.serverTimestamp(),
            });
        });
        await batch.commit();
        console.log(`⏳ ${snapshot.size} remplacement(s) expiré(s)`);
    } catch (error) {
        console.error('❌ Erreur expireRemplacements:', error);
    }
    return null;
});

// ===== NOUVELLE FONCTION : Traiter la queue d'emails avec Mailjet =====
exports.processEmailQueue = onDocumentWritten({
    document: 'emailQueue/{emailId}',
    region: 'europe-west1',
    secrets: [MAILJET_API_KEY, MAILJET_SECRET_KEY],
}, async (event) => {
    // Si le document est supprimé, on ne fait rien
    if (!event.data.after.exists) {
        return null;
    }

    const emailData = event.data.after.data();
    const previousData = event.data.before.data() || {};
    const emailId = event.params.emailId;

    // Éviter de traiter si le statut n'a pas changé vers 'pending'
    // ou si c'est une création (previousData vide) et le statut est 'pending'
    if (emailData.status !== 'pending') {
        return null;
    }

    // Si ce n'est pas une création et que le statut n'a pas changé, on ignore
    if (event.data.before.exists && previousData.status === 'pending') {
        return null;
    }

    console.log(`📧 Traitement de l'email ${emailId}:`, JSON.stringify(emailData, null, 2));

    try {
        // Vérifier si toutes les données nécessaires sont présentes
        if (!emailData.to || !emailData.templateData) {
            console.error('❌ Données d\'email insuffisantes:', emailData);
            await event.data.after.ref.update({
                status: 'failed',
                error: 'Données insuffisantes',
                lastErrorAt: FieldValue.serverTimestamp()
            });
            return null;
        }

        // Marquer comme 'processing'
        await event.data.after.ref.update({
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
                Email: "noreply@poppin-s.fr",
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

        const request = getMailjet().post('send', { version: 'v3.1' }).request({
            Messages: [mailjetMessage]
        });

        const result = await request;

        console.log(`✅ Email ${emailId} envoyé avec succès via Mailjet`);
        console.log('📊 Réponse Mailjet:', JSON.stringify(result.body, null, 2));

        // Marquer comme 'sent'
        await event.data.after.ref.update({
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

        await event.data.after.ref.update({
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
    schedule: 'every 15 minutes',
    region: 'europe-west1',
    memory: '128MiB',
    cpu: 0.08,
    maxInstances: 1,
    minInstances: 0,
    concurrency: 1,
}, async (event) => {
    try {
        const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);

        console.log('🔄 Recherche des emails échoués à retry...');

        // retryCount >= 3 car un email passe à 'failed' seulement après 3 tentatives
        const failedEmails = await db
            .collection('emailQueue')
            .where('status', '==', 'failed')
            .where('lastErrorAt', '<', twoHoursAgo)
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

// 🗑️ NETTOYAGE : Supprimer les invitations expirées (hebdomadaire)
exports.cleanupExpiredInvitations = onSchedule({
    schedule: 'every sunday 03:00',
    timeZone: 'Europe/Paris',
    region: 'europe-west1'
}, async (event) => {
    try {
        const now = Timestamp.now();
        console.log('🗑️ Nettoyage des invitations expirées...');

        const snapshot = await db
            .collection('invitations')
            .where('status', 'in', ['pending', 'expired'])
            .where('expiresAt', '<', now)
            .get();

        if (snapshot.empty) {
            console.log('✅ Aucune invitation expirée à supprimer');
            return null;
        }

        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        console.log(`🗑️ ${snapshot.size} invitation(s) expirée(s) supprimée(s)`);
    } catch (error) {
        console.error('❌ Erreur nettoyage invitations:', error);
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

// ===== MÉMO MENSUEL — envoyé le 25 de chaque mois à toutes les assistantes =====

// --- Helpers ---

function memoGetStructureName(d) {
    if (!d) return 'Ma structure';
    const p = (d.structureName || d.name || '').toString().trim();
    if (p) return p;
    return [(d.ownerFirstName || d.firstName || ''), (d.ownerLastName || d.lastName || '')]
        .map(s => s.toString().trim()).filter(Boolean).join(' ').trim() || 'Ma structure';
}

function memoNormalizeEmail(email) {
    if (!email || typeof email !== 'string') return '';
    return email.trim().toLowerCase();
}

function memoToSlug(value) {
    if (!value) return 'memo';
    return value.toString().normalize('NFD').replace(/[̀-ͯ]/g, '')
        .replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_+|_+$/g, '').toLowerCase() || 'memo';
}

function memoTimeToMinutes(hhmm) {
    if (!hhmm || typeof hhmm !== 'string') return null;
    const parts = hhmm.split(':');
    if (parts.length < 2) return null;
    const h = parseInt(parts[0], 10);
    const m = parseInt(parts[1], 10);
    if (isNaN(h) || isNaN(m)) return null;
    return h * 60 + m;
}

function memoFormatHours(totalHours) {
    const h = Math.floor(totalHours);
    const m = Math.round((totalHours - h) * 60);
    return `${h}h${String(m).padStart(2, '0')}`;
}

function memoResolveAssistant(structureDoc, structureData) {
    for (const c of [structureData.assistantEmail, structureData.ownerEmail, structureData.email]) {
        const email = memoNormalizeEmail(c);
        if (!email) continue;
        const name = [(structureData.ownerFirstName || structureData.firstName || ''),
                      (structureData.ownerLastName || structureData.lastName || '')]
            .map(s => s.toString().trim()).filter(Boolean).join(' ').trim() || email;
        return { email, name };
    }
    console.warn(`⚠️ ${structureDoc.id}: aucune assistante identifiable.`);
    return null;
}

// --- Collecte des données d'un enfant ---

async function memoCollectChildData({ structureId, childDoc, periodStart, periodEnd }) {
    const childData = childDoc.data() || {};
    const childId = childDoc.id;
    const firstName = (childData.firstName || childData.prenom || '').toString().trim();
    const lastName = (childData.lastName || childData.nom || '').toString().trim();
    const weeklySchedule = childData.schedule || null;
    const netSalary = parseFloat((childData.financialInfo || {}).monthlySalary) || 0;

    const structureRef = db.collection('structures').doc(structureId);
    const startTs = Timestamp.fromDate(periodStart.toJSDate());
    const endTs = Timestamp.fromDate(periodEnd.toJSDate());

    // Repas du mois
    const mealsByDate = {};
    try {
        const repasSnap = await structureRef.collection('children').doc(childId)
            .collection('repas').where('date', '>=', startTs).where('date', '<', endTs).get();
        repasSnap.forEach((doc) => {
            const d = doc.data() || {};
            if (!d.date) return;
            const dt = typeof d.date.toDate === 'function' ? d.date.toDate() : new Date(d.date);
            const dateKey = DateTime.fromJSDate(dt, { zone: 'Europe/Paris' }).toISODate();
            let label = '';
            if (d.moment && d.moment.toString().trim()) label = d.moment.toString().trim();
            else if (d.gouter) label = 'Goûter';
            else if (d.typeAlimentation) {
                const t = d.typeAlimentation.toString();
                label = t === 'Biberon' ? 'Biberon' : t === 'Allaitement' ? 'Allaitement' : 'Repas';
            } else label = 'Repas';
            if (!mealsByDate[dateKey]) mealsByDate[dateKey] = [];
            if (!mealsByDate[dateKey].includes(label)) mealsByDate[dateKey].push(label);
        });
    } catch (e) {
        console.warn(`⚠️ Repas ${childId}: ${e.message}`);
    }

    // Parcours jour par jour du 1er au 25
    const dailyRecords = [];
    let totalHours = 0;
    let plannedHours = 0;
    let totalAbsences = 0;
    const lastDay = periodEnd.minus({ days: 1 });
    let current = periodStart;

    while (current <= lastDay) {
        const dateKey = current.toISODate();
        const dayLabel = current.setLocale('fr').toFormat('cccc dd/MM/yyyy');
        const capDay = dayLabel.charAt(0).toUpperCase() + dayLabel.slice(1);

        let arrivalTime = '';
        let departureTime = '';
        let dayHours = 0;
        let isPresent = false;
        let isAbsent = false;

        try {
            const horaireDoc = await structureRef.collection('horaires').doc(dateKey).get();
            if (horaireDoc.exists) {
                const childHoraire = (horaireDoc.data() || {})[childId];
                if (childHoraire) {
                    if (childHoraire.actionType === 'absent' || childHoraire.absent === true) {
                        isAbsent = true;
                    } else if (Array.isArray(childHoraire.segments) && childHoraire.segments.length > 0) {
                        isPresent = true;
                        for (const seg of childHoraire.segments) {
                            const arr = seg.arrivee || '';
                            const dep = seg.depart || seg.heureFin || '';
                            if (!arrivalTime && arr) arrivalTime = arr;
                            if (dep) departureTime = dep;
                            if (arr && dep) {
                                const aM = memoTimeToMinutes(arr);
                                const dM = memoTimeToMinutes(dep);
                                if (aM !== null && dM !== null) {
                                    let diff = dM - aM;
                                    if (diff < 0) diff += 1440;
                                    dayHours += diff / 60;
                                }
                            }
                        }
                    } else if (childHoraire.arrivee || childHoraire.depart) {
                        isPresent = true;
                        arrivalTime = childHoraire.arrivee || '';
                        departureTime = childHoraire.depart || '';
                        if (arrivalTime && departureTime) {
                            const aM = memoTimeToMinutes(arrivalTime);
                            const dM = memoTimeToMinutes(departureTime);
                            if (aM !== null && dM !== null) {
                                let diff = dM - aM;
                                if (diff < 0) diff += 1440;
                                dayHours = diff / 60;
                            }
                        }
                    }
                }
            }
        } catch (e) {
            console.warn(`⚠️ Horaire ${childId} ${dateKey}: ${e.message}`);
        }

        // Heures contractuelles du jour
        if (weeklySchedule) {
            try {
                const frDay = current.setLocale('fr').toFormat('cccc');
                const key = frDay.charAt(0).toUpperCase() + frDay.slice(1);
                const entry = weeklySchedule[key];
                if (entry) {
                    const segs = Array.isArray(entry) ? entry : [entry];
                    for (const seg of segs) {
                        const s = (seg.start || seg.heureDebut || '').toString();
                        const e2 = (seg.end || seg.heureFin || '').toString();
                        if (s.includes(':') && e2.includes(':')) {
                            const sm = memoTimeToMinutes(s);
                            const em = memoTimeToMinutes(e2);
                            if (sm !== null && em !== null) {
                                let diff = em - sm;
                                if (diff < 0) diff += 1440;
                                plannedHours += diff / 60;
                            }
                        }
                    }
                }
            } catch (_) { /* ignore */ }
        }

        if (isPresent) {
            totalHours += dayHours;
            dailyRecords.push({
                dayLabel: capDay,
                status: 'Présent',
                arrivalTime,
                departureTime,
                meals: (mealsByDate[dateKey] || []).join(', '),
                realHours: dayHours > 0 ? memoFormatHours(dayHours) : '',
            });
        } else if (isAbsent) {
            totalAbsences += 1;
            dailyRecords.push({
                dayLabel: capDay,
                status: 'ABSENT',
                arrivalTime: '',
                departureTime: '',
                meals: '',
                realHours: 'ABSENT',
            });
        }

        current = current.plus({ days: 1 });
    }

    return { childId, firstName, lastName, dailyRecords, totalHours, plannedHours, totalAbsences, netSalary };
}

// --- Génération PDF tableau style "Mémo mensuel" ---

async function memoGeneratePdf({ assistant, structureName, periodLabel, childrenData }) {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const buffers = [];

    return new Promise((resolve, reject) => {
        doc.on('data', (chunk) => buffers.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(buffers)));
        doc.on('error', reject);

        const M = 40;
        // Colonnes: Jour(185) Statut(55) Arrivée(55) Départ(55) Repas(110) Heures(55) = 515
        const COLS = [185, 55, 55, 55, 110, 55];
        const HEADERS = ['Jour', 'Statut', 'Arrivée', 'Départ', 'Repas', 'Heures'];
        const ROW_H = 18;
        const TOTAL_W = COLS.reduce((a, b) => a + b, 0);
        const PAGE_H = 841 - M; // A4 height - bottom margin

        function drawRow(y, cells, bold, bg) {
            if (bg) {
                doc.save().fillColor(bg).rect(M, y, TOTAL_W, ROW_H).fill().restore();
            }
            doc.save().strokeColor('#000000').lineWidth(0.5).rect(M, y, TOTAL_W, ROW_H).stroke().restore();
            let x = M;
            for (let i = 0; i < COLS.length; i++) {
                if (i > 0) {
                    doc.save().strokeColor('#000000').lineWidth(0.5)
                        .moveTo(x, y).lineTo(x, y + ROW_H).stroke().restore();
                }
                doc.font(bold ? 'Helvetica-Bold' : 'Helvetica')
                   .fontSize(8).fillColor('#000000')
                   .text(cells[i] || '', x + 3, y + 5, { width: COLS[i] - 6, lineBreak: false, ellipsis: true });
                x += COLS[i];
            }
        }

        let firstChild = true;
        for (const child of childrenData) {
            const childName = [child.firstName, child.lastName].filter(Boolean).join(' ').trim() || child.childId;

            // ── Page 1 : tableau MÉMO ──
            if (!firstChild) doc.addPage();
            firstChild = false;

            let y = M;

            doc.font('Helvetica-Bold').fontSize(13).fillColor('#D94350')
               .text('RAPPEL', M, y, { align: 'center', width: TOTAL_W });
            y += 18;
            doc.font('Helvetica-Bold').fontSize(10).fillColor('#D94350')
               .text('Vous devez vérifier les éléments du mémo', M, y, { align: 'center', width: TOTAL_W });
            y += 16;

            doc.font('Helvetica-Bold').fontSize(14).fillColor('#000000')
               .text('MÉMO MENSUEL', M, y, { align: 'center', width: TOTAL_W });
            y += 22;

            doc.font('Helvetica-Bold').fontSize(10).fillColor('#000000').text(`Période: ${periodLabel}`, M, y);
            y += 14;
            doc.font('Helvetica-Bold').fontSize(10).text(`Enfant: ${childName}`, M, y);
            y += 18;

            // En-tête tableau
            drawRow(y, HEADERS, true, '#EEEEEE');
            y += ROW_H;

            // Lignes de données
            for (const rec of child.dailyRecords) {
                if (y + ROW_H > PAGE_H) {
                    doc.addPage();
                    y = M;
                    drawRow(y, HEADERS, true, '#EEEEEE');
                    y += ROW_H;
                }
                const cells = [rec.dayLabel, rec.status, rec.arrivalTime, rec.departureTime, rec.meals, rec.realHours];
                drawRow(y, cells, false, null);
                y += ROW_H;
            }

            // Ligne TOTAL
            if (y + ROW_H > PAGE_H) { doc.addPage(); y = M; }
            drawRow(y, ['TOTAL', `Absences: ${child.totalAbsences}`, '', '', '', memoFormatHours(child.totalHours)], true, '#EEEEEE');
            y += ROW_H + 10;

            doc.font('Helvetica-Oblique').fontSize(9).fillColor('#555555')
               .text('Voir le récapitulatif à la page suivante', M, y, { align: 'center', width: TOTAL_W });

            // ── Page 2 : RÉCAPITULATIF ──
            doc.addPage();
            y = M;

            doc.font('Helvetica-Bold').fontSize(14).fillColor('#000000')
               .text('RÉCAPITULATIF', M, y, { align: 'center', width: TOTAL_W });
            y += 22;
            doc.font('Helvetica-Bold').fontSize(10).text(`Période: ${periodLabel}`, M, y);
            y += 14;
            doc.font('Helvetica-Bold').fontSize(10).text(`Enfant: ${childName}`, M, y);
            y += 22;

            const BOX_X = M + 40;
            const BOX_W = TOTAL_W - 80;
            const LINE_H = 22;
            const hoursDiff = child.totalHours - child.plannedHours;
            const rows = [
                ['Heures prévues au contrat:', `${child.plannedHours.toFixed(2)} heures`],
                ['Nombre d’heures réelles total:', `${child.totalHours.toFixed(2)} heures`],
                ['Écart (réel − prévu):', `${hoursDiff.toFixed(2)} heures`],
                ['Salaire net:', `${child.netSalary.toFixed(2)} €`],
                ['Nombre d’absences total:', `${child.totalAbsences}`],
            ];
            const BOX_H = rows.length * LINE_H + 20;

            doc.save().strokeColor('#000000').lineWidth(0.5)
               .rect(BOX_X, y, BOX_W, BOX_H).stroke().restore();

            let rowY = y + 10;
            for (const [label, value] of rows) {
                doc.font('Helvetica').fontSize(10).fillColor('#000000').text(label, BOX_X + 10, rowY);
                doc.font('Helvetica-Bold').fontSize(10)
                   .text(value, BOX_X + 10, rowY, { width: BOX_W - 20, align: 'right' });
                rowY += LINE_H;
            }
        }

        doc.end();
    });
}

// --- Email ---

async function memoEnqueueEmail({ assistant, structureName, periodLabel, pdfBuffer, childCount }) {
    const slug = memoToSlug(structureName);
    const periodSlug = memoToSlug(periodLabel);
    await db.collection('emailQueue').add({
        to: assistant.email,
        subject: `Mémo mensuel ${periodLabel} — ${structureName}`,
        template: 'monthly-assistant-recap',
        templateData: {
            assistantName: assistant.name || assistant.email,
            structureName,
            monthLabel: periodLabel,
            childCount,
        },
        pdfAttachment: pdfBuffer.toString('base64'),
        pdfFilename: `Memo_${slug}_${periodSlug}.pdf`,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
    });
    console.log(`📧 Mémo en file pour ${assistant.email} (${childCount} enfant(s))`);
}

// --- Traitements par type de structure ---

async function memoProcessSingle({ structureDoc, structureData, structureName, periodStart, periodEnd, periodLabel, childrenSnapshot }) {
    const assistant = memoResolveAssistant(structureDoc, structureData);
    if (!assistant) return;

    const childrenData = [];
    for (const childDoc of childrenSnapshot.docs) {
        childrenData.push(await memoCollectChildData({ structureId: structureDoc.id, childDoc, periodStart, periodEnd }));
    }
    if (!childrenData.length) return;

    const pdfBuffer = await memoGeneratePdf({ assistant, structureName, periodLabel, childrenData });
    await memoEnqueueEmail({ assistant, structureName, periodLabel, pdfBuffer, childCount: childrenData.length });
}

async function memoProcessMam({ structureDoc, structureName, periodStart, periodEnd, periodLabel, childrenSnapshot }) {
    const membersSnapshot = await structureDoc.ref.collection('members').get();
    if (membersSnapshot.empty) return;

    const membersByEmail = new Map();
    membersSnapshot.forEach((doc) => {
        const d = doc.data() || {};
        const email = memoNormalizeEmail(d.email);
        if (!email) return;
        const name = [d.firstName || '', d.lastName || ''].map(s => s.toString().trim()).filter(Boolean).join(' ').trim() || d.fullName || 'Assistante';
        membersByEmail.set(email, { email, name });
    });

    const childrenByMember = new Map();
    childrenSnapshot.forEach((doc) => {
        const d = doc.data() || {};
        const email = memoNormalizeEmail(d.assignedMemberEmail);
        if (!email || !membersByEmail.has(email)) return;
        if (!childrenByMember.has(email)) childrenByMember.set(email, []);
        childrenByMember.get(email).push(doc);
    });

    for (const [email, childDocs] of childrenByMember.entries()) {
        const assistant = membersByEmail.get(email);
        if (!assistant) continue;
        const childrenData = [];
        for (const childDoc of childDocs) {
            childrenData.push(await memoCollectChildData({ structureId: structureDoc.id, childDoc, periodStart, periodEnd }));
        }
        if (!childrenData.length) continue;
        const pdfBuffer = await memoGeneratePdf({ assistant, structureName, periodLabel, childrenData });
        await memoEnqueueEmail({ assistant, structureName, periodLabel, pdfBuffer, childCount: childrenData.length });
    }
}

// --- Export Cloud Function (schedule: 25 de chaque mois à 6h Paris) ---

exports.sendMonthlyAssistantRecaps = onSchedule({
    schedule: '0 6 25 * *',
    timeZone: 'Europe/Paris',
    region: 'europe-west1',
}, async () => {
    const nowParis = DateTime.now().setZone('Europe/Paris');
    const periodStart = nowParis.startOf('month');
    const periodEnd = nowParis.startOf('day').plus({ days: 1 }); // 26 à 00:00 (exclusif)
    const periodLabel = periodStart.setLocale('fr').toFormat('LLLL yyyy');

    console.log(`📅 Mémo mensuel — ${periodStart.toISODate()} → ${nowParis.toISODate()} (${periodLabel})`);

    const structuresSnapshot = await db.collection('structures').get();
    console.log(`🏢 ${structuresSnapshot.size} structures`);

    for (const structureDoc of structuresSnapshot.docs) {
        const structureData = structureDoc.data() || {};
        const structureName = memoGetStructureName(structureData);
        const normalizedType = (structureData.structureType || '').toString().toLowerCase();
        try {
            const childrenSnapshot = await structureDoc.ref.collection('children').get();
            if (childrenSnapshot.empty) continue;
            if (normalizedType === 'mam') {
                await memoProcessMam({ structureDoc, structureName, periodStart, periodEnd, periodLabel, childrenSnapshot });
            } else {
                await memoProcessSingle({ structureDoc, structureData, structureName, periodStart, periodEnd, periodLabel, childrenSnapshot });
            }
        } catch (err) {
            console.error(`❌ ${structureDoc.id}:`, err);
        }
    }

    console.log('✅ Mémo mensuel terminé.');
})

// ===== FONCTION PONCTUELLE : BACKFILL DES SUBSCRIPTIONS =====
/**
 * ATTENTION : Cette fonction est à déclencher UNE SEULE FOIS
 * Elle corrige les données de subscription manquantes dans les structures
 * Après utilisation, supprimer cette fonction pour éviter toute exécution accidentelle
 */
exports.backfillSubscriptions = onRequest({
    region: 'europe-west1',
    cors: true
}, async (request, response) => {
    // 🔐 PROTECTION : Vérifier le token admin Firebase
    const authHeader = request.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) {
        return response.status(401).json({ error: 'Token manquant' });
    }
    try {
        const decoded = await getAuth().verifyIdToken(token);
        if (!decoded.admin && !['cbeylet06@gmail.com', 'chrisgugu1101@gmail.com'].includes(decoded.email || '')) {
            return response.status(403).json({ error: 'Accès réservé aux admins' });
        }
    } catch (authErr) {
        return response.status(401).json({ error: 'Token invalide' });
    }

    try {
        console.log("🚀 Début du backfill des subscriptions...");

        // 1. Récupérer toutes les structures avec subscriptionActive = true
        const structuresSnapshot = await db
            .collection("structures")
            .where("subscriptionActive", "==", true)
            .get();

        console.log(`📊 ${structuresSnapshot.size} structures actives trouvées`);

        let updated = 0;
        let skipped = 0;
        let errors = 0;
        const details = [];

        // 2. Pour chaque structure
        for (const structureDoc of structuresSnapshot.docs) {
            const structureId = structureDoc.id;
            const structureData = structureDoc.data();

            try {
                // Vérifier si le backfill est déjà fait
                if (
                    structureData.subscriptionStatus === "active" &&
                    structureData.subscriptionPrice &&
                    structureData.subscriptionPlatform
                ) {
                    console.log(`⏭️  Structure ${structureId} déjà à jour`);
                    skipped++;
                    details.push({
                        structureId,
                        status: 'skipped',
                        reason: 'already_complete'
                    });
                    continue;
                }

                // 3. Récupérer la dernière subscription de cette structure
                const subscriptionSnapshot = await db
                    .collection("subscriptions")
                    .where("structureId", "==", structureId)
                    .orderBy("createdAt", "desc")
                    .limit(1)
                    .get();

                if (subscriptionSnapshot.empty) {
                    console.log(`⚠️  Pas de subscription trouvée pour ${structureId}`);
                    skipped++;
                    details.push({
                        structureId,
                        status: 'skipped',
                        reason: 'no_subscription_found'
                    });
                    continue;
                }

                const subscriptionData = subscriptionSnapshot.docs[0].data();

                // 4. Préparer les données de mise à jour
                const updateData = {
                    subscriptionStatus: "active",
                    subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                };

                // Ajouter le prix si disponible
                if (subscriptionData.price) {
                    updateData.subscriptionPrice = subscriptionData.price;
                }

                // Ajouter la plateforme si disponible
                if (subscriptionData.platform) {
                    updateData.subscriptionPlatform = subscriptionData.platform;
                }

                // Ajouter la source si pas déjà présente
                if (!structureData.subscriptionSource) {
                    updateData.subscriptionSource = "backfill_correction";
                }

                // Mettre à jour trialStatus si nécessaire
                if (!structureData.trialStatus || structureData.trialStatus === "active") {
                    updateData.trialStatus = "converted";
                }

                // 5. Mettre à jour la structure
                await structureDoc.ref.update(updateData);

                console.log(`✅ Structure ${structureId} mise à jour`, updateData);
                updated++;
                details.push({
                    structureId,
                    status: 'updated',
                    updatedFields: Object.keys(updateData)
                });
            } catch (error) {
                console.error(`❌ Erreur pour structure ${structureId}:`, error);
                errors++;
                details.push({
                    structureId,
                    status: 'error',
                    error: error.message
                });
            }
        }

        // 6. Résumé
        const summary = {
            success: true,
            totalStructures: structuresSnapshot.size,
            updated: updated,
            skipped: skipped,
            errors: errors,
            message: "Backfill terminé avec succès",
            timestamp: new Date().toISOString(),
            details: details
        };

        console.log("🎉 Backfill terminé:", summary);
        response.status(200).json(summary);
    } catch (error) {
        console.error("💥 Erreur globale:", error);
        response.status(500).json({
            success: false,
            error: error.message || "Erreur inconnue",
            timestamp: new Date().toISOString()
        });
    }
});

/**
 * CORRECTION - Réparer les subscriptionStatus
 * Différencier les trials des abonnements actifs
 */
exports.fixSubscriptionStatusV2 = onRequest({
    region: 'europe-west1'
}, async (request, response) => {
    // 🔐 PROTECTION admin
    const authHeader2 = request.headers.authorization || '';
    const token2 = authHeader2.startsWith('Bearer ') ? authHeader2.slice(7) : null;
    if (!token2) return response.status(401).json({ error: 'Token manquant' });
    try {
        const decoded2 = await getAuth().verifyIdToken(token2);
        if (!decoded2.admin && !['cbeylet06@gmail.com', 'chrisgugu1101@gmail.com'].includes(decoded2.email || '')) {
            return response.status(403).json({ error: 'Accès réservé aux admins' });
        }
    } catch (_e) { return response.status(401).json({ error: 'Token invalide' }); }

    try {
        console.log("🔧 Début de la correction V2 des subscriptionStatus...");

        const structuresSnapshot = await db
            .collection("structures")
            .where("subscriptionActive", "==", true)
            .get();

        console.log(`📊 ${structuresSnapshot.size} structures actives trouvées`);

        let fixedToActive = 0;
        let keptAsTrial = 0;
        let alreadyCorrect = 0;
        let errors = 0;
        const details = [];

        for (const structureDoc of structuresSnapshot.docs) {
            const structureId = structureDoc.id;
            const structureData = structureDoc.data();

            try {
                const subscriptionSnapshot = await db
                    .collection("subscriptions")
                    .where("structureId", "==", structureId)
                    .orderBy("createdAt", "desc")
                    .limit(1)
                    .get();

                if (subscriptionSnapshot.empty) {
                    console.log(`⚠️ Pas de subscription pour ${structureId}`);
                    details.push({
                        structureId,
                        status: 'skipped',
                        reason: 'no_subscription_found'
                    });
                    continue;
                }

                const subscriptionData = subscriptionSnapshot.docs[0].data();
                const currentStatus = structureData.subscriptionStatus;

                // NOUVELLE LOGIQUE CORRIGÉE
                let correctStatus;

                // 1. Si platform ou source = "firebase_trial" → C'EST UN TRIAL
                if (
                    subscriptionData.platform === "firebase_trial" ||
                    subscriptionData.source === "firebase_trial"
                ) {
                    correctStatus = "trial";
                }
                // 2. Si status = "active" ET platform = "ios" ou "android" → C'EST UN ABONNÉ PAYANT
                else if (
                    subscriptionData.status === "active" &&
                    (subscriptionData.platform === "ios" || subscriptionData.platform === "android")
                ) {
                    correctStatus = "active";
                }
                // 3. Si status = "trial" → C'EST UN TRIAL
                else if (subscriptionData.status === "trial") {
                    correctStatus = "trial";
                }
                // 4. Par défaut, on regarde isTrialPeriod (cas de fallback)
                else if (subscriptionData.isTrialPeriod === true) {
                    correctStatus = "trial";
                }
                // 5. Sinon, on considère comme actif
                else {
                    correctStatus = "active";
                }

                // Mettre à jour si nécessaire
                if (currentStatus !== correctStatus) {
                    await structureDoc.ref.update({
                        subscriptionStatus: correctStatus,
                        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
                    });

                    if (correctStatus === "active") {
                        console.log(`✅ ${structureId}: CORRIGÉ de "${currentStatus}" vers "active"`);
                        fixedToActive++;
                        details.push({
                            structureId,
                            status: 'fixed_to_active',
                            previousStatus: currentStatus,
                            subscriptionPlatform: subscriptionData.platform
                        });
                    } else {
                        console.log(`✅ ${structureId}: CORRIGÉ vers "trial"`);
                        keptAsTrial++;
                        details.push({
                            structureId,
                            status: 'kept_as_trial',
                            previousStatus: currentStatus
                        });
                    }
                } else {
                    console.log(`⏭️  ${structureId}: déjà correct (${correctStatus})`);
                    alreadyCorrect++;
                    details.push({
                        structureId,
                        status: 'already_correct',
                        subscriptionStatus: correctStatus
                    });
                }
            } catch (error) {
                console.error(`❌ Erreur pour ${structureId}:`, error);
                errors++;
                details.push({
                    structureId,
                    status: 'error',
                    error: error.message
                });
            }
        }

        const summary = {
            success: true,
            totalStructures: structuresSnapshot.size,
            fixedToActive: fixedToActive,
            keptAsTrial: keptAsTrial,
            alreadyCorrect: alreadyCorrect,
            errors: errors,
            message: "Correction V2 terminée",
            timestamp: new Date().toISOString(),
            details: details
        };

        console.log("🎉 Correction V2 terminée:", summary);
        response.status(200).json(summary);
    } catch (error) {
        console.error("💥 Erreur globale:", error);
        response.status(500).json({
            success: false,
            error: error.message || "Erreur inconnue",
            timestamp: new Date().toISOString()
        });
    }
});
const _expiredTrialStatuses = ['trial', 'trialing'];

exports.deactivateExpiredTrials = onSchedule(
    { schedule: 'every 24 hours', timeZone: 'Europe/Paris', region: 'europe-west1' },
    async () => {
        const now = Timestamp.now();
        console.log('🚀 Début du nettoyage des trials expirés à', now.toDate());

        try {
            const processed = new Set();
            let updatedCount = 0;

            const queries = [
                db
                    .collection('structures')
                    .where('subscriptionStatus', 'in', _expiredTrialStatuses)
                    .where('subscriptionTrialEndsAt', '<=', now),
                db
                    .collection('structures')
                    .where('subscriptionStatus', 'in', _expiredTrialStatuses)
                    .where('trialEndsAt', '<=', now),
            ];

            for (const query of queries) {
                const snapshot = await query.get();
                for (const doc of snapshot.docs) {
                    if (processed.has(doc.id)) continue;
                    processed.add(doc.id);

                    const data = doc.data() || {};
                    if (!_isTrialExpired(data, now)) {
                        continue;
                    }

                    await _expireStructureAndSubscription(doc.id);
                    updatedCount++;
                    console.log(`✅ ${doc.id} passé en expired (structure + subscription)`);
                }
            }

            console.log(`🎉 Nettoyage terminé : ${updatedCount} structure(s) mises à jour.`);
        } catch (error) {
            console.error('❌ Erreur pendant le nettoyage des trials expirés:', error);
        }
    },
);

function _isTrialExpired(data, nowTimestamp) {
    const candidate =
        data.subscriptionTrialEndsAt ?? data.trialEndsAt ?? data.trialEndsAtIso;
    if (!candidate) {
        return false;
    }
    const endDate = _toDate(candidate);
    if (!endDate) {
        return false;
    }
    return endDate.getTime() <= nowTimestamp.toDate().getTime();
}

function _toDate(value) {
    if (!value) return null;
    if (value instanceof Timestamp) {
        return value.toDate();
    }
    if (typeof value.toDate === 'function') {
        return value.toDate();
    }
    if (typeof value === 'number') {
        return new Date(value);
    }
    if (typeof value === 'string') {
        const parsed = new Date(value);
        return isNaN(parsed.getTime()) ? null : parsed;
    }
    return null;
}

async function _expireStructureAndSubscription(structureId) {
    const structureRef = db.collection('structures').doc(structureId);
    const serverTimestamp = FieldValue.serverTimestamp();

    const batch = db.batch();
    batch.set(
        structureRef,
        {
            subscriptionStatus: 'expired',
            subscriptionActive: false,
            subscriptionUpdatedAt: serverTimestamp,
            trialStatus: 'expired',
            trialEndedAt: serverTimestamp,
        },
        { merge: true },
    );

    // 🔧 CORRECTION : Pour les trials Firebase, le doc subscription est créé avec
    // l'ID = structureId (voir FirebaseTrialService). Pour les abonnements Stripe/IAP
    // le doc a un ID différent. On met à jour les deux cas.
    // 1. Tenter de mettre à jour le doc subscription avec ID = structureId (trial Firebase)
    const subscriptionRefById = db.collection('subscriptions').doc(structureId);
    batch.set(
        subscriptionRefById,
        {
            status: 'expired',
            isTrialPeriod: false,
            updatedAt: serverTimestamp,
        },
        { merge: true },
    );

    await batch.commit();

    // 2. Mettre à jour aussi les docs subscription liés par structureId (Stripe/IAP)
    try {
        const linkedSubs = await db.collection('subscriptions')
            .where('structureId', '==', structureId)
            .where('status', 'in', ['trial', 'trialing', 'active'])
            .get();
        if (!linkedSubs.empty) {
            const subBatch = db.batch();
            linkedSubs.docs.forEach(doc => {
                subBatch.set(doc.ref, { status: 'expired', isTrialPeriod: false, updatedAt: serverTimestamp }, { merge: true });
            });
            await subBatch.commit();
            console.log(`✅ ${linkedSubs.size} subscription(s) liée(s) expirée(s) pour structure ${structureId}`);
        }
    } catch (err) {
        console.error(`⚠️ Erreur expiration subscriptions liées pour ${structureId}:`, err);
    }
}

const inactiveSubscriptionStatuses = new Set([
    'expired',
    'cancelled',
    'canceled',
    'inactive',
    'ended',
    'terminated',
    'replaced',
    // Statuts Stripe d'échec de paiement / abonnement jamais abouti : doivent
    // rester inactifs, jamais retomber dans un défaut "actif" (bug corrigé le
    // 2026-07-08 — un abonnement past_due repassait "actif" ici juste après
    // que le webhook Stripe principal l'ait correctement marqué inactif).
    'past_due',
    'unpaid',
    'incomplete',
    'incomplete_expired',
    'paused'
]);

const activeSubscriptionStatuses = new Set([
    'active',
    'purchased',
    'approved',
    'succeeded',
    'renewing',
    'grace',
    'grace_period',
    'in_grace_period'
]);

async function syncStructureWithSubscription(subscriptionId, subscriptionData, structureId) {
    if (!structureId) {
        console.warn('⚠️ Impossible de synchroniser, structureId absent');
        return false;
    }

    const status = (subscriptionData.status || '').toString().toLowerCase();
    const platform = (subscriptionData.platform || '').toString().toLowerCase();
    const source = (subscriptionData.source || '').toString().toLowerCase();
    const isTrialDoc =
        status.includes('trial') ||
        subscriptionData.isTrialPeriod === true ||
        platform === 'firebase_trial' ||
        source === 'firebase_trial';
    const isInactiveDoc = inactiveSubscriptionStatuses.has(status);
    const isKnownActiveDoc = activeSubscriptionStatuses.has(status);
    // Sécurité par défaut : un statut non reconnu (ni actif, ni inactif, ni essai)
    // est désormais traité comme INACTIF plutôt qu'actif, avec un log pour
    // investigation manuelle — l'ancien fallback "actif par défaut" est ce qui
    // a causé le bug ci-dessus.
    if (!isTrialDoc && !isInactiveDoc && !isKnownActiveDoc) {
        console.warn(`⚠️ syncStructureWithSubscription: statut inconnu "${status}" pour subscription ${subscriptionId} (structure ${structureId}) — traité comme INACTIF par sécurité, à vérifier manuellement.`);
    }
    const isActiveDoc = isKnownActiveDoc;

    const updates = {
        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
    };

    if (isActiveDoc) {
        updates.subscriptionActive = true;
        updates.subscriptionStatus = 'active';
        updates.subscriptionDocId = subscriptionId;
        updates.subscriptionPlatform = platform || 'unknown';
        updates.subscriptionSource = source || platform || 'unknown';
        updates.trialStatus = 'converted';
    } else if (isTrialDoc) {
        updates.subscriptionActive = true;
        updates.subscriptionStatus = 'trial';
        updates.subscriptionDocId = subscriptionId;
        updates.subscriptionPlatform = platform || 'firebase_trial';
        updates.subscriptionSource = source || platform || 'firebase_trial';
        updates.trialStatus = 'trial';
    } else if (isInactiveDoc) {
        updates.subscriptionActive = false;
        updates.subscriptionStatus = status || 'expired';
        updates.trialStatus = 'expired';
    }

    const ensureDateField = (fieldValue) => {
        if (!fieldValue) return null;
        if (fieldValue.toDate) {
            return fieldValue.toDate();
        }
        const parsed = new Date(fieldValue);
        return isNaN(parsed.getTime()) ? null : parsed;
    };

    const expirationDate = ensureDateField(
        subscriptionData.expirationDate ||
        subscriptionData.expiresAt ||
        subscriptionData.subscriptionExpiresAtIso
    );
    if (expirationDate) {
        updates.subscriptionExpiresAt = Timestamp.fromDate(expirationDate);
        updates.subscriptionExpirationDate = expirationDate.toISOString();
        updates.subscriptionExpiresAtIso = expirationDate.toISOString();
    }

    const trialStart = ensureDateField(
        subscriptionData.trialStartAt ||
        subscriptionData.trialStartedAt ||
        subscriptionData.subscriptionTrialStartsAt
    );
    if (trialStart) {
        updates.subscriptionTrialStartsAt = Timestamp.fromDate(trialStart);
    }

    const trialEnd = ensureDateField(
        subscriptionData.trialEndsAt ||
        subscriptionData.subscriptionTrialEndsAt
    );
    if (trialEnd) {
        updates.subscriptionTrialEndsAt = Timestamp.fromDate(trialEnd);
    }

    if (subscriptionData.maxMemberCount) {
        updates.maxMemberCount = subscriptionData.maxMemberCount;
    }
    if (subscriptionData.memberCount) {
        updates.memberCount = subscriptionData.memberCount;
    }
    if (subscriptionData.priceAmount != null) {
        updates.currentPriceAmount = subscriptionData.priceAmount;
    }
    if (subscriptionData.priceDisplay) {
        updates.currentPriceDisplay = subscriptionData.priceDisplay;
    }

    const structureRef = db.collection('structures').doc(structureId);
    const structureSnap = await structureRef.get();
    const structureData = structureSnap.exists ? structureSnap.data() : {};

    if (isInactiveDoc && structureData?.subscriptionDocId !== subscriptionId) {
        console.log('ℹ️ Subscription inactive mais non liée à la structure, on ignore');
        return false;
    }

    await structureRef.set(updates, { merge: true });
    console.log(`✅ Structure ${structureId} synchronisée avec subscription ${subscriptionId}`);
    return true;
}

// ==========================================
// ===== ON STRUCTURE CREATED (LINK SUB) ====
// ==========================================
exports.onStructureCreated = onDocumentCreated({
    document: 'structures/{structureId}',
    region: 'europe-west1'
}, async (event) => {
    try {
        const snapshot = event.data;
        if (!snapshot) return null; // suppression

        const structureId = event.params.structureId;
        const structureData = snapshot.data();
        const email = structureData.ownerEmail || structureData.email;

        if (!email) {
            console.log(`ℹ️ Structure ${structureId} sans email, skip linking.`);
            return null;
        }

        // 1. Chercher une souscription existante avec cet email
        console.log(`🔍 Recherche souscription pour email: "${email}" (Structure: ${structureId})`);

        let subQuery;
        try {
            subQuery = await db.collection('subscriptions')
                .where('email', '==', email)
                .orderBy('createdAt', 'desc')
                .limit(1)
                .get();
        } catch (queryErr) {
            console.warn(`⚠️ Erreur index/query pour ${email}, retry sans tri:`, queryErr.message);
            // Fallback sans tri si index manquant
            subQuery = await db.collection('subscriptions')
                .where('email', '==', email)
                .limit(1)
                .get();
        }

        if (subQuery.empty) {
            console.log(`ℹ️ Aucune souscription trouvée pour "${email}". Fin.`);
            return null;
        }

        const subDoc = subQuery.docs[0];
        const subData = subDoc.data();
        const subId = subDoc.id;

        const priceId = subData.planId;
        console.log(`✅ Souscription trouvée: ${subId} (Plan: ${priceId}) pour ${email}`);

        // 2. Déterminer les règles du plan (Assmat vs MAM)
        let structureType = 'AssistanteMaternelle'; // Correction finale : CamelCase requis
        let maxMemberCount = 1;

        if (priceId === 'price_1SfkUILID2pA5i1C75uu1TCH' || priceId === 'price_1SflCBPpvDnoE6wk9jqNDsWP') {
            // MAM 2-3
            structureType = 'MAM'; // Correction : Uppercase requis
            maxMemberCount = 3;
        } else if (priceId === 'price_1SfkWULID2pA5i1CmSdrRF0c' || priceId === 'price_1SflCjPpvDnoE6wkfD6BliGn') {
            // MAM 4+
            structureType = 'MAM'; // Correction : Uppercase requis
            maxMemberCount = 50;
        }
        console.log(`📝 Application règles: Price=${priceId} -> Type=${structureType}, Max=${maxMemberCount}`);

        // 3. Mettre à jour la souscription avec le structureId
        await subDoc.ref.set({
            structureId: structureId,
            structureType: structureType,
            maxMemberCount: maxMemberCount,
            updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });

        // 4. Mettre à jour la structure
        await snapshot.ref.set({
            structureType: structureType, // Force la correction
            maxMemberCount: maxMemberCount,
            subscriptionDocId: subId,
            stripeSubscriptionId: subId,
            subscriptionStatus: subData.status || 'active',
            subscriptionPlatform: 'stripe',
            subscriptionActive: true,
        }, { merge: true });

        console.log(`🎉 SUCCÈS: Structure ${structureId} corrigée en ${structureType} (Max: ${maxMemberCount})`);
    } catch (err) {
        console.error("❌ CRASH onStructureCreated:", err);
    }
    return null;
});

// ==========================================
// ===== MISE À NIVEAU MAM (abonnés Stripe) ===
// ==========================================
// Corrige un gap découvert le 10/07 : l'écran de mise à niveau
// (subscription_upgrade_screen.dart) ne savait déclencher qu'un nouvel achat
// In-App Purchase, quelle que soit la source de l'abonnement actuel — une
// abonnée Stripe qui tapait "Mettre à niveau" se serait retrouvée avec un
// second abonnement (Apple/Google) facturé en parallèle du premier (Stripe),
// jamais résilié. Cette fonction modifie DIRECTEMENT l'abonnement Stripe
// existant (même souscription, changement de prix avec proration) au lieu
// d'en créer un nouveau.
const STRIPE_MAM_PRICE_IDS = {
    '2-3': 'price_1SfkUILID2pA5i1C75uu1TCH',
    '4+': 'price_1SfkWULID2pA5i1CmSdrRF0c',
};

exports.upgradeStripeSubscription = onCall({
    region: 'europe-west1',
    secrets: [STRIPE_SECRET_KEY],
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentification requise');
    }

    const tier = (request.data && request.data.tier || '').toString();
    if (!STRIPE_MAM_PRICE_IDS[tier]) {
        throw new HttpsError('invalid-argument', `tier invalide (attendu '2-3' ou '4+'): ${tier}`);
    }
    const newPriceId = STRIPE_MAM_PRICE_IDS[tier];
    const newMaxMemberCount = tier === '4+' ? 50 : 3;

    // Résoudre structureId comme partout ailleurs : users/{email}.structureId, sinon uid
    const email = (request.auth.token?.email || '').toLowerCase();
    let structureId = request.auth.uid;
    if (email) {
        const userDoc = await db.collection('users').doc(email).get();
        const sid = userDoc.exists ? userDoc.data().structureId : null;
        if (sid && String(sid).trim()) structureId = String(sid).trim();
    }

    const structureRef = db.collection('structures').doc(structureId);
    const structureSnap = await structureRef.get();
    if (!structureSnap.exists) {
        throw new HttpsError('not-found', 'Structure introuvable');
    }
    const structureData = structureSnap.data();

    const platform = (structureData.subscriptionPlatform || structureData.subscriptionSource || '').toString().toLowerCase();
    if (platform !== 'stripe') {
        throw new HttpsError('failed-precondition', `Cette fonction ne gère que les abonnements Stripe (plateforme détectée: ${platform || 'inconnue'})`);
    }

    const subId = structureData.subscriptionDocId || structureData.stripeSubscriptionId;
    if (!subId) {
        throw new HttpsError('failed-precondition', 'Aucun abonnement Stripe lié à cette structure');
    }

    let subscription;
    try {
        subscription = await getStripe().subscriptions.retrieve(subId);
    } catch (error) {
        console.error(`❌ upgradeStripeSubscription: abonnement Stripe ${subId} introuvable:`, error);
        throw new HttpsError('not-found', 'Abonnement Stripe introuvable');
    }

    const currentItem = subscription.items?.data?.[0];
    if (!currentItem) {
        throw new HttpsError('internal', 'Abonnement Stripe sans ligne de produit');
    }

    if (currentItem.price?.id === newPriceId) {
        return { success: true, alreadyOnTier: true, maxMemberCount: newMaxMemberCount };
    }

    let updatedSubscription;
    try {
        updatedSubscription = await getStripe().subscriptions.update(subId, {
            items: [{ id: currentItem.id, price: newPriceId }],
            proration_behavior: 'create_prorations',
        });
    } catch (error) {
        console.error(`❌ upgradeStripeSubscription: échec de la mise à jour Stripe pour ${subId}:`, error);
        throw new HttpsError('internal', `Échec de la mise à jour de l'abonnement Stripe: ${error.message}`);
    }

    const priceDisplay = tier === '4+' ? '14,99 € / mois' : '9,99 € / mois';
    const priceAmount = tier === '4+' ? 14.99 : 9.99;

    await structureRef.set({
        structureType: 'MAM',
        maxMemberCount: newMaxMemberCount,
        subscriptionActive: true,
        subscriptionStatus: 'active',
        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
        currentPriceAmount: priceAmount,
        currentPriceDisplay: priceDisplay,
    }, { merge: true });

    await db.collection('subscriptions').doc(subId).set({
        planId: newPriceId,
        maxMemberCount: newMaxMemberCount,
        priceAmount,
        priceDisplay,
        updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`✅ upgradeStripeSubscription: ${subId} passé au tier ${tier} (structure ${structureId})`);

    return { success: true, subscriptionId: updatedSubscription.id, maxMemberCount: newMaxMemberCount };
});

// ==========================================
// ===== SYNC SUBSCRIPTION → STRUCTURE  =====
// ==========================================
exports.syncSubscriptionWithStructure = onDocumentWritten({
    document: 'subscriptions/{subscriptionId}',
    region: 'europe-west1'
}, async (event) => {
    const beforeData = event.data.before.exists ? event.data.before.data() : null;
    const afterSnap = event.data.after;

    if (!afterSnap.exists) {
        console.log('ℹ️ Subscription supprimée, aucune action');
        return null;
    }

    const subscriptionId = event.params.subscriptionId;
    const subscriptionData = afterSnap.data() || {};
    const structureId = subscriptionData.structureId || beforeData?.structureId;

    await syncStructureWithSubscription(subscriptionId, subscriptionData, structureId);
    return null;
});

// ==========================================
// ===== ON-DEMAND BACKFILL SUBSCRIPTIONS ===
// ==========================================
exports.repairSubscriptions = onRequest({
    region: 'europe-west1'
}, async (request, response) => {
    // 🔐 PROTECTION admin
    const authHeaderR = request.headers.authorization || '';
    const tokenR = authHeaderR.startsWith('Bearer ') ? authHeaderR.slice(7) : null;
    if (!tokenR) return response.status(401).json({ error: 'Token manquant' });
    try {
        const decodedR = await getAuth().verifyIdToken(tokenR);
        if (!decodedR.admin && !['cbeylet06@gmail.com', 'chrisgugu1101@gmail.com'].includes(decodedR.email || '')) {
            return response.status(403).json({ error: 'Accès réservé aux admins' });
        }
    } catch (_eR) { return response.status(401).json({ error: 'Token invalide' }); }

    try {
        const snapshot = await db.collection('subscriptions').get();
        let updated = 0;
        for (const doc of snapshot.docs) {
            const data = doc.data() || {};
            const structureId = data.structureId;
            if (!structureId) {
                continue;
            }
            const applied = await syncStructureWithSubscription(doc.id, data, structureId);
            if (applied) {
                updated++;
            }
        }

        response.status(200).json({
            success: true,
            processed: snapshot.size,
            updated,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('❌ Erreur repairSubscriptions:', error);
        response.status(500).json({
            success: false,
            error: error.message || 'Erreur inconnue'
        });
    }
});

async function _upsertSubscriptionToken({ token, platform, userDocPath, userDocId, productId }) {
    if (!token || !platform) return;
    const payload = {
        uid: userDocId || null,
        userDocId: userDocId || null,
        userDocPath: userDocPath || null,
        platform,
        productId: productId || null,
        updatedAt: FieldValue.serverTimestamp(),
    };
    if (!payload.createdAt) {
        payload.createdAt = FieldValue.serverTimestamp();
    }
    await db.collection('subscriptionTokens').doc(token).set(payload, { merge: true });
    console.log('✅ subscriptionTokens upsert', { token, platform, userDocId, userDocPath, productId });
}

// ============================================
// ========== WEBHOOKS ABONNEMENTS ============
// ============================================
const GOOGLE_NOTIFICATION_TYPES = {
    SUBSCRIPTION_RECOVERED: 1,
    SUBSCRIPTION_RENEWED: 2,
    SUBSCRIPTION_CANCELED: 3,
    SUBSCRIPTION_PURCHASED: 4,
    SUBSCRIPTION_ON_HOLD: 5,
    SUBSCRIPTION_IN_GRACE_PERIOD: 6,
    SUBSCRIPTION_RESTARTED: 7,
    SUBSCRIPTION_PRICE_CHANGE_CONFIRMED: 8,
    SUBSCRIPTION_DEFERRED: 9,
    SUBSCRIPTION_PAUSED: 10,
    SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED: 11,
    SUBSCRIPTION_REVOKED: 12,
    SUBSCRIPTION_EXPIRED: 13
};

exports.handleGooglePlayWebhook = onRequest({
    region: 'europe-west1'
}, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send('Method Not Allowed');
    }

    const message = req.body?.message;
    if (!message?.data) {
        console.error('No Pub/Sub message found');
        return res.status(400).send('Bad Request');
    }

    let data;
    try {
        data = JSON.parse(Buffer.from(message.data, 'base64').toString('utf-8'));
    } catch (error) {
        console.error('Unable to parse Pub/Sub message', error);
        return res.status(400).send('Invalid message');
    }

    console.log('Google Play Notification:', data);

    const notificationType = data.subscriptionNotification?.notificationType;
    const purchaseToken = data.subscriptionNotification?.purchaseToken;
    const subscriptionId = data.subscriptionNotification?.subscriptionId;

    if (!purchaseToken) {
        return res.status(400).send('No purchase token');
    }

    // 🔧 FIX 11/07/2026 : même trou que handleAppStoreWebhook — _findUserDocsByToken
    // cherchait sur users/{email}, jamais alimenté par android_subscription_service.dart
    // (qui écrit purchaseToken uniquement sur subscriptions/{id}). Résolution directe
    // sur subscriptions à la place.
    let subDocs = [];
    try {
        const byToken = await db.collection('subscriptions')
            .where('platform', '==', 'android')
            .where('purchaseToken', '==', purchaseToken)
            .get();
        subDocs = byToken.docs;
    } catch (err) {
        console.error('❌ handleGooglePlayWebhook: erreur résolution subscriptions:', err);
    }

    if (subDocs.length === 0) {
        console.log('⚠️ handleGooglePlayWebhook: aucun document subscriptions trouvé pour', purchaseToken);
        return res.status(200).send('OK - No subscription found');
    }

    const updates = {
        lastWebhookUpdate: FieldValue.serverTimestamp(),
        lastNotificationType: notificationType,
        subscriptionId
    };

    switch (notificationType) {
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_CANCELED:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_EXPIRED:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_REVOKED:
            updates.subscriptionActive = false;
            updates.subscriptionCancelDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'expired';
            updates.subscriptionStatus = 'canceled';
            updates.status = 'canceled';
            break;
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_RENEWED:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_RECOVERED:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_RESTARTED:
            updates.subscriptionActive = true;
            updates.lastRenewalDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'converted';
            updates.subscriptionStatus = 'active';
            updates.status = 'active';
            break;
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_ON_HOLD:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_PAUSED:
            updates.subscriptionActive = false;
            updates.subscriptionStatus = 'paused';
            break;
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_IN_GRACE_PERIOD:
            updates.subscriptionStatus = 'grace_period';
            break;
    }

    const structureFields = ['subscriptionActive', 'subscriptionStatus', 'trialStatus'];
    const structureUpdates = { lastWebhookUpdate: updates.lastWebhookUpdate, subscriptionUpdatedAt: FieldValue.serverTimestamp() };
    structureFields.forEach((key) => {
        if (key in updates) structureUpdates[key] = updates[key];
    });

    const batch = db.batch();
    const structureIdsToUpdate = new Set();
    subDocs.forEach((doc) => {
        batch.set(doc.ref, updates, { merge: true });
        const sid = doc.data().structureId;
        if (sid) structureIdsToUpdate.add(sid);
    });
    structureIdsToUpdate.forEach((sid) => {
        batch.set(db.collection('structures').doc(sid), structureUpdates, { merge: true });
    });
    await batch.commit();

    console.log(`✅ handleGooglePlayWebhook: ${subDocs.length} subscription(s) et ${structureIdsToUpdate.size} structure(s) mis à jour`, {
        notificationType,
        subscriptionId
    });
    res.status(200).send('OK');
});

// ============================================
// ========== SYNC TOKEN DEPUIS USERS ==========
// ============================================
exports.syncSubscriptionTokenFromUser = onDocumentWritten({
    document: 'users/{userId}',
    region: 'europe-west1'
}, async (event) => {
    const afterSnap = event.data.after;
    if (!afterSnap.exists) return null;

    const beforeData = event.data.before.exists ? event.data.before.data() : {};
    const afterData = afterSnap.data() || {};

    const platform = afterData.subscriptionPlatform;
    if (platform !== 'android' && platform !== 'ios') return null;

    const token = platform === 'android'
        ? afterData.purchaseToken
        : afterData.originalTransactionId;
    if (!token) return null;

    const productId =
        afterData.subscriptionId ||
        afterData.productId ||
        afterData.subscriptionProductId ||
        null;

    const beforeToken = platform === 'android'
        ? beforeData.purchaseToken
        : beforeData.originalTransactionId;

    const beforePlatform = beforeData.subscriptionPlatform;
    const beforeProduct =
        beforeData.subscriptionId ||
        beforeData.productId ||
        beforeData.subscriptionProductId ||
        null;

    // Si rien n'a changé, on ne refait pas l'upsert
    if (beforeToken === token && beforePlatform === platform && beforeProduct === productId) {
        return null;
    }

    await _upsertSubscriptionToken({
        token,
        platform,
        userDocId: event.params.userId,
        userDocPath: afterSnap.ref.path,
        productId
    });

    return null;
});

exports.handleAppStoreWebhook = onRequest({
    region: 'europe-west1',
    memory: '128MiB',
    cpu: 0.08,
    maxInstances: 1,
    minInstances: 0,
    concurrency: 1,
}, async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).send('Method Not Allowed');
    }

    const notification = req.body;
    console.log('App Store Notification:', JSON.stringify(notification, null, 2));

    const notificationType = notification.notification_type || notification.notificationType;
    const receiptInfo = Array.isArray(notification.unified_receipt?.latest_receipt_info)
        ? notification.unified_receipt.latest_receipt_info[0]
        : null;

    const transactionId = receiptInfo?.transaction_id;
    const originalTransactionId = receiptInfo?.original_transaction_id || notification.originalTransactionId;

    if (!originalTransactionId) {
        return res.status(400).send('No transaction ID');
    }

    // 🔧 FIX 11/07/2026 : _findUserDocsByToken cherchait sur users/{email},
    // un modèle de données que le flux d'achat iOS réel (ios_subscription_service.dart)
    // n'alimente jamais — ce webhook ne trouvait donc littéralement JAMAIS aucun
    // compte, pour aucune utilisatrice iOS, depuis toujours. Les notifications de
    // renouvellement/échec/annulation n'étaient donc jamais répercutées dans
    // Firestore. Le vrai modèle de données lu par le reste de l'app est
    // structures/{id} + subscriptions/{id} : on résout donc directement sur
    // subscriptions. originalTransactionId est cherché sur 2 champs :
    // 'originalTransactionId' (nouveaux achats via verifyApplePurchase) et
    // 'transactionId' (achats existants — pour un tout premier achat, StoreKit
    // fixe transactionId == originalTransactionId, donc la valeur déjà stockée
    // reste valable pour matcher les notifications futures de ce même abonnement).
    let subDocs = [];
    try {
        const byOriginal = await db.collection('subscriptions')
            .where('platform', '==', 'ios')
            .where('originalTransactionId', '==', originalTransactionId)
            .get();
        subDocs = byOriginal.docs;

        if (subDocs.length === 0) {
            const byTransaction = await db.collection('subscriptions')
                .where('platform', '==', 'ios')
                .where('transactionId', '==', originalTransactionId)
                .get();
            subDocs = byTransaction.docs;
        }
    } catch (err) {
        console.error('❌ handleAppStoreWebhook: erreur résolution subscriptions:', err);
    }

    if (subDocs.length === 0) {
        console.log('⚠️ handleAppStoreWebhook: aucun document subscriptions trouvé pour', originalTransactionId);
        return res.status(200).send('OK - No subscription found');
    }

    const updates = {
        lastWebhookUpdate: FieldValue.serverTimestamp(),
        lastNotificationType: notificationType,
        transactionId,
        originalTransactionId
    };

    switch (notificationType) {
        case 'CANCEL':
        case 'DID_FAIL_TO_RENEW':
        case 'EXPIRED':
        case 'REFUND':
            updates.subscriptionActive = false;
            updates.subscriptionCancelDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'expired';
            updates.subscriptionStatus = 'canceled';
            updates.status = 'canceled';
            break;
        case 'DID_RENEW':
        case 'INTERACTIVE_RENEWAL':
            updates.subscriptionActive = true;
            updates.lastRenewalDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'converted';
            updates.subscriptionStatus = 'active';
            updates.status = 'active';
            break;
        case 'DID_CHANGE_RENEWAL_PREF':
            updates.subscriptionModified = true;
            break;
        case 'INITIAL_BUY':
            updates.subscriptionActive = true;
            updates.subscriptionStartDate = FieldValue.serverTimestamp();
            updates.subscriptionStatus = 'active';
            updates.status = 'active';
            break;
    }

    // Les champs subscriptionActive/subscriptionStatus/trialStatus doivent aussi
    // être répercutés sur structures/{id} : c'est CE document que le reste de
    // l'app lit réellement pour décider de l'accès, pas le doc subscriptions.
    const structureFields = ['subscriptionActive', 'subscriptionStatus', 'trialStatus'];
    const structureUpdates = { lastWebhookUpdate: updates.lastWebhookUpdate, subscriptionUpdatedAt: FieldValue.serverTimestamp() };
    structureFields.forEach((key) => {
        if (key in updates) structureUpdates[key] = updates[key];
    });

    const batch = db.batch();
    const structureIdsToUpdate = new Set();
    subDocs.forEach((doc) => {
        batch.set(doc.ref, updates, { merge: true });
        const sid = doc.data().structureId;
        if (sid) structureIdsToUpdate.add(sid);
    });
    structureIdsToUpdate.forEach((sid) => {
        batch.set(db.collection('structures').doc(sid), structureUpdates, { merge: true });
    });
    await batch.commit();

    console.log(`✅ handleAppStoreWebhook: ${subDocs.length} subscription(s) et ${structureIdsToUpdate.size} structure(s) mis à jour`, {
        notificationType,
        originalTransactionId
    });
    res.status(200).send('OK');
});

// ============================================
// ===== VÉRIFICATION REÇU APP STORE (IAP) =====
// ============================================
// Corrige un bug critique : ios_subscription_service.dart écrivait
// status:'active' dans Firestore dès qu'un PurchaseStatus.purchased/restored
// arrivait côté client, sans jamais valider le reçu auprès d'Apple (stub TODO
// jamais implémenté). N'importe quel reçu falsifié/rejoué (device jailbreické,
// reçu sandbox en prod) obtenait donc un abonnement actif gratuit. Cette
// fonction est désormais le SEUL endroit qui écrit un abonnement 'active'
// pour la plateforme iOS — via l'Admin SDK, après confirmation d'Apple.

const APPSTORE_SUBSCRIPTION_PLANS = {
    'com.beylet.poppinsApp.subscription.assistante_maternelle': { structureType: 'assistante_maternelle', memberCount: 1, maxMemberCount: 1, priceAmount: 3.99, priceDisplay: '3,99 € / mois' },
    'com.beylet.poppinsApp.subscription.mam_2_membres': { structureType: 'MAM', memberCount: 2, maxMemberCount: 2, priceAmount: 9.99, priceDisplay: '9,99 € / mois' },
    'com.beylet.poppinsApp.subscription.mam_3_membres': { structureType: 'MAM', memberCount: 3, maxMemberCount: 3, priceAmount: 9.99, priceDisplay: '9,99 € / mois' },
    'com.beylet.poppinsApp.subscription.mam_4_membres': { structureType: 'MAM', memberCount: 4, maxMemberCount: 99, priceAmount: 14.99, priceDisplay: '14,99 € / mois' },
};

async function _callAppleVerifyReceipt(url, receiptData, sharedSecret) {
    const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            'receipt-data': receiptData,
            'password': sharedSecret,
            'exclude-old-transactions': true,
        }),
    });
    return resp.json();
}

exports.verifyApplePurchase = onCall({
    region: 'europe-west1',
    secrets: [APPSTORE_SHARED_SECRET],
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Utilisateur non authentifié');
    }

    const { receiptData, productId, transactionId } = request.data || {};
    if (!receiptData || typeof receiptData !== 'string') {
        throw new HttpsError('invalid-argument', 'receiptData manquant');
    }
    const plan = APPSTORE_SUBSCRIPTION_PLANS[productId];
    if (!plan) {
        throw new HttpsError('invalid-argument', `productId inconnu: ${productId}`);
    }

    const sharedSecret = APPSTORE_SHARED_SECRET.value();
    let result = await _callAppleVerifyReceipt('https://buy.itunes.apple.com/verifyReceipt', receiptData, sharedSecret);
    if (result.status === 21007) {
        // Reçu sandbox envoyé par erreur à l'endpoint de prod -> on retente sur sandbox
        result = await _callAppleVerifyReceipt('https://sandbox.itunes.apple.com/verifyReceipt', receiptData, sharedSecret);
    }
    if (result.status !== 0) {
        console.warn(`⚠️ verifyApplePurchase: reçu Apple invalide (status ${result.status}) pour uid ${request.auth.uid}, productId ${productId}`);
        throw new HttpsError('permission-denied', `Reçu Apple invalide (status ${result.status})`);
    }

    const latestInfo = Array.isArray(result.latest_receipt_info)
        ? result.latest_receipt_info
        : (Array.isArray(result.receipt?.in_app) ? result.receipt.in_app : []);
    const matches = latestInfo.filter((tx) => tx.product_id === productId);
    if (matches.length === 0) {
        throw new HttpsError('permission-denied', 'Aucune transaction pour ce productId dans le reçu Apple vérifié');
    }
    matches.sort((a, b) => Number(b.purchase_date_ms || 0) - Number(a.purchase_date_ms || 0));
    const latestTx = matches[0];
    const expiresMs = Number(latestTx.expires_date_ms || 0);
    if (!expiresMs || expiresMs <= Date.now()) {
        throw new HttpsError('permission-denied', 'Abonnement Apple expiré selon le reçu vérifié');
    }

    // Résoudre structureId comme le fait le reste de l'app : users/{email}.structureId, sinon uid
    const email = (request.auth.token?.email || '').toLowerCase();
    let structureId = request.auth.uid;
    if (email) {
        const userDoc = await db.collection('users').doc(email).get();
        const sid = userDoc.exists ? userDoc.data().structureId : null;
        if (sid && String(sid).trim()) structureId = String(sid).trim();
    }

    const finalTransactionId = String(latestTx.transaction_id || transactionId || '');

    // Anti-duplication : cette transaction Apple a-t-elle déjà été enregistrée ?
    if (finalTransactionId) {
        const existing = await db.collection('subscriptions')
            .where('transactionId', '==', finalTransactionId)
            .limit(1)
            .get();
        if (!existing.empty) {
            return { verified: true, alreadyRecorded: true, expiresAt: expiresMs };
        }
    }

    const batch = db.batch();

    // Désactiver les anciens abonnements actifs de cette structure
    const oldActive = await db.collection('subscriptions')
        .where('structureId', '==', structureId)
        .where('status', '==', 'active')
        .get();
    oldActive.forEach((doc) => {
        batch.update(doc.ref, { status: 'replaced', replacedAt: FieldValue.serverTimestamp() });
    });

    const newSubRef = db.collection('subscriptions').doc();
    const purchaseDate = new Date(Number(latestTx.purchase_date_ms) || Date.now());
    batch.set(newSubRef, {
        structureId,
        structureType: plan.structureType,
        memberCount: plan.memberCount,
        maxMemberCount: plan.maxMemberCount,
        status: 'active',
        productId,
        transactionId: finalTransactionId,
        originalTransactionId: latestTx.original_transaction_id || finalTransactionId,
        purchaseDate: purchaseDate.toISOString(),
        expirationDate: new Date(expiresMs).toISOString(),
        expiresAt: Timestamp.fromMillis(expiresMs),
        priceAmount: plan.priceAmount,
        priceDisplay: plan.priceDisplay,
        currency: 'EUR',
        billingPeriod: 'monthly',
        platform: 'ios',
        source: 'app_store',
        verifiedByAppleAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
    });

    batch.set(db.collection('structures').doc(structureId), {
        maxMemberCount: plan.maxMemberCount,
        subscriptionActive: true,
        subscriptionDocId: newSubRef.id,
        subscriptionStatus: 'active',
        subscriptionPlatform: 'ios',
        subscriptionSource: 'app_store',
        trialStatus: 'converted',
        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
        currentPriceAmount: plan.priceAmount,
        currentPriceDisplay: plan.priceDisplay,
    }, { merge: true });

    await batch.commit();

    console.log(`✅ verifyApplePurchase: ${productId} vérifié auprès d'Apple et enregistré pour structure ${structureId} (transaction ${finalTransactionId})`);

    return { verified: true, subscriptionId: newSubRef.id, expiresAt: expiresMs };
});

// ============================================
// ========== NETTOYAGE ABONNEMENTS ===========
// ============================================
exports.dailySubscriptionCheck = onSchedule({
    schedule: 'every 24 hours',
    timeZone: 'Europe/Paris'
}, async () => {
    console.log('Starting daily subscription check...');

    const activeSubscriptions = await db
        .collection('users')
        .where('subscriptionActive', '==', true)
        .get();

    let deactivated = 0;
    const batch = db.batch();

    activeSubscriptions.forEach((doc) => {
        const data = doc.data() || {};
        const lastWebhook = data.lastWebhookUpdate?.toDate
            ? data.lastWebhookUpdate.toDate()
            : null;

        if (lastWebhook) {
            const daysSinceLastWebhook = (Date.now() - lastWebhook.getTime()) / (1000 * 60 * 60 * 24);
            if (daysSinceLastWebhook > 35) {
                batch.update(doc.ref, {
                    subscriptionActive: false,
                    trialStatus: 'expired',
                    deactivationReason: 'no_webhook_update',
                    deactivatedBy: 'daily_check'
                });
                deactivated++;
            }
        }
    });

    if (deactivated > 0) {
        await batch.commit();
        console.log(`Deactivated ${deactivated} stale subscriptions`);
    } else {
        console.log('No stale subscriptions found');
    }
});

exports.cleanupInactiveSubscriptions = onCall({
    region: 'europe-west1'
}, async (request) => {
    // v2 API: request.auth replaces context.auth
    if (!request.auth || !request.auth.token?.admin) {
        throw new HttpsError('permission-denied', 'Must be admin');
    }

    // NOTE: abonnements Stripe/IAP sont stockés sur structures, pas sur users.
    // On cible la bonne collection.
    const activeStructures = await db
        .collection('structures')
        .where('subscriptionActive', '==', true)
        .get();

    const batch = db.batch();
    let updated = 0;

    activeStructures.forEach((doc) => {
        const data = doc.data() || {};
        const lastWebhook = data.lastWebhookUpdate?.toDate
            ? data.lastWebhookUpdate.toDate()
            : null;

        if (!lastWebhook) {
            const startDate = data.subscriptionUpdatedAt?.toDate
                ? data.subscriptionUpdatedAt.toDate()
                : (data.createdAt?.toDate ? data.createdAt.toDate() : null);
            if (startDate && (Date.now() - startDate.getTime()) > (35 * 24 * 60 * 60 * 1000)) {
                batch.update(doc.ref, {
                    subscriptionActive: false,
                    trialStatus: 'expired',
                    deactivationReason: 'manual_cleanup'
                });
                updated++;
            }
        }
    });

    if (updated > 0) {
        await batch.commit();
    }

    return { success: true, deactivated: updated };
});

// ===== INVITATION PARENT AUTOMATIQUE (déclenchée côté serveur) =====
// Se déclenche quand un enfant est créé ou modifié avec un email parent
// Fonctionne pour toutes les versions de l'app, sans rebuild nécessaire
exports.onChildParentEmailSet = onDocumentWritten({
    document: 'structures/{structureId}/children/{childId}',
    region: 'europe-west1',
}, async (event) => {
    if (!event.data.after.exists) return null; // document supprimé

    const afterData = event.data.after.data();
    const beforeData = event.data.before.exists ? event.data.before.data() : {};
    const { structureId, childId } = event.params;

    const childFirstName = (afterData.firstName || 'Enfant').toString();

    // Collecter les emails parents à inviter (parent1 et parent2)
    const parentsToCheck = [];
    for (const key of ['parent1', 'parent2']) {
        const after = afterData[key] || {};
        const before = beforeData[key] || {};
        const emailAfter = (after.email || '').toString().trim().toLowerCase();
        const emailBefore = (before.email || '').toString().trim().toLowerCase();

        // Déclencher seulement si l'email vient d'apparaître ou a changé
        if (emailAfter && emailAfter !== emailBefore) {
            parentsToCheck.push({
                email: emailAfter,
                firstName: (after.firstName || '').toString(),
                lastName: (after.lastName || '').toString(),
            });
        }
    }

    if (parentsToCheck.length === 0) return null;

    // Récupérer le nom de la structure
    let structureName = 'Structure d\'accueil';
    try {
        const structDoc = await db.collection('structures').doc(structureId).get();
        structureName = (structDoc.data() || {}).structureName || structureName;
    } catch (_) {}

    for (const parent of parentsToCheck) {
        const { email, firstName, lastName } = parent;
        console.log(`📧 onChildParentEmailSet: invitation pour ${email} (enfant: ${childFirstName})`);

        try {
            // Garde-fou : si users/{email} existe déjà, ce parent est déjà lié à un compte
            // Poppins (ex: migration d'email self-service qui réécrit parent1/parent2.email) →
            // ne pas ré-inviter un parent déjà lié.
            const existingUserDoc = await db.collection('users').doc(email).get();
            if (existingUserDoc.exists) {
                console.log(`ℹ️ users/${email} existe déjà, parent déjà lié - pas d'invitation créée`);
                continue;
            }

            // Vérifier si une invitation pending existe déjà pour éviter les doublons
            const existing = await db.collection('invitations')
                .where('email', '==', email)
                .where('childId', '==', childId)
                .where('status', '==', 'pending')
                .limit(1)
                .get();

            if (!existing.empty) {
                console.log(`ℹ️ Invitation déjà existante pour ${email} / ${childId}, skip`);
                continue;
            }

            const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

            // Créer l'invitation
            await db.collection('invitations').add({
                email,
                type: 'parent',
                structureId,
                structureName,
                childId,
                childName: childFirstName,
                parentFirstName: firstName,
                parentLastName: lastName,
                status: 'pending',
                createdAt: FieldValue.serverTimestamp(),
                expiresAt: Timestamp.fromDate(expiresAt),
                source: 'onChildParentEmailSet',
            });

            // Mettre en file d'envoi
            await db.collection('emailQueue').add({
                to: email,
                template: 'parent-invitation',
                subject: `Invitation Poppins - Pour ${childFirstName}`,
                status: 'pending',
                createdAt: FieldValue.serverTimestamp(),
                retryCount: 0,
                priority: 'high',
                templateData: {
                    firstName,
                    lastName,
                    childName: childFirstName,
                    childId,
                    structureName,
                    structureId,
                    androidLink: 'https://play.google.com/store/apps/details?id=com.beylet.poppinsapp',
                    iosLink: 'https://apps.apple.com/us/app/poppins/id6744274953',
                    year: new Date().getFullYear().toString(),
                },
            });

            console.log(`✅ Invitation + emailQueue créés pour ${email}`);
        } catch (err) {
            console.error(`❌ Erreur invitation pour ${email}:`, err);
        }
    }

    return null;
});

// ===== ASSISTANT CALCULS IA (chat limité, DeepSeek deepseek-chat) =====
// Mots-clés autorisant l'appel à l'IA (filtre en amont, sans coût)
const CALCUL_ASSISTANT_KEYWORDS = [
    'heure', 'salaire', 'contrat', 'congé', 'conge', 'tarif', 'mensualis',
    'pajemploi', 'indemnit', 'cdi', 'cdd', 'avenant', 'smic', 'brut', 'net',
    'préavis', 'preavis', 'rupture', 'assistante maternelle', 'nounou',
    'garde', 'enfant'
];
// TODO: remettre à 5 avant publication publique — 20 uniquement pour la phase de test interne
const CALCUL_ASSISTANT_MAX_QUESTIONS_PER_DAY = 20;
const CALCUL_ASSISTANT_OFF_TOPIC_MESSAGE =
    'Je ne peux répondre qu\'aux questions liées aux contrats et calculs d\'assistante maternelle.';
const CALCUL_ASSISTANT_NUMBER_VIOLATION_MESSAGE =
    'Je ne peux pas afficher de chiffre ici — utilise l\'écran "Calculer une mensualisation" de ' +
    'l\'application pour obtenir le montant exact et fiable.';

exports.askCalculAssistant = onCall({
    region: 'europe-west1',
    secrets: [DEEPSEEK_API_KEY],
}, async (request) => {
    console.log('🤖 askCalculAssistant appelée');

    // Vérification authentification
    if (!request.auth) {
        console.error('❌ Utilisateur non authentifié');
        throw new HttpsError('unauthenticated', 'Utilisateur non authentifié');
    }

    const { question } = request.data;

    // Validation des données
    if (!question || typeof question !== 'string' || question.trim().length === 0) {
        console.error('❌ Question manquante ou vide');
        throw new HttpsError('invalid-argument', 'La question est requise et ne peut pas être vide');
    }

    if (question.length > 500) {
        console.error('❌ Question trop longue:', question.length);
        throw new HttpsError('invalid-argument', 'La question est trop longue (500 caractères maximum)');
    }

    // Filtre mots-clés en amont (avant tout appel API, pour économiser le coût)
    const normalizedQuestion = question.toLowerCase();
    const isOnTopic = CALCUL_ASSISTANT_KEYWORDS.some((keyword) => normalizedQuestion.includes(keyword));

    if (!isOnTopic) {
        console.log('🚫 Question hors-sujet, aucun appel IA, quota non consommé');
        return { response: CALCUL_ASSISTANT_OFF_TOPIC_MESSAGE };
    }

    const uid = request.auth.uid;
    const today = new Date().toLocaleDateString('fr-FR', { timeZone: 'Europe/Paris' })
        .split('/').reverse().join('-'); // format YYYY-MM-DD
    const usageRef = db.collection('users').doc(uid).collection('aiUsage').doc(today);

    // Rate limiting : transaction Firestore pour éviter les races
    try {
        await db.runTransaction(async (transaction) => {
            const usageDoc = await transaction.get(usageRef);
            const currentCount = usageDoc.exists ? (usageDoc.data().count || 0) : 0;

            if (currentCount >= CALCUL_ASSISTANT_MAX_QUESTIONS_PER_DAY) {
                throw new HttpsError(
                    'resource-exhausted',
                    `Vous avez atteint la limite de ${CALCUL_ASSISTANT_MAX_QUESTIONS_PER_DAY} questions aujourd'hui. Réessayez demain.`
                );
            }

            transaction.set(usageRef, {
                count: currentCount + 1,
                updatedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
        });
    } catch (error) {
        if (error instanceof HttpsError) {
            console.error('❌ Quota atteint:', error.message);
            throw error;
        }
        console.error('❌ Erreur transaction rate limiting:', error);
        throw new HttpsError('internal', 'Erreur lors de la vérification du quota');
    }

    // Appel à l'IA DeepSeek (deepseek-chat)
    try {
        // Le modèle ne doit jamais produire de chiffre/calcul lui-même : le formulaire local de l'app
        // (calcul déterministe) est la seule source fiable. L'IA ne fait qu'expliquer le principe et
        // renvoie vers le formulaire, ce qui évite les erreurs de calcul constatées en test (ex: mauvaise
        // prise en compte des semaines de congés payés en année complète).
        const systemPrompt = "Tu es l'assistant Poppin's, spécialisé UNIQUEMENT dans les contrats, la " +
            "mensualisation, les congés payés, les indemnités et les démarches Pajemploi pour les " +
            "assistantes maternelles en France. Règle stricte : ne donne JAMAIS de chiffre, de formule ni " +
            "de calcul détaillé, même en exemple — tu n'es pas fiable pour les calculs précis. Décris " +
            "seulement le principe en 1 à 2 phrases maximum, puis invite l'utilisateur à utiliser l'écran " +
            "'Calculer une mensualisation' de l'application pour obtenir le chiffre exact et fiable. Si la " +
            "question sort de ce cadre métier, réponds uniquement : 'Je ne peux répondre qu'aux questions " +
            "liées aux contrats et calculs d'assistante maternelle.' Sois très concis (max 80 mots).";

        const deepseekResponse = await fetch('https://api.deepseek.com/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${DEEPSEEK_API_KEY.value()}`,
            },
            body: JSON.stringify({
                model: 'deepseek-chat',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: question },
                ],
                max_tokens: 300,
            }),
        });

        if (!deepseekResponse.ok) {
            const errorBody = await deepseekResponse.text();
            throw new Error(`DeepSeek API a répondu avec le statut ${deepseekResponse.status}: ${errorBody}`);
        }

        const deepseekData = await deepseekResponse.json();
        const aiMessage = deepseekData?.choices?.[0]?.message?.content;

        if (!aiMessage) {
            throw new Error('Réponse DeepSeek vide ou mal formée');
        }

        // Garde-fou serveur : la règle métier interdit tout chiffre/calcul précis dans
        // une réponse IA (seul le formulaire local de mensualisation fait foi). Le
        // system prompt le demande déjà au modèle, mais deepseek-chat n'est pas fiable
        // à 100% sur le respect strict des consignes — on filtre donc aussi côté
        // serveur avant de renvoyer quoi que ce soit au client, plutôt que de ne
        // compter que sur l'instruction textuelle.
        if (/\d/.test(aiMessage)) {
            console.warn(`⚠️ askCalculAssistant: réponse DeepSeek contenait un chiffre malgré la consigne, bloquée avant envoi au client (uid ${uid})`);
            return { response: CALCUL_ASSISTANT_NUMBER_VIOLATION_MESSAGE };
        }

        console.log('✅ Réponse IA générée avec succès');

        return { response: aiMessage };

    } catch (error) {
        console.error('❌ Erreur appel IA DeepSeek:', error);

        // L'appel API a échoué : on rembourse le quota pour ne pas pénaliser l'utilisateur
        try {
            await usageRef.set({
                count: FieldValue.increment(-1),
                updatedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
            console.log('↩️ Quota remboursé suite à l\'échec de l\'appel IA');
        } catch (refundError) {
            console.error('❌ Erreur lors du remboursement du quota:', refundError);
        }

        return { response: 'Service IA temporairement indisponible.' };
    }
});
