# Session courante — Poppins App

**Dernière mise à jour :** 2026-07-02 (session chrisbeylet@gmail.com, longue session)
**Statut global :** ✅ Fix changement d'email + ✅ Feature Remplacement déployés en prod (backend) — ✅ 5 correctifs UI/texte + FAQ complète 12 écrans faits mais **NON COMMITÉS** — ✅ Build Android 2.1.7+2061 prêt — 🔧 Build iOS bloqué côté compte Apple (Christophe s'en occupe) — ⚠️ Bug "Aide flottante" du 23/06 **RÉSOLU**

---

## 🆕 Feature "Remplacement" — accès délégué temporaire (02/07/2026) — ✅ DÉPLOYÉ (backend)

### Origine
Une utilisatrice (Marianne) part en congé maternité et voulait donner accès à sa remplaçante sans partager son mot de passe ni supprimer son compte. En creusant, on a découvert que le bouton "changer d'email" existant dans les paramètres était **cassé en prod depuis un moment** (appelait une Cloud Function `updateUserEmail` inexistante/orpheline).

### Architecture retenue
La remplaçante s'authentifie avec **son propre mot de passe** (jamais celui de la propriétaire). Si une fenêtre de dates est active, la Cloud Function `activateRemplacementSession` lui délivre un **custom token Firebase Admin SDK pour l'UID de la propriétaire** → elle devient littéralement l'UID propriétaire côté Firestore. Conséquence : **aucune modification de `firestore.rules`** nécessaire (y compris pour `engagements_reciproques/contrats_cdi/contrats_cdd` qui exigent `request.auth.uid == userId` exactement).

### Fichiers clés
- Backend (`functions/index.js`) : `createRemplacement`, `activateRemplacementSession`, `cancelRemplacement`, `expireRemplacements` (toutes `europe-west1`)
- `lib/services/remplacement_session_service.dart` — activation après login, surveillance locale (Timer 1min + listener Firestore), marqueur `SharedPreferences` jamais synchronisé
- `lib/widgets/remplacement_banner.dart` — bandeau "vous intervenez en tant que..." / "X intervient en tant que..." (cloné de `demo_mode_banner.dart`, qui n'était lui-même jamais câblé)
- `lib/screens/remplacements_management_screen.dart` — écran de gestion (accessible depuis `/structure-management`)
- Branchage : `login_screen_new.dart`, `quick_login_screen.dart` (activation post-login), `auth_check_screen.dart` (vérif au démarrage froid), `invitation_signup_screen.dart` (nouvelle branche `remplacement`)
- Nouvelle collection `structures/{id}/remplacements/{id}` + index `firestore.indexes.json` (`replacementEmail`, `status`)

### ⚠️ Faille de sécurité trouvée ET corrigée avant tout déploiement
`activateRemplacementSession` s'exécute à **chaque connexion normale** (pas seulement à la redemption de l'invitation) et ne matchait que par email. Comme un email Firebase est unique, un compte préexistant sans lien avec la demande (coïncidence, faute de frappe) aurait pu être basculé silencieusement dans le compte de la propriétaire à sa prochaine connexion ordinaire, sans jamais avoir vu l'invitation. **Fix appliqué :** on exige désormais que l'invitation associée (`invitations/{invitationId}`) soit passée à `status: 'completed'` avant toute activation/liaison — ce qui ne peut arriver que via l'écran explicite de redemption. Un compte qui n'a jamais vu l'invitation reste bloqué indéfiniment.

### Comment tester (from scratch)
1. Dashboard → Administration (ou "Modifier les coordonnées") → `/structure-management` → bouton **"Gérer les remplacements"** en bas → `/remplacements`
2. Remplir email + prénom/nom + période (calendrier) → "Envoyer l'invitation"
3. Côté remplaçante : écran de connexion → "J'ai reçu un email d'invitation" → `/invitation-code` → saisir l'email → suit le flux d'inscription (son propre mot de passe)
4. Si la période est déjà active, bascule immédiate + bandeau. Sinon, activation automatique à la prochaine connexion normale une fois la période commencée.

---

## 🔧 Fix changement d'email self-service (02/07/2026) — ✅ DÉPLOYÉ

`exports.updateUserEmail` (functions/index.js) reconstruite de zéro : lit toutes les données AVANT d'écrire (batch unique), migre `users/{email}` (clé = email), `structures.ownerEmail/.email`, `structures/{id}/members/*.email`, `structures/{id}/assistants/{email}` (renommage, doc ID = email), enfants (`assignedMemberEmail`, `parent1/2.email`) — **Firestore d'abord, Firebase Auth en tout dernier**, avec rollback automatique si l'étape Auth échoue après le batch. Garde-fou ajouté dans `onChildParentEmailSet` pour ne pas ré-inviter un parent déjà lié suite à la migration.

Client : nouveau `lib/services/email_change_service.dart` mutualisé entre `structure_management_screen.dart` et `parent_settings_screen.dart`, invalide le cache biométrique + `SharedPreferences` de l'ancien email après succès.

**Découverte au déploiement :** une fonction `updateUserEmail` existait déjà côté serveur (orpheline, probablement une ancienne version jamais nettoyée) — le déploiement l'a remplacée par la bonne implémentation.

---

## 🗄️ Backup Firestore — créé le 02/07/2026 (n'existait PAS avant)

Aucun backup Firestore (ni ponctuel ni planifié) n'existait sur le projet `poppin-s-app` avant cette session. Créé une sauvegarde automatique **quotidienne, rétention 7 jours** (`firebase firestore:backups:schedules:create --recurrence DAILY --retention 7d`). Pas de `gcloud` installé sur cette machine → pas d'export ponctuel possible, seulement via cette planification native Firestore.

---

## ✅ 5 correctifs + FAQ complète (02/07/2026) — CODE FAIT, **NON COMMITÉ**

1. `remplacements_management_screen.dart` : bouton retour ajouté (pattern `canPop() ? pop() : context.go('/structure-management')`, identique à `add-mam-members.dart`) + fix overflow RenderFlex (le `trailing` d'un `ListTile` a une hauteur fixe, ne peut pas contenir un badge + un bouton empilés — le bouton "Annuler" est sorti du `ListTile`).
2. **Aide flottante** (`lib/features/aide/aide_floating_button.dart`) : `_hiddenOnPaths` (liste noire) remplacé par `_visibleOnPaths` (liste blanche) — visible **uniquement** sur les 12 écrans de la grille Home (`/horaires`, `/repas`, `/activites`, `/sieste`, `/sante`, `/change`, `/photos`, `/agenda`, `/stock`, `/recap-enfant`, `/actualites`, `/transmissions`), nulle part ailleurs. **Le bug du 23/06 (bouton invisible) est résolu** — n'apparaissait plus une fois restreint car testé sur un écran hors liste.
3. **`aide_faq_data.dart` complété** : les 10 écrans qui n'avaient que le message générique ont maintenant chacun 3 vraies questions/réponses écrites à partir du comportement réel du code (ex: règle "au moins un élément" sur Change, reset auto du menu chaque lundi sur Actualités, impact du poids sur la fiche enfant sur Santé). Seuls `/repas` et `/sieste` avaient du contenu avant.
4. **Calculs IA basculé d'OpenAI vers DeepSeek** (`functions/index.js`, `askCalculAssistant`) : modèle `deepseek-chat`, endpoint `https://api.deepseek.com/chat/completions`, secret Firebase renommé `DEEPSEEK_API_KEY` (clé collée en clair par Christophe dans le chat le 02/07 → configurée immédiatement en secret, signalée une fois, régénération suggérée mais pas faite — voir [[feedback_cles_api_en_clair]]). **Déjà déployé en prod.** La règle "l'IA ne calcule jamais de chiffre elle-même" reste inchangée.
5. Dashboard → Administration : "Contrats" renommé en **"Documents contractuels"** (3 endroits : sheet mobile, titre sous-menu, tuile tablette).
6. Stock (`stock_screen.dart` + `parent_stock_screen.dart`) : "Mouchoirs" remplacé par **"Paquet de mouchoirs"** et **"Boîte de mouchoirs"** (deux entrées distinctes).

⚠️ **Tout ce bloc (points 1-6) + le bump de version pubspec.yaml sont encore SEULEMENT en local sur `main`, PAS commité.** Christophe n'a pas encore confirmé le commit — à faire dès qu'il valide.

---

## 📦 Build & Release 2.1.7+2061 (02/07/2026)

### Environnement de build — problèmes trouvés et corrigés
- **JDK système = Java 26 (Temurin)**, incompatible avec Gradle 8.7 / AGP 8.6.0 du projet (erreur cryptique "`> 26.0.1`" lors de tout `./gradlew`). **Fix :** installé JDK 17 via `brew install openjdk@17` (formule, pas cask — pas de sudo nécessaire), chemin : `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`. Configuré via `flutter config --jdk-dir=...` ET nécessaire de `export JAVA_HOME=...` avant tout `./gradlew` direct.
- **`android/app/build.gradle.kts` existe en double avec `android/app/build.gradle`** — le `.kts` (template par défaut, jamais nettoyé) signe en `debug` même pour la release ("TODO: Add your own signing config"). **Bonne nouvelle vérifiée en pratique** (`./gradlew :app:signingReport` + inspection du `.aab` produit) : Gradle ignore silencieusement le `.kts` et utilise le `.gradle` (Groovy) qui a la vraie config de signature (`upload-keystore.jks`, alias `upload`, valide jusqu'en 2052). Le build produit est donc **correctement signé**. **TODO non fait :** supprimer `build.gradle.kts` pour éviter toute confusion/risque futur (proposé à Christophe, pas encore confirmé).

### Résultat
- **Android** : `build/app/outputs/bundle/release/app-release.aab` (104 Mo), signature vérifiée OK. Prêt pour Play Console.
- **iOS** : archive Xcode réussie (`build/ios/archive/Runner.xcarchive`, 262 Mo), mais export IPA App Store échoue — **problèmes côté compte Apple Developer, pas côté code** : (1) "PLA Update available" (accord de licence à accepter sur developer.apple.com), (2) aucun certificat "iOS Distribution" local, Xcode non connecté à un Apple ID sur cette machine. **Christophe s'en occupe lui-même** via Xcode Organizer (`open build/ios/archive/Runner.xcarchive` → Distribute App).
- **Version bumpée** : `pubspec.yaml` 2.1.6+2060 → **2.1.7+2061** (pas encore commité, voir bloc ci-dessus).

### dSYM "Upload Symbols Failed" lors de l'upload iOS (02/07/2026) — confirmé bénin
Warnings pour `FirebaseFirestoreInternal`, `absl`, `grpc`, `grpcpp`, `openssl_grpc` — **n'empêche pas l'upload/la review**, juste la symbolication de crashs (rarissimes) dans ces frameworks tiers précompilés. Un fix Podfile existait déjà (26/05, commit `51ae05e`, désactive `DEBUG_INFORMATION_FORMAT=dwarf` pour ces pods) mais ne s'applique plus car ces frameworks sont maintenant distribués en XCFramework binaire précompilé (plus de compilation locale à influencer). Pas de nouvelle action nécessaire, comportement connu/documenté côté Firebase iOS SDK.

### Textes préparés (pas encore utilisés/collés par Christophe)
- **Google Play "Nouveautés"** (469/500 caractères) et **App Store "Quoi de neuf"** (format long avec émojis par section) rédigés — couvrent tout depuis la 2.1.6 : Documents contractuels, Calculs IA, Remplacement, Aide contextuelle, fix email.
- **Notes App Review Apple** (en anglais) rédigées — expliquent en particulier le mécanisme du custom token pour "Remplacement" (pour éviter qu'un reviewer le prenne pour une faille). **Question ouverte non répondue par Christophe :** faut-il un compte de démo/review avec abonnement actif à fournir aux reviewers Apple ? Proposé de lui en créer un jetable si besoin.

---

## 🐛 Bugs / tâches non résolues (reportées des sessions précédentes, toujours valides)

1. **Rate limit Calculs IA à remettre à 5/jour** avant publication publique (actuellement 20, TODO dans le code `CALCUL_ASSISTANT_MAX_QUESTIONS_PER_DAY`) — Christophe a dit qu'il le ferait lui-même, jamais confirmé fait.
2. **Clés API collées en clair** (Kimi + OpenAI le 22/06, DeepSeek le 02/07) — configurées en secret Firebase à chaque fois, mais **jamais régénérées côté fournisseur** par précaution malgré la recommandation.
3. **Tests device réel jamais explicitement confirmés** pour Documents (CDI/CDD/Avenant/Engagement) — committé le 23/06 sur demande explicite malgré ça.
4. **Faux message orange "Échec envoi"** dans `child_financial_info_screen.dart` (bug UI mineur, pas retouché).
5. **`android/app/build.gradle.kts` mort** à supprimer (voir section Build ci-dessus) — cosmétique/sécurité, pas urgent puisque Gradle l'ignore déjà correctement.
6. **Compte de démo/review Apple** — question posée à Christophe, pas encore répondue.

---

## 📝 Infos essentielles toujours valides

- App en production ~100 utilisateurs actifs/jour — NE PAS casser
- Admin : cbeylet06@gmail.com, chrisgugu1101@gmail.com
- chrisgugu1101@gmail.com = Christelle (femme de Christophe) — utilise l'app tous les jours
- Deux comptes Claude sur même Mac (chrisbeylet@gmail.com + cbeylet06@gmail.com) : lire ce fichier à chaque session
- Projet Firebase : `poppin-s-app`, région Cloud Functions : `europe-west1`
- JDK pour builds Android sur cette machine : `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` (pas le JDK système, qui est en Java 26)
- Backup Firestore désormais actif (quotidien, 7 jours de rétention) — avant le 02/07/2026 il n'y en avait aucun
