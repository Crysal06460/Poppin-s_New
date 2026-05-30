import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:poppins_app/features/documents/models/engagement_reciproque_model.dart';

/// Service de persistance des engagements réciproques.
///
/// - Brouillons   : Firestore `engagements_reciproques/{userId}/brouillons/current`
/// - Historique   : Firestore `engagements_reciproques/{userId}/historique/{auto-id}`
/// - PDF générés  : Firebase Storage `documents/{userId}/engagements/{nomFichier}`
class EngagementStorageService {
  EngagementStorageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  // -------------------------------------------------------------------------
  // Chemins Firestore
  // -------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _brouillonRef(String userId) =>
      _firestore
          .collection('engagements_reciproques')
          .doc(userId)
          .collection('brouillons')
          .doc('current');

  CollectionReference<Map<String, dynamic>> _historiqueRef(String userId) =>
      _firestore
          .collection('engagements_reciproques')
          .doc(userId)
          .collection('historique');

  // -------------------------------------------------------------------------
  // Brouillon
  // -------------------------------------------------------------------------

  /// Sauvegarde le brouillon courant dans Firestore.
  ///
  /// Utilise [SetOptions(merge: true)] pour ne pas écraser des champs
  /// non présents dans le JSON du modèle.
  Future<void> sauvegarderBrouillon(
    String userId,
    EngagementReciproqueModel model,
  ) async {
    final data = model.toJson()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _brouillonRef(userId).set(data, SetOptions(merge: true));
  }

  /// Charge le brouillon courant depuis Firestore.
  ///
  /// Retourne `null` si aucun brouillon n'existe encore.
  Future<EngagementReciproqueModel?> chargerBrouillon(String userId) async {
    final snapshot = await _brouillonRef(userId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    try {
      return EngagementReciproqueModel.fromJson(snapshot.data()!);
    } catch (e) {
      // Données corrompues : on retourne null plutôt que de planter.
      return null;
    }
  }

  /// Supprime le brouillon courant de Firestore.
  Future<void> supprimerBrouillon(String userId) async {
    await _brouillonRef(userId).delete();
  }

  // -------------------------------------------------------------------------
  // PDF générés
  // -------------------------------------------------------------------------

  /// Upload le PDF vers Firebase Storage et enregistre la métadonnée
  /// dans l'historique Firestore.
  ///
  /// Retourne l'URL de téléchargement publique du fichier uploadé.
  Future<String> sauvegarderPdfGenere(
    String userId,
    Uint8List pdfBytes,
    String nomFichier,
  ) async {
    // 1. Upload vers Firebase Storage
    final storageRef = _storage
        .ref()
        .child('documents')
        .child(userId)
        .child('engagements')
        .child(nomFichier);

    final uploadTask = await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // 2. Enregistrement dans Firestore (historique)
    await _historiqueRef(userId).add({
      'url': downloadUrl,
      'nomFichier': nomFichier,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  // -------------------------------------------------------------------------
  // Historique
  // -------------------------------------------------------------------------

  /// Stream sur la liste des engagements générés, triés du plus récent au plus
  /// ancien.
  ///
  /// Chaque élément contient les champs Firestore + la clé `'id'` du document.
  Stream<List<Map<String, dynamic>>> listerEngagementsGeneres(String userId) {
    return _historiqueRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...doc.data(),
                },
              )
              .toList(),
        );
  }
}
