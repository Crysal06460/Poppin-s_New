// child_removal_screen.dart - Version corrigée
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ChildRemovalScreen extends StatefulWidget {
  final String structureId;
  final String childId;

  const ChildRemovalScreen({
    Key? key,
    required this.structureId,
    required this.childId,
  }) : super(key: key);

  @override
  State<ChildRemovalScreen> createState() => _ChildRemovalScreenState();
}

class _ChildRemovalScreenState extends State<ChildRemovalScreen> {
  bool _isLoading = false;
  String _status = '';

  // Service de génération PDF et envoi email CORRIGÉ
  Future<void> _generateAndSendChildHistory() async {
    try {
      setState(() {
        _status = 'Récupération des données...';
      });

      // 1. Récupérer les données de l'enfant
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (!childDoc.exists) {
        throw Exception('Enfant non trouvé');
      }

      final childData = childDoc.data()!;
      final childName = childData['prenom'] ?? 'Enfant';

      setState(() {
        _status = 'Récupération de l\'historique...';
      });

      // 2. Récupérer tout l'historique
      final history =
          await _getCompleteHistory(widget.structureId, widget.childId);

      setState(() {
        _status = 'Génération du PDF...';
      });

      // 3. Générer le PDF
      final pdfBytes = await _generatePdf(childData, history);
      final pdfBase64 = base64Encode(pdfBytes);

      setState(() {
        _status = 'Envoi des emails...';
      });

      // 4. Envoyer l'email avec le PDF - CORRECTION ICI
      await _sendHistoryEmail(childData, pdfBase64, widget.structureId);

      setState(() {
        _status = 'Suppression des données...';
      });

      // 5. Supprimer toutes les données
      await _deleteAllChildData(widget.structureId, widget.childId);

      setState(() {
        _status = 'Terminé avec succès !';
      });
    } catch (e) {
      setState(() {
        _status = 'Erreur: $e';
      });
      throw e;
    }
  }

  // CORRECTION FINALE : Méthode d'envoi email pour l'historique
  // CORRECTION MAJEURE : Méthode d'envoi email avec les bons noms de champs
  Future<void> _sendHistoryEmail(Map<String, dynamic> childData,
      String pdfBase64, String structureId) async {
    // Récupérer l'email de l'assistante maternelle
    final structureDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .get();

    final structureData = structureDoc.data()!;
    final assistanteEmail = structureData['email'] ?? '';
    final structureName =
        structureData['nom'] ?? structureData['structureName'] ?? 'Structure';

    // CORRECTION : Utiliser les vrais noms de champs de Firestore
    final parentEmail =
        childData['parentEmail'] ?? childData['parent_email'] ?? '';
    final childName = childData['firstName'] ?? childData['prenom'] ?? 'Enfant';
    final parentName =
        childData['parentName'] ?? childData['parent_nom'] ?? 'Parent';

    print("🔍 DEBUG - Données enfant récupérées:");
    print("  - childData keys: ${childData.keys.toList()}");
    print("  - firstName: ${childData['firstName']}");
    print("  - parentEmail: ${childData['parentEmail']}");
    print("  - structureName: $structureName");

    if (parentEmail.isEmpty && assistanteEmail.isEmpty) {
      throw Exception('Aucun email de destinataire trouvé');
    }

    // Structure des données conforme à votre Cloud Function
    final emailData = {
      'to': parentEmail.isNotEmpty ? parentEmail : assistanteEmail,
      'subject': 'Historique complet de $childName',
      'template': 'child-history', // ← Template correct
      'templateData': {
        'childName': childName,
        'structureName': structureName,
        'firstName': parentName,
        'lastName': '',
        'currentDate': DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now()),
      },
      'pdfAttachment': pdfBase64,
      'pdfFilename':
          'Historique_${childName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    print("📧 Email data à envoyer:");
    print("  - to: ${emailData['to']}");
    print("  - template: ${emailData['template']}");
    print("  - subject: ${emailData['subject']}");

    try {
      if (parentEmail.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('emailQueue')
            .add(emailData);
        print("✅ Email parent ajouté à la queue");
      }

      if (assistanteEmail.isNotEmpty && assistanteEmail != parentEmail) {
        final emailDataAssmat = Map<String, dynamic>.from(emailData);
        emailDataAssmat['to'] = assistanteEmail;
        emailDataAssmat['subject'] =
            'Historique complet de $childName - Copie assistante maternelle';

        await FirebaseFirestore.instance
            .collection('emailQueue')
            .add(emailDataAssmat);
        print("✅ Email assistante maternelle ajouté à la queue");
      }
    } catch (e) {
      print("❌ Erreur lors de l'ajout des emails: $e");
      throw e;
    }
  }

// CORRECTION : Méthode de génération PDF avec les bons noms de champs
  // CORRECTION : Méthode _generatePdf avec police Unicode
  Future<Uint8List> _generatePdf(Map<String, dynamic> childData,
      Map<String, List<Map<String, dynamic>>> history) async {
    final pdf = pw.Document();

    // CORRECTION : Nettoyer tous les textes avec la nouvelle fonction
    final childName = _cleanTextForPdf(
        childData['firstName'] ?? childData['prenom'] ?? 'Enfant');
    final lastName =
        _cleanTextForPdf(childData['lastName'] ?? childData['nom'] ?? '');
    final parentName = _cleanTextForPdf(childData['parent1']?['firstName'] ??
        childData['parent1']?['prenom'] ??
        childData['parentName'] ??
        'Non spécifié');

    // Récupérer le nom de la structure
    final structureDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(widget.structureId)
        .get();
    final structureData = structureDoc.data()!;
    final structureName = _cleanTextForPdf(
        structureData['nom'] ?? structureData['structureName'] ?? 'Structure');

    print("🔍 DEBUG - Génération PDF:");
    print("  - childName: $childName");
    print("  - lastName: $lastName");
    print("  - parentName: $parentName");
    print("  - structureName: $structureName");
    print("  - History keys: ${history.keys.toList()}");

    // Calculer le total d'événements
    int totalEvents = 0;
    for (String key in history.keys) {
      final count = history[key]?.length ?? 0;
      print("  - $key: $count événements");
      totalEvents += count;
    }
    print("  - TOTAL événements: $totalEvents");

    // Organiser les événements
    final allEvents = _organizeEventsByDate(history);
    print("🗓️ Événements organisés par date: ${allEvents.keys.length} jours");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          // En-tête
          content.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'Historique complet de $childName $lastName',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
          );

          content.add(pw.SizedBox(height: 10));

          // Informations générales
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Structure: $structureName',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text('Enfant: $childName $lastName',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text('Parent: $parentName',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text('Total d\'événements enregistrés: $totalEvents',
                      style: pw.TextStyle(fontSize: 10)),
                  pw.Text(
                      'Généré le: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 15));

          if (allEvents.isEmpty) {
            content.add(
              pw.Text(
                'Aucun événement trouvé dans l\'historique.',
                style:
                    pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            );
          } else {
            // Ajouter les événements par date
            final sortedDates = allEvents.keys.toList()..sort();

            for (String date in sortedDates) {
              final events = allEvents[date] ?? [];

              content.add(
                pw.Text(
                  _cleanTextForPdf(_formatDateForDisplay(date)),
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800),
                ),
              );

              content.add(pw.SizedBox(height: 3));

              for (String event in events) {
                // CORRECTION : Nettoyer chaque événement
                final cleanEvent = _cleanTextForPdf(event);
                content.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
                    child: pw.Text(
                      cleanEvent,
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  ),
                );
              }

              content.add(pw.SizedBox(height: 8));
            }
          }

          return content;
        },
      ),
    );

    return pdf.save();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getCompleteHistory(
      String structureId, String childId) async {
    Map<String, List<Map<String, dynamic>>> history = {};

    print("🔍 DEBUG - Récupération historique pour childId: $childId");
    print("🔍 DEBUG - structureId: $structureId");

    // PARTIE 1: Collections dans children/{childId}/{collection}
    final collections = [
      'repas',
      'activites',
      'siestes',
      'changes',
      'sante',
      'transmissions',
    ];

    for (String collection in collections) {
      try {
        print("📊 Recherche dans children/$childId/$collection...");

        final snapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(childId)
            .collection(collection)
            .get();

        print("  - Trouvé ${snapshot.docs.length} documents dans $collection");

        history[collection] = [];

        for (var doc in snapshot.docs) {
          final data = {'id': doc.id, ...doc.data()};
          print(
              "    * ${doc.id}: date=${data['date']}, heure=${data['heure']}, type=${data['type']}");

          // Vérifier que les données sont valides
          if (data.containsKey('date') && data.containsKey('heure')) {
            history[collection]!.add(data);
          } else {
            print(
                "      ⚠️ Document invalide (pas de date/heure): ${data.keys.toList()}");
          }
        }

        print(
            "  ✅ $collection: ${history[collection]!.length} événements valides ajoutés");
      } catch (e) {
        print('❌ Erreur pour $collection: $e');
        history[collection] = [];
      }
    }

    // PARTIE 2: Horaires - CORRECTION MAJEURE
    try {
      print("📊 Recherche spécifique des horaires...");
      history['horaires'] = [];

      // Méthode 1: Chercher dans horaires_history d'abord
      try {
        final horaireHistorySnapshot = await FirebaseFirestore.instance
            .collection('horaires_history')
            .where('childId', isEqualTo: childId)
            .get();

        print(
            "  - horaires_history: ${horaireHistorySnapshot.docs.length} documents");

        for (var doc in horaireHistorySnapshot.docs) {
          final data = doc.data();
          print("    * ${doc.id}: ${data.keys.toList()}");

          if (data.containsKey('timestamp')) {
            final timestamp = data['timestamp'] as Timestamp;
            final date = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
            final heure = DateFormat('HH:mm').format(timestamp.toDate());

            history['horaires']!.add({
              'id': doc.id,
              'date': date,
              'heure': heure,
              'type': data['type'] ?? 'inconnu',
              'timestamp': timestamp,
              'prenom': data['prenom'] ?? '',
            });
          }
        }
      } catch (e) {
        print("    ❌ Erreur horaires_history: $e");
      }

      // Méthode 2: Chercher dans structures/{id}/horaires/{date} SEULEMENT si besoin
      if (history['horaires']!.isEmpty) {
        print("  - Recherche dans structures/horaires...");

        final horairesSnapshot = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('horaires')
            .get();

        print("  - structures/horaires: ${horairesSnapshot.docs.length} dates");

        for (var dateDoc in horairesSnapshot.docs) {
          final dateStr = dateDoc.id;
          final dateData = dateDoc.data();

          print("    * Date: $dateStr, clés: ${dateData.keys.toList()}");

          // Chercher les données de cet enfant spécifiquement
          dateData.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final entryData = Map<String, dynamic>.from(value);

              // DEBUG: Afficher le contenu de chaque entrée
              print(
                  "      - Entrée $key: prenom=${entryData['prenom']}, childId=${entryData['childId']}");

              // Vérifier si cette entrée concerne notre enfant (par prénom ou childId)
              bool isForThisChild = false;

              if (entryData.containsKey('childId') &&
                  entryData['childId'] == childId) {
                isForThisChild = true;
                print("        ✅ Trouvé par childId");
              }
              // Vous pouvez aussi ajouter une vérification par prénom si nécessaire

              if (isForThisChild && entryData.containsKey('segments')) {
                final segments = entryData['segments'];
                if (segments is List) {
                  print("        📝 ${segments.length} segments trouvés");

                  for (int i = 0; i < segments.length; i++) {
                    final segment = segments[i];
                    if (segment is Map<String, dynamic>) {
                      // Traiter arrivée
                      if (segment.containsKey('arrivee') &&
                          segment['arrivee'] != null &&
                          segment['arrivee'].toString().isNotEmpty) {
                        print("          ➡️ Arrivée: ${segment['arrivee']}");
                        history['horaires']!.add({
                          'id': '${dateStr}_${key}_${i}_arrivee',
                          'date': dateStr,
                          'type': 'arrivee',
                          'heure': segment['arrivee'].toString(),
                          'timestamp': _parseHourToTimestamp(
                              dateStr, segment['arrivee'].toString()),
                        });
                      }

                      // Traiter départ
                      if (segment.containsKey('depart') &&
                          segment['depart'] != null &&
                          segment['depart'].toString().isNotEmpty) {
                        print("          ⬅️ Départ: ${segment['depart']}");
                        history['horaires']!.add({
                          'id': '${dateStr}_${key}_${i}_depart',
                          'date': dateStr,
                          'type': 'depart',
                          'heure': segment['depart'].toString(),
                          'timestamp': _parseHourToTimestamp(
                              dateStr, segment['depart'].toString()),
                          'km': segment['km'],
                        });
                      }
                    }
                  }
                }
              }
            }
          });
        }
      }

      print(
          "  ✅ horaires: ${history['horaires']!.length} événements d'horaires ajoutés");

      // Trier les horaires par timestamp
      if (history['horaires']!.isNotEmpty) {
        history['horaires']!.sort((a, b) {
          final aTime = a['timestamp'] as Timestamp?;
          final bTime = b['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return aTime.compareTo(bTime);
        });
      }
    } catch (e) {
      print('❌ Erreur pour horaires: $e');
      history['horaires'] = [];
    }

    // Résumé final avec détails
    int totalEvents = 0;
    history.forEach((collection, events) {
      totalEvents += events.length;
      print("📈 $collection: ${events.length} événements");

      // Debug: afficher quelques exemples d'événements
      if (events.isNotEmpty && events.length <= 3) {
        for (var event in events) {
          print(
              "    Ex: date=${event['date']}, heure=${event['heure']}, type=${event['type']}");
        }
      }
    });

    print("🎯 TOTAL: $totalEvents événements trouvés");
    return history;
  }

// Méthode utilitaire pour convertir "HH:mm" + date en Timestamp
  Timestamp _parseHourToTimestamp(String dateStr, String hourStr) {
    try {
      // Nettoyer la chaîne d'heure
      final cleanHour = hourStr.trim();
      if (cleanHour.isEmpty || cleanHour == 'null') {
        return Timestamp.now();
      }

      final dateParts = dateStr.split('-');
      final hourParts = cleanHour.split(':');

      if (dateParts.length != 3 || hourParts.length != 2) {
        print("❌ Format invalide - date: $dateStr, heure: $hourStr");
        return Timestamp.now();
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final hour = int.parse(hourParts[0]);
      final minute = int.parse(hourParts[1]);

      final dateTime = DateTime(year, month, day, hour, minute);
      return Timestamp.fromDate(dateTime);
    } catch (e) {
      print(
          "❌ Erreur parsing timestamp: $e pour date: $dateStr, heure: $hourStr");
      return Timestamp.now();
    }
  }

  Map<String, List<String>> _organizeEventsByDate(
      Map<String, List<Map<String, dynamic>>> history) {
    Map<String, List<String>> eventsByDate = {};

    print("🗓️ Organisation des événements par date...");

    // Traiter chaque type d'événement
    history.forEach((type, events) {
      print("📝 Traitement $type: ${events.length} événements");

      for (var event in events) {
        String dateKey = _extractDateKey(event, type);

        if (dateKey.isNotEmpty) {
          if (!eventsByDate.containsKey(dateKey)) {
            eventsByDate[dateKey] = [];
          }

          String eventText = _formatEventText(event, type);
          if (eventText.isNotEmpty) {
            eventsByDate[dateKey]!.add(eventText);
            print("  ✅ Ajouté à $dateKey: $eventText");
          }
        } else {
          print(
              "  ❌ Date manquante pour événement $type: ${event.keys.toList()}");
        }
      }
    });

    // Trier les événements de chaque jour par heure
    eventsByDate.forEach((date, events) {
      events.sort((a, b) {
        // Extraire l'heure du début de chaque événement pour trier
        String hourA = _extractHourFromEvent(a);
        String hourB = _extractHourFromEvent(b);
        return hourA.compareTo(hourB);
      });

      print("📅 $date: ${events.length} événements triés");
    });

    print("🎯 Total: ${eventsByDate.keys.length} jours avec événements");
    return eventsByDate;
  }

  String _extractHourFromEvent(String eventText) {
    try {
      // Format: "HH:mm - Description"
      if (eventText.contains(' - ')) {
        String hour = eventText.split(' - ')[0];
        // Vérifier que c'est bien une heure (format HH:mm)
        if (hour.contains(':') && hour.length >= 4) {
          return hour;
        }
      }
      return "00:00"; // Par défaut si pas d'heure trouvée
    } catch (e) {
      return "00:00";
    }
  }

  String _extractDateKey(Map<String, dynamic> event, String type) {
    try {
      if (type == 'horaires') {
        // Pour les horaires, utiliser le champ 'date' directement
        if (event.containsKey('date') && event['date'] is String) {
          return event['date']; // Format: "2025-05-30"
        }

        // Fallback: utiliser timestamp
        final timestamp = event['timestamp'] as Timestamp?;
        if (timestamp != null) {
          return DateFormat('yyyy-MM-dd').format(timestamp.toDate());
        }
      } else {
        // Pour les autres événements (repas, activités, etc.)
        final date = event['date'];
        if (date is Timestamp) {
          return DateFormat('yyyy-MM-dd').format(date.toDate());
        } else if (date is String) {
          // Si c'est déjà une string, vérifier le format
          if (date.contains('-') && date.length >= 10) {
            return date.substring(0, 10); // Garder seulement YYYY-MM-DD
          }
          return date;
        }
      }
      return '';
    } catch (e) {
      print("❌ Erreur extraction date pour $type: $e");
      return '';
    }
  }

  // CORRECTION : Méthode _formatEventText corrigée pour gérer les types de données
  String _formatEventText(Map<String, dynamic> event, String type) {
    try {
      switch (type) {
        case 'horaires':
          final heure = event['heure'] ?? '';
          final actionType = event['type'] ?? 'Non spécifié';
          return '$heure - ${actionType == 'arrivee' ? 'Arrivée' : 'Départ'}';

        case 'repas':
          final heure = event['heure'] ?? '';
          final quantite = event['quantite'];
          String quantiteStr = '';
          if (quantite != null) {
            if (quantite is String) {
              quantiteStr = quantite.isNotEmpty ? ' ($quantite)' : '';
            } else if (quantite is num) {
              quantiteStr = ' (${quantite}ml)';
            }
          }
          final typeRepas = event['type'] ?? event['typeRepas'] ?? 'Repas';
          return '$heure - $typeRepas$quantiteStr';

        case 'activites':
          final heure = event['heure'] ?? '';
          final typeActivite =
              event['type'] ?? event['typeActivite'] ?? 'Activité';
          final duree = event['duree'] ?? event['duration'] ?? '1 heure';
          final participation =
              event['participation'] ?? event['notes'] ?? 'Bien participé';
          return '$heure - $typeActivite ($duree) - $participation';

        case 'siestes':
          final heure = event['heure'] ?? '';
          final duree = event['duree'] ?? event['duration'] ?? '1 heure';
          final qualite = event['qualite'] ?? event['notes'] ?? 'Bien dormi';
          return '$heure - Sieste ($duree) - $qualite';

        case 'changes':
          final heure = event['heure'] ?? '';
          final typeChange = event['type'] ?? event['typeChange'] ?? 'Change';
          final details = event['details'] ?? event['notes'] ?? 'pipi';
          return '$heure - Change $typeChange ($details)';

        case 'sante':
          final heure = event['heure'] ?? '';
          final typeSoin = event['type'] ?? event['typeSoin'] ?? 'Soin';
          final valeur =
              event['valeur'] ?? event['temperature'] ?? event['value'];
          String valeurStr = '';
          if (valeur != null) {
            if (valeur is String) {
              valeurStr = valeur.isNotEmpty ? ' ($valeur)' : '';
            } else if (valeur is num) {
              valeurStr = ' (${valeur}°C)';
            }
          }
          final notes = event['notes'] ?? event['details'] ?? '';
          return '$heure - $typeSoin$valeurStr${notes.isNotEmpty ? ' - $notes' : ''}';

        case 'transmissions':
          final heure = event['heure'] ?? '';
          final typeTransmission = event['type'] ??
              event['typeTransmission'] ??
              event['category'] ??
              'Général';
          // CORRECTION : Essayer plusieurs champs pour le contenu de la transmission
          final message = event['message'] ??
              event['content'] ??
              event['notes'] ??
              event['details'] ??
              event['description'] ??
              event['texte'] ??
              '';

          // DEBUG : Afficher tous les champs pour identifier le bon
          print("🔍 DEBUG Transmission - event keys: ${event.keys.toList()}");
          print("🔍 DEBUG Transmission - message trouvé: '$message'");

          // Si le message est vide, afficher les données brutes pour debug
          if (message.isEmpty) {
            print("🔍 DEBUG Transmission - données complètes: $event");
            return '$heure - $typeTransmission: [Message vide - vérifier les champs]';
          }

          return '$heure - $typeTransmission: $message';

        default:
          return '${event['heure'] ?? 'Heure non spécifiée'} - ${event['type'] ?? type}';
      }
    } catch (e) {
      print("❌ Erreur formatage $type: $e");
      print("   Event data: $event");
      final heure = event['heure']?.toString() ?? 'Heure inconnue';
      return '$heure - $type (erreur formatage)';
    }
  }

  String _cleanTextForPdf(String text) {
    return text
        .replaceAll(''', "'")           // Apostrophe courbe gauche
      .replaceAll(''', "'") // Apostrophe courbe droite
        .replaceAll('"', '"') // Guillemet courbe gauche
        .replaceAll('"', '"') // Guillemet courbe droite
        .replaceAll('à', 'a') // à
        .replaceAll('é', 'e') // é
        .replaceAll('è', 'e') // è
        .replaceAll('ê', 'e') // ê
        .replaceAll('ë', 'e') // ë
        .replaceAll('î', 'i') // î
        .replaceAll('ï', 'i') // ï
        .replaceAll('ô', 'o') // ô
        .replaceAll('ö', 'o') // ö
        .replaceAll('ù', 'u') // ù
        .replaceAll('û', 'u') // û
        .replaceAll('ü', 'u') // ü
        .replaceAll('ç', 'c') // ç
        .replaceAll('À', 'A') // À
        .replaceAll('É', 'E') // É
        .replaceAll('È', 'E') // È
        .replaceAll('Ê', 'E') // Ê
        .replaceAll('Ë', 'E') // Ë
        .replaceAll('Î', 'I') // Î
        .replaceAll('Ï', 'I') // Ï
        .replaceAll('Ô', 'O') // Ô
        .replaceAll('Ö', 'O') // Ö
        .replaceAll('Ù', 'U') // Ù
        .replaceAll('Û', 'U') // Û
        .replaceAll('Ü', 'U') // Ü
        .replaceAll('Ç', 'C'); // Ç
  }

  String _formatDateForDisplay(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final weekdays = [
        'Lundi',
        'Mardi',
        'Mercredi',
        'Jeudi',
        'Vendredi',
        'Samedi',
        'Dimanche'
      ];
      final months = [
        'janvier',
        'février',
        'mars',
        'avril',
        'mai',
        'juin',
        'juillet',
        'août',
        'septembre',
        'octobre',
        'novembre',
        'décembre'
      ];

      return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateKey;
    }
  }

  Future<void> _deleteChildFromFirebase(
      String childId, String structureId) async {
    try {
      print("🗑️ Début suppression de l'enfant $childId...");

      final batch = FirebaseFirestore.instance.batch();

      // 1. Supprimer toutes les sous-collections de l'enfant
      final collectionsToDelete = [
        'repas',
        'activites',
        'siestes',
        'changes',
        'sante',
        'transmissions'
      ];

      for (String collection in collectionsToDelete) {
        print("🗑️ Suppression de la collection $collection...");

        final collectionRef = FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(childId)
            .collection(collection);

        final snapshot = await collectionRef.get();
        print("  - Trouvé ${snapshot.docs.length} documents dans $collection");

        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
          print("    * Suppression doc: ${doc.id}");
        }
      }

      // 2. Supprimer l'enfant des horaires
      print("🗑️ Suppression des horaires...");
      final horairesRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('horaires');

      final horairesSnapshot = await horairesRef.get();
      print("  - Trouvé ${horairesSnapshot.docs.length} dates d'horaires");

      for (var dateDoc in horairesSnapshot.docs) {
        final data = dateDoc.data();
        if (data.containsKey(childId)) {
          print(
              "    * Suppression de $childId dans les horaires du ${dateDoc.id}");
          batch.update(dateDoc.reference, {childId: FieldValue.delete()});
        }
      }

      // 3. Supprimer le document principal de l'enfant
      print("🗑️ Suppression du document principal de l'enfant...");
      final childRef = FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId);

      batch.delete(childRef);

      // 4. Exécuter toutes les suppressions
      print("🗑️ Exécution du batch de suppression...");
      await batch.commit();

      print("✅ Suppression complète de l'enfant $childId terminée !");
    } catch (e) {
      print("❌ Erreur lors de la suppression: $e");
      rethrow;
    }
  }

  Future<void> _removeChild() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print("🔄 Début du processus de retrait d'enfant...");

      // 1. Récupérer les données de l'enfant
      final childDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(widget.structureId)
          .collection('children')
          .doc(widget.childId)
          .get();

      if (!childDoc.exists) {
        throw Exception('Enfant non trouvé');
      }

      final childData = childDoc.data()!;
      print("✅ Données enfant récupérées");

      // 2. Récupérer l'historique complet
      final history =
          await _getCompleteHistory(widget.structureId, widget.childId);
      print("✅ Historique récupéré: ${history.length} types d'événements");

      // 3. Générer le PDF
      final pdfBytes = await _generatePdf(childData, history);
      final pdfBase64 = base64Encode(pdfBytes);
      print("✅ PDF généré: ${pdfBase64.length} caractères");

      // 4. Envoyer l'email
      await _sendHistoryEmail(childData, pdfBase64, widget.structureId);
      print("✅ Email envoyé");

      // 5. NOUVEAU : Supprimer complètement l'enfant de Firebase
      await _deleteChildFromFirebase(widget.childId, widget.structureId);
      print("✅ Enfant supprimé de Firebase");

      // 6. Afficher le message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Enfant retiré avec succès. L\'historique a été envoyé par email et toutes les données ont été supprimées.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Retourner au dashboard
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("❌ Erreur lors du retrait: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du retrait: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAllChildData(String structureId, String childId) async {
    final batch = FirebaseFirestore.instance.batch();

    // Collections dans la structure
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
          .collection(collection)
          .where('childId', isEqualTo: childId)
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    // Horaires dans collection séparée
    final horaireSnapshot = await FirebaseFirestore.instance
        .collection('horaires_history')
        .where('childId', isEqualTo: childId)
        .get();

    for (var doc in horaireSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // L'enfant lui-même
    batch.delete(FirebaseFirestore.instance
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(childId));

    await batch.commit();
  }

  Future<void> _showRemovalConfirmationDialog() async {
    final childDoc = await FirebaseFirestore.instance
        .collection('structures')
        .doc(widget.structureId)
        .collection('children')
        .doc(widget.childId)
        .get();

    final childName = childDoc.data()?['prenom'] ?? 'Enfant';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Retirer $childName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Êtes-vous sûr de vouloir retirer cet enfant ?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text('Cette action va :'),
                  Text('• Générer un PDF avec tout l\'historique'),
                  Text(
                      '• Envoyer l\'historique par email aux parents et à l\'assistante maternelle'),
                  Text(
                      '• Supprimer définitivement toutes les données de l\'enfant'),
                  SizedBox(height: 16),
                  if (_isLoading) ...[
                    LinearProgressIndicator(),
                    SizedBox(height: 8),
                    Text(_status, style: TextStyle(fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                if (!_isLoading) ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      setDialogState(() {
                        _isLoading = true;
                        _status = 'Début du processus...';
                      });

                      try {
                        await _generateAndSendChildHistory();

                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Enfant retiré avec succès. L\'email avec l\'historique a été envoyé.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        context.go('/home');
                      } catch (e) {
                        setDialogState(() {
                          _isLoading = false;
                          _status = 'Erreur: $e';
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur lors du retrait: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Retirer définitivement'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // En-tête avec fond de couleur
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A90E2),
                  Color(0xFF357ABD),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Retirer l\'enfant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Attention',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cette action retirera définitivement l\'enfant de l\'application.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ce qui va se passer :',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('• Un PDF avec tout l\'historique sera généré'),
                        Text(
                            '• L\'historique sera envoyé par email aux parents et à l\'assistante maternelle'),
                        Text(
                            '• Toutes les données de l\'enfant seront supprimées définitivement'),
                      ],
                    ),
                  ),
                  Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showRemovalConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Retirer l\'enfant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
