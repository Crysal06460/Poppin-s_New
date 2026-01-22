/* eslint-disable max-len */
const admin = require("firebase-admin");
const Stripe = require("stripe");

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore"); // AJOUT
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

let stripe;
const PRICE_MAM_2_3 = process.env.PRICE_MAM_2_3 || "price_1SfkUILID2pA5i1C75uu1TCH"; // ID trouvé dans logs ou code user ? Pour l'instant on garde var env ou hardcode si besoin
const PRICE_MAM_4_PLUS = process.env.PRICE_MAM_4_PLUS || "price_1SflCjPpvDnoE6wkfD6BliGn";

/**
 * Returns a lazily initialized Stripe client.
 * @return {Stripe} Stripe client.
 */
function getStripe() {
  if (!stripe) {
    stripe = new Stripe(STRIPE_SECRET_KEY.value());
  }
  return stripe;
}

exports.createCheckoutSession = onRequest(
  {
    region: "europe-west1",
    memory: "512MiB",
    cpu: 1,
    timeoutSeconds: 60,
    cors: true,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (req, res) => {
    try {
      const { priceId, email } = req.body;
      if (!priceId) {
        return res.status(400).send("priceId manquant");
      }

      const session = await getStripe().checkout.sessions.create({
        mode: "subscription",
        customer_email: email,
        line_items: [{ price: priceId, quantity: 1 }],
        subscription_data: {
          trial_period_days: 7,
        },
        allow_promotion_codes: true,
        success_url:
          "https://www.poppin-s.fr/completer_profil/?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "https://www.poppin-s.fr/abonnement-annule",
      });

      return res.json({ url: session.url });
    } catch (error) {
      console.error("createCheckoutSession error:", error);
      return res.status(500).send(error.message);
    }
  },
);

exports.getCheckoutInfo = onCall(
  {
    region: "europe-west1",
    cors: true,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    try {
      const { sessionId } = request.data;
      if (!sessionId) {
        throw new admin.functions.https.HttpsError("invalid-argument", "sessionId manquant");
      }

      const session = await getStripe().checkout.sessions.retrieve(
        sessionId,
        { expand: ["line_items"] },
      );

      const lineItems =
        (session.line_items && session.line_items.data) || [];
      const priceId =
        lineItems[0] && lineItems[0].price && lineItems[0].price.id;

      let structureType = "AssistanteMaternelle";
      if (priceId === PRICE_MAM_2_3 || priceId === PRICE_MAM_4_PLUS) {
        structureType = "MAM";
      }

      return { structureType };
    } catch (error) {
      console.error("getCheckoutInfo error:", error);
      throw new admin.functions.https.HttpsError("internal", error.message);
    }
  },
);

exports.createPortalSession = onRequest(
  {
    region: "europe-west1",
    cors: true,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (req, res) => {
    try {
      const { sessionId } = req.body;
      if (!sessionId) {
        return res.status(400).send("sessionId manquant");
      }

      const checkoutSession = await getStripe().checkout.sessions.retrieve(
        sessionId,
      );

      const returnUrl = "https://www.poppin-s.fr";

      const portalSession = await getStripe().billingPortal.sessions.create({
        customer: checkoutSession.customer,
        return_url: returnUrl,
      });

      return res.json({ url: portalSession.url });
    } catch (error) {
      console.error("createPortalSession error:", error);
      return res.status(500).send(error.message);
    }
  },
);

exports.createWebUser = onRequest(
  { secrets: [STRIPE_SECRET_KEY] },
  async (req, res) => res
    .status(410)
    .json({ error: "createWebUser deprecated, use finalizeStripeSignup" }),
);

exports.checkStripeSubscription = onCall(
  {
    region: "europe-west1",
    cors: true,
    secrets: [STRIPE_SECRET_KEY],
  },
  async (request) => {
    try {
      const { email } = request.data;
      if (!email) {
        throw new admin.functions.https.HttpsError("invalid-argument", "Email manquant");
      }

      const normalizedEmail = email.trim().toLowerCase();
      const db = admin.firestore();

      // 1. Vérifier si un compte existe déjà dans Firebase Auth ou Firestore (Structure)
      // On vérifie d'abord les structures car c'est le plus important
      const structuresSnapshot = await db.collection("structures")
        .where("email", "==", normalizedEmail)
        .limit(1)
        .get();

      if (!structuresSnapshot.empty) {
        // Un compte existe déjà !
        return {
          accountExists: true,
          hasActiveSubscription: false // On met false pour empêcher la redirection vers register si le compte existe déjà
        };
      }

      // 2. Rechercher les clients Stripe par email
      const customers = await getStripe().customers.list({
        email: normalizedEmail,
        limit: 5,
        expand: ['data.subscriptions'],
      });

      let hasActiveSubscription = false;
      let subscriptionData = null;

      // 3. Parcourir les clients et leurs souscriptions
      for (const customer of customers.data) {
        if (customer.subscriptions && customer.subscriptions.data.length > 0) {
          for (const sub of customer.subscriptions.data) {
            if (sub.status === 'active' || sub.status === 'trialing') {
              hasActiveSubscription = true;
              subscriptionData = sub;
              break;
            }
          }
        }
        if (hasActiveSubscription) break;
      }

      if (hasActiveSubscription && subscriptionData) {
        // 4. Déterminer le type de structure via le Price ID
        const lineItems = subscriptionData.items.data;
        const priceId = lineItems[0] && lineItems[0].price && lineItems[0].price.id;

        let structureType = "assistante_maternelle"; // Par défaut (minuscules pour cohérence app)
        if (priceId === PRICE_MAM_2_3 || priceId === PRICE_MAM_4_PLUS) {
          structureType = "mam";
        }

        return {
          accountExists: false,
          hasActiveSubscription: true,
          structureType: structureType
        };
      }

      return {
        accountExists: false,
        hasActiveSubscription: false
      };

    } catch (error) {
      console.error("checkStripeSubscription error:", error);
      throw new admin.functions.https.HttpsError("internal", error.message);
    }
  },
);

exports.stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
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
    ];

    if (subEvents.includes(event.type)) {
      const sub = event.data.object;
      const subId = sub.id;
      const status = sub.status;
      const trialEnd = sub.trial_end;
      const trialStart = sub.trial_start || sub.start_date;
      const periodEnd = sub.current_period_end;

      const trialEndsAtMs = trialEnd ? trialEnd * 1000 : null;
      const trialStartsAtMs = trialStart ? trialStart * 1000 : null;
      const expiresAtMs = periodEnd ? periodEnd * 1000 : null;

      let trialEndsAt = null;
      if (trialEndsAtMs != null) {
        trialEndsAt = admin.firestore.Timestamp.fromMillis(trialEndsAtMs);
      }

      let trialStartsAt = null;
      if (trialStartsAtMs != null) {
        trialStartsAt = admin.firestore.Timestamp.fromMillis(trialStartsAtMs);
      }

      let expiresAt = null;
      if (expiresAtMs != null) {
        expiresAt = admin.firestore.Timestamp.fromMillis(expiresAtMs);
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
      customerEmail = customerEmail.toLowerCase();

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

      try {
        const subscriptionUpdate = {
          status,
          trialEndsAt,
          trialStartedAt: trialStartsAt,
          expiresAt,
          platform: "stripe",
          source: "stripe",
          email: customerEmail, // AJOUT
          stripeCustomerId: sub.customer, // AJOUT
        };

        if (structureId) {
          subscriptionUpdate.structureId = structureId;
        }

        await admin.firestore().collection("subscriptions").doc(subId).set(
          subscriptionUpdate,
          { merge: true },
        );

        let structureDoc = null;
        if (structureId) {
          structureDoc = await admin
            .firestore()
            .collection("structures")
            .doc(structureId)
            .get();
          if (!structureDoc.exists) {
            structureDoc = null;
          }
        }

        if (!structureDoc && customerEmail) {
          const byOwnerEmail = await admin
            .firestore()
            .collection("structures")
            .where("ownerEmail", "==", customerEmail)
            .limit(1)
            .get();
          if (!byOwnerEmail.empty) {
            structureDoc = byOwnerEmail.docs[0];
          } else {
            const byEmail = await admin
              .firestore()
              .collection("structures")
              .where("email", "==", customerEmail)
              .limit(1)
              .get();
            if (!byEmail.empty) {
              structureDoc = byEmail.docs[0];
            }
          }
        }

        if (!structureDoc) {
          const bySubscription = await admin
            .firestore()
            .collection("structures")
            .where("subscriptionDocId", "==", subId)
            .limit(1)
            .get();
          if (!bySubscription.empty) {
            structureDoc = bySubscription.docs[0];
          }
        }

        // 4. (Reverted) On ne crée plus l'utilisateur automatiquement ici.
        // L'utilisateur créera son compte via l'application (CongratulationsScreen).
        // Le webhook se contentera de mettre à jour la souscription, et un mécanisme de sync fera le lien.


        if (structureDoc) {
          const structureRef = structureDoc.ref;
          let trialStatus = "expired";
          if (status === "trialing") {
            trialStatus = "trial";
          } else if (status === "active") {
            trialStatus = "converted";
          }

          await structureRef.set(
            {
              subscriptionStatus: status,
              subscriptionActive,
              subscriptionDocId: subId,
              subscriptionPlatform: "stripe",
              subscriptionSource: "stripe",
              trialStatus,
              subscriptionTrialStartsAt: trialStartsAt,
              subscriptionTrialEndsAt: trialEndsAt,
              trialStartAt: trialStartsAt,
              trialEndsAt: trialEndsAt,
              subscriptionExpiresAt: expiresAt,
            },
            { merge: true },
          );

          if (!structureId) {
            await admin
              .firestore()
              .collection("subscriptions")
              .doc(subId)
              .set(
                { structureId: structureRef.id },
                { merge: true },
              );
          }
        }
      } catch (err) {
        console.error("Erreur mise à jour Stripe webhook :", err);
      }
    }

    return res.json({ received: true });
  },
);

exports.runStripeSync = onRequest(
  {
    secrets: [STRIPE_SECRET_KEY],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (req, res) => {
    const db = admin.firestore();
    const structuresSnapshot = await db.collection("structures").get();
    let updatedCount = 0;
    const logs = [];

    const promises = structuresSnapshot.docs.map(async (doc) => {
      const data = doc.data();
      const subId = data.subscriptionDocId;

      if (!subId || !subId.startsWith("sub_")) return;

      try {
        // Récupération de la souscription Stripe
        const sub = await getStripe().subscriptions.retrieve(subId);

        // Extraction des dates (logique identique au webhook)
        const trialEnd = sub.trial_end;
        const trialStart = sub.trial_start || sub.start_date;
        const periodEnd = sub.current_period_end;

        const trialEndsAtMs = trialEnd ? trialEnd * 1000 : null;
        const trialStartsAtMs = trialStart ? trialStart * 1000 : null;
        const expiresAtMs = periodEnd ? periodEnd * 1000 : null;

        let trialEndsAt = null;
        if (trialEndsAtMs != null) {
          trialEndsAt = admin.firestore.Timestamp.fromMillis(trialEndsAtMs);
        }

        let trialStartsAt = null;
        if (trialStartsAtMs != null) {
          trialStartsAt =
            admin.firestore.Timestamp.fromMillis(trialStartsAtMs);
        }

        let expiresAt = null;
        if (expiresAtMs != null) {
          expiresAt = admin.firestore.Timestamp.fromMillis(expiresAtMs);
        }

        const subscriptionActive =
          sub.status === "active" || sub.status === "trialing";

        let trialStatus = "expired";
        if (sub.status === "trialing") {
          trialStatus = "trial";
        } else if (sub.status === "active") {
          trialStatus = "converted";
        }

        // Mise à jour de la structure
        await doc.ref.set(
          {
            subscriptionStatus: sub.status,
            subscriptionActive,
            trialStatus,
            subscriptionTrialStartsAt: trialStartsAt,
            subscriptionTrialEndsAt: trialEndsAt,
            trialStartAt: trialStartsAt,
            trialEndsAt: trialEndsAt,
            subscriptionExpiresAt: expiresAt,
          },
          { merge: true },
        );

        // Mise à jour de la collection subscriptions
        await db.collection("subscriptions").doc(subId).set(
          {
            status: sub.status,
            trialEndsAt,
            trialStartedAt: trialStartsAt,
            expiresAt,
            platform: "stripe",
            source: "stripe",
            structureId: doc.id,
          },
          { merge: true },
        );

        updatedCount++;
        logs.push(`Updated ${doc.id} (Sub: ${subId})`);
      } catch (error) {
        console.error(`Error updating structure ${doc.id}:`, error.message);
        logs.push(`Error ${doc.id}: ${error.message}`);
      }
    });

    await Promise.all(promises);

    return res.json({
      success: true,
      updated: updatedCount,
      details: logs,
    });
  },
);

exports.onStructureCreated = onDocumentCreated(
  {
    document: "structures/{structureId}",
    secrets: [STRIPE_SECRET_KEY],
    region: "europe-west1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }
    const data = snapshot.data();
    const structureId = event.params.structureId;
    const email = data.email;

    if (!email) {
      console.log(`Structure ${structureId} created without email.`);
      return;
    }

    console.log(`Structure ${structureId} created for ${email}. Checking for orphan subscriptions...`);

    const db = admin.firestore();
    // Chercher une souscription Stripe existante par email qui n'est pas encore liée
    // Note: "where structureId == null" peut nécessiter un index ou échouer si le champ n'existe pas.
    // Alternative plus sûre si pas d'index: chercher par email et filtrer en mémoire

    let foundSubDoc = null;
    // Fallback: chercher par email tout court
    const allSubs = await db.collection("subscriptions").where("email", "==", email).limit(5).get();
    for (const doc of allSubs.docs) {
      const subData = doc.data();
      if (!subData.structureId) {
        foundSubDoc = doc;
        break;
      }
    }

    if (foundSubDoc) {
      console.log(`✅ Subscription found: ${foundSubDoc.id}. Linking to structure ${structureId}...`);

      const subData = foundSubDoc.data();
      const trialStatus = subData.status === "trialing" ? "trial" : (subData.status === "active" ? "converted" : "expired");
      const subscriptionActive = subData.status === "active" || subData.status === "trialing";

      // 1. Mettre à jour la structure
      await snapshot.ref.set({
        subscriptionDocId: foundSubDoc.id,
        subscriptionStatus: subData.status || "unknown",
        subscriptionActive: subscriptionActive,
        trialStatus: trialStatus,
        subscriptionPlatform: "stripe",
        subscriptionSource: "stripe",
        // On copie les dates si dispos
        subscriptionTrialStartsAt: subData.trialStartedAt || null,
        subscriptionTrialEndsAt: subData.trialEndsAt || null,
        trialStartAt: subData.trialStartedAt || null,
        trialEndsAt: subData.trialEndsAt || null,
        subscriptionExpiresAt: subData.expiresAt || null,
      }, { merge: true });

      // 2. Mettre à jour la souscription
      await foundSubDoc.ref.set({
        structureId: structureId,
      }, { merge: true });

      console.log(`🔗 Link successful between ${structureId} and ${foundSubDoc.id}`);
    } else {
      console.log(`No orphan subscription found for ${email}.`);
    }
  },
);

exports.updateUserEmail = onCall(
  {
    region: "europe-west1",
    cors: true,
    secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async (request) => {
    if (!request.auth) {
      throw new admin.functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié.",
      );
    }

    const oldEmail = request.auth.token.email;
    const { newEmail } = request.data;

    if (!newEmail || !oldEmail) {
      throw new admin.functions.https.HttpsError(
        "invalid-argument",
        "Email manquant.",
      );
    }

    const normalizedNewEmail = newEmail.trim().toLowerCase();
    const normalizedOldEmail = oldEmail.trim().toLowerCase();

    if (normalizedOldEmail === normalizedNewEmail) {
      return { success: true, message: "Aucun changement nécessaire." };
    }

    const db = admin.firestore();

    try {
      // 1. Vérif collision Auth
      try {
        await admin.auth().getUserByEmail(normalizedNewEmail);
        throw new admin.functions.https.HttpsError(
          "already-exists",
          "Cette adresse email est déjà utilisée.",
        );
      } catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
      }

      // 2. Mise à jour Auth
      await admin.auth().updateUser(request.auth.uid, {
        email: normalizedNewEmail,
        emailVerified: false,
      });

      console.log(`[EmailMigration] Auth updated: ${normalizedOldEmail} -> ${normalizedNewEmail}`);

      // 3. Migration Firestore (Batch)
      const batch = db.batch();

      // A. Migration User Doc
      const oldUserRef = db.collection("users").doc(normalizedOldEmail);
      const newUserRef = db.collection("users").doc(normalizedNewEmail);
      const oldUserDoc = await oldUserRef.get();

      if (oldUserDoc.exists) {
        batch.set(newUserRef, {
          ...oldUserDoc.data(),
          email: normalizedNewEmail,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          previousEmail: normalizedOldEmail,
        });
        batch.delete(oldUserRef);
      }

      // B. Structures (Owner & Contact)
      const structuresOwner = await db.collection("structures").where("ownerEmail", "==", normalizedOldEmail).get();
      structuresOwner.docs.forEach(doc => batch.update(doc.ref, { ownerEmail: normalizedNewEmail }));

      const structuresContact = await db.collection("structures").where("email", "==", normalizedOldEmail).get();
      structuresContact.docs.forEach(doc => batch.update(doc.ref, { email: normalizedNewEmail }));

      // C. Members
      const members = await db.collectionGroup("members").where("email", "==", normalizedOldEmail).get();
      members.docs.forEach(doc => batch.update(doc.ref, { email: normalizedNewEmail }));

      // D. Children (Parent Email)
      const children = await db.collectionGroup("children").where("parentEmail", "==", normalizedOldEmail).get();
      children.docs.forEach(doc => batch.update(doc.ref, { parentEmail: normalizedNewEmail }));

      // E. Subscriptions
      const subscriptions = await db.collection("subscriptions").where("email", "==", normalizedOldEmail).get();
      subscriptions.docs.forEach(doc => batch.update(doc.ref, { email: normalizedNewEmail }));

      // F. Invitations
      const invitations = await db.collection("invitations").where("email", "==", normalizedOldEmail).get();
      invitations.docs.forEach(doc => batch.update(doc.ref, { email: normalizedNewEmail }));

      await batch.commit();

      return { success: true };

    } catch (error) {
      console.error("[EmailMigration] Error:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);
