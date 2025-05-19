import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/models/garde_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';

class PlanningWeeklyView extends StatelessWidget {
  final DateTime weekStart;
  final List<Membre> membres;
  final List<Enfant> enfants;
  final List<Garde> gardes;
  final Function(Garde) onGardeEdit;
  final Color primaryColor;

  const PlanningWeeklyView({
    Key? key,
    required this.weekStart,
    required this.membres,
    required this.enfants,
    required this.gardes,
    required this.onGardeEdit,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Liste des jours de la semaine
    final jours = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"];

    // Couleurs pour les membres de la MAM (assistantes maternelles)
    final membreColors = [
      Color(0xFF4285F4), // Bleu
      Color(0xFFEA4335), // Rouge
      Color(0xFFFBBC05), // Jaune
      Color(0xFF34A853), // Vert
    ];

    // Calculer les dates des jours de la semaine
    final joursDates =
        List.generate(5, (index) => weekStart.add(Duration(days: index)));

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // En-tête avec les jours de la semaine
          Container(
            color: primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                // Cellule vide pour la colonne des noms d'assistantes
                Container(
                  width: 100,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    "Assistantes",
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

                // En-têtes de jours avec dates
                Expanded(
                  child: Row(
                    children: List.generate(jours.length, (index) {
                      final jour = jours[index];
                      final date = joursDates[index];
                      return Expanded(
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                jour,
                                style: TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow
                                    .visible, // Éviter la troncature
                              ),
                              Text(
                                "${date.day}/${date.month}",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Corps du planning - Scrollable pour les membres
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(membres.length, (index) {
                  final membre = membres[index];
                  final membreColor = membreColors[index % membreColors.length];
                  return _buildMemberRow(membre, jours, context, membreColor);
                }).toList(),
              ),
            ),
          ),

          // Légende des couleurs
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Légende:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                // Légende des assistantes
                Row(
                  children: [
                    Text("Assistantes: ",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    ...List.generate(membres.length, (index) {
                      final membre = membres[index];
                      final membreColor =
                          membreColors[index % membreColors.length];
                      return Container(
                        margin: EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: membreColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(membre.prenom, style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                SizedBox(height: 4),
                // Légende des enfants
                Text("Enfants:",
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: enfants.map((enfant) {
                    // Convertir la couleur hexadécimale en Color
                    Color couleur = _parseColor(enfant.couleur ?? "CCCCCC");

                    return Container(
                      margin: EdgeInsets.only(right: 4, bottom: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: couleur.withOpacity(0.3),
                        border: Border.all(color: couleur),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        enfant.prenom,
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Membre membre, List<String> jours,
      BuildContext context, Color membreColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom de l'assistante maternelle
        Container(
          width: 100,
          height: 200, // Hauteur fixe pour tous les jours
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: membreColor.withOpacity(0.1),
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
              right: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
              left: BorderSide(color: membreColor, width: 3),
            ),
          ),
          child: Center(
            child: Text(
              "${membre.prenom}\n${membre.nom}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: membreColor.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Cellules pour chaque jour
        Expanded(
          child: Row(
            children: List.generate(jours.length, (index) {
              final jourSemaine = index + 1; // 1=lundi, 2=mardi...
              final jourDate = weekStart.add(Duration(days: index));

              // Récupérer les gardes pour ce jour et ce membre
              List<Garde> jourGardes =
                  _getGardesForMemberAndDay(membre.id, jourSemaine, jourDate);

              return Expanded(
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Stack(
                    children: [
                      // Lignes d'heures (8h-18h)
                      ..._buildHourLines(),

                      // Gardes du jour
                      ...jourGardes.map((garde) =>
                          _buildGardeItem(garde, context, membreColor)),

                      // Compteurs d'enfants par créneau horaire
                      ..._buildChildCounters(membre.id, jourSemaine, jourDate),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Garde> _getGardesForMemberAndDay(
      String membreId, int jourSemaine, DateTime date) {
    // Récupérer les gardes récurrentes pour ce jour de la semaine
    final recurrentGardes = gardes
        .where((g) =>
            g.membreId == membreId &&
            g.jourSemaine == jourSemaine &&
            g.recurrent)
        .toList();

    // Récupérer les gardes exceptionnelles pour cette date spécifique
    final dateGardes = gardes
        .where((g) =>
            g.membreId == membreId &&
            g.recurrent == false &&
            g.dateException != null &&
            g.dateException!.year == date.year &&
            g.dateException!.month == date.month &&
            g.dateException!.day == date.day)
        .toList();

    // Donner priorité aux gardes exceptionnelles
    // Si une garde exceptionnelle existe pour cette date, elle remplace la garde récurrente
    final allGardes = [...recurrentGardes];

    for (var exceptGarde in dateGardes) {
      // Vérifier si une garde récurrente existe déjà pour cet enfant ce jour
      final index = allGardes.indexWhere(
          (g) => g.enfantId == exceptGarde.enfantId && g.recurrent == true);

      if (index >= 0) {
        // Remplacer la garde récurrente par la garde exceptionnelle
        allGardes[index] = exceptGarde;
      } else {
        // Ajouter la garde exceptionnelle
        allGardes.add(exceptGarde);
      }
    }

    return allGardes;
  }

  // Construire les compteurs d'enfants pour chaque créneau horaire
  List<Widget> _buildChildCounters(
      String membreId, int jourSemaine, DateTime date) {
    // Créneaux horaires à vérifier (toutes les demi-heures de 8h à 18h)
    final creneaux = List.generate(21, (i) {
      final hour = 8 + (i ~/ 2);
      final minute = (i % 2) * 30;
      return TimeOfDay(hour: hour, minute: minute);
    });

    // Récupérer les gardes pour ce membre et ce jour
    final memberGardes = _getGardesForMemberAndDay(membreId, jourSemaine, date);

    return creneaux.map((creneau) {
      // Compter les enfants présents à ce créneau horaire
      final enfantsCount = memberGardes.where((garde) {
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
        right: 2,
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
                padding: EdgeInsets.only(left: 2),
                color: Colors.white,
                child: Text(
                  '$heure:00',
                  style: TextStyle(
                    fontSize: 9,
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
    // Calcul de la position et taille du créneau
    final debut = _parseHeure(garde.heureDebut);
    final fin = _parseHeure(garde.heureFin);
    final top = (debut.hour - 8) * 16 + (debut.minute / 60 * 16);
    final height =
        ((fin.hour - debut.hour) * 60 + (fin.minute - debut.minute)) / 60 * 16;

    // Trouver l'enfant et sa couleur
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

    // Convertir la couleur hexadécimale en Color
    Color couleur = _parseColor(enfant.couleur ?? "CCCCCC");

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height > 0 ? height : 16, // Garantir une hauteur minimale
      child: GestureDetector(
        onTap: () => onGardeEdit(garde),
        child: Container(
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: couleur),
            // Ajouter une bordure à gauche de la couleur de l'assistante
            boxShadow: [
              BoxShadow(
                color: membreColor.withOpacity(0.3),
                blurRadius: 1,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: membreColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      enfant.prenom,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (height > 20)
                Text(
                  '${garde.heureDebut}-${garde.heureFin}',
                  style: TextStyle(fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
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
