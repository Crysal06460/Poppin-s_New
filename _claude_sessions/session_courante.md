# Session courante — Poppins App

**Dernière mise à jour :** 2026-06-23 (session chrisbeylet@gmail.com)
**Statut global :** ✅ CDI ✅ CDD ✅ Avenant ✅ Engagement Réciproque (Documents) — ✅ Calculs IA déployé — 🔧 Aide flottante EN COURS (bug à résoudre) — **TOUT VIENT D'ÊTRE COMMITÉ**

---

## 🆕 Feature "Calculs" — mensualisation + chat IA (22/06/2026) — ✅ DÉPLOYÉ

### Ce qui existe
- Menu Dashboard → Administration → **"Calculs"** (nouvelle entrée, à côté de "Mes Documents"/"Contrats")
- `lib/features/calculs/screens/calculs_home_screen.dart` — écran d'accueil conversationnel : 2 boutons
  - "Calculer une mensualisation" → `mensualisation_form_screen.dart` (calcul 100% local, formule : heures_hebdo × semaines ÷ 12 × tarif)
  - "Poser une question à l'IA Poppin's" → `calculs_chat_screen.dart` (chat connecté à la Cloud Function)
- `lib/features/calculs/models/mensualisation_params.dart` — calcul déterministe, pas de Firestore

### Backend — Cloud Function `askCalculAssistant` (functions/index.js, ~ligne 3890)
- **Fournisseur : OpenAI `gpt-4o-mini`** (PAS Kimi — testé et abandonné, voir note ci-dessous)
- Secret Firebase : `OPENAI_API_KEY` (configuré via `firebase functions:secrets:set`, jamais en clair dans le code)
- Rate limit : **20 questions/jour/utilisateur actuellement** (⚠️ TEMPORAIRE pour tests internes — **remettre à 5 avant publication publique**, TODO déjà inscrit dans le code à la ligne `CALCUL_ASSISTANT_MAX_QUESTIONS_PER_DAY`)
- Filtre mots-clés en amont (pas d'appel IA si hors-sujet, donc zéro coût)
- Règle stricte dans le system prompt : **l'IA ne fait JAMAIS de calcul chiffré elle-même** — elle explique le principe et renvoie vers le formulaire local. Raison : testé en réel, Kimi K2 ET gpt-4o-mini se trompaient tous les deux sur le calcul exact (mauvaise prise en compte des semaines de congés). Le formulaire local reste la seule source fiable.
- Disclaimer visible dans le chat (au-dessus du champ de saisie, toujours visible) : "L'IA peut se tromper : vérifiez les informations importantes."
- Firestore : `users/{uid}/aiUsage/{date}` verrouillé côté client (`allow read, write: if false`), uniquement modifiable par la Cloud Function (Admin SDK)

### Historique technique (pour ne pas refaire les mêmes erreurs)
1. Essayé Kimi K2 (Moonshot AI) en premier → modèle "reasoning", consomme tous les tokens en réflexion interne, réponse vide si max_tokens trop bas → augmenté à 500, ça répondait mais avec des calculs FAUX
2. Basculé sur OpenAI gpt-4o-mini sur demande de Christophe → toujours des erreurs de calcul sur les congés payés → solution finale : interdire à l'IA tout calcul chiffré, elle renvoie systématiquement vers le formulaire local
3. **Clés API collées en clair dans le chat Claude** (Kimi puis OpenAI) → configurées comme secrets Firebase immédiatement, mais **recommandation en attente : régénérer ces clés côté fournisseur par précaution** (pas fait à ce jour)

---

## 🆕 Feature "Aide flottante" — bouton d'aide global (22-23/06/2026) — 🔧 BUG EN COURS, NON RÉSOLU

### Concept (validé avec Christophe)
- Bouton flottant rond bleu (icône `?`) visible sur **tous les écrans connectés**, position bas-droite
- Tap → bottom sheet avec FAQ statique **adaptée à l'écran courant** (PAS d'IA ici — décision explicite de Christophe pour limiter les coûts, contrairement au module Calculs)
- Approche en 2 niveaux : V1 = FAQ statique pré-écrite (en cours), V2 = IA contextuelle (pas commencée, pas décidée)

### Fichiers créés
- `lib/features/aide/aide_route_observer.dart` — `ValueNotifier<String> currentRoutePath` + `attachAideRouteTracking(router)` (écoute `router.routeInformationProvider`, appelé dans `main.dart` `initState`)
- `lib/features/aide/aide_faq_data.dart` — FAQ statique rédigée par Claude à partir du code (PAS ENCORE VALIDÉE par Christophe) pour `/repas` et `/sieste` (3 questions chacun)
- `lib/features/aide/aide_floating_button.dart` — le bouton + bottom sheet
- `lib/main.dart` modifié : `builder` de `MaterialApp.router` enveloppe `child` dans un `Stack` avec `AideFloatingButton()` en overlay global

### 🐛 BUG ACTUEL — NON RÉSOLU, À REPRENDRE ICI
**Symptôme 1 (résolu) :** le tap sur le bouton ne faisait rien → cause identifiée : le `context` du `builder` de `MaterialApp.router` est **au-dessus** du `Navigator` (pas dedans), donc `showModalBottomSheet(context: context)` ne trouvait aucun Navigator ancêtre et échouait silencieusement. **Fix appliqué :** utiliser `rootNavigatorKey.currentContext` (exporté depuis `routes.dart`) au lieu du context local dans `_openFaq()`.

**Symptôme 2 (PAS résolu) :** après ce fix + hot restart, **le bouton a complètement disparu** de l'écran (plus aucune pastille visible nulle part). Aucune erreur de compilation détectée (`flutter analyze` propre). Cause non identifiée — hypothèses non vérifiées :
- Hot restart qui n'a pas réellement pris (bug simulateur) → **à tester : kill complet de l'app + `flutter run` propre**
- Exception runtime silencieuse dans `attachAideRouteTracking` ou le `ValueListenableBuilder` → **à vérifier : logs console Flutter au démarrage**
- Christophe n'a pas encore renvoyé les logs console malgré la demande

**Prochaine étape impérative à la reprise :** demander à Christophe de relancer l'app avec `flutter run` (pas juste hot restart) et de copier-coller la sortie console complète, en particulier toute ligne en rouge ou tout `FlutterError` au démarrage ou au tap.

---

## ✅ Feature Documents — CDI/CDD/Avenant/Engagement (12-15 juin 2026)

Détails complets inchangés depuis la dernière session — voir contenu précédent de ce fichier conservé dans l'historique git. Résumé : 4 types de documents contractuels complets (wizard + PDF NotoSans/OpenSans + storage Firebase + intégration dashboard via menu "Contrats"), style PDF unifié, tous les bugs connus corrigés (cases à cocher vectorielles, exposants ASCII, hot reload PDFViewerScreen, headers/footers, "Lu et approuvé" avec accent).

⚠️ **Tests sur device réel toujours pas explicitement confirmés** (CDI, CDD avec/sans Parent 2, Avenant, Engagement, vérification persistance Firebase) — committé quand même sur demande explicite de Christophe le 23/06/2026 pour ne rien perdre, **mais à tester avant toute publication en production**.

---

## 📦 Commit du 23/06/2026

Tout le travail en attente a été commité en une fois sur demande explicite de Christophe ("sauvegarde TOUT") :
- Feature Documents (CDI/CDD/Avenant/Engagement) — non testée sur device, voir avertissement ci-dessus
- Feature Calculs (mensualisation + chat IA OpenAI) — déployée et fonctionnelle
- Feature Aide flottante — bug en cours, bouton invisible après le dernier fix
- Divers : transmissions_screen.dart, stock_screen.dart, parent_home_screen.dart, subscription_service.dart, pdf_generator_service.dart, monthly-assistant-recap.html — modifications déjà en cours avant cette session, contenu exact non ré-audité ici, voir `git show` sur le commit pour le détail

---

## 🐛 Bugs non résolus / tâches restantes

1. **Bug bouton d'aide flottant invisible** (voir section dédiée ci-dessus) — PRIORITÉ à la reprise
2. **Rate limit Calculs IA à remettre à 5/jour** avant publication publique (actuellement 20 pour tests internes)
3. **Clés API Kimi + OpenAI collées en clair dans le chat** — recommandé de les régénérer côté fournisseur par précaution, pas fait
4. **FAQ aide flottante non validée** par Christophe (rédigée par Claude à partir du code, à relire avant extension à d'autres écrans)
5. **Soumettre 2.1.5 aux stores** (en attente depuis plusieurs sessions)
   - iOS : `Product > Archive` dans Xcode → App Store Connect
   - Android : upload `app-release.aab` 2.1.5 sur Google Play Console
6. **Faux message orange "Échec envoi"** dans `child_financial_info_screen.dart` → wrapper update user dans try/catch séparé
7. **Règles Firestore subscriptions** (après déploiement app)
8. **Tests device réel Documents** jamais explicitement confirmés (voir section Documents ci-dessus)

---

## 📝 Infos essentielles toujours valides

- App en production ~100 utilisateurs actifs/jour — NE PAS casser
- Admin : cbeylet06@gmail.com, chrisgugu1101@gmail.com
- chrisgugu1101@gmail.com = Christelle (femme de Christophe) — utilise l'app tous les jours
- Deux comptes Claude sur même Mac (chrisbeylet@gmail.com + cbeylet06@gmail.com) : lire ce fichier à chaque session
- structureId Christelle : euAkwrpTFEMeH1GXjJQcUy8yLO53
- Projet Firebase : `poppin-s-app`, région Cloud Functions : `europe-west1`
