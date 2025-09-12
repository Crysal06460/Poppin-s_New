import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';

class MonthlyReportGenerateScreen extends StatefulWidget {
  final Map<String, dynamic> reportParams;

  const MonthlyReportGenerateScreen({
    Key? key,
    required this.reportParams,
  }) : super(key: key);

  @override
  _MonthlyReportGenerateScreenState createState() =>
      _MonthlyReportGenerateScreenState();
}

class _MonthlyReportGenerateScreenState
    extends State<MonthlyReportGenerateScreen> {
  bool isLoading = true;
  late Map<String, dynamic> structureData = {};
  late Map<String, dynamic> childData = {};
  late Map<String, dynamic> reportData = {};
  late List<Map<String, dynamic>> dailyRecords = [];
  Uint8List? pdfBytes;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadData();
    });
  }

  // Extension pour capitaliser la première lettre d'une chaîne
  String capitalize(String input) {
    if (input.isEmpty) return input;
    return "${input[0].toUpperCase()}${input.substring(1)}";
  }

  String currentUserEmail = "";
  String structureId = "";

  // Vérifier et créer les informations financières si nécessaires
  Future<void> _ensureFinancialInfoExists() async {
    if (structureId.isEmpty) return;

    final childDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId) // ← Utiliser structureId au lieu de user.uid
        .collection('children')
        .doc(widget.reportParams['childId'])
        .get();

    if (!childDoc.exists) return;

    final data = childDoc.data() ?? {};
    final financialInfo = data['financialInfo'] as Map<String, dynamic>?;

    if (financialInfo == null || financialInfo['monthlySalary'] == null) {
      // Créer des informations financières par défaut
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // ← Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.reportParams['childId'])
          .update({
        'financialInfo': {
          'useMonthlyTable': true,
          'monthlySalary': 500.0, // Salaire net par défaut
        }
      });
    }
  }

  Future<String> _getStructureId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "";

      // Obtenir l'email de l'utilisateur actuel
      currentUserEmail = user.email?.toLowerCase() ?? '';
      print("👤 Email de l'utilisateur connecté: $currentUserEmail");

      // Vérifier si l'utilisateur est un membre MAM
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();

      print(
          "👤 Vérification du document utilisateur: ${userDoc.exists ? 'existe' : 'n\'existe pas'}");
      if (userDoc.exists) {
        final userData = userDoc.data();
        print("👤 Données utilisateur: $userData");
      }

      // Si c'est un membre MAM, obtenir l'ID de la structure associée
      if (userDoc.exists &&
          userDoc.data() != null &&
          userDoc.data()!.containsKey('structureId')) {
        String structId = userDoc.data()!['structureId'];
        print("👤 Utilisateur MAM détecté avec structureId: $structId");
        return structId;
      }

      // Par défaut, utiliser l'ID de l'utilisateur
      print("👤 Utilisateur standard avec uid: ${user.uid}");
      return user.uid;
    } catch (e) {
      print("🚨 Erreur dans _getStructureId: $e");
      return "";
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Obtenir l'ID de structure correct
      structureId = await _getStructureId();
      if (structureId.isEmpty) {
        throw Exception('ID de structure non trouvé');
      }

      print("🔍 Chargement des données pour la structure: $structureId");

      // Charger les données de la structure avec l'ID correct
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // ← Utiliser structureId au lieu de user.uid
          .get();

      if (!structureDoc.exists) {
        print(
            "⚠️ Document de structure non trouvé, utilisation de valeurs par défaut");
        structureData = {'structureName': 'Ma Structure'};
      } else {
        structureData = structureDoc.data() ?? {};
      }

      // Charger les données de l'enfant avec l'ID correct
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // ← Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.reportParams['childId'])
          .get();

      if (!childDoc.exists) throw Exception('Enfant non trouvé');
      childData = childDoc.data() ?? {};

      // Vérifier et ajouter les informations financières si nécessaire
      await _ensureFinancialInfoExists();

      // Recharger les données de l'enfant avec les infos financières
      final updatedChildDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // ← Utiliser structureId au lieu de user.uid
          .collection('children')
          .doc(widget.reportParams['childId'])
          .get();

      childData = updatedChildDoc.data() ?? {};

      // Préparer les données pour le rapport
      await _prepareReportData();

      // Générer le PDF
      final pdf = await _generatePdf();
      pdfBytes = await pdf.save();

      setState(() => isLoading = false);
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _prepareReportData() async {
    if (structureId.isEmpty) throw Exception('ID de structure non défini');

    final int year = widget.reportParams['year'];
    final int month = widget.reportParams['month'];

    // Déterminer le premier et le dernier jour du mois
    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    final DateTime lastDayOfMonth = DateTime(year, month + 1, 0);

    // Initialiser les totaux
    double totalHours = 0;
    double plannedHours = 0; // Heures prévues au contrat sur le mois
    int totalAbsences = 0;
    int totalDays = 0;
    int totalMeals = 0;
    double totalKm = 0;

    // Préparer la liste des enregistrements quotidiens
    List<Map<String, dynamic>> records = [];

    // Planning contractuel hebdomadaire de l'enfant (si présent)
    final Map<String, dynamic>? weeklySchedule =
        (childData['schedule'] as Map<String, dynamic>?);

    // Pour chaque jour du mois
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final DateTime currentDate = DateTime(year, month, day);
      final String frenchDayName =
          DateFormat('EEEE', 'fr_FR').format(currentDate);
      final String formattedDate =
          DateFormat('dd/MM/yyyy', 'fr_FR').format(currentDate);

      // Variables pour les données de la journée
      String arrivalTime = '';
      String departureTime = '';
      String realHours = '';
      int maintenance = 0;
      int meal = 0;
      double km = 0;
      bool isPresent = false;
      bool isAbsent = false;
      double dayTotalHours = 0.0;

      // Récupérer les données d'horaire pour cette journée
      final String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);

      // Vérifier s'il y a des données d'horaire pour ce jour
      final horaireSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId) // ← Utiliser structureId au lieu de user.uid
          .collection('horaires')
          .doc(dateKey)
          .get();

      if (horaireSnapshot.exists) {
        final Map<String, dynamic>? horaireData = horaireSnapshot.data();
        final Map<String, dynamic>? childHoraire =
            horaireData?[widget.reportParams['childId']]
                as Map<String, dynamic>?;

        if (childHoraire != null) {
          // Si l'enfant était absent, on continue avec les valeurs par défaut
          if (childHoraire['actionType'] == 'absent') {
            isPresent = false;
            isAbsent = true;
          } else {
            // Si l'enfant était présent, on définit isPresent à true
            isPresent = true;

            // Initialiser les compteurs quand l'enfant est présent
            maintenance = 1;
            meal = 1;

            // Vérifier si le nouveau format avec segments est utilisé
            if (childHoraire['segments'] != null &&
                childHoraire['segments'] is List) {
              List<dynamic> segments = childHoraire['segments'];

              // Pour chaque segment, on récupère les heures d'arrivée et de départ
              for (var segment in segments) {
                // Vérifier si on a une heure d'arrivée enregistrée
                if (segment['arrivee'] != null) {
                  String segmentArrival = segment['arrivee'];

                  // Si c'est le premier segment avec des heures, on initialise l'heure d'arrivée
                  if (arrivalTime.isEmpty) {
                    arrivalTime = segmentArrival;
                  }

                  // Vérifier si on a une heure de départ enregistrée
                  // (sinon utiliser heureFin comme fallback)
                  String? segmentDeparture = segment['depart'];
                  if (segmentDeparture == null && segment['heureFin'] != null) {
                    // Utiliser l'heure de fin planifiée si l'heure de départ n'est pas enregistrée
                    segmentDeparture = segment['heureFin'];
                  }

                  // On ne traite que les segments complets (avec arrivée et départ)
                  if (segmentDeparture != null) {
                    // On met à jour l'heure de départ avec celle du dernier segment complet
                    departureTime = segmentDeparture;

                    // Calculer les heures pour ce segment
                    try {
                      // Parse l'heure d'arrivée et de départ du segment
                      final List<String> arrivalParts =
                          segmentArrival.split(':');
                      final List<String> departureParts =
                          segmentDeparture.split(':');

                      // Convertir en minutes depuis minuit
                      final int arrivalMinutes =
                          (int.parse(arrivalParts[0]) * 60) +
                              int.parse(arrivalParts[1]);
                      final int departureMinutes =
                          (int.parse(departureParts[0]) * 60) +
                              int.parse(departureParts[1]);

                      // Calculer la différence en minutes
                      int diffMinutes = departureMinutes - arrivalMinutes;

                      // S'assurer que la différence est positive
                      if (diffMinutes < 0) {
                        diffMinutes += 24 * 60; // Ajouter 24 heures en minutes
                      }

                      // Ajouter les heures de ce segment au total de la journée
                      dayTotalHours += diffMinutes / 60;
                    } catch (e) {
                      print(
                          'Erreur lors du calcul des heures pour un segment: $e');
                    }
                  }
                }

                // Récupérer les KM du segment
                if (segment['km'] != null) {
                  double segmentKm = (segment['km'] is int)
                      ? (segment['km'] as int).toDouble()
                      : (segment['km'] as num).toDouble();
                  km += segmentKm;
                }
              }

              // Formater le résultat des heures totales pour ce jour
              if (dayTotalHours > 0) {
                final int hours = dayTotalHours.floor();
                final int minutes = ((dayTotalHours - hours) * 60).round();
                realHours = '${hours}h${minutes.toString().padLeft(2, '0')}';
              } else if (arrivalTime.isNotEmpty) {
                // Si on a seulement l'heure d'arrivée sans départ, utiliser heureDebut et heureFin pour l'estimation
                for (var segment in segments) {
                  if (segment['heureDebut'] != null &&
                      segment['heureFin'] != null) {
                    try {
                      final List<String> startParts =
                          segment['heureDebut'].split(':');
                      final List<String> endParts =
                          segment['heureFin'].split(':');

                      final int startMinutes = (int.parse(startParts[0]) * 60) +
                          int.parse(startParts[1]);
                      final int endMinutes = (int.parse(endParts[0]) * 60) +
                          int.parse(endParts[1]);

                      int diffMinutes = endMinutes - startMinutes;
                      if (diffMinutes < 0) {
                        diffMinutes += 24 * 60;
                      }

                      dayTotalHours += diffMinutes / 60;

                      // Utiliser les heures planifiées pour remplir les heures d'arrivée/départ manquantes
                      if (arrivalTime.isEmpty &&
                          segment['heureDebut'] != null) {
                        arrivalTime = segment['heureDebut'];
                      }
                      if (departureTime.isEmpty &&
                          segment['heureFin'] != null) {
                        departureTime = segment['heureFin'];
                      }

                      final int hours = dayTotalHours.floor();
                      final int minutes =
                          ((dayTotalHours - hours) * 60).round();
                      realHours =
                          '${hours}h${minutes.toString().padLeft(2, '0')}';
                    } catch (e) {
                      print('Erreur lors du calcul des heures planifiées: $e');
                    }
                  }
                }
              }
            }
            // Ancien format (compatibilité)
            else {
              if (childHoraire['arrivee'] != null) {
                arrivalTime = childHoraire['arrivee'];
              }

              if (childHoraire['depart'] != null) {
                departureTime = childHoraire['depart'];
              }

              // Calculer les heures réelles
              if (arrivalTime.isNotEmpty && departureTime.isNotEmpty) {
                try {
                  // Parse l'heure d'arrivée et de départ
                  final List<String> arrivalParts = arrivalTime.split(':');
                  final List<String> departureParts = departureTime.split(':');

                  // Convertir en minutes depuis minuit
                  final int arrivalMinutes = (int.parse(arrivalParts[0]) * 60) +
                      int.parse(arrivalParts[1]);
                  final int departureMinutes =
                      (int.parse(departureParts[0]) * 60) +
                          int.parse(departureParts[1]);

                  // Calculer la différence en minutes
                  int diffMinutes = departureMinutes - arrivalMinutes;

                  // S'assurer que la différence est positive
                  if (diffMinutes < 0) {
                    diffMinutes += 24 * 60; // Ajouter 24 heures en minutes
                  }

                  // Convertir en heures et minutes
                  final int hours = diffMinutes ~/ 60;
                  final int minutes = diffMinutes % 60;

                  // Formater le résultat
                  realHours = '${hours}h${minutes.toString().padLeft(2, '0')}';

                  // Ajouter au total d'heures de la journée
                  dayTotalHours = hours + (minutes / 60);
                } catch (e) {
                  print('Erreur lors du calcul des heures: $e');
                  realHours = 'Erreur';
                }
              }

              // Récupérer les KM
              if (childHoraire['km'] != null) {
                km = (childHoraire['km'] is int)
                    ? (childHoraire['km'] as int).toDouble()
                    : (childHoraire['km'] as num).toDouble();
              }
            }

            // Ajouter aux totaux uniquement si l'enfant est présent
            totalHours += dayTotalHours;
            totalDays += maintenance;
            totalMeals += meal;
            totalKm += km;
          }
        }
      }

      // Calcul des heures prévues au contrat pour ce jour
      try {
        if (weeklySchedule != null) {
          final String dayKey =
              frenchDayName[0].toUpperCase() + frenchDayName.substring(1).toLowerCase();
          if (weeklySchedule.containsKey(dayKey) && weeklySchedule[dayKey] != null) {
            List<dynamic> segmentsDuJour = [];
            final entry = weeklySchedule[dayKey];
            if (entry is List) {
              segmentsDuJour = entry;
            } else if (entry is Map) {
              segmentsDuJour = [
                {
                  'start': entry['start'] ?? entry['arrival'],
                  'end': entry['end'] ?? entry['departure'],
                }
              ];
            }
            for (final seg in segmentsDuJour) {
              final String? s = (seg['start'] ?? seg['heureDebut'])?.toString();
              final String? e = (seg['end'] ?? seg['heureFin'])?.toString();
              if (s != null && e != null && s.contains(':') && e.contains(':')) {
                final sp = s.split(':');
                final ep = e.split(':');
                int sm = (int.tryParse(sp[0]) ?? 0) * 60 + (int.tryParse(sp[1]) ?? 0);
                int em = (int.tryParse(ep[0]) ?? 0) * 60 + (int.tryParse(ep[1]) ?? 0);
                int diff = em - sm;
                if (diff < 0) diff += 24 * 60; // gestion minuit si besoin
                plannedHours += diff / 60.0;
              }
            }
          }
        }
      } catch (e) {
        print('Erreur calcul heures prévues: $e');
      }

      // Ajouter l'enregistrement: présent avec heures, ou absent clairement indiqué
      if (isPresent) {
        records.add({
          'date': formattedDate,
          'dayName': capitalize(frenchDayName),
          'arrivalTime': arrivalTime,
          'departureTime': departureTime,
          'realHours': realHours,
          'status': 'Présent',
        });
      } else if (isAbsent) {
        records.add({
          'date': formattedDate,
          'dayName': capitalize(frenchDayName),
          'arrivalTime': '',
          'departureTime': '',
          'realHours': 'ABSENT',
          'status': 'ABSENT',
        });
        totalAbsences += 1;
      }
    }

    // Calculer les montants financiers en utilisant les données de financialInfo
    final Map<String, dynamic> financialInfo = childData['financialInfo'] ?? {};
    final double netSalary = (financialInfo['monthlySalary'] ?? 0.0).toDouble();

    // Stocker toutes les données du rapport
    reportData = {
      'childName':
          '${childData['firstName'] ?? ''} ${childData['lastName'] ?? ''}'
              .trim(),
      'structureName': structureData['structureName'] ?? 'Nom de la structure',
      'month': DateFormat('MMMM yyyy', 'fr_FR').format(firstDayOfMonth),
      'totalHours': totalHours,
      'totalDays': totalDays,
      'netSalary': netSalary,
      'plannedHours': plannedHours,
      'hoursDiff': (totalHours - plannedHours),
      'totalAbsences': totalAbsences,
    };

    dailyRecords = records;
  }

  pw.Widget _buildTableCell(String text, pw.Font font,
      {pw.Alignment alignment = pw.Alignment.center, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    // Définir la police par défaut
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Première page : Tableau des présences
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Message de rappel en rouge
              pw.Center(
                child: pw.Text(
                  'RAPPEL',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 14,
                    color: PdfColors.red,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Vous devez vérifier les éléments du mémo',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: PdfColors.red,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              // En-tête de la page
              pw.Center(
                child: pw.Text(
                  'MÉMO MENSUEL',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              // Informations générales
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Période: ${reportData['month']}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Enfant: ${reportData['childName']}',
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
              pw.SizedBox(height: 15),

              // Tableau des présences journalières (présences et absences)
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 0.5,
                ),
                children: [
                  // En-tête du tableau
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Jour', fontBold, isBold: true),
                      _buildTableCell('Statut', fontBold, isBold: true),
                      _buildTableCell('Arrivée', fontBold, isBold: true),
                      _buildTableCell('Départ', fontBold, isBold: true),
                      _buildTableCell('Heures', fontBold, isBold: true),
                    ],
                  ),

                  // Lignes du tableau pour chaque jour
                  ...dailyRecords
                      .map((record) => pw.TableRow(children: [
                            _buildTableCell(
                                '${record['dayName']} ${record['date']}', font),
                            _buildTableCell((record['status'] ?? '') as String, font),
                            _buildTableCell((record['arrivalTime'] ?? '') as String, font),
                            _buildTableCell((record['departureTime'] ?? '') as String, font),
                            _buildTableCell((record['realHours'] ?? '') as String, font),
                          ]))
                      .toList(),

                  // Ligne des totaux
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('TOTAL', fontBold, isBold: true),
                      _buildTableCell(
                          'Absences: ${reportData['totalAbsences']}', font,
                          isBold: true),
                      _buildTableCell('', font),
                      _buildTableCell(
                          '${reportData['totalHours'].toStringAsFixed(2)}h',
                          fontBold,
                          isBold: true),
                    ],
                  ),
                ],
              ),

              // Note de bas de page
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Voir le récapitulatif à la page suivante',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey800,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Deuxième page : Récapitulatif
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // En-tête de la page
              pw.Center(
                child: pw.Text(
                  'RÉCAPITULATIF',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              // Informations générales
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Période: ${reportData['month']}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Enfant: ${reportData['childName']}',
                style: pw.TextStyle(font: fontBold, fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Tableau récapitulatif simple
              pw.Container(
                width: 400,
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        '',
                        style: pw.TextStyle(font: fontBold, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(height: 15),

                    // Heures prévues au contrat
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Heures prévues au contrat:',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['plannedHours'].toStringAsFixed(2)} heures',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Nombre d'heures réelles total
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Nombre d\'heures réelles total:',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['totalHours'].toStringAsFixed(2)} heures',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Écart (réel - prévu)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Écart (réel - prévu):',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['hoursDiff'].toStringAsFixed(2)} heures',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Salaire net
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Salaire net:',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['netSalary'].toStringAsFixed(2)} €',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Nombre d'absences total
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Nombre d\'absences total:',
                            style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text('${reportData['totalAbsences']}',
                            style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // Méthode pour partager le PDF
  Future<void> _sharePdf() async {
    try {
      if (pdfBytes == null) return;

      // Obtenir le répertoire temporaire
      final tempDir = await getTemporaryDirectory();
      final fileName = 'rapport_mensuel_${reportData['month']}.pdf';
      final file = File('${tempDir.path}/$fileName');

      // Écrire le PDF dans un fichier temporaire
      await file.writeAsBytes(pdfBytes!);

      // Partager le fichier
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Rapport mensuel - ${reportData['month']}',
        text:
            'Rapport mensuel pour ${reportData['childName']} - ${reportData['month']}',
      );
    } catch (e) {
      print('Erreur lors du partage du PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du partage: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mémo mensuel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Utiliser le router pour la navigation
            context.go('/dashboard');
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pdfBytes != null
              ? PdfPreview(
                  build: (format) => pdfBytes!,
                  maxPageWidth: 700,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName: 'rapport_mensuel_${reportData['month']}.pdf',
                  // Désactiver les actions par défaut de PdfPreview
                  actions: [],
                  // Désactiver également l'appBar de PdfPreview qui peut créer des doublons
                  useActions: false,
                )
              : const Center(child: Text('Erreur de génération du PDF')),
      bottomNavigationBar: BottomAppBar(
        color: Colors.deepPurple,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: pdfBytes != null
                  ? () async {
                      await Printing.layoutPdf(
                        onLayout: (format) => pdfBytes!,
                        name: 'rapport_mensuel_${reportData['month']}.pdf',
                      );
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: pdfBytes != null ? _sharePdf : null,
            ),
          ],
        ),
      ),
    );
  }
}
