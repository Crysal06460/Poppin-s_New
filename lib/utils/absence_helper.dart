import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AbsenceHelper {
  const AbsenceHelper._();

  static Future<Set<String>> fetchAbsentChildIds(
    String structureId, {
    DateTime? date,
  }) async {
    if (structureId.isEmpty) return const <String>{};
    final targetDate = date ?? DateTime.now();
    final docId = DateFormat('yyyy-MM-dd').format(targetDate);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('horaires')
          .doc(docId)
          .get();

      final data = snapshot.data();
      if (data == null || data.isEmpty) {
        return const <String>{};
      }

      final Set<String> absentChildIds = <String>{};
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final String actionType =
              (value['actionType'] ?? '').toString().toLowerCase();
          final bool absentFlag = value['absent'] == true;
          if (absentFlag || actionType == 'absent' || actionType == 'conge') {
            absentChildIds.add(key);
          }
        }
      });
      return absentChildIds;
    } catch (e) {
      print("⚠️ AbsenceHelper: erreur lors de la récupération des absents: $e");
      return const <String>{};
    }
  }
}
