# Session courante — Poppins App

**Dernière mise à jour :** 2026-07-16 soir (session chrisbeylet@gmail.com)

## 🚨 16/07/2026 (suite) — Audit complet du parcours enfant + incident de test + garde-fou anti-corruption

Après le fix du matin (voir section ci-dessous), Christophe a demandé une vérification exhaustive : "une fois l'enfant ajouté, est-ce que TOUT fonctionnera pour lui (horaires, profil, historique...) et pour Clara aussi ?" — pour ne pas que Fiona revienne une 4e fois. 2 agents lancés en parallèle pour auditer (1) le reste du parcours d'ajout d'enfant (étapes après "Informations Parent") et (2) tous les écrans de gestion d'un enfant existant (horaires, profils, historique, photo, retrait, coordonnées).

### Bugs trouvés (en plus des 2 du matin)
1. **`parent_second_info_screen.dart:892`** — même lecture illégale de toute la collection `structures` que le bug du matin, sur l'étape optionnelle "Ajouter un 2e parent". Touche TOUS les utilisateurs non-admin (Fiona ET Clara), pas seulement les fondatrices. **Fix : bloc supprimé (code mort, comparait aussi un champ `type`/`members` qui n'existe même pas dans le vrai modèle de données). Modifié en local, pas commité.**
2. **`canManageParentUsers()` (firestore.rules) oubliait le rôle `'structure'`** dans sa liste autorisée (`['admin','mamMember','assistant']`) — cassait 2 écrans cœur de métier pour toute fondatrice : `child_financial_info_screen.dart` (rattacher un enfant à un parent déjà existant, silencieux) et surtout **`parent_coordonnées_screen.dart`** (impossible d'enregistrer/modifier l'email d'un parent ou de renvoyer une invitation — Fiona n'aurait jamais pu inviter aucun parent). **Fix : `'structure'` ajouté à la liste. DÉPLOYÉ EN PROD**, testé emulator avant (18 tests, 3 nouveaux ajoutés dans `firestore-tests/run-tests.js`).
3. **`dashboard_screen.dart::_canCurrentUserEditChild()`** ignorait `showAllChildrenOnHome` — un membre MAM non-propriétaire (Clara) se serait vu bloquée en lecture-seule sur "Profils enfants" pour tout enfant ajouté par l'autre membre (Fiona), malgré le réglage "tous les enfants visibles" activé. **Fix : nouveau champ d'état `_allowAllChildren`, vérifié en priorité. Modifié en local, pas commité.**

### 🚨 Incident pendant la vérification en direct — détecté et corrigé dans la foulée
En testant "Renvoyer l'invitation" sur la fiche d'Assiyah (dont le `parent1.email` pointait par erreur vers `clara.beausoleil@hotmail.com`, résidu d'un test antérieur de Christophe/Clara), le bug n°2 ci-dessus a été pris en flagrant délit : **le compte réel de Clara a été écrasé** (`role: mamMember` → `role: parent`, `children: [Assiyah]` ajouté) par l'écriture `users/{email}.set({role:'parent',...}, merge:true)` de `_queueParentInvitationEmail()`. Détecté immédiatement, réparé (`role` restauré, `children`/`childName` supprimés), fausse invitation et `parent1` erroné nettoyés sur la fiche d'Assiyah.

**Root cause plus large découverte à cette occasion** : `parent_coordonnées_screen.dart::_queueParentInvitationEmail()` écrivait `role:'parent'` sur n'importe quel email saisi, **sans jamais vérifier si cet email appartenait déjà à un compte professionnel**. N'importe quelle fondatrice qui se trompe d'email (tape l'adresse d'une collègue par erreur) aurait pu casser silencieusement le compte de cette collègue — un vrai bug de corruption de données, pas juste un artefact de test. **Fix ajouté** : garde-fou en tout début de fonction, vérifie `users/{email}.role` et refuse avec un message clair (`"Cet email est déjà utilisé par un compte professionnel"`) si c'est déjà un compte pro. Try/catch ajouté aussi dans `_showEditEmailDialog` pour bien afficher l'erreur. **Modifié en local, pas commité.**

### Vérifié en direct sur simulateur
- "Renvoyer l'invitation" pour Fiona fonctionne (avant le garde-fou) — confirmé succès complet pour un email normal.
- Après ajout du garde-fou : re-testé avec l'email de Clara → refusé proprement, message d'erreur clair, **aucune écriture** (vérifié : `role` de Clara toujours `mamMember` après le test).
- Bug n°1 (2e parent) et n°3 (Clara lecture-seule) : corrigés par lecture de code, **pas testés en direct** faute de temps (pas de session avec un 2e parent essayée, pas de connexion possible avec le vrai mot de passe de Clara).

### État des fichiers — toujours rien commité
7 fichiers modifiés en local au total depuis hier (aucun commit) : `firestore.rules`, `firestore.indexes.json`, `firestore-tests/run-tests.js`, `lib/screens/mam_member_add_screen.dart`, `lib/screens/parent_info_screen.dart`, `lib/screens/parent_second_info_screen.dart`, `lib/screens/dashboard_screen.dart`, `lib/screens/parent_coordonnees_screen.dart`. 2 déploiements prod déjà faits (`firestore.rules` deux fois, `firestore.indexes.json` une fois) sans qu'aucun ne soit commité dans le repo — **risque réel qu'un futur commit écrase l'état prod actuel**.

---

## 🚨 16/07/2026 (matin) — Fiona Audy : bug "Ajouter un enfant" cassé — corrigé, bug latent identifié (pas un problème d'onboarding actif)

2e signalement de Fiona le lendemain (16/07) : erreur générique "Une erreur est survenue. Veuillez réessayer." à l'étape "Informations Parent" de l'ajout d'enfant, reproductible à volonté. **Reproduit et corrigé en direct sur simulateur iOS avec son vrai compte** (méthode détaillée plus bas — nouvelle capacité acquise cette session).

### Cause n°1 — code mort devenu bloquant, corrigé
`lib/screens/parent_info_screen.dart::_saveParentInfo()` faisait une lecture non filtrée de **toute** la collection `structures` pour vérifier si l'email saisi correspondait à un ID de structure existant — interdit par les règles Firestore pour un compte non-admin. Ce check n'a jamais pu fonctionner de toute façon (comparait un ID de structure, toujours un UID Firebase Auth, à un email — aucun match possible sur les 798 structures réelles). Présent depuis le tout premier commit du repo (19/05/2025), cassé de façon bloquante seulement depuis le durcissement sécurité du 30/05/2026. **Fix : bloc supprimé. Modifié en local, PAS COMMITÉ, PAS BUILDÉ.**

### Cause n°2 — champ `role` manquant sur le compte de Fiona, réparé manuellement pour elle
Sans le champ `role` sur `users/{email}`, la fonction `isProfessional()` des règles Firestore échoue, ce qui bloque même la 1ère lecture de l'écran. **Réparé manuellement** : `role: 'structure'` ajouté sur `users/fionaudy04@gmail.com`.

### ⚠️ Ampleur réelle du problème — investiguée à fond, PAS un bug d'onboarding actif
Premier réflexe (erroné) : un échantillon rapide de 57 structures a suggéré que ~91% des fondatrices seraient affectées — Christophe a eu raison de douter immédiatement ("l'ajout d'enfant est la première chose qu'ils font, ça devait fonctionner, jamais eu de plainte"). Audit complet refait sur les **798 structures réelles** (2 agents lancés en parallèle pour vérifier Clara + l'ampleur réelle) :

- Comptes créés **après le 05/01/2026** (date où `congratulations_screen.dart` a commencé à écrire `role:'structure'` à l'inscription) : **97,5% corrects** (40 structures)
- Comptes créés **après le 30/05/2026** (durcissement des règles) : **100% corrects** (11 structures)
- Comptes créés **avant le 05/01/2026** (727 sur 798, la quasi-totalité du parc) : **0,7% corrects** — c'est tout le problème
- Preuve directe que le flux marche aujourd'hui : **8 structures distinctes** ont ajouté un enfant avec succès après le 30/05/2026 (dont une le 16/07 même), toutes avec `role` correct.

**Fiona correspond exactement au profil du vrai bug** : structure créée le 06/10/2025 (avant le mécanisme qui écrit `role`), et son compte n'a jamais déclenché les réparations automatiques existantes (`auth_check_screen.dart:171/193` — ne se déclenche que si le lookup par `structureId` échoue —, ou le webhook Stripe lors d'un re-paiement). Les ~41 autres vieux comptes payants avec `role` manquant identifiés n'ont **aucune activité récente** (`lastActiveDate`) — elles n'ajoutent quasiment jamais de nouvel enfant, ce qui explique l'absence totale de plainte en 7 semaines malgré le bug.

**Conclusion : bug réel mais dormant, touche des vieux comptes peu actifs, pas les nouvelles inscriptions.** Pas urgent de backfiller en masse dans la panique. Reste à faire, calmement : un backfill ponctuel de `role:'structure'` pour les fondatrices anciennes qui en manquent, si/quand elles refont l'action qui le déclenche.

### Testé en conditions réelles de bout en bout
Après les 2 fixes, flux complet vérifié sur simulateur : enfant de test créé, infos parent enregistrées (log `✅ Infos du parent enregistrées`), invitation envoyée, redirection vers "Adresse Parent". Enfant/invitation/emailQueue de test supprimés après vérification — aucune trace laissée dans les données réelles de Fiona.

### 🛠️ Méthode de test en direct sur simulateur (nouvelle capacité acquise cette session)
```
xcrun simctl boot "DE24F1AD-4500-4EBF-9460-B9161D133082"   # iPhone 17
open -a Simulator
flutter run -d DE24F1AD-4500-4EBF-9460-B9161D133082   # ~2-5 min de build la 1ère fois
```
Pour interagir (taper, cliquer) : **`cliclick`** (installé via `brew install cliclick` cette session — pas présent par défaut). Piège important : la fenêtre Simulator **change de position à chaque réactivation** (`osascript -e 'tell application "Simulator" to activate'`), donc ne JAMAIS réutiliser des coordonnées calculées à un tour précédent. Toujours, dans l'ordre : activer Simulator → `screencapture -x` (capture plein écran Mac — PAS `simctl io screenshot`, qui ne donne que le contenu de l'écran device, inutile pour calculer des coordonnées Mac) → lire les coordonnées dans l'image (×1.44 pour la résolution réelle en pixels, ÷2 pour convertir en points Mac, écran Retina 2x) → cliquer avec `cliclick c:x,y` (clic) ou `cliclick dd:x,y w:50 dm:x2,y2 w:50 du:x2,y2` (glisser/scroll — **`dm:` obligatoire pour les points intermédiaires d'un drag, `m:` seul ne génère pas d'événement mouseDragged et le scroll ne se produit pas**). Ensuite `xcrun simctl io <device> screenshot` pour voir le résultat sur l'écran device.

---

## 🚨 15/07/2026 — Fiona Audy (fionaudy04@gmail.com) : 2 bugs corrigés + 1 bug profond trouvé (non corrigé)

Fiona a signalé par email 2 bugs le même jour. Les 2 sont maintenant **résolus et vérifiés en direct** (simulateur iOS, connectée avec son vrai compte). Un 3e bug plus profond a été découvert en creusant mais **volontairement pas touché** (hors sujet, nécessite sa propre session).

### Bug 1 — "Ajouter un membre" cassé (permission-denied) — chemin de code corrigé, PAS ENCORE COMMITÉ/BUILDÉ
Deux causes empilées dans le flux self-service MAM, présentes probablement depuis toujours (jamais fonctionné en prod pour aucune MAM) :
1. `lib/screens/mam_member_add_screen.dart` créait `users/{email}` du nouveau membre depuis le compte de la fondatrice — interdit par `firestore.rules` (seul le titulaire du compte peut écrire son propre doc). **Fix : écriture supprimée** (le doc sera créé par le membre lui-même à l'inscription, comme le fait déjà `invitation_signup_screen.dart:1123`). **Modifié en local, PAS COMMITÉ.**
2. `firestore.rules` (règle `invitations`, création) exigeait `childId is string`, un champ pensé pour les invitations parent, jamais fourni pour les invitations `type: mamMember` → la création de l'invitation échouait aussi, systématiquement. **Fix déployé en prod** : `childId is string || type == 'mamMember'`. Testé dans l'émulateur (`firestore-tests/`, 2 nouveaux tests ajoutés, 12/12 passent) avant déploiement.

**Pour Fiona spécifiquement** : contourné l'écran cassé, ajout manuel en base (Admin SDK, clé `firebase-export/serviceAccountKey.json`) : membre Clara Beausoleil (`clara.beausoleil@hotmail.com`) ajouté dans `structures/ueVnOL4WzkMnpo9fWRNMngqseuF3/members/member_2`, invitation créée (`invitations/lyWp9NQTX3tZIyMvE8qv`), email réel envoyé via Mailjet (confirmé `status: sent`). **Testé en direct** : Christophe a suivi le flux "J'ai reçu une invitation" sur simulateur avec l'email de Clara, créé son compte avec un mot de passe provisoire — fonctionnel.

⚠️ **Le bouton "Ajouter un membre" reste cassé pour TOUTE AUTRE fondatrice MAM** tant qu'un nouveau build n'est pas publié (le fix client n'est que dans le code source local, pas committé, pas buildé). Le fix `firestore.rules`, lui, est déjà en prod mais ne suffit pas seul (cause n°1 toujours présente côté client publié).

### Bug 2 — "Aucun enfant trouvé" sur Dashboard → Enfants & Parents — CORRIGÉ ET DÉPLOYÉ
Cause réelle : **pas un problème de données**, un **index Firestore manquant**. `firestore.indexes.json` avait un `fieldOverride` sur `members.email` qui ne déclarait que le scope `COLLECTION_GROUP` (utilisé légitimement par `home_screen.dart:3483`), ce qui supprimait l'index automatique en scope `COLLECTION` dont dépend `dashboard_screen.dart::_loadChildren()` (partagée par 6 actions : Profils enfants, Modifier horaires, Modifier profil, historique, photos, suppression enfant). L'erreur (`failed-precondition: requires a COLLECTION_ASC index`) était catchée silencieusement et affichée comme "Aucun enfant trouvé", alors que les 6 enfants de Fiona existaient et étaient bien assignés.

**Touche potentiellement TOUTES les vraies MAM multi-membres** (pas les assistantes solo, qui ne passent pas par ce filtre). Le même index manquant cassait aussi silencieusement le "compteur délégations" et la "vérification du mémo mensuel" (vus dans les logs) — devraient aussi être réparés par ce fix.

**Fix déployé** (`firebase deploy --only firestore:indexes`) : ajout des scopes `COLLECTION` (ASC+DESC) à côté du `COLLECTION_GROUP` existant, sans rien supprimer. Index confirmé construit et fonctionnel (requête testée + vérifiée en direct sur simulateur : Fiona voit maintenant bien ses 6 enfants dans "Enfants & Parents").

### Bug 3 — TROUVÉ, PAS CORRIGÉ, à creuser une prochaine session
`firestore.rules:90-93` — règle `subscriptions/{docId}` : `isStructureMember(docId)` vérifie l'UID contre **l'ID Firestore auto-généré du document d'abonnement** (ex: `ZLZvfzTYGHvuG4ygUmYa`), pas contre le champ `structureId` réel stocké DANS le document. Résultat : `permission-denied` systématique dès qu'un client lit/interroge `subscriptions` (vu dans les logs : `Erreur check ID dashboard`, `Erreur correction structure via abonnement`). Concrètement, le bloc "🛡️ SÉCURITÉ ANTI-WEBHOOK" de `dashboard_screen.dart` (~ligne 1332-1377), censé vérifier que le `productId` réel de l'abonnement (Stripe/IAP) correspond bien au `structureType`/`maxMemberCount` stocké dans `structures/{id}` (garde-fou anti-fraude), échoue silencieusement pour tout le monde, tout le temps — donc ne protège en réalité jamais rien. Pas un trou de sécurité (trop restrictif, pas trop permissif) mais une vérification censée exister qui ne s'exécute jamais.

**À faire avant de toucher à ça** : identifier TOUS les endroits où le client lit/écrit `subscriptions` (au moins `dashboard_screen.dart:1334`, à vérifier aussi `subscription_service.dart`, `unified_subscription_service.dart`, `home_screen.dart`), écrire un test emulator dédié, puis corriger la règle pour se baser sur `resource.data.structureId` plutôt que `docId`. Ne pas se précipiter (leçon de l'incident du 10/07 : toute modif de `firestore.rules` doit passer par `firestore-tests/` avant déploiement).

### État des fichiers — RIEN DE COMMITÉ malgré 2 déploiements prod déjà faits
- `firestore.rules` et `firestore.indexes.json` sont **déjà déployés en prod** mais **pas committés** dans le repo — à committer rapidement pour ne pas perdre la trace (risque : quelqu'un pourrait écraser l'état prod actuel avec un ancien commit sans le vouloir).
- `lib/screens/mam_member_add_screen.dart` et `firestore-tests/run-tests.js` : modifiés en local, pas committés, pas déployés/buildés.

### Actions manuelles faites sur données réelles de prod aujourd'hui
- Structure Fiona (`ueVnOL4WzkMnpo9fWRNMngqseuF3`) : ajout `members/member_2` (Clara Beausoleil), `invitations/lyWp9NQTX3tZIyMvE8qv`, email Mailjet envoyé.
- Compte Firebase Auth créé pour `clara.beausoleil@hotmail.com` avec un **mot de passe provisoire** (choisi par Christophe pendant le test en direct) — Clara doit le changer dès sa première connexion (via "Mot de passe oublié", flux 100% Firebase natif, aucun code Poppins impliqué).
- Le vrai mot de passe de Fiona a été utilisé pour se connecter sur le simulateur à des fins de test (fourni en direct par Christophe, non stocké) — **Fiona doit aussi changer son mot de passe**.

### À faire à la prochaine session
1. Committer les 4 fichiers modifiés (`firestore.rules`, `firestore.indexes.json`, `lib/screens/mam_member_add_screen.dart`, `firestore-tests/run-tests.js`).
2. Prévoir un nouveau build app (le fix client `mam_member_add_screen.dart` ne profite qu'à Fiona pour l'instant, via le contournement manuel — toute autre fondatrice MAM reste bloquée jusqu'à publication).
3. Dire à Fiona : les 2 bugs sont résolus, Clara a déjà un compte (mot de passe provisoire à changer), et lui rappeler de changer son propre mot de passe suite aux tests.
4. Reprendre le bug n°3 (`subscriptions` / `isStructureMember(docId)`) dans une session dédiée, avec tests emulator avant tout déploiement.
5. Vérifier un jour le message d'avertissement vu au déploiement des index : "7 indexes définis dans le projet absents du fichier local" (drift pré-existant, pas touché, pas urgent).

---

## 🚨 INCIDENT + RÉSOLU 11/07/2026 — verifyApplePurchase non déployée, achats iOS cassés en prod

Le build iOS/Android livré aujourd'hui (v2.1.8+2063) incluait le nouveau code client (`ios_subscription_service.dart`, committé le 10/07) qui appelle la Cloud Function `verifyApplePurchase` — mais cette fonction était restée **non déployée** (mise en pause faute de secret Apple, un placeholder avait été mis pour débloquer d'autres déploiements). Conséquence réelle : **tout nouvel achat iOS depuis la sortie de cette version échouait** avec "Achat non validé : NOT FOUND" (Firebase renvoie NOT_FOUND quand la fonction appelée n'existe pas côté serveur) — Apple prélevait bien l'utilisatrice, mais l'app ne validait jamais l'achat côté serveur et ne débloquait rien.

**Découvert via Fiona Audy** (fionaudy04@gmail.com, structure `ueVnOL4WzkMnpo9fWRNMngqseuF3`) : a payé 9,99€ pour passer en MAM 2 membres (confirmé dans ses Réglages iOS > Abonnements, renouvellement 13 août), bloquée en "1 assistante maternelle" avec message d'erreur.

**Résolu en 2 temps :**
1. **Fiona débloquée manuellement** (Admin SDK, correspond exactement à ce que `verifyApplePurchase` aurait dû faire) : `structureType: MAM`, `maxMemberCount: 3`, nouveau doc `subscriptions` (productId `mam_2_membres`, 9,99€, `manualFix: true`), ancien abonnement assistante_maternelle marqué `replaced`.
2. **Cause corrigée** : vrai secret App-Specific Shared Secret récupéré sur App Store Connect (Poppin's → Abonnement Poppin's → "Secret partagé spécifique à l'app" → Gérer) et configuré via `firebase functions:secrets:set APPSTORE_SHARED_SECRET`, puis `verifyApplePurchase` déployée pour de vrai. Confirmé fonctionnelle : un appel non authentifié renvoie maintenant 401 (au lieu de 404/NOT_FOUND avant).

**⚠️ À surveiller** : toute utilisatrice iOS ayant tenté un nouvel achat/upgrade entre la sortie de la v2.1.8+2063 et ce fix a pu subir le même problème (prélevée, bloquée). Si d'autres réclamations similaires arrivent pour cette fenêtre, reproduire le fix manuel ci-dessus (structureType/maxMemberCount/subscriptions).

## ✅ DÉPLOYÉ 11/07/2026 — Webhooks App Store / Google Play réparés

En vérifiant "sera-t-elle bien prélevée le mois prochain" pour Fiona (conversion MAM), découvert que `handleAppStoreWebhook` et `handleGooglePlayWebhook` ne trouvaient **littéralement jamais aucun compte** depuis toujours : ils cherchaient sur `users/{email}.subscriptionPlatform`/`originalTransactionId`/`purchaseToken`, des champs que ni `ios_subscription_service.dart` ni `android_subscription_service.dart` n'ont jamais écrits (ces services écrivent uniquement dans `subscriptions`/`structures`). Résultat concret : les notifications Apple/Google de renouvellement, échec de paiement, ou annulation n'ont **jamais** été répercutées dans Firestore, pour aucune utilisatrice iOS/Android, depuis le début. Bug préexistant, pas causé par la conversion MAM — juste découvert en creusant cette question.

**Fix** : les 2 fonctions résolvent maintenant directement sur `subscriptions` (par `originalTransactionId` puis fallback `transactionId` pour iOS — StoreKit fixe les deux égaux au tout premier achat, donc ça couvre aussi l'historique existant ; par `purchaseToken` pour Android — pas de fallback possible, donc **les achats Android déjà existants sans `purchaseToken` enregistré ne seront pas rattrapés rétroactivement**, seuls les futurs achats seront couverts). Fonction morte `_findUserDocsByToken` supprimée.

**Testé avant déploiement** (leçon de l'incident du 10/07 : plus jamais de déploiement sans test réel) : requête exacte exécutée en lecture seule contre la vraie prod — retrouve bien l'abonnement réel de Fiona Audy via son `transactionId`. Aucune erreur d'index. Déployé sans incident (fonctions appelées uniquement par les serveurs Apple/Google, jamais par un utilisateur — aucun risque de type "panne du 10/07").

## 🚨 DANGER IDENTIFIÉ ET ÉVITÉ — `dailySubscriptionCheck` — NE PAS corriger naïvement

En creusant plus loin ("y a-t-il d'autres trous du même genre ?"), trouvé que `exports.dailySubscriptionCheck` (cron automatique toutes les 24h, censé désactiver les abonnements sans confirmation webhook depuis 35j) a **exactement le même bug** que les 2 webhooks (interroge `users` au lieu de `structures`) — jamais fonctionné depuis toujours. `exports.cleanupInactiveSubscriptions` (outil admin manuel juste en dessous dans le fichier) a déjà le bon fix appliqué (cible `structures`), jamais reporté sur la version automatique.

**J'ai commencé à porter le même fix, PUIS vérifié l'impact réel avant tout déploiement (leçon du 10/07 appliquée à fond cette fois) : 64 structures actives sur 89 (72%!) auraient été désactivées immédiatement**, dont de vraies utilisatrices payantes (Delphine, Marielle, "L'îlot Doudous", Maria, etc.) — parce que le webhook n'ayant jamais fonctionné, quasiment personne n'a de date de mise à jour récente, donc "pas de nouvelle depuis 35 jours" ne veut pas dire "a arrêté de payer", juste "le suivi n'a jamais marché".

**Décision : reverté avant déploiement, `functions/index.js` remis exactement à l'état du commit `48f152e`, rien de risqué en attente.** `dailySubscriptionCheck` reste dans son état actuel (cassé mais inoffensif — ne fait jamais rien).

**Si ce sujet est repris un jour**, il faudra une approche différente, pas juste corriger la collection cible :
- D'abord tourner en mode "log only" (lister ce qui serait désactivé, sans jamais écrire) pendant un certain temps pour observer le volume réel une fois les webhooks (maintenant corrigés) auront eu le temps d'alimenter `lastWebhookUpdate` naturellement.
- Ou "grandfather" toutes les structures actuellement actives (leur donner une date de référence fraîche) avant d'activer la désactivation automatique, pour ne jamais pénaliser quelqu'un pour un défaut de suivi historique plutôt qu'un vrai défaut de paiement.
- Ne jamais réactiver ce cron sans re-vérifier le nombre de structures impactées juste avant, la situation change chaque jour maintenant que les webhooks fonctionnent.

## 🔧 Conversion Assmat → MAM (Fiona Audy) — récap

## 🔧 EN COURS — Conversion Assistante Maternelle → MAM (PAS ENCORE TESTÉE DE BOUT EN BOUT)

### Contexte
Utilisatrice (Fiona Audy, fionaudy04@gmail.com) bloquée depuis 3 semaines : impossible de convertir son compte solo en MAM. Trouvé 3 bugs empilés dans `subscription_upgrade_screen.dart` + `dashboard_screen.dart` (voir commit précédent pour le détail : gate `isMam` bloquant l'accès, `maxMemberCount` forcé à 2 avant paiement, `structureType` jamais mis à jour après conversion). Corrigés et **committés** dans le commit "Corrige route horaires, bug perte de planning, conversion MAM inaccessible — v2.1.8+2062".

### Ce qui a été ajouté APRÈS ce commit (non committé, dans l'arbre de travail)
1. **`lib/screens/dashboard_screen.dart` — `_checkIfMAMStructure()`** : la branche "else" (structure non-MAM) forçait `currentMemberCount = 1` SANS jamais vérifier le nombre réel de membres dans la sous-collection `members`. Bug découvert en testant sur le compte de test de la femme de Christophe (`chrisgugu1101@gmail.com`, structure `euAkwrpTFEMeH1GXjJQcUy8yL053` "Les P'tits Lutins") : `structureType: "AssistanteMaternelle"` mais 2 vrais membres dans la sous-collection `members` (configurée manuellement par le passé, jamais via un vrai flux de conversion) — le bouton "Passer en MAM" réapparaissait à tort. Fix : compter les vrais documents `members` même dans la branche non-MAM. **Corrigé et vérifié fonctionnel** (le bouton a bien disparu pour ce compte après le fix).
2. **`lib/screens/subscription_upgrade_screen.dart` — simplification 3→2 choix** : à la demande de Christophe, remplacé les 3 boutons (2/3/4 membres) par 2 paliers ("2-3 membres" à 9,99€, "4 membres et +" à 14,99€) — 2 et 3 membres ont le même prix, avoir 3 boutons "mélangeait plus qu'autre chose". Nouvelle fonction `_buildTierButton` (remplace `_buildMemberCountButton`), nouveau `_tierLabel()` pour l'affichage. Choisir "2-3" utilise en interne memberCount=3 (plus généreux que 2, même prix, cohérent avec la convention déjà utilisée côté Stripe/webhook).
3. **Bug prix corrigé** : `_getPriceForMembers(1)` retournait "9,99€" au lieu de "3,99€" pour 1 membre (invisible tant que l'écran était inaccessible aux comptes solo). Ajout aussi de `_priceAmountForMembers()` et écriture de `currentPriceAmount`/`currentPriceDisplay` dans `_syncStructureAfterUpgrade` (jamais fait avant).
4. **Nouveau flux Stripe — `functions/index.js` : `exports.upgradeStripeSubscription`** (déployée) : gap découvert en répondant à la question de Christophe "est-ce que le prix se met à jour sur Stripe aussi ?" — AUCUN code ne gérait le cas d'une abonnée Stripe voulant upgrader depuis l'app ; le flux existant aurait déclenché un 2ᵉ achat In-App Purchase en parallèle de l'abonnement Stripe (double facturation, jamais résilié). Nouvelle Cloud Function qui modifie l'abonnement Stripe EXISTANT (changement d'item price + proration) au lieu d'en créer un nouveau. Réutilise les Price ID déjà connus du code (`price_1SfkUILID2pA5i1C75uu1TCH` = 2-3, `price_1SfkWULID2pA5i1CmSdrRF0c` = 4+) — **Christophe n'a pas encore confirmé sur le Dashboard Stripe que ces Price ID sont bien actifs/non archivés**, à vérifier. Côté client (`subscription_upgrade_screen.dart`), détection `_isStripeSubscription` (basée sur `subscriptionPlatform`/`subscriptionSource` == 'stripe') qui route vers `_upgradeViaStripe()` au lieu du flux IAP.
   - ⚠️ **Aucun test réel possible** contre un vrai abonnement Stripe depuis cet environnement (pas d'accès Stripe Dashboard). Seulement vérifié : `node --check` (syntaxe) + déploiement réussi.

### État des tests
- `dart analyze` clean sur les 3 fichiers modifiés (aucune erreur, seulement des warnings préexistants sans rapport).
- Testé en conditions réelles sur simulateur iOS (voir section outillage ci-dessous) : le fix `currentMemberCount` fonctionne (bouton "Passer en MAM" disparaît bien pour une structure à 2 membres réels).
- **PAS ENCORE TESTÉ** : le parcours complet des 2 nouveaux boutons de palier (2-3 / 4+) avec les bons prix affichés, la conversion effective (dev mode simulé), ni le flux Stripe réel. Christophe n'avait pas de compte solo sous la main pour tester (celui de sa femme est maintenant correctement détecté comme multi-membres, donc le bouton ne s'affiche plus pour elle — c'est le comportement voulu, mais ça empêche de re-tester avec ce compte).

### Pour reprendre demain
1. **Compte de test créé et prêt** : `claude.test.conversion.mam@poppins-test.local` / `TestConversion2026!` (compte Firebase Auth réel, structure `AssistanteMaternelle` solo, 1 membre, isolé — pas une vraie utilisatrice). Se connecter avec ce compte sur le simulateur pour voir et tester l'écran "Passer en MAM" avec les 2 nouveaux boutons.
2. Vérifier que le prix affiché est bien 3,99€ pour "1 membre" (abonnement actuel), puis tester le choix "2-3" (doit afficher 9,99€) et "4+" (14,99€), simuler la mise à niveau (mode dev, pas de vrai achat), et vérifier dans Firebase que `structureType` passe bien à `MAM` avec le bon `maxMemberCount`.
3. Demander à Christophe de vérifier les 2 Price ID Stripe sur son Dashboard avant de considérer le flux Stripe comme fiable.
4. **Committer** ces 3 fichiers modifiés (functions/index.js, dashboard_screen.dart, subscription_upgrade_screen.dart) — pas encore fait, resté dans l'arbre de travail à la pause.
5. **Ne pas réutiliser le build Android déjà fait (v2.1.8+2062)** pour la mise en prod : il a été généré AVANT ces derniers fixes (currentMemberCount, 2 boutons, Stripe). Il faut relancer `flutter build appbundle --release` après avoir committé, avant tout upload sur Play Console. Idem si Christophe relance un archive iOS.
6. Un `flutter run` tourne peut-être encore en arrière-plan sur le simulateur iOS ("iPhone 17") de la session précédente — sans effet si la machine est encore allumée, sinon il faudra relancer.

---

## 🚨 INCIDENT PROD 10/07/2026 06h-06h55 — panne totale, résolu

Le fix de la faille "remplacements" (voir plus bas) modifiait la règle générique `structures/{id}/{documentPath=**}` en ajoutant `&& documentPath[0] != 'remplacements'`. Ça a compilé sans erreur (`firebase deploy --dry-run` ne vérifie que la syntaxe), mais a provoqué une **erreur d'évaluation à l'exécution** qui a bloqué TOUTE lecture/écriture sous `structures/{id}/...` (enfants, repas, sieste, santé, photos, messages, équipements) pour TOUS les comptes, pendant ~1h ce matin. Détecté par Christophe et 2 utilisatrices dès 6h.

**Résolu à 06h55** : rollback de cette seule condition (retour à la règle d'origine sans l'exclusion `documentPath`). Confirmé par les tests emulator (voir ci-dessous) : 10/10 passent, y compris tous les scénarios d'usage quotidien normal.

**Conséquence** : la faille de sécurité "remplacements" (membre MAM/parent peut forcer un remplacement + invitation auto-approuvée) est **de nouveau ouverte** — reste à corriger, mais uniquement après validation complète dans l'émulateur, jamais par simple compilation.

**Nouveau garde-fou permanent** : `firestore-tests/` (à la racine du repo) — suite de tests `@firebase/rules-unit-testing` contre l'émulateur Firestore local, jamais contre la prod. Couvre : usage quotidien normal (assistante solo, membre MAM, parent — lecture/écriture enfants/repas/sieste), frontières de sécurité (un inconnu à la structure ne doit jamais pouvoir lire/écrire), notifications admin, avenants. **Obligatoire avant tout déploiement futur de `firestore.rules`** :
```
firebase emulators:exec --only firestore "cd firestore-tests && npm test"
```
Un seul échec → ne pas déployer. `firebase.json` a maintenant une section `emulators.firestore` (port 8080).

### 📱 Fix client Flutter — PAS ENCORE EN PROD — bug horaires signalé par Mam'aison D'apprenti'sage
Utilisatrice (`mamaisondapprentisage@laposte.net`) signale depuis le 08/07 : impossible d'ajouter/modifier les horaires d'un enfant, et depuis le 10/07 : "les enfants sont parfois supprimés du jour au lendemain sans pouvoir les rajouter".

**Bug trouvé et corrigé** : `lib/planning/planning_repository.dart::save()` faisait 6 écritures Firestore séparées non-transactionnelles (delete+set du sous-doc planning, delete en double du champ planning sur la fiche enfant, set des nouvelles données, delete du champ legacy schedule). Une interruption entre deux étapes (réseau, app en arrière-plan) pouvait supprimer l'ancien planning sans jamais écrire le nouveau → fiche enfant vidée. Simplifié en un seul `WriteBatch` atomique (2 écritures : set du sous-doc planning sans merge = remplacement complet, + set du doc enfant avec merge qui gère déjà planning ET schedule legacy en un seul appel). `dart analyze` clean.

**Vérification données actuelles** : les 23 enfants de sa structure (KV5UNpUfnGaHWR0gKyjYWQjMFIz1) ont tous un planning non-vide actuellement (2 encore en legacy `schedule` jamais migrés, le reste en nouveau format `planning`). Donc pas de perte de données visible aujourd'hui — le bug explique probablement les échecs de sauvegarde ("impossible de modifier"), mais **ne confirme pas** sa plainte "les enfants sont supprimés" (pourrait être autre chose : profil enfant entier supprimé, pas juste les horaires — pas encore identifié). À clarifier avec elle avant de considérer le sujet clos.

**⚠️ Fix client, pas serveur — ne prendra effet qu'à la prochaine sortie d'app.** Elle a aussi relancé une demande de remboursement pour un paiement en double (février) restée sans suite — action manuelle Stripe/admin, pas un bug de code.

**Statut global :** ✅ Fix changement d'email + ✅ Feature Remplacement déployés en prod (backend) — ✅ 5 correctifs UI/texte + FAQ complète 12 écrans faits mais **NON COMMITÉS** — ✅ Build Android 2.1.7+2061 prêt — 🔧 Build iOS bloqué côté compte Apple (Christophe s'en occupe) — ⚠️ Bug "Aide flottante" du 23/06 **RÉSOLU**

---

## 🔎 08–09/07/2026 — Webhook Stripe, règles Firestore, audit 3 équipes, IAP iOS

### ✅ DÉPLOYÉ EN PROD
- **Bug webhook Stripe `past_due`** : `syncStructureWithSubscription` (functions/index.js) traitait tout statut Stripe non reconnu (`past_due`, `unpaid`, `incomplete`...) comme "actif" par défaut — corrigé (ces statuts sont maintenant explicitement inactifs, plus de fallback dangereux). Backfill manuel fait sur les 2 structures déjà affectées (dont Mam'aison D'apprenti'sage / `mamaisondapprentisage@laposte.net`).
- **`firestore.rules`** : ajout d'un `isAppAdmin()` (cbeylet06@gmail.com, chrisgugu1101@gmail.com) pour réparer la diffusion de notifications admin (`admin_broadcast_notification_screen.dart` → `StructureNotificationService.broadcast()`), cassée depuis le durcissement sécurité du 30/05 (lecture globale de `structures` + écriture ciblée sur `structures/{id}/notifications`).
- **Non traité à ce stade** : l'outil `admin_screen.dart` ("corriger les relations parent-enfant") a probablement le même problème (lecture/écriture cross-structures bloquée par le même durcissement) — Christophe a choisi de ne pas l'ouvrir pour l'instant (donnerait aux 2 comptes admin un accès en lecture aux fiches enfants de toutes les structures).
- **`firestore.rules` — feature Avenant** : ajout de la règle manquante `users/{userId}/avenants/{docId}` (owner-only, `request.auth.uid == userId`), sur le modèle CDI/CDD/Engagement. La feature était intégralement cassée (`permission-denied` systématique sur brouillon/liste/finalisation).
- **`functions/index.js` — Calculs IA** : `askCalculAssistant` filtre désormais la réponse DeepSeek côté serveur (`/\d/.test(aiMessage)`) — si un chiffre apparaît malgré la consigne du system prompt, la réponse est remplacée par un message de redirection vers le calcul local au lieu d'être affichée. Déployé (fonction seule).
- **`firestore.rules` — faille de consentement Remplacement** : la règle générique `structures/{id}/{documentPath=**}` autorisait tout membre de la structure (MAM co-listé, parent) à écrire directement dans `remplacements/{id}`, contournant `createRemplacement`. Fix : `remplacements` exclu explicitement du wildcard (`documentPath[0] != 'remplacements'`), règle dédiée ajoutée — écriture toujours refusée côté client (seules les Cloud Functions Admin SDK écrivent), lecture réservée à la propriétaire réelle (`request.auth.uid == structureId`). Vérifié que les 3 usages client de cette sous-collection sont tous des lectures, aucun write direct.
- ⚠️ Un secret placeholder `APPSTORE_SHARED_SECRET` (valeur factice, PAS le vrai secret Apple) a dû être créé dans Secret Manager pour débloquer le déploiement d'`askCalculAssistant` (Firebase exige que tous les secrets référencés dans `index.js` existent, même pour un déploiement scopé à une seule fonction). À remplacer par la vraie valeur avant de jamais déployer `verifyApplePurchase`.
- **`functions/index.js` — email_change, `assistantEmail` non migré** : `updateUserEmail` migrait `ownerEmail`/`email`/`assistants/{email}` mais jamais `structures/{id}.assistantEmail` (écrit par `parent_home_screen.dart` pour un parent-employeur, lu par les notifications/Calculs IA/compteur messages non lus). Ajout de `structureAssistantEmailMatches` + migration forward/rollback sur le même modèle que les 2 champs existants. Déployé (fonction seule).
- **`functions/index.js` — email_change, écrasement silencieux d'invitation** : `updateUserEmail` ne vérifiait l'unicité du nouvel email que côté Firebase Auth, pas Firestore. Un changement vers un email correspondant à un placeholder d'invitation (`parent_home_screen.dart`, assistante invitée sans compte Auth) écrasait silencieusement ce document sans erreur. Ajout d'une lecture `users/{newEmail}` avant le batch : si le doc existe déjà, `HttpsError('already-exists', 'target-email-firestore-doc-exists')` — déjà géré côté client (`email_change_service.dart:96` mappe `already-exists` → message générique existant, aucun changement Dart nécessaire). Déployé (fonction seule).

### 📱 Fix client Flutter — PAS ENCORE EN PROD (nécessite un nouveau build)
- **`lib/routes.dart` — route `/subscription-confirmed` manquante** : après un paiement IAP/restauration réussi, `pricing_screen.dart` redirigeait vers cette route inexistante → écran "Page non trouvée" juste après un paiement réel. L'écran `SubscriptionConfirmedScreen` existait déjà tout fait (probablement retiré du routeur par erreur lors du nettoyage du 30/05, l'import était resté). Route `GoRoute('/subscription-confirmed', ...)` rajoutée, même modèle que `/upgrade-confirmed`. **⚠️ Fix client, pas serveur — ne prendra effet qu'à la prochaine sortie (build + soumission App Store/Google Play), pas immédiatement.**

### 📋 Audit 3 équipes (workflow multi-agents, résultat : voir artifact `audit-poppins.html`)
Déclenché après la découverte du bug webhook. 78 findings bruts → **33 confirmés** (12 critiques) par vérification adversariale, mais **interrompu par une limite de session** avant la fin : Équipe 2 (Abonnements) et Équipe 3 (Fonctionnalités) quasi pas vérifiées (42 findings bruts en attente). **À relancer** : `Workflow({scriptPath, resumeFromRunId: "wf_a5fab21a-c69"})` — les 18 explorations sont en cache, coût réduit.
Points saillants confirmés : faille Firestore rôle/structureId auto-modifiable, webhooks App Store/Google Play sans vérification de signature, `purgeIncompleteAccount` sans auth, feature Avenant inutilisable (règles manquantes), quota Calculs IA à 20/jour au lieu de 5.

### 🔧 Fix IAP iOS — CODE ÉCRIT, NON DÉPLOYÉ (mis en pause par Christophe)
`ios_subscription_service.dart::_verifyPurchase()` était un stub TODO qui ne validait jamais le reçu Apple — tout achat/restauration (y compris falsifié) était accepté et écrivait `status:'active'` directement depuis le client. Correctif :
- `functions/index.js` : nouvelle Cloud Function `exports.verifyApplePurchase` (onCall, region europe-west1) qui appelle `verifyReceipt` d'Apple (prod + fallback sandbox sur status 21007) et n'écrit l'abonnement dans Firestore (`subscriptions` + `structures`) qu'après confirmation — remplace l'écriture cliente.
- `ios_subscription_service.dart` : `_verifyPurchase` appelle désormais cette Cloud Function via `cloud_functions` ; l'ancienne méthode `_saveSubscriptionToFirestore` (~220 lignes, la faille) a été supprimée.
- **Bloquant pour déployer** : secret `APPSTORE_SHARED_SECRET` (App Store Connect → app → Achats intégrés en app → "Secret partagé propre à l'app") à configurer via `firebase functions:secrets:set APPSTORE_SHARED_SECRET` avant tout déploiement de cette fonction.
- **Pourquoi en pause** : Christophe indique que quasiment tous les abonnements actifs passent par Stripe, très peu par Apple IAP → impact financier actuel faible. Le code reste prêt dans le repo (non commité), à reprendre quand le secret sera fourni. Le chemin de code reste néanmoins celui emprunté par défaut par tout nouvel utilisateur iOS qui s'abonne depuis l'app (`Platform.isIOS` dans `unified_subscription_service.dart`), donc la faille reste réelle même si peu exploitée actuellement.

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
