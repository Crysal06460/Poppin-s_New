# 🚨 URGENCE — Règles Firestore à remettre en cas de panique

**Créé le :** 2026-05-25  
**Utiliser si :** des utilisateurs ne peuvent pas se connecter demain matin

---

## Commande de remise en état immédiate (30 secondes)

```bash
cd /Users/macbook/poppins
cp firestore.rules.BACKUP_AVANT_MODIFICATIONS firestore.rules
firebase deploy --only firestore:rules
```

C'est tout. Les utilisateurs se reconnectent dans la minute.

---

## Règles originales (copie de sécurité textuelle)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function canManageParentUsers() {
      return request.auth != null &&
        request.auth.token.email is string &&
        get(/databases/$(database)/documents/users/$(lower(request.auth.token.email))).data.role in ['admin', 'mamMember', 'assistant'];
    }

    match /users/{userId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && (
        userId == request.auth.uid ||
        (request.auth.token.email is string && (userId == request.auth.token.email || userId == lower(request.auth.token.email))) ||
        (canManageParentUsers() && request.resource.data.role == 'parent' && (resource == null || resource.data.role == 'parent'))
      );
      allow update: if isSignedIn() && request.resource.data.diff(resource.data).changedKeys().hasOnly(['unreadMessages']);
    }

    match /subscriptions/{docId} {
      allow read: if isSignedIn();
      allow create, update: if isSignedIn();
      allow delete: if false;
    }

    match /structures/{structureId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn();
      match /{documentPath=**} {
        allow read: if isSignedIn();
        allow write: if isSignedIn();
      }
    }

    match /exchanges/{messageId} {
      allow read, write: if isSignedIn();
    }

    match /emailQueue/{emailId} {
      allow read: if false;
      allow update, delete: if false;
      allow create: if isSignedIn() &&
        request.resource.data.to is string &&
        request.resource.data.status == 'pending' &&
        request.resource.data.createdAt == request.time &&
        request.resource.data.templateData is map;
    }

    match /invitations/{invitationId} {
      allow read: if isSignedIn();
      allow update: if isSignedIn() &&
        resource.data.email == lower(request.auth.token.email) &&
        request.resource.data.diff(resource.data).changedKeys().hasOnly(['status']) &&
        request.resource.data.status == 'completed';
      allow delete: if false;
      allow create: if isSignedIn() &&
        request.resource.data.email is string &&
        request.resource.data.structureId is string &&
        request.resource.data.childId is string &&
        request.resource.data.status is string &&
        request.resource.data.createdAt == request.time &&
        request.resource.data.expiresAt is timestamp;
    }

    match /horaires_history/{docId} {
      allow read, write: if isSignedIn();
    }

    match /notifications/{notificationId} {
      allow read: if isSignedIn() && (
        resource.data.recipientUserId == request.auth.token.email ||
        resource.data.recipientUserId == lower(request.auth.token.email) ||
        resource.data.recipientUserId == request.auth.uid
      );
      allow update: if isSignedIn() && (
        resource.data.recipientUserId == request.auth.token.email ||
        resource.data.recipientUserId == lower(request.auth.token.email) ||
        resource.data.recipientUserId == request.auth.uid
      ) && request.resource.data.diff(resource.data).changedKeys().hasOnly(['appDelivered', 'appDeliveredAt']);
      allow create, delete: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Contexte

- Ces règles étaient en prod AVANT la session du 2026-05-25
- Les règles actuelles déployées sont IDENTIQUES (la tentative de restriction subscriptions a été revertée)
- Aucun risque connu avec ces règles pour les 100 utilisateurs actifs
