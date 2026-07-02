// email_change_service.dart
//
// Logique partagée pour le changement d'email self-service, mutualisée entre
// structure_management_screen.dart et parent_settings_screen.dart (qui
// avaient chacun leur propre implémentation quasi identique de _changeEmail).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'biometric_auth_service.dart';

class EmailChangeService {
  EmailChangeService._();

  /// Ré-authentifie l'utilisateur courant avec son mot de passe actuel puis
  /// déclenche la migration serveur (Cloud Function `updateUserEmail` en
  /// europe-west1) vers [newEmail]. La Cloud Function fait tout le travail de
  /// migration Firestore (users/{email}, structures, members, assistants,
  /// enfants) puis met à jour Firebase Auth en dernier.
  ///
  /// En cas de succès, invalide également les données locales (biométrie,
  /// email mémorisé pour la reconnexion rapide) qui étaient liées à l'ancien
  /// email, AVANT que l'appelant ne déclenche la déconnexion forcée déjà en
  /// place — cela évite un accès biométrique fantôme sur l'ancien email après
  /// le changement.
  ///
  /// Retourne `true` en cas de succès. En cas d'échec, retourne `false` et
  /// appelle [onError] avec un message lisible par l'utilisateur.
  static Future<bool> changeEmail(
    String newEmail,
    String password,
    void Function(String message) onError,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onError("Utilisateur non connecté");
        return false;
      }

      final String? oldEmail = user.email;
      if (oldEmail == null || oldEmail.isEmpty) {
        onError("Impossible de déterminer votre email actuel.");
        return false;
      }

      final String normalizedNewEmail = newEmail.trim().toLowerCase();
      if (normalizedNewEmail.isEmpty) {
        onError("Le nouvel email est requis.");
        return false;
      }
      if (oldEmail.trim().toLowerCase() == normalizedNewEmail) {
        onError("Le nouvel email doit être différent de l'actuel.");
        return false;
      }

      // 1. Ré-authentification côté client (le mot de passe ne sert qu'ici,
      // il n'est jamais envoyé à la Cloud Function).
      final cred = EmailAuthProvider.credential(
        email: oldEmail,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // 2. Appel Cloud Function : migration Firestore + Auth côté serveur.
      // Le trust boundary est request.auth côté fonction, pas les données
      // envoyées par le client : on n'envoie donc que le newEmail.
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('updateUserEmail');

      await callable.call({'newEmail': normalizedNewEmail});

      // 3. Invalider les données locales liées à l'ancien email avant que
      // l'appelant ne déconnecte l'utilisateur.
      await _invalidateLocalStateForOldEmail(oldEmail);

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        onError("Mot de passe incorrect.");
      } else {
        onError("Erreur d'authentification: ${e.message}");
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      onError(_messageForFunctionError(e));
      return false;
    } catch (e) {
      onError("Une erreur est survenue: $e");
      return false;
    }
  }

  static String _messageForFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'already-exists':
        return "Cet email est déjà utilisé par un autre compte.";
      case 'invalid-argument':
        return "Adresse email invalide.";
      case 'not-found':
        return "Compte introuvable. Contactez le support.";
      case 'failed-precondition':
        return "Impossible de traiter cette demande pour le moment.";
      default:
        return e.message ??
            "Une erreur est survenue lors du changement d'email.";
    }
  }

  /// Efface/désactive tout ce qui, côté appareil, était indexé sur l'ancien
  /// email : credential biométrique, flag d'activation, entrée dans la liste
  /// des comptes biométriques, "dernier email" biométrique, et l'email
  /// mémorisé pour la reconnexion rapide (AuthCheckScreen / QuickLoginScreen).
  static Future<void> _invalidateLocalStateForOldEmail(String oldEmail) async {
    final String normalizedOldEmail = oldEmail.trim().toLowerCase();

    try {
      await BiometricAuthService.instance.disableBiometrics(normalizedOldEmail);
    } catch (_) {
      // Non bloquant : le pire cas est un ré-enrôlement biométrique manuel.
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedEmail = prefs.getString('saved_email');
      if (savedEmail != null &&
          savedEmail.trim().toLowerCase() == normalizedOldEmail) {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_email', false);
      }
    } catch (_) {
      // Non bloquant.
    }
  }
}
