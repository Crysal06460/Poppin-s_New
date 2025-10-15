import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';

class PdfEmailService {
  static Future<void> generateAndSendChildHistory(String childId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Récupérer l'ID de structure
      String structureId = await _getStructureId(user);

      // Récupérer les données de l'enfant
      final childData = await _getChildData(structureId, childId);
      if (childData == null) throw Exception('Enfant non trouvé');

      // Récupérer l'historique complet
      final historyData = await _getCompleteHistory(structureId, childId);

      // Générer le PDF
      final pdfData = await _generatePdf(childData, historyData);

      // Convertir en base64 pour l'email
      final pdfBase64 = base64Encode(pdfData);

      // Envoyer l'email aux parents et à l'assistante maternelle
      await _sendEmailWithPdf(childData, pdfBase64, structureId);

      // Supprimer toutes les données de l'enfant
      await _deleteChildData(structureId, childId);

      print("✅ Historique généré et envoyé avec succès");
    } catch (e) {
      print("❌ Erreur lors de la génération: $e");
      throw e;
    }
  }

  static Future<String> _getStructureId(User user) async {
    final userEmail = user.email?.toLowerCase() ?? '';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data() ?? {};
      if (userData['role'] == 'mamMember' && userData['structureId'] != null) {
        return userData['structureId'];
      }
    }
    return user.uid;
  }

  static Future<Map<String, dynamic>?> _getChildData(
      String structureId, String childId) async {
    final doc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(childId)
        .get();

    if (doc.exists) {
      return {...doc.data()!, 'id': doc.id};
    }
    return null;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _getCompleteHistory(
      String structureId, String childId) async {
    Map<String, List<Map<String, dynamic>>> history = {};

    // Collections à récupérer
    final collections = [
      'repas',
      'activites',
      'siestes',
      'changes',
      'sante',
      'transmissions'
    ];

    for (String collection in collections) {
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection(collection)
          .orderBy('date', descending: false)
          .get();

      history[collection] =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    }

    // Récupérer les horaires
    final horairesSnapshot = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('horaires_history')
        .where('childId', isEqualTo: childId)
        .orderBy('timestamp', descending: false)
        .get();

    history['horaires'] =
        horairesSnapshot.docs.map((doc) => doc.data()).toList();

    return history;
  }

  static Future<Uint8List> _generatePdf(Map<String, dynamic> childData,
      Map<String, List<Map<String, dynamic>>> historyData) async {
    final pdf = pw.Document();

    // Page de titre
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Historique complet de ${childData['firstName']}',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Prénom: ${childData['firstName']}'),
              pw.Text('Nom: ${childData['lastName'] ?? 'Non renseigné'}'),
              pw.Text(
                  'Date de naissance: ${_formatDate(childData['birthdate'])}'),
              pw.Text('Genre: ${childData['gender'] ?? 'Non renseigné'}'),
              pw.Text(
                  'Email parent(s): ${childData['parentEmail'] ?? 'Non renseigné'}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Document généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                style:
                    pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );

    // Organiser les données par date
    final dataByDate = _organizeDataByDate(historyData);

    // Générer une page par période (par exemple par mois)
    final sortedDates = dataByDate.keys.toList()..sort();

    for (String date in sortedDates) {
      final dayData = dataByDate[date]!;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 1,
                  child: pw.Text(
                    _formatDateHeader(date),
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 10),
                ..._buildDayContent(dayData),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  static Map<String, Map<String, List<Map<String, dynamic>>>>
      _organizeDataByDate(Map<String, List<Map<String, dynamic>>> historyData) {
    Map<String, Map<String, List<Map<String, dynamic>>>> dataByDate = {};

    historyData.forEach((collection, items) {
      for (var item in items) {
        String date;
        if (item['date'] is Timestamp) {
          date = DateFormat('yyyy-MM-dd')
              .format((item['date'] as Timestamp).toDate());
        } else if (item['timestamp'] is Timestamp) {
          date = DateFormat('yyyy-MM-dd')
              .format((item['timestamp'] as Timestamp).toDate());
        } else {
          continue; // Skip si pas de date
        }

        if (!dataByDate.containsKey(date)) {
          dataByDate[date] = {};
        }
        if (!dataByDate[date]!.containsKey(collection)) {
          dataByDate[date]![collection] = [];
        }
        dataByDate[date]![collection]!.add(item);
      }
    });

    return dataByDate;
  }

  static List<pw.Widget> _buildDayContent(
      Map<String, List<Map<String, dynamic>>> dayData) {
    List<pw.Widget> widgets = [];

    // Horaires
    if (dayData.containsKey('horaires') && dayData['horaires']!.isNotEmpty) {
      widgets.add(pw.Text('🕐 HORAIRES',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var horaire in dayData['horaires']!) {
        if (horaire['actionType'] == 'absent') {
          widgets.add(pw.Text('  • Enfant absent'));
        } else {
          final segments = horaire['segments'] as List?;
          if (segments != null) {
            for (var segment in segments) {
              if (segment['arrivee'] != null) {
                widgets.add(pw.Text('  • Arrivée: ${segment['arrivee']}'));
              }
              if (segment['depart'] != null) {
                widgets.add(pw.Text('  • Départ: ${segment['depart']}'));
                if (segment['km'] != null) {
                  widgets.add(pw.Text('    Kilomètres: ${segment['km']} km'));
                }
              }
            }
          }
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    // Repas
    if (dayData.containsKey('repas') && dayData['repas']!.isNotEmpty) {
      widgets.add(pw.Text('🍽️ REPAS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var repas in dayData['repas']!) {
        final String rawMoment = (repas['moment'] ?? '').toString();
        final String momentLabel = rawMoment.isNotEmpty
            ? rawMoment
            : (repas['gouter'] == true ? 'Goûter' : '');
        final String rawType = (repas['typeAlimentation'] ?? '').toString();
        final bool isBiberon = rawType == 'Biberon' || repas['biberon'] == true;
        final bool isAllaitement = rawType == 'Allaitement' || repas['allaitement'] == true;
        final bool isSolide = rawType == 'Solide';
        final bool isMixte = rawType == 'Mixte';
        final String typeLabel = rawType.isNotEmpty
            ? rawType
            : isBiberon
                ? 'Biberon'
                : isAllaitement
                    ? 'Allaitement'
                    : (momentLabel.isNotEmpty ? momentLabel : 'Repas');
        final String description =
            (repas['alimentationDescription'] ?? '').toString();
        final String qualite = (repas['qualite'] ?? '').toString();

        String content = '  • ${repas['heure']} - ';
        String detail;
        if (isBiberon) {
          detail = 'Biberon ${repas['ml']}ml';
        } else if (isAllaitement) {
          detail = 'Allaitement';
        } else if (isSolide || isMixte) {
          final String descOrQualite =
              description.isNotEmpty ? description : qualite;
          detail = descOrQualite.isNotEmpty
              ? '$typeLabel - $descOrQualite'
              : typeLabel;
        } else {
          detail = qualite.isNotEmpty ? qualite : typeLabel;
        }

        if (momentLabel.isNotEmpty && !detail.startsWith(momentLabel)) {
          content += '$momentLabel - $detail';
        } else {
          content += detail;
        }
        widgets.add(pw.Text(content));
        if (repas['observations']?.isNotEmpty == true) {
          widgets.add(pw.Text('    Observations: ${repas['observations']}'));
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    // Activités
    if (dayData.containsKey('activites') && dayData['activites']!.isNotEmpty) {
      widgets.add(pw.Text('🎨 ACTIVITÉS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var activite in dayData['activites']!) {
        widgets.add(pw.Text('  • ${activite['heure']} - ${activite['type']}'));
        widgets.add(pw.Text('    Durée: ${activite['duration']}'));
        widgets.add(pw.Text('    Participation: ${activite['participation']}'));
        if (activite['observations']?.isNotEmpty == true) {
          widgets.add(pw.Text('    Observations: ${activite['observations']}'));
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    // Siestes
    if (dayData.containsKey('siestes') && dayData['siestes']!.isNotEmpty) {
      widgets.add(pw.Text('😴 SIESTES',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var sieste in dayData['siestes']!) {
        widgets.add(
            pw.Text('  • ${sieste['heure']} - Durée: ${sieste['duration']}'));
        widgets.add(pw.Text('    Qualité: ${sieste['qualite']}'));
        if (sieste['observations']?.isNotEmpty == true) {
          widgets.add(pw.Text('    Observations: ${sieste['observations']}'));
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    // Changes
    if (dayData.containsKey('changes') && dayData['changes']!.isNotEmpty) {
      widgets.add(pw.Text('👶 CHANGES',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var change in dayData['changes']!) {
        String content = '  • ${change['heure']} - ${change['type']}';
        List<String> details = [];
        if (change['pipi'] == true) details.add('Pipi');
        if (change['selles'] == true) details.add('Selles');
        if (details.isNotEmpty) content += ' (${details.join(', ')})';
        widgets.add(pw.Text(content));

        if (change['soins'] != null && (change['soins'] as List).isNotEmpty) {
          widgets.add(
              pw.Text('    Soins: ${(change['soins'] as List).join(', ')}'));
        }
        if (change['observations']?.isNotEmpty == true) {
          widgets.add(pw.Text('    Observations: ${change['observations']}'));
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    // Santé
    if (dayData.containsKey('sante') && dayData['sante']!.isNotEmpty) {
      widgets.add(pw.Text('🏥 SANTÉ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var sante in dayData['sante']!) {
        String content = '  • ${sante['heure']} - ${sante['type']}';
        if (sante['type'] == 'Température') {
          content += ' ${sante['temperature']}° (${sante['route']})';
        } else if (sante['type'] == 'Poids') {
          content += ' ${sante['weight']} kg';
        } else if (sante['type'] == 'Médicaments') {
          content += ' ${sante['medicationType']}';
        }
        widgets.add(pw.Text(content));
        if (sante['observations']?.isNotEmpty == true) {
          widgets.add(pw.Text('    Observations: ${sante['observations']}'));
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    // Transmissions
    if (dayData.containsKey('transmissions') &&
        dayData['transmissions']!.isNotEmpty) {
      widgets.add(pw.Text('📝 TRANSMISSIONS',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      for (var transmission in dayData['transmissions']!) {
        widgets.add(pw.Text(
            '  • ${transmission['heure']} - ${transmission['category']}'));
        widgets.add(pw.Text('    ${transmission['content']}'));
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    return widgets;
  }

  static Future<void> _sendEmailWithPdf(Map<String, dynamic> childData,
      String pdfBase64, String structureId) async {
    // Récupérer l'email de l'assistante maternelle
    final structureDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .get();

    String assmatEmail = '';
    String structureName = '';
    if (structureDoc.exists) {
      final data = structureDoc.data()!;
      assmatEmail = data['email'] ?? '';
      structureName = data['structureName'] ?? 'Structure';
    }

    String parentEmail = childData['parentEmail'] ?? '';
    String childName = childData['firstName'] ?? 'Enfant';

    // Créer les données pour le template
    final templateData = {
      'childName': childName,
      'structureName': structureName,
      'currentDate': DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now()),
      'firstName': childData['firstName'] ?? '',
      'lastName': childData['lastName'] ?? '',
    };

    try {
      // Envoyer l'email aux parents s'il y a un email
      if (parentEmail.isNotEmpty) {
        await _addEmailToQueue(
            parentEmail,
            'Historique complet de $childName',
            'child-history',
            templateData,
            pdfBase64,
            'Historique_${childName}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf');
        print("✅ Email parent ajouté à la queue");
      }

      // Envoyer l'email à l'assistante maternelle s'il y a un email
      if (assmatEmail.isNotEmpty && assmatEmail != parentEmail) {
        await _addEmailToQueue(
            assmatEmail,
            'Historique complet de $childName - Copie assistante maternelle',
            'child-history',
            templateData,
            pdfBase64,
            'Historique_${childName}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf');
        print("✅ Email assistante maternelle ajouté à la queue");
      }

      print("✅ Emails ajoutés à la queue avec succès");
    } catch (e) {
      print("❌ Erreur ajout emails à la queue: $e");
      throw e;
    }
  }

  static Future<void> _addEmailToQueue(
    String toEmail,
    String subject,
    String template,
    Map<String, dynamic> templateData,
    String pdfBase64,
    String filename,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('emailQueue').add({
        'to': toEmail,
        'subject': subject,
        'template': template,
        'templateData': templateData,
        'pdfAttachment': pdfBase64,
        'pdfFilename': filename,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Erreur lors de l'ajout à la queue email: $e");
      throw e;
    }
  }

  static Future<void> _deleteChildData(
      String structureId, String childId) async {
    final batch = FirebaseFirestore.instance.batch();

    // Collections à supprimer
    final collections = [
      'repas',
      'activites',
      'siestes',
      'changes',
      'sante',
      'transmissions'
    ];

    for (String collection in collections) {
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection(collection)
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    // Supprimer les horaires
    final horairesSnapshot = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('horaires_history')
        .where('childId', isEqualTo: childId)
        .get();

    for (var doc in horairesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Supprimer les km
    final kmSnapshot = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('km_history')
        .where('childId', isEqualTo: childId)
        .get();

    for (var doc in kmSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Supprimer l'enfant lui-même
    final childRef = FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(childId);

    batch.delete(childRef);

    // Exécuter toutes les suppressions
    await batch.commit();
    print("✅ Toutes les données de l'enfant ont été supprimées");
  }

  static String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(date.toDate());
    } else if (date is String) {
      try {
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(date));
      } catch (e) {
        return date;
      }
    }
    return 'Non renseigné';
  }

  static String _formatDateHeader(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(dateTime);
    } catch (e) {
      return date;
    }
  }
}
