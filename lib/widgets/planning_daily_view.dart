import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/models/garde_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';
import 'dart:math';

class PlanningDailyView extends StatelessWidget {
  final DateTime selectedDate;
  final List<Membre> membres;
  final List<Enfant> enfants;
  final List<Garde> gardes;
  final Function(Garde) onGardeEdit;
  final Color primaryColor;

  const PlanningDailyView({
    Key? key,
    required this.selectedDate,
    required this.membres,
    required this.enfants,
    required this.gardes,
    required this.onGardeEdit,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Couleurs pour les membres de la MAM (assistantes maternelles)
    final membreColors = [
      Color(0xFF4285F4), // Bleu
      Color(0xFFEA4335), // Rouge
      Color(0xFFFBBC05), // Jaune
      Color(0xFF34A853), // Vert
    ];

    // Récupérer le jour de la semaine (1 = lundi, etc.)
    final jourSemaine = selectedDate.weekday;
    if (jourSemaine > 5) {
      // Weekend
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.weekend,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                "Pas de gardes le week-end",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Filtrer les gardes pour ce jour
    final List<Garde> gardesDuJour = gardes.where((garde) {
      if (garde.recurrent && garde.jourSemaine == jourSemaine) {
        return true;
      }
      if (!garde.recurrent &&
          garde.dateException != null &&
          garde.dateException!.year == selectedDate.year &&
          garde.dateException!.month == selectedDate.month &&
          garde.dateException!.day == selectedDate.day) {
        return true;
      }
      return false;
    }).toList();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // En-tête du jour
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            color: primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEEE dd MMMM', 'fr_FR').format(selectedDate),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Liste des assistantes avec leurs créneaux
          Expanded(
            child: membres.isEmpty
                ? Center(child: Text("Aucune assistante dans cette MAM"))
                : ListView.builder(
                    itemCount: membres.length,
                    itemBuilder: (context, index) {
                      final membre = membres[index];
                      final membreColor =
                          membreColors[index % membreColors.length];

                      // Gardes pour cette assistante ce jour
                      final membreGardes = gardesDuJour
                          .where((g) => g.membreId == membre.id)
                          .toList();

                      return _buildMembreSection(
                          membre, membreGardes, membreColor, context);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterLegendItem(int count, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }

  // Récupérer uniquement les enfants de ce jour
  List<Enfant> _getEnfantsDuJour(List<Garde> gardesDuJour) {
    final Set<String> enfantIds = gardesDuJour.map((g) => g.enfantId).toSet();
    return enfants.where((e) => enfantIds.contains(e.id)).toList();
  }

  Widget _buildMembreSection(Membre membre, List<Garde> membreGardes,
      Color membreColor, BuildContext context) {
    print(
        "Affichage section pour membre: ${membre.prenom} ${membre.nom} (ID: ${membre.id})");
    print("Nombre de gardes pour ce membre: ${membreGardes.length}");

    for (var garde in membreGardes) {
      final enfant = enfants.firstWhere(
        (e) => e.id == garde.enfantId,
        orElse: () => Enfant(
            id: '',
            nom: '',
            prenom: 'Inconnu',
            dateNaissance: DateTime.now(),
            membresIds: []),
      );
      print(
          "  - Garde: ${enfant.prenom} de ${garde.heureDebut} à ${garde.heureFin}, ID: ${garde.id}");
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: membreColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec nom de l'assistante
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: membreColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: membreColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "${membre.prenom} ${membre.nom}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  // Nombre d'enfants total ce jour
                  Text(
                    "${membreGardes.length} enfant${membreGardes.length > 1 ? 's' : ''}",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color:
                          membreGardes.length > 4 ? Colors.red : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Timeline des gardes
            Container(
              height: 500, // Hauteur augmentée
              color: Colors.grey.shade100, // Couleur de fond pour mieux voir
              child: Stack(
                children: [
                  // Lignes des heures (modifiées pour nouvelle échelle)
                  ..._buildHourLinesAlternative(),

                  // Message si pas de gardes
                  if (membreGardes.isEmpty)
                    Center(
                      child: Text(
                        "Aucune garde aujourd'hui",
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  // Gardes avec nouvelles positions
                  ...membreGardes.map(
                      (garde) => _buildGardeItem(garde, context, membreColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHourLinesAlternative() {
    return List.generate(11, (i) {
      final heure = i + 8; // 8h à 18h
      final posY = i * 50.0; // 50px par heure

      return Positioned(
        top: posY,
        left: 0,
        right: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne horizontale
            Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
            // Heure
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: Colors.white,
              child: Text(
                "$heure:00",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildHourLines() {
    // Générer des lignes pour les heures de 8h à 18h
    return List.generate(11, (i) {
      final heure = i + 8;
      return Positioned(
        top: i * 16.0, // 16px par heure
        left: 0,
        right: 0,
        child: Container(
          height: 1,
          color: Colors.grey.shade200,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.only(left: 4),
                color: Colors.white,
                child: Text(
                  '$heure:00',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildGardeItem(Garde garde, BuildContext context, Color membreColor) {
    // Trouver l'enfant
    final enfant = enfants.firstWhere(
      (e) => e.id == garde.enfantId,
      orElse: () => Enfant(
        id: '',
        nom: '',
        prenom: 'Inconnu',
        dateNaissance: DateTime.now(),
        membresIds: [],
      ),
    );

    // Couleur pour l'enfant
    Color couleur = _parseColor(enfant.couleur ?? "CCCCCC");

    // Calcul simplifié - pour un affichage vertical basique
    // Chaque heure = 50 pixels de hauteur
    final debut = _parseHeure(garde.heureDebut);
    final fin = _parseHeure(garde.heureFin);

    // Calculer les hauteurs en fonction de l'heure de début (depuis 8h)
    double top = ((debut.hour - 8) * 60 + debut.minute) * (50 / 60);
    double height =
        ((fin.hour - debut.hour) * 60 + (fin.minute - debut.minute)) *
            (50 / 60);

    // Garantir une hauteur minimale
    height = height < 30 ? 30 : height;

    print("NOUVELLE APPROCHE: top=$top, height=$height");

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: Container(
        margin: EdgeInsets.fromLTRB(40, 2, 10, 2),
        decoration: BoxDecoration(
          color: Colors.red, // Rouge vif pour test de visibilité
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.child_care, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    enfant.prenom,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                "${garde.heureDebut} - ${garde.heureFin}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Construire les compteurs d'enfants par créneau horaire
  List<Widget> _buildChildCounters(String membreId, List<Garde> membreGardes) {
    // Créneaux horaires à vérifier (toutes les demi-heures de 8h à 18h)
    final creneaux = List.generate(21, (i) {
      final hour = 8 + (i ~/ 2);
      final minute = (i % 2) * 30;
      return TimeOfDay(hour: hour, minute: minute);
    });

    return creneaux.map((creneau) {
      // Compter les enfants présents à ce créneau horaire
      final enfantsCount = membreGardes.where((garde) {
        final debut = _parseHeure(garde.heureDebut);
        final fin = _parseHeure(garde.heureFin);

        // Vérifier si le créneau est dans la plage horaire de la garde
        final creneauMinutes = creneau.hour * 60 + creneau.minute;
        final debutMinutes = debut.hour * 60 + debut.minute;
        final finMinutes = fin.hour * 60 + fin.minute;

        return creneauMinutes >= debutMinutes && creneauMinutes < finMinutes;
      }).length;

      // Ne rien afficher si aucun enfant
      if (enfantsCount == 0) {
        return SizedBox.shrink();
      }

      // Position du compteur
      final top = (creneau.hour - 8) * 16 + (creneau.minute / 60 * 16);

      // Couleur selon le nombre d'enfants
      Color counterColor;
      if (enfantsCount <= 2) {
        counterColor = Colors.green; // Peu d'enfants
      } else if (enfantsCount <= 4) {
        counterColor = Colors.orange; // Nombre normal
      } else {
        counterColor = Colors.red; // Trop d'enfants (plus de 4)
      }

      return Positioned(
        top: top - 8, // Légèrement au-dessus de la ligne d'heure
        right: 4,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: counterColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$enfantsCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  TimeOfDay _parseHeure(String heure) {
    final parts = heure.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Color _parseColor(String hexColor) {
    // Ajouter le préfixe # si nécessaire
    if (!hexColor.startsWith('#')) {
      hexColor = '#$hexColor';
    }

    // Assurer que la chaîne a la bonne longueur
    if (hexColor.length == 7) {
      return Color(int.parse(hexColor.substring(1, 7), radix: 16) + 0xFF000000);
    } else if (hexColor.length == 9) {
      return Color(int.parse(hexColor.substring(1, 9), radix: 16));
    } else {
      // Couleur par défaut en cas d'erreur
      return Color(0xFFCCCCCC);
    }
  }
}
