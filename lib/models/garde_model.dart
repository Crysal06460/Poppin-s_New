import 'package:cloud_firestore/cloud_firestore.dart';

class Garde {
  final String id;
  final String enfantId;
  final String membreId;
  final String mamId;
  final int jourSemaine; // 1=lundi, 2=mardi...
  final String heureDebut; // Format "HH:MM"
  final String heureFin; // Format "HH:MM"
  final bool recurrent;
  final DateTime? dateException; // Pour un jour spécifique, nullable
  // Champs d'affichage (non persistés) pour gérer les délégations à la journée
  final bool isDelegated; // True si garde déléguée pour ce jour
  final String? delegatedFromMembreId; // Membre d'origine
  final String? delegationId; // Id de la délégation

  Garde({
    required this.id,
    required this.enfantId,
    required this.membreId,
    required this.mamId,
    required this.jourSemaine,
    required this.heureDebut,
    required this.heureFin,
    this.recurrent = true,
    this.dateException,
    this.isDelegated = false,
    this.delegatedFromMembreId,
    this.delegationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'enfantId': enfantId,
      'membreId': membreId,
      'mamId': mamId,
      'jourSemaine': jourSemaine,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'recurrent': recurrent,
      'dateException':
          dateException != null ? Timestamp.fromDate(dateException!) : null,
    };
  }

  Garde copyWith({
    String? id,
    String? enfantId,
    String? membreId,
    String? mamId,
    int? jourSemaine,
    String? heureDebut,
    String? heureFin,
    bool? recurrent,
    DateTime? dateException,
    bool clearDateException = false,
    bool? isDelegated,
    String? delegatedFromMembreId,
    String? delegationId,
  }) {
    return Garde(
      id: id ?? this.id,
      enfantId: enfantId ?? this.enfantId,
      membreId: membreId ?? this.membreId,
      mamId: mamId ?? this.mamId,
      jourSemaine: jourSemaine ?? this.jourSemaine,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      recurrent: recurrent ?? this.recurrent,
      dateException:
          clearDateException ? null : (dateException ?? this.dateException),
      isDelegated: isDelegated ?? this.isDelegated,
      delegatedFromMembreId:
          delegatedFromMembreId ?? this.delegatedFromMembreId,
      delegationId: delegationId ?? this.delegationId,
    );
  }
}
