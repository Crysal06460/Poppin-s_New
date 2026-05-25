# Audit Général — Poppins App

## Résumé
- 2 problèmes critiques 🔴
- 4 problèmes importants 🟠
- 6 problèmes mineurs 🟡

---

## 🔴 Critiques

### [ROUTE MANQUANTE] La route `/pricing` est commentée dans routes.dart
- **Fichier :** `lib/routes.dart` lignes 312–333
- **Description :** `GoRoute(path: '/pricing', ...)` était dans un bloc `/* ... */`. Or, 6 fichiers de production font `context.go('/pricing')` : `dashboard_screen.dart`, `auth_check_screen.dart`, `splash_screen.dart`, `home_screen.dart`, et `demo_mode_banner.dart` (x2).
- **Impact :** Tout utilisateur dont l'abonnement est expiré ou inexistant tombe sur l'écran d'erreur "Page non trouvée" au lieu de voir l'écran de tarification. Ces utilisateurs ne peuvent pas s'abonner.
- **Correction appliquée ✅** : La route `/pricing` a été décommentée. `PricingScreen` était déjà importé dans `routes.dart`.

### [SÉCURITÉ] L'écran `/admin` est accessible à tout utilisateur connecté
- **Fichier :** `lib/routes.dart` ligne 309, `lib/screens/admin_screen.dart`
- **Description :** La route `/admin` ne vérifie pas le rôle de l'utilisateur avant de rendre `AdminScreen`. N'importe quel utilisateur authentifié (même un parent) peut naviguer vers `/admin` et lancer la fonction "Corriger les relations parent-enfant" qui fait des lectures/écritures sur TOUTES les structures (`structures` collection entière).
- **Impact :** Un utilisateur malveillant peut corrompre les données parent-enfant de toutes les structures.
- **Correction à faire ⚠️** : Ajouter un guard dans le builder de `/admin` :
  ```dart
  builder: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    const adminEmails = {'cbeylet06@gmail.com', 'chrisgugu1101@gmail.com'};
    if (user == null || !adminEmails.contains(user.email?.toLowerCase())) {
      return const Scaffold(body: Center(child: Text('Accès réservé')));
    }
    return const AdminScreen();
  },
  ```

---

## 🟠 Importants

### [CLOUD FUNCTIONS] `throw new Error()` au lieu de `throw new HttpsError()` dans les fonctions onCall
- **Fichiers :** `functions/index.js` — fonctions `sendEmailToParent` (lignes 601, 628, 739), `acceptDelegation` (1023, 1026, 1042, 1045, 1058), `declineDelegation` (1113, 1115, 1118, 1129), `cancelDelegation` (1135, 1137, 1140, 1151)
- **Description :** Les fonctions Cloud `onCall` doivent jeter `new HttpsError(code, message)` pour propager correctement le code d'erreur au SDK Flutter/Dart. Jeter `new Error('unauthenticated')` retourne au client une erreur générique sans code exploitable.
- **Impact :** Les erreurs d'auth, de permission et de validation sont traitées côté Flutter comme des erreurs génériques "internal". Impossible de distinguer "non authentifié" de "données invalides". Le débogage est difficile en production.
- **Correction appliquée ✅** : Toutes les occurrences ont été remplacées par `new HttpsError(code, message)` dans les 4 fonctions concernées.

### [SÉCURITÉ] Fallback "30 jours d'inactivité" dans `isUserSubscribed`
- **Fichier :** `lib/services/subscription_service.dart` lignes 161–178
- **Description :** Si aucun abonnement Firestore ni Google Play n'est trouvé, la fonction retourne `true` si l'utilisateur a un champ `hadActiveSubscription: true` et a été actif dans les 30 derniers jours. Ce champ est écrit côté client (ligne 456-461 du même fichier).
- **Impact :** Un utilisateur dont l'abonnement est réellement expiré garde accès jusqu'à 30 jours après expiration. Pire, le champ `hadActiveSubscription` est modifiable via les règles Firestore actuelles (les structures sont en `allow write: if isSignedIn()`).
- **Correction à faire ⚠️** : Supprimer ou désactiver ce fallback. La vérification doit être exclusive sur Firestore `structures/{id}.subscriptionStatus` (déjà vérifiée en priorité 1). Si la structure n'a pas d'abonnement actif, rediriger vers `/pricing`.

### [SÉCURITÉ] Vérification serveur des achats in-app non implémentée (TODO critique)
- **Fichiers :**
  - `lib/services/subscription_service.dart` ligne 717 — TODO "Vérifier l'achat avec votre serveur backend"
  - `lib/services/ios_subscription_service.dart` lignes 168, 531
  - `lib/services/unified_subscription_service.dart` lignes 259, 266
- **Description :** La validation cryptographique des reçus Apple App Store / Google Play n'est pas implémentée. L'app accepte tout achat marqué `purchased` ou `restored` sans vérification serveur.
- **Impact :** Un utilisateur avec un outil de manipulation du trafic réseau ou un jailbreak peut simuler un achat réussi sans payer.
- **Correction à faire ⚠️** : Implémenter la vérification serveur dans une Cloud Function. Apple : POST `https://buy.itunes.apple.com/verifyReceipt`. Google Play : utiliser l'API `androidpublisher.purchases.subscriptions.get`. Le reçu côté client est dans `purchase.verificationData.serverVerificationData`.

### [VARIABLE GLOBALE] `_abacusClickCount` déclaré deux fois dans dashboard_screen.dart
- **Fichier :** `lib/screens/dashboard_screen.dart` lignes 41 et 78 (avant correction)
- **Description :** Une variable globale `int _abacusClickCount = 0;` était déclarée au niveau du fichier ET comme variable d'instance dans `_DashboardScreenState`. Le code interne utilise `_abacusClickCount++` sans préfixe, donc il utilise la variable d'instance, mais la variable globale existe inutilement et peut prêter à confusion.
- **Correction appliquée ✅** : La déclaration globale a été supprimée.

---

## 🟡 Mineurs

### [IMPORT DUPLIQUÉ] `cloud_firestore` importé deux fois dans routes.dart
- **Fichier :** `lib/routes.dart` lignes 4 et 72 (avant correction)
- **Description :** `import 'package:cloud_firestore/cloud_firestore.dart';` apparaissait deux fois.
- **Correction appliquée ✅** : La seconde occurrence (ligne 72) a été supprimée.

### [IMPORT DUPLIQUÉ] `child_removal_screen.dart` importé deux fois dans dashboard_screen.dart
- **Fichier :** `lib/screens/dashboard_screen.dart` lignes 13 et 22 (avant correction)
- **Correction appliquée ✅** : Le doublon supprimé.

### [PUBSPEC] `mockito` et `build_runner` déclarés en doublon (dependencies ET dev_dependencies)
- **Fichier :** `pubspec.yaml` lignes 46-47 (dependencies) et 82-83 (dev_dependencies)
- **Description :** Ces packages de test étaient dans les `dependencies` de production ET dans les `dev_dependencies`. Cela les inclut dans le build de release, augmentant inutilement la taille de l'app.
- **Correction appliquée ✅** : Supprimés des `dependencies` de production ; ils restent uniquement en `dev_dependencies`.

### [ROUTES COMMENTÉES] Routes commentées mais encore référencées dans `absolutelyPublicRoutes`
- **Fichier :** `lib/routes.dart` lignes 972–983
- **Description :** Les routes `/trial-info`, `/structure-details`, `/subscription-confirmed` sont listées dans `absolutelyPublicRoutes` mais leur `GoRoute` correspondant est commenté. Elles ne causeront pas de crash (la liste est juste informative pour le redirect), mais c'est trompeur.
- **Correction à faire ⚠️** : Retirer les routes mortes de `absolutelyPublicRoutes` ou décommenter les GoRoutes.

### [RÈGLES FIRESTORE] Collection `subscriptions` trop permissive
- **Fichier :** `firestore.rules` lignes 41-45
- **Description :** `allow read: if isSignedIn()` sur `/subscriptions/{docId}` permet à n'importe quel utilisateur connecté de lire TOUS les abonnements de TOUTES les structures. Un utilisateur peut lire l'abonnement d'une autre structure.
- **Correction à faire ⚠️** : Restreindre la lecture :
  ```
  allow read: if isSignedIn() && (
    resource.data.structureId == request.auth.uid ||
    resource.data.email == request.auth.token.email
  );
  ```

### [NOTIFICATION SERVICE] Définition dupliquée de `firebaseMessagingBackgroundHandler`
- **Fichier :** `lib/services/notification_service.dart` lignes 20 (top-level) et 851 (méthode static)
- **Description :** Le handler de fond est défini deux fois : une fois au niveau global (utilisé dans `main.dart` via `FirebaseMessaging.onBackgroundMessage`) et une fois comme méthode statique inutilisée dans la classe. La méthode statique (ligne 851) ne fait rien (juste un print) et n'est jamais appelée.
- **Correction à faire ⚠️** : Supprimer la méthode statique `firebaseMessagingBackgroundHandler` de la classe `NotificationService` (ligne 850-855). Seul le handler top-level doit exister.

---

## Récapitulatif des corrections appliquées

| Fichier | Correction |
|---|---|
| `lib/routes.dart` | Route `/pricing` décommentée |
| `lib/routes.dart` | Import dupliqué `cloud_firestore` supprimé |
| `lib/screens/dashboard_screen.dart` | Import dupliqué `child_removal_screen` supprimé |
| `lib/screens/dashboard_screen.dart` | Variable globale `_abacusClickCount` supprimée |
| `pubspec.yaml` | `mockito` + `build_runner` retirés des `dependencies` de prod |
| `functions/index.js` | `throw new Error()` → `throw new HttpsError()` dans 4 fonctions Cloud |
