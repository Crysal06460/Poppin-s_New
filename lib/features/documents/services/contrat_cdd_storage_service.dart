import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:poppins_app/features/documents/models/contrat_cdd_model.dart';

class ContratCddStorageService {
  ContratCddStorageService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _brouillonRef(String userId) =>
      _firestore.collection('contrats_cdd').doc(userId).collection('brouillons').doc('current');

  CollectionReference<Map<String, dynamic>> _historiqueRef(String userId) =>
      _firestore.collection('contrats_cdd').doc(userId).collection('historique');

  Future<void> sauvegarderBrouillon(String userId, ContratCddModel model) async {
    final data = model.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
    await _brouillonRef(userId).set(data, SetOptions(merge: true));
  }

  Future<ContratCddModel?> chargerBrouillon(String userId) async {
    final snapshot = await _brouillonRef(userId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    try {
      return ContratCddModel.fromJson(snapshot.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> supprimerBrouillon(String userId) async {
    await _brouillonRef(userId).delete();
  }

  Future<String> sauvegarderPdfGenere(String userId, Uint8List pdfBytes, String nomFichier) async {
    final storageRef = _storage.ref().child('documents').child(userId).child('contrats_cdd').child(nomFichier);
    final uploadTask = await storageRef.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    await _historiqueRef(userId).add({
      'url': downloadUrl,
      'nomFichier': nomFichier,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return downloadUrl;
  }

  Future<void> supprimerContrat(String userId, String docId, String nomFichier) async {
    await _historiqueRef(userId).doc(docId).delete();
    try {
      await _storage.ref().child('documents').child(userId).child('contrats_cdd').child(nomFichier).delete();
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> listerContratsGeneres(String userId) {
    return _historiqueRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
