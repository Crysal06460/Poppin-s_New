import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère les sessions "Remplacement" : une assistante remplaçante qui se
/// connecte avec SON PROPRE mot de passe pendant une fenêtre de dates active
/// reçoit, via la Cloud Function `activateRemplacementSession`, un accès
/// strictement identique à celui de la propriétaire du compte — obtenu en
/// signant à nouveau avec un `customToken` correspondant à l'UID de la
/// propriétaire (voir `functions/index.js`).
///
/// ⚠️ Tout ce que ce service stocke localement (marqueur "acting as
/// replacement") reste STRICTEMENT sur l'appareil (SharedPreferences) et
/// n'est JAMAIS écrit dans Firestore : Firestore ne peut techniquement pas
/// distinguer une session remplaçante d'une session propriétaire réelle
/// (elles partagent le même UID). L'application de la fenêtre de dates
/// repose donc sur ce service + sur les Cloud Functions, pas sur les règles
/// Firestore.
class RemplacementSessionService {
  RemplacementSessionService._();

  static final RemplacementSessionService instance =
      RemplacementSessionService._();

  static const String _kStructureIdKey = 'acting_as_replacement_structureId';
  static const String _kOwnerNameKey = 'acting_as_replacement_ownerName';
  static const String _kStructureNameKey =
      'acting_as_replacement_structureName';
  static const String _kEndDateKey = 'acting_as_replacement_endDate';
  static const String _kRemplacementIdKey = 'acting_as_replacement_id';

  /// Notifie l'UI (bandeau) de l'état courant. `null` = pas de session de
  /// remplacement active côté client.
  final ValueNotifier<Map<String, String?>?> marker = ValueNotifier(null);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _docSubscription;
  Timer? _periodicTimer;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// À appeler juste après un `signInWithEmailAndPassword` réussi, AVANT
  /// toute décision de routing basée sur le rôle. Si une fenêtre de
  /// remplacement est active pour l'email actuellement connecté, bascule la
  /// session Firebase Auth vers l'UID de la propriétaire et démarre la
  /// surveillance locale (annulation / expiration). Ne fait jamais échouer
  /// la connexion normale : toute erreur est avalée et retourne `false`.
  Future<bool> tryActivate() async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('activateRemplacementSession')
          .call();
      final Map<dynamic, dynamic>? data =
          result.data is Map ? result.data as Map : null;
      if (data == null || data['active'] != true) {
        return false;
      }

      final String? customToken = data['customToken'] as String?;
      if (customToken == null || customToken.isEmpty) {
        return false;
      }

      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      await _persistLocalMarker(
        structureId: (data['structureId'] ?? '').toString(),
        ownerName: (data['ownerName'] ?? '').toString(),
        structureName: (data['structureName'] ?? '').toString(),
        endDateIso: (data['endDate'] ?? '').toString(),
        remplacementId: (data['remplacementId'] ?? '').toString(),
      );

      startWatching();
      return true;
    } catch (e) {
      debugPrint('⚠️ RemplacementSessionService.tryActivate error: $e');
      return false;
    }
  }

  Future<void> _persistLocalMarker({
    required String structureId,
    required String ownerName,
    required String structureName,
    required String endDateIso,
    required String remplacementId,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStructureIdKey, structureId);
    await prefs.setString(_kOwnerNameKey, ownerName);
    await prefs.setString(_kStructureNameKey, structureName);
    await prefs.setString(_kEndDateKey, endDateIso);
    await prefs.setString(_kRemplacementIdKey, remplacementId);

    marker.value = {
      'structureId': structureId,
      'ownerName': ownerName,
      'structureName': structureName,
      'endDate': endDateIso,
      'remplacementId': remplacementId,
    };
  }

  Future<void> _clearLocalMarker() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStructureIdKey);
    await prefs.remove(_kOwnerNameKey);
    await prefs.remove(_kStructureNameKey);
    await prefs.remove(_kEndDateKey);
    await prefs.remove(_kRemplacementIdKey);
    marker.value = null;
  }

  /// Vérifie que la fenêtre locale n'est pas expirée. Si elle l'est (ou s'il
  /// n'y a simplement pas de marqueur local, ce qui est le cas normal pour
  /// 100% des utilisateurs sans remplacement en cours), nettoie tout état et
  /// force une déconnexion le cas échéant.
  ///
  /// Appelé :
  /// - au démarrage froid par `AuthCheckScreen` (porte d'entrée unique) pour
  ///   qu'un marqueur local périmé ne puisse jamais rouvrir un accès expiré,
  /// - toutes les minutes en foreground par le minuteur démarré via
  ///   [startWatching].
  ///
  /// Retourne `false` si une session expirée a été coupée (l'appelant doit
  /// alors rediriger vers l'écran de connexion), `true` sinon.
  Future<bool> checkStillActive() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? structureId = prefs.getString(_kStructureIdKey);
    final String? endDateIso = prefs.getString(_kEndDateKey);

    if (structureId == null ||
        structureId.isEmpty ||
        endDateIso == null ||
        endDateIso.isEmpty) {
      // Pas de marqueur local : utilisateur normal, rien à faire.
      marker.value = null;
      return true;
    }

    final DateTime? endDate = DateTime.tryParse(endDateIso);
    final bool expired = endDate == null || DateTime.now().isAfter(endDate);

    if (expired) {
      await _forceEndSession();
      return false;
    }

    marker.value = {
      'structureId': structureId,
      'ownerName': prefs.getString(_kOwnerNameKey),
      'structureName': prefs.getString(_kStructureNameKey),
      'endDate': endDateIso,
      'remplacementId': prefs.getString(_kRemplacementIdKey),
    };
    startWatching();
    return true;
  }

  /// Écoute live du doc `remplacements/{id}` (annulation immédiate par la
  /// propriétaire) + minuteur d'une minute (expiration par le temps), en
  /// complément du scheduler serveur `expireRemplacements` (15 min).
  /// Idempotent : peut être appelé plusieurs fois sans dupliquer les
  /// écouteurs.
  void startWatching() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkStillActive();
    });

    final Map<String, String?>? current = marker.value;
    final String? structureId = current?['structureId'];
    final String? remplacementId = current?['remplacementId'];
    if (structureId == null ||
        structureId.isEmpty ||
        remplacementId == null ||
        remplacementId.isEmpty) {
      return;
    }

    _docSubscription?.cancel();
    _docSubscription = FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('remplacements')
        .doc(remplacementId)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
      final String status = (snap.data()?['status'] ?? '').toString();
      if (!snap.exists || status == 'cancelled' || status == 'expired') {
        _forceEndSession();
      }
    }, onError: (_) {
      // Pas de panique en cas d'erreur réseau ponctuelle : le minuteur et
      // AuthCheckScreen restent des filets de sécurité.
    });
  }

  void stopWatching() {
    _docSubscription?.cancel();
    _docSubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> _forceEndSession() async {
    stopWatching();
    await _clearLocalMarker();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Fin volontaire de session, déclenchée par le bouton "Terminer
  /// maintenant" du bandeau.
  Future<void> endSessionManually() => _forceEndSession();
}
