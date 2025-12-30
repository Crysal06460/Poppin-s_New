import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/painting.dart';

class EmergencySheetService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF3D9DF2); // Blue Poppins
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFFE3F2FD); // Light Blue
  static const PdfColor accentColor = PdfColor.fromInt(0xFF263238); // Dark Grey text

  static Future<void> generateAndPrint({
    required String assMatName,
    required String childFirstName,
    required String childLastName,
    required String? childPhotoUrl,
    required String parent1Phone,
    required String parent2Phone,
    bool isMAM = false,
    String mamName = "",
  }) async {
    final pdf = pw.Document();

    pw.ImageProvider? childImage;
    if (childPhotoUrl != null && childPhotoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(childPhotoUrl));
        if (response.statusCode == 200) {
          childImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print("Erreur chargement image enfant: $e");
      }
    }

    // Charger le logo Poppins via flutterImageProvider (plus robuste)
    pw.ImageProvider? logoImage;
    try {
      logoImage = await flutterImageProvider(const AssetImage('assets/images/app_icon.png'));
    } catch (e) {
      print("Erreur chargement logo: $e");
    }

    // Sanitize MAM name to avoid PDF encoding issues with special chars
    final cleanMamName = mamName.replaceAll("’", "'").replaceAll("“", '"').replaceAll("”", '"');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.zero, // Full bleed header
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER DYNAMIQUE ET MODERNE
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(20),
                    bottomRight: pw.Radius.circular(20),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "FICHE D'URGENCE",
                          style: pw.TextStyle(
                            fontSize: 18, 
                            fontWeight: pw.FontWeight.bold, 
                            color: PdfColors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          "Informations vitales pour les secours",
                          style: pw.TextStyle(
                            fontSize: 10, 
                            color: PdfColors.white,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    // Affichage conditionnel du nom de la MAM ou rien
                    if (isMAM && cleanMamName.isNotEmpty)
                      pw.Container(
                         padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: pw.BoxDecoration(
                           color: PdfColors.white,
                           borderRadius: pw.BorderRadius.circular(15),
                         ),
                         child: pw.Text(
                           cleanMamName,
                           style: pw.TextStyle(
                             color: primaryColor,
                             fontSize: 10, // Adjusted for A5
                             fontWeight: pw.FontWeight.bold,
                           ),
                         ),
                      )
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20), // Reduced from 30
                child: pw.Column(
                  children: [
                    
                    // SECTION ENFANT (Carte Hero)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15), // Reduced from 20
                      decoration: pw.BoxDecoration(
                        color: secondaryColor,
                        borderRadius: pw.BorderRadius.circular(15),
                        border: pw.Border.all(color: primaryColor, width: 2),
                      ),
                      child: pw.Row(
                        children: [
                          // Photo avec cadre circulaire - Resize for A5
                          pw.Container(
                            width: 70, // Reduced from 100
                            height: 70, // Reduced from 100
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: PdfColors.white, width: 3),
                              color: PdfColors.grey300,
                              image: childImage != null 
                                  ? pw.DecorationImage(image: childImage, fit: pw.BoxFit.cover)
                                  : null,
                            ),
                            child: childImage == null 
                                ? pw.Center(child: pw.Text("Photo", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))) 
                                : null,
                          ),
                          pw.SizedBox(width: 15),
                          // Info Enfant
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "ENFANT ACCUEILLI",
                                  style: pw.TextStyle(fontSize: 8, color: primaryColor, fontWeight: pw.FontWeight.bold), // Reduced size
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  "${childFirstName} ${childLastName.toUpperCase()}",
                                  style: pw.TextStyle(
                                    fontSize: 20, // Reduced from 26
                                    fontWeight: pw.FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 15), // Reduced from 30

                    // SECTION ASSISTANT MATERNEL (Style Badge Pro)
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(left: pw.BorderSide(color: primaryColor, width: 4)),
                        color: PdfColors.grey100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Assistant(e) Maternel(le) Agréé(e)",
                            style: pw.TextStyle(fontSize: 12, color: accentColor), // Reduced from 16
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            assMatName,
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor), // Reduced from 20
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20), // Reduced from 40

                    // SECTION CONTACTS D'URGENCE (Focus Clarté)
                    pw.Text(
                      "PERSONNES À PRÉVENIR EN CAS D'URGENCE",
                      style: pw.TextStyle(
                        fontSize: 10, // Reduced from 14
                        fontWeight: pw.FontWeight.bold, 
                        color: accentColor,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.Divider(color: primaryColor, thickness: 1),
                    pw.SizedBox(height: 10),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildContactCard("Parent 1", parent1Phone),
                        pw.SizedBox(width: 15),
                        _buildContactCard("Parent 2", parent2Phone),
                      ],
                    ),

                    pw.SizedBox(height: 20), // Reduced from 40
                    
                    // SECTION BAS DE PAGE (Informations Médicales / Note)
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(10), // Reduced from 15
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(10),
                        border: pw.Border.all(color: PdfColors.red200),
                      ),
                      child: pw.Row(
                         children: [
                           pw.Container(
                             padding: const pw.EdgeInsets.all(5),
                             decoration: const pw.BoxDecoration(color: PdfColors.red100, shape: pw.BoxShape.circle),
                             child: pw.Text("!", style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                           ),
                           pw.SizedBox(width: 10),
                           pw.Expanded(
                             child: pw.Text(
                               "En cas d'urgence vitale, composez le 15 (SAMU) ou le 18 (Pompiers) immédiatement.",
                               style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 8), // Reduced from 10
                             ),
                           )
                         ]
                      )
                    ),

                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer avec logo et texte - Layout simplifié (Row)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                   if (logoImage != null)
                     pw.Container(
                        width: 25,
                        height: 25,
                        margin: const pw.EdgeInsets.only(right: 10),
                        child: pw.Image(logoImage),
                     ),
                   pw.Text(
                      "Généré via Poppins - L'application des Pros de la Petite Enfance",
                      style: pw.TextStyle(color: PdfColors.grey400, fontSize: 6),
                   ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'fiche_urgence_${childFirstName}_${childLastName}.pdf',
    );
  }

  static pw.Widget _buildContactCard(String label, String phone) {
    bool hasPhone = phone.isNotEmpty;
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10), // Reduced from 15
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColors.grey300),
          boxShadow: const [
             pw.BoxShadow(color: PdfColors.grey200, blurRadius: 4, offset: PdfPoint(0, 2))
          ]
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontWeight: pw.FontWeight.bold), // Reduced from 10
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              hasPhone ? _formatPhone(phone) : "Non renseigné",
              style: pw.TextStyle(
                fontSize: 14, // Reduced from 18
                fontWeight: pw.FontWeight.bold, 
                color: hasPhone ? accentColor : PdfColors.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPhone(String phone) {
    if (phone.isEmpty) return "";
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 2) return phone;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
        if (i > 0 && i % 2 == 0) buffer.write(' ');
        buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
