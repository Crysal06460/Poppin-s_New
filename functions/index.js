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
    region: 'us-central1',
    memory: '128MiB',
    cpu: 0.08,
    maxInstances: 1,
    minInstances: 0,
    concurrency: 1,
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

async function collectChildMonthlyData({ structureId, childDoc, startDate, endDate }) {
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
                day[collectionName].push({ ...data });
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
        day.horaires.push({ ...data });
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

async function generateMonthlyPdf({ assistant, structureName, period, childrenReports }) {
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

async function enqueueMonthlyEmail({ assistant, structureName, period, pdfBuffer, childCount }) {
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
    'replaced'
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
    const isActiveDoc = activeSubscriptionStatuses.has(status) || (!isTrialDoc && !isInactiveDoc);

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

// Utilitaire : lookup direct via collection subscriptionTokens/{token}
async function _findUserDocsByToken(token, platform) {
    if (!token) return [];

    try {
        const tokenSnap = await db.collection('subscriptionTokens').doc(token).get();
        if (tokenSnap.exists) {
            const tokenData = tokenSnap.data() || {};
            const docPath = tokenData.userDocPath;
            const docId = tokenData.userDocId || tokenData.uid;
            if (docPath) {
                const directDoc = await db.doc(docPath).get();
                if (directDoc.exists) return [directDoc];
            }
            if (docId) {
                const directDoc = await db.collection('users').doc(docId).get();
                if (directDoc.exists) return [directDoc];
            }
        }
    } catch (err) {
        console.error('⚠️ Lookup token direct échoué', err);
    }

    // Fallback : ancienne requête
    try {
        const snapshot = await db
            .collection('users')
            .where('subscriptionPlatform', '==', platform)
            .where(platform === 'android' ? 'purchaseToken' : 'originalTransactionId', '==', token)
            .get();
        return snapshot.docs;
    } catch (err) {
        console.error('⚠️ Lookup token fallback échoué', err);
        return [];
    }
}

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

    const userDocs = await _findUserDocsByToken(purchaseToken, 'android');

    if (!userDocs.length) {
        console.log('No user found with this purchase token');
        return res.status(200).send('OK - No user found');
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
            break;
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_RENEWED:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_RECOVERED:
        case GOOGLE_NOTIFICATION_TYPES.SUBSCRIPTION_RESTARTED:
            updates.subscriptionActive = true;
            updates.lastRenewalDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'converted';
            updates.subscriptionStatus = 'active';
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

    const batch = db.batch();
    userDocs.forEach((doc) => {
        batch.update(doc.ref, updates);
    });
    await batch.commit();

    console.log(`Updated ${userDocs.length} user(s) for Google Play notification`, {
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

    const userDocs = await _findUserDocsByToken(originalTransactionId, 'ios');

    if (!userDocs.length) {
        console.log('No user found with this transaction ID');
        return res.status(200).send('OK - No user found');
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
            updates.subscriptionActive = false;
            updates.subscriptionCancelDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'expired';
            updates.subscriptionStatus = 'canceled';
            break;
        case 'DID_RENEW':
        case 'INTERACTIVE_RENEWAL':
            updates.subscriptionActive = true;
            updates.lastRenewalDate = FieldValue.serverTimestamp();
            updates.trialStatus = 'converted';
            updates.subscriptionStatus = 'active';
            break;
        case 'DID_CHANGE_RENEWAL_PREF':
            updates.subscriptionModified = true;
            break;
        case 'INITIAL_BUY':
            updates.subscriptionActive = true;
            updates.subscriptionStartDate = FieldValue.serverTimestamp();
            updates.subscriptionStatus = 'active';
            break;
    }

    const batch = db.batch();
    userDocs.forEach((doc) => {
        batch.update(doc.ref, updates);
    });
    await batch.commit();

    console.log(`Updated ${userDocs.length} user(s) for App Store notification`, {
        notificationType,
        originalTransactionId
    });
    res.status(200).send('OK');
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
