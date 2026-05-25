# Rapport Agent 2 — Onglet Documents dans Dashboard/Administration

**Date :** 2026-05-25
**Statut :** TERMINÉ

---

## Résumé des modifications

### Fichiers créés
- `lib/screens/documents_screen.dart` — Écran complet de gestion des documents professionnels

### Fichiers modifiés
- `lib/screens/dashboard_screen.dart` — Ajout de l'entrée "Documents professionnels" dans l'administration

---

## Ce qui a été implémenté

### `lib/screens/documents_screen.dart`

Écran autonome `DocumentsScreen(structureId: String)` avec :

**Types de documents gérés :**
- Diplôme secourisme (PSC1/AFGSU)
- Assurance responsabilité civile professionnelle
- Agrément assistante maternelle
- Formation continue
- Autre document (nom personnalisé)

**Fonctionnalités :**
- Upload de fichiers PDF/JPG/PNG (via file_picker, compatible web et mobile)
- Sauvegarde dans Firebase Storage : `structures/{structureId}/documents/{filename}`
- Métadonnées dans Firestore : `structures/{structureId}/documents/{docId}`
  - `type`, `name`, `url`, `uploadedAt`, `expiresAt` (optionnel), `uploadedBy`
- Date d'expiration optionnelle avec badge de statut (Valide / Expire bientôt / Expiré)
  - "Expire bientôt" = moins de 30 jours avant expiration
  - "Expiré" = date passée
- Suppression avec confirmation (supprime Storage + Firestore)
- Ouverture du document dans le navigateur externe
- FAB "Ajouter" pour ouvrir le sheet d'ajout
- Pull-to-refresh via bouton dans AppBar

**Design UX/UI :**
- Cards avec borderRadius 16/20, ombres douces
- Couleurs officielles de l'app
- Badge de statut coloré sur chaque card
- Bottom sheet d'ajout avec sélecteur de type (chips animés)
- Indicateur de progression pendant l'upload
- SnackBar de feedback après chaque action

### `lib/screens/dashboard_screen.dart`

**Méthode ajoutée :**
- `_openDocuments()` : récupère l'ID de structure via `_getStructureId()` puis navigue vers `DocumentsScreen`

**Mobile (bottom sheet administration) :**
- Nouvelle entrée "Documents professionnels" dans `_openMamAdministration()`
- Disponible pour tous les types de structure (MAM et AssistanteMaternelle)

**Tablette (panel latéral) :**
- Nouvelle entrée "Documents professionnels" dans `_buildStructureActions()`
- Affichée après les sections MAM/Assmat avec icône `Icons.folder_rounded`

**Import ajouté :**
```dart
import 'package:poppins_app/screens/documents_screen.dart';
```

---

## Dépendances utilisées (déjà présentes dans pubspec.yaml)
- `firebase_storage: ^12.4.1` — upload des fichiers
- `cloud_firestore: ^5.5.1` — métadonnées
- `firebase_auth: ^5.3.2` — identification de l'utilisateur
- `file_picker: ^10.1.2` — sélection de fichiers
- `url_launcher: ^6.1.10` — ouverture des documents

Aucune nouvelle dépendance à ajouter.

---

## Déploiement

Aucune modification de routes.dart nécessaire (navigation directe via `Navigator.push`).
Ne pas déployer en production sans validation manuelle.
