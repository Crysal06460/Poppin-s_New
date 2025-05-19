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
    );
  }
}
