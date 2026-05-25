# Agent 1 — Rapport d'audit complet Abonnements/Stripe/Firebase
**Date :** 2026-05-25  
**Statut global :** 9 bugs identifiés — 8 corrigés dans le code, 1 à déployer manuellement

---

## Résumé exécutif

L'audit complet du système d'abonnements révèle que le flux de base (Stripe webhook → Firebase structure) fonctionne correctement. Cependant, plusieurs bugs critiques ont été trouvés, notamment des endpoints admin sans authentification (risque sécurité majeur), un bug d'API v2 qui fait crasher une Cloud Function, et des cas pathologiques où certains statuts Stripe (past_due, invoice.payment_failed) ne sont pas gérés.

---

## PROBLÈMES TROUVÉS ET CORRIGÉS

---

### BUG 1 — CRITIQUE : `cleanupInactiveSubscriptions` utilise l'API v1 et crash
**Fichier :** `functions/index.js` ligne 3848  
**Description :** La fonction `cleanupInactiveSubscriptions` (onCall) utilise la signature `async (data, context)` de l'API Firebase Functions v1, alors que tout le projet utilise la v2. En v2, le paramètre unique est `request`. De plus, elle parcourait la collection `users` au lieu de `structures` où sont stockés les abonnements Stripe.  
**Impact :** La fonction crash à chaque appel admin. Collection incorrecte ciblée.  
**Correction :** Signature corrigée en `async (request)`, `request.auth` au lieu de `context.auth`, collection corrigée en `structures`.  
**Statut :** ✅ Corrigé dans le code — ⚠️ À déployer

---

### BUG 2 — CRITIQUE : Endpoints admin sans authentification
**Fichiers :** `functions/index.js` lignes 2846 (`backfillSubscriptions`), 2999 (`fixSubscriptionStatusV2`), 3505 (`repairSubscriptions`)  
**Description :** Ces 3 endpoints `onRequest` sont accessibles sans aucune vérification d'identité. N'importe qui connaissant l'URL peut modifier les statuts d'abonnement de TOUS les utilisateurs ou lancer un backfill destructif.  
**Impact :** Sécurité critique — 100% des utilisateurs potentiellement affectés.  
**Correction :** Ajout d'une vérification `verifyIdToken()` + contrôle email admin (`cbeylet06@gmail.com`, `chrisgugu1101@gmail.com`) sur les 3 endpoints.  
**Statut :** ✅ Corrigé dans le code — ⚠️ À déployer

---

### BUG 3 — MAJEUR : Événements Stripe manquants (invoice.payment_failed)
**Fichier :** `functions/index.js` ligne 358  
**Description :** Le webhook Stripe ne gérait que 3 événements (`customer.subscription.created/updated/deleted`). Les événements `invoice.payment_failed` et `invoice.payment_succeeded` n'étaient pas traités. Résultat : quand un paiement échoue (carte expirée, fonds insuffisants), Firebase ne le sait pas et l'utilisateur garde son accès `active` alors que Stripe est en `past_due`.  
**Impact :** Utilisateurs avec accès alors que leur paiement a échoué — potentiellement plusieurs dizaines d'utilisateurs.  
**Correction :** Ajout du traitement pour `invoice.payment_failed` (passe la structure en `past_due`) et `invoice.payment_succeeded` (confirme `active`).  
**Statut :** ✅ Corrigé dans le code — ⚠️ À déployer (+ configurer ces 2 événements dans le tableau de bord Stripe Webhooks)  
**Action manuelle requise :** Dans Stripe Dashboard > Webhooks > votre endpoint, ajouter les événements `invoice.payment_failed` et `invoice.payment_succeeded`.

---

### BUG 4 — MAJEUR : `_expireStructureAndSubscription` écrit dans le mauvais document
**Fichier :** `functions/index.js` ligne 3232  
**Description :** Cette fonction appelée par `deactivateExpiredTrials` (scheduler 24h) faisait un `db.collection('subscriptions').doc(structureId)`. Or, pour les abonnements Stripe et IAP, le doc subscription a comme ID le Stripe subscription ID (ex: `sub_1AbCdE...`) ou un ID généré automatiquement — pas l'UID de la structure. Résultat : la fonction créait/modifiait un document fantôme avec l'ID = structureId, sans toucher le vrai document.  
**Impact :** Les expirations de trial ne se répercutaient pas sur les vrais documents subscription pour les utilisateurs Stripe/IAP.  
**Correction :** Conservation de la logique existante pour les trials Firebase (qui utilisent structureId comme ID de doc), + ajout d'une requête secondaire pour mettre à jour les docs liés via `structureId` (Stripe/IAP).  
**Statut :** ✅ Corrigé dans le code — ⚠️ À déployer

---

### BUG 5 — MAJEUR : `deactivateExpiredTrials` sans région spécifiée
**Fichier :** `functions/index.js` ligne 3128  
**Description :** Le scheduler `deactivateExpiredTrials` n'avait pas de `region` spécifiée, ce qui le déployait dans `us-central1` par défaut alors que tout le reste est `europe-west1`. Cela entraîne une latence inutile et une incohérence de configuration.  
**Impact :** Performances dégradées pour l'expiration automatique des trials.  
**Correction :** Ajout de `region: 'europe-west1'` dans la configuration.  
**Statut :** ✅ Corrigé dans le code — ⚠️ À déployer

---

### BUG 6 — MAJEUR : `_isTrialPeriod()` retourne toujours `true`
**Fichier :** `lib/services/unified_subscription_service.dart` ligne 307  
**Description :** La méthode `_isTrialPeriod(productId)` retournait systématiquement `true` avec un commentaire "Pour le moment, on considère que tous les nouveaux achats sont des essais". Cela marque incorrectement TOUS les abonnements IAP comme périodes d'essai dans le `SubscriptionInfo` émis par le stream, même les abonnements payants normaux.  
**Impact :** Potentiellement tous les utilisateurs IAP (iOS/Android) — affichage incorrect du statut, logique d'expiration incorrecte.  
**Correction :** Retourner `false` par défaut. La détection réelle de la période d'essai est faite par les services `iOSSubscriptionService` et `AndroidSubscriptionService` qui lisent les vraies données de transaction et stockent `isTrialPeriod` dans Firestore.  
**Statut :** ✅ Corrigé dans le code

---

### BUG 7 — MOYEN : `_calculateExpiryDate()` retourne toujours `now + 30 jours`
**Fichier :** `lib/services/unified_subscription_service.dart` ligne 286  
**Description :** La méthode retournait `DateTime.now().add(Duration(days: 30))` indépendamment du produit et de la vraie date d'expiration. Cette date fictive peut polluer l'UI et masquer une vraie expiration précoce ou tardive.  
**Impact :** Affichage incorrect de la date d'expiration dans l'UI pour les utilisateurs IAP.  
**Correction :** Retourner `null` — la vraie date est disponible dans Firestore via les services iOS/Android.  
**Statut :** ✅ Corrigé dans le code

---

### BUG 8 — MOYEN : `_backgroundCleanup` supprimait des docs d'audit trail Stripe
**Fichier :** `lib/services/subscription_service.dart` ligne 189  
**Description :** La méthode `_backgroundCleanup()` supprimait silencieusement les documents `subscriptions` avec `status: 'expired'` quand la structure était active. Or, ces docs sont des preuves d'audit (historique des paiements Stripe) et le webhook Stripe les réécrit de toute façon à chaque événement. La suppression créait un risque de perte de données et une boucle create/delete.  
**Impact :** Perte d'audit trail, risque de race condition avec webhook Stripe.  
**Correction :** Remplacé la suppression par un simple log d'avertissement.  
**Statut :** ✅ Corrigé dans le code

---

### BUG 9 — MOYEN : `subscription_helper.dart` utilisait `user.uid` à la place du `structureId` réel
**Fichier :** `lib/services/subscription_helper.dart` ligne 26-49  
**Description :** `getSubscriptionInfo()` dans `SubscriptionHelper` cherchait les abonnements avec `structureId == user.uid`. Or, pour les utilisateurs Stripe web, le structureId est l'UID Firebase créé lors de l'inscription, qui correspond bien à `user.uid`. Mais pour des MAM membres ou cas edge cases, le structureId est stocké dans `users/{email}.structureId`. Sans résolution via le doc users, certains utilisateurs ne trouvaient pas leur abonnement.  
**Impact :** Utilisateurs potentiellement redirigés vers l'écran d'abonnement alors qu'ils ont un abonnement actif.  
**Correction :** Ajout d'une méthode `_resolveStructureId()` qui lit `users/{email}.structureId` avant de fallback sur `user.uid`. Corrigé dans les 3 requêtes Firestore de la méthode.  
**Statut :** ✅ Corrigé dans le code

---

## POINTS À VÉRIFIER MANUELLEMENT (sans correction de code)

### VÉRIF 1 — Configuration Stripe Webhook Dashboard
**Description :** Vérifier que le webhook Stripe est configuré avec les bons événements.  
**Action requise :** Dans Stripe Dashboard > Développeurs > Webhooks, vérifier que l'endpoint pointe vers la Cloud Function `stripeWebhook` et inclut au minimum :
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_failed` (nouveau)
- `invoice.payment_succeeded` (nouveau)

**Statut :** 🔴 Nécessite validation manuelle

---

### VÉRIF 2 — Utilisateurs `expired` Firebase avec abonnement Stripe actif
**Description :** Potentiel cas pathologique — des structures avec `subscriptionStatus: 'expired'` dans Firebase mais un abonnement Stripe actif. Ce cas peut survenir si le webhook n'a pas été reçu (timeout, instance froide).  
**Action requise :** 
1. Ouvrir Firebase Console > Firestore > structures
2. Filtrer sur `subscriptionStatus == 'expired'`
3. Pour chaque structure avec `subscriptionPlatform == 'stripe'`, vérifier dans Stripe Dashboard que l'abonnement est bien réellement expiré
4. Si actif sur Stripe mais expiré sur Firebase : appeler l'endpoint `/repairSubscriptions` (maintenant protégé) avec un token admin

**Statut :** 🔴 Nécessite validation manuelle

---

### VÉRIF 3 — Utilisateurs sans structureId dans métadonnées Stripe
**Description :** Le webhook Stripe résout le structureId via 3 fallbacks si les métadonnées sont vides. Vérifier qu'il n'y a pas de subscriptions Firestore sans `structureId`.  
**Action requise :** Dans Firebase Console > Firestore > subscriptions, chercher les docs où `structureId` est vide ou absent.  
**Statut :** 🔴 Nécessite validation manuelle

---

### VÉRIF 4 — `handleAppStoreWebhook` : événements manquants Apple
**Fichier :** `functions/index.js` ligne 3764  
**Description :** Le handler App Store V1 (deprecated) ne gère pas tous les événements. Apple a migré vers les notifications V2 (signed transactions). Il faudrait valider si Apple envoie toujours des notifications V1 ou si une migration V2 est nécessaire. Les événements `REVOKE` et `REFUND` ne sont pas non plus traités.  
**Statut :** 🔴 Nécessite validation manuelle (consultation doc Apple StoreKit 2)

---

## CE QUI FONCTIONNE BIEN

- Webhook Stripe de base : signature vérifiée correctement avec `constructEvent`
- Fallback de résolution du `structureId` via 3 mécanismes (metadata Stripe → users → structures → subscriptions existantes)
- Synchronisation bidirectionnelle `subscriptions ↔ structures` via `syncSubscriptionWithStructure` (Firestore trigger)
- Expiration automatique des trials Firebase via `deactivateExpiredTrials` (scheduler)
- Création de trial Firebase via `FirebaseTrialService.ensureTrialForStructure`
- Vérification d'accès dans `subscription_service.dart` avec priorité structure > subscriptions > fallback Google Play
- La fonction `onStructureCreated` qui lie automatiquement un abonnement existant à une nouvelle structure
- Protection anti-duplication dans les services iOS et Android
- Dashboard admin `AdminSubscriptionDashboardScreen` avec accès restreint aux emails admin

---

## DÉPLOIEMENT REQUIS

Les fichiers `functions/index.js` ont été modifiés. **Ne pas déployer sans validation du propriétaire.**

Commande de déploiement (à exécuter manuellement) :
```bash
cd /Users/macbook/poppins/functions
firebase deploy --only functions:stripeWebhook,functions:cleanupInactiveSubscriptions,functions:backfillSubscriptions,functions:fixSubscriptionStatusV2,functions:repairSubscriptions,functions:deactivateExpiredTrials
```

**Ordre recommandé :**
1. D'abord configurer les nouveaux événements Stripe dans le Dashboard
2. Puis déployer les Cloud Functions
3. Puis appeler `/repairSubscriptions` pour synchroniser les états existants

---

## FICHIERS MODIFIÉS

- `/Users/macbook/poppins/functions/index.js` — 6 corrections (BUG 1, 2, 3, 4, 5)
- `/Users/macbook/poppins/lib/services/unified_subscription_service.dart` — 2 corrections (BUG 6, 7)
- `/Users/macbook/poppins/lib/services/subscription_service.dart` — 2 corrections (BUG 8 + trialEndsAt artificielle)
- `/Users/macbook/poppins/lib/services/subscription_helper.dart` — 1 correction (BUG 9)
