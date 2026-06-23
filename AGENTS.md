# Poppins App — Contexte Codex (mis à jour automatiquement)

> **IMPORTANT** : Ce fichier est lu par Codex à chaque session (même en changeant de compte).
> Il contient tout le contexte nécessaire pour reprendre le travail sans réexpliquer.
> Comptes admin : chrisbeylet@gmail.com et cbeylet06@gmail.com (même Mac, user `macbook`)

---

## 🏗️ Description du projet

**Poppins** est une application Flutter (iOS + Android) destinée aux **assistantes maternelles** et **MAMs** (Maisons d'Assistantes Maternelles) en France.

- **~100 utilisateurs actifs par jour** — production réelle, NE PAS casser
- Backend : **Firebase** (Firestore, Auth, Cloud Functions, Storage)
- Paiements : **Stripe** (via webhook Cloud Functions) + **In-App Purchase** iOS/Android
- Emails : **Mailjet** (via Cloud Functions)

## 📁 Structure clé

```
lib/
  main.dart                          # Point d'entrée
  routes.dart                        # GoRouter navigation
  theme/app_colors.dart              # Couleurs: primaryRed #D94350, primaryBlue #3D9DF2, lightBlue #DFE9F2, brightCyan #05C7F2, primaryYellow #F2B705
  screens/
    dashboard_screen.dart            # Écran principal après login
    admin_screen.dart                # Admin maintenance DB
    admin_subscription_dashboard_screen.dart  # Admin abonnements
    admin_broadcast_notification_screen.dart  # Admin notifications push
    parent_messages_screen.dart      # Messagerie parent ↔ assistante
    mam_group_chat_screen.dart       # Chat groupe MAM
    subscription_screen.dart         # Écran abonnement
    trial_pricing_info_screen.dart   # Info période d'essai
  services/
    unified_subscription_service.dart  # Service principal abonnements iOS+Android
    ios_subscription_service.dart      # IAP iOS
    android_subscription_service.dart  # IAP Android
    subscription_service.dart          # Service abonnement Firebase
    firebase_trial_service.dart        # Gestion période d'essai Firebase
    subscription_helper.dart           # Helpers abonnement
  models/
    subscription_model.dart          # Modèles (SubscriptionStatus, SubscriptionPlan, SubscriptionInfo)
  widgets/
    subscription_summary_widget.dart
    custom_bottom_navigation.dart
    custom_scaffold.dart
functions/
  index.js                           # Toutes les Cloud Functions (Stripe webhooks, emails, etc.)
```

## 💳 Système d'abonnement

### Plans tarifaires
- Assistante Maternelle : **3,99€/mois**
- MAM 2 membres : **9,99€/mois**
- MAM 3 membres : **9,99€/mois**
- MAM 4+ membres : **14,99€/mois**

### Flow complet
1. **Inscription** → période d'essai gratuite (géré par `firebase_trial_service.dart`)
2. **Fin d'essai** → redirection vers `subscription_screen.dart`
3. **Paiement** → via Stripe (web/redirect) OU IAP iOS/Android (`unified_subscription_service.dart`)
4. **Webhook Stripe** → `functions/index.js` → mise à jour statut Firebase
5. **Vérification** → `subscription_service.dart` lit le statut dans Firestore

### Statuts possibles (Firestore)
- `trial` — période d'essai en cours
- `active` — abonnement actif payé
- `expired` — expiré (ne peut plus se connecter)
- `cancelled` — annulé

### Problèmes connus identifiés
- Certains utilisateurs ont `expired` dans Firebase mais abonnement actif sur Stripe
- L'inverse peut aussi arriver (accès sans paiement)
- Webhook Stripe potentiellement manquant ou mal configuré

## 💬 Messagerie

- `parent_messages_screen.dart` — messagerie texte + fichiers entre parent et assistante
- `mam_group_chat_screen.dart` — chat groupe pour les MAMs
- **À AJOUTER** : messages vocaux (Agent 3)

## 🎛️ Dashboard — Onglets Admin

Le dashboard a des onglets administration. **À AJOUTER** : onglet "Documents" (Agent 2)
- Diplômes secourisme, assurance civile, etc.
- Lié à l'utilisateur dans Firebase
- Design UX/UI 2026

## 👤 Comptes développeur

- Admin app : `cbeylet06@gmail.com`, `chrisgugu1101@gmail.com`
- Compte Codex principal : `chrisbeylet@gmail.com`
- Compte Codex secondaire : `cbeylet06@gmail.com`
- Les deux comptes travaillent sur `/Users/macbook/poppins` (même Mac)

## 🚨 Règles absolues

1. **NE PAS** déployer en production sans vérification manuelle
2. **NE PAS** modifier les Cloud Functions sans backup
3. **TOUJOURS** tester en local/sandbox avant prod
4. **BACKUP** obligatoire avant toute modification critique
5. Les 100 utilisateurs quotidiens ne doivent jamais être impactés

---

## 📋 Sessions de travail — État courant

Voir `_claude_sessions/session_courante.md` pour l'état précis du travail en cours.
