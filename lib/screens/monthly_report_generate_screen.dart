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

  // Vérifier et créer les informations financières si nécessaires
  Future<void> _ensureFinancialInfoExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final childDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(user.uid)
        .collection('children')
        .doc(widget.reportParams['childId'])
        .get();

    if (!childDoc.exists) return;

    final data = childDoc.data() ?? {};
    final financialInfo = data['financialInfo'] as Map<String, dynamic>?;

    if (financialInfo == null ||
        financialInfo['monthlySalary'] == null ||
        financialInfo['careExpenses'] == null ||
        financialInfo['mealExpenses'] == null ||
        financialInfo['kmExpenses'] == null) {
      // Créer des informations financières par défaut
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .collection('children')
          .doc(widget.reportParams['childId'])
          .update({
        'financialInfo': {
          'useMonthlyTable': true,
          'monthlySalary': 500.0, // Salaire net mensuel par défaut
          'careExpenses': 3.5, // Indemnité d'entretien journalière
          'mealExpenses': 4.0, // Indemnité de repas
          'kmExpenses': 0.35, // Indemnité kilométrique
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Charger les données de la structure
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
          .get();

      if (!structureDoc.exists) throw Exception('Structure non trouvée');
      structureData = structureDoc.data() ?? {};

      // Charger les données de l'enfant
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
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
          .doc(user.uid)
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final int year = widget.reportParams['year'];
    final int month = widget.reportParams['month'];

    // Déterminer le premier et le dernier jour du mois
    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    final DateTime lastDayOfMonth = DateTime(year, month + 1, 0);

    // Initialiser les totaux
    double totalHours = 0;
    int totalDays = 0;
    int totalMeals = 0;
    double totalKm = 0;

    // Préparer la liste des enregistrements quotidiens
    List<Map<String, dynamic>> records = [];

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
      double dayTotalHours = 0.0;

      // Récupérer les données d'horaire pour cette journée
      final String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);

      // Vérifier s'il y a des données d'horaire pour ce jour
      final horaireSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(user.uid)
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

      // N'ajouter l'enregistrement que si l'enfant était présent ce jour-là
      if (isPresent) {
        records.add({
          'date': formattedDate,
          'dayName': capitalize(frenchDayName),
          'arrivalTime': arrivalTime,
          'departureTime': departureTime,
          'realHours': realHours,
          'maintenance': maintenance,
          'meal': meal,
          'km': km,
        });
      }
    }

    // Calculer les montants financiers en utilisant les données de financialInfo
    final Map<String, dynamic> financialInfo = childData['financialInfo'] ?? {};
    final double netSalary = financialInfo['monthlySalary'] ?? 0.0;
    final double maintenanceRate = financialInfo['careExpenses'] ?? 0.0;
    final double mealRate = financialInfo['mealExpenses'] ?? 0.0;
    final double kmRate = financialInfo['kmExpenses'] ?? 0.0;

    final double maintenanceAmount = totalDays * maintenanceRate;
    final double mealAmount = totalMeals * mealRate;
    final double kmAmount = totalKm * kmRate;
    final double totalAmount =
        netSalary + maintenanceAmount + mealAmount + kmAmount;

    // Stocker toutes les données du rapport
    reportData = {
      'childName':
          '${childData['firstName'] ?? ''} ${childData['lastName'] ?? ''}'
              .trim(),
      'structureName': structureData['structureName'] ?? 'Nom de la structure',
      'month': DateFormat('MMMM yyyy', 'fr_FR').format(firstDayOfMonth),
      'totalHours': totalHours,
      'totalDays': totalDays,
      'totalMeals': totalMeals,
      'totalKm': totalKm,
      'netSalary': netSalary,
      'maintenanceRate': maintenanceRate,
      'mealRate': mealRate,
      'kmRate': kmRate,
      'maintenanceAmount': maintenanceAmount,
      'mealAmount': mealAmount,
      'kmAmount': kmAmount,
      'totalAmount': totalAmount,
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
                  'Vous devez vérifier les éléments du tableau',
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
                  'TABLEAU MENSUEL',
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
                    'Structure: ${reportData['structureName']}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
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

              // Tableau des présences journalières (uniquement jours présents)
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
                      _buildTableCell('Arrivée', fontBold, isBold: true),
                      _buildTableCell('Départ', fontBold, isBold: true),
                      _buildTableCell('Heures', fontBold, isBold: true),
                      _buildTableCell('Entretien', fontBold, isBold: true),
                      _buildTableCell('Repas', fontBold, isBold: true),
                      _buildTableCell('KM', fontBold, isBold: true),
                    ],
                  ),

                  // Lignes du tableau pour chaque jour où l'enfant était présent
                  ...dailyRecords
                      .map((record) => pw.TableRow(
                            children: [
                              _buildTableCell(
                                  '${record['dayName']} ${record['date']}',
                                  font),
                              _buildTableCell(record['arrivalTime'], font),
                              _buildTableCell(record['departureTime'], font),
                              _buildTableCell(record['realHours'], font),
                              _buildTableCell(
                                  record['maintenance'].toString(), font),
                              _buildTableCell(record['meal'].toString(), font),
                              _buildTableCell(
                                  record['km'] > 0
                                      ? record['km'].toString()
                                      : '',
                                  font),
                            ],
                          ))
                      .toList(),

                  // Ligne des totaux
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('TOTAL', fontBold, isBold: true),
                      _buildTableCell('', font),
                      _buildTableCell('', font),
                      _buildTableCell(
                          '${reportData['totalHours'].toStringAsFixed(2)}h',
                          fontBold,
                          isBold: true),
                      _buildTableCell('${reportData['totalDays']}', fontBold,
                          isBold: true),
                      _buildTableCell('${reportData['totalMeals']}', fontBold,
                          isBold: true),
                      _buildTableCell(
                          '${reportData['totalKm'].toStringAsFixed(2)}',
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
                  'Voir le récapitulatif financier à la page suivante',
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

    // Deuxième page : Récapitulatif financier
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
                  'RÉCAPITULATIF FINANCIER',
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
                    'Structure: ${reportData['structureName']}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
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

              // Tableau récapitulatif financier
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
                        'RÉCAPITULATIF',
                        style: pw.TextStyle(font: fontBold, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(height: 15),

                    // Nombre d'heures total
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Nombre d\'heures total:',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['totalHours'].toStringAsFixed(2)} heures',
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

                    // Indemnité d'entretien
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Indemnité d\'entretien (${reportData['totalDays']} jours x ${reportData['maintenanceRate']} €):',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['maintenanceAmount'].toStringAsFixed(2)} €',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Indemnité repas
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Indemnité repas (${reportData['totalMeals']} repas x ${reportData['mealRate']} €):',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['mealAmount'].toStringAsFixed(2)} €',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),

                    // Indemnité kilométrique
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Indemnité kilométrique (${reportData['totalKm'].toStringAsFixed(2)} km x ${reportData['kmRate']} €):',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '${reportData['kmAmount'].toStringAsFixed(2)} €',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 15),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 15),

                    // Total
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL:',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
                        pw.Text(
                          '${reportData['totalAmount'].toStringAsFixed(2)} €',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
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
        title: const Text('Tableau Mensuel'),
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
