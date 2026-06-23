import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:poppins_app/features/documents/models/avenant_model.dart';

class AvenantStorageService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('users').doc(userId).collection('avenants');

  // ── Brouillon ────────────────────────────────────────────────────────────────

  Future<void> sauvegarderBrouillon(String userId, AvenantModel model) async {
    await _col(userId).doc('brouillon').set({
      ...model.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDraft': true,
    }, SetOptions(merge: true));
  }

  Future<AvenantModel?> chargerBrouillon(String userId) async {
    final doc = await _col(userId).doc('brouillon').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['isDraft'] != true) return null;
    return AvenantModel.fromJson(data);
  }

  Future<void> supprimerBrouillon(String userId) async {
    await _col(userId).doc('brouillon').delete();
  }

  // ── Sauvegarde finale ────────────────────────────────────────────────────────

  Future<String> sauvegarderPdfGenere(
      String userId, Uint8List pdfBytes, String nomFichier) async {
    final ref = _storage.ref('users/$userId/avenants/$nomFichier');
    await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();

    await _col(userId).add({
      'nomFichier': nomFichier,
      'urlPdf': url,
      'createdAt': FieldValue.serverTimestamp(),
      'isDraft': false,
    });

    return url;
  }

  // ── Liste ────────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> listeAvenants(String userId) =>
      _col(userId)
          .where('isDraft', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots();

  // ── Téléchargement PDF ───────────────────────────────────────────────────────

  Future<Uint8List> telechargerPdf(String userId, String nomFichier) async {
    final ref = _storage.ref('users/$userId/avenants/$nomFichier');
    final data = await ref.getData();
    if (data == null) throw Exception('PDF introuvable');
    return data;
  }

  Future<void> supprimerAvenant(String userId, String docId, String nomFichier) async {
    await _col(userId).doc(docId).delete();
    try {
      await _storage.ref('users/$userId/avenants/$nomFichier').delete();
    } catch (_) {}
  }
}
