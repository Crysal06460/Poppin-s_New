import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poppins_app/models/garde_model.dart';
import 'package:poppins_app/models/enfant_model.dart';
import 'package:poppins_app/models/membre_model.dart';

class PlanningTableView extends StatefulWidget {
  final DateTime selectedDate;
  final List<Membre> membres;
  final List<Enfant> enfants;
  final List<Garde> gardes;
  final Function(Garde) onGardeEdit;
  final Color primaryColor;

  const PlanningTableView({
    Key? key,
    required this.selectedDate,
    required this.membres,
    required this.enfants,
    required this.gardes,
    required this.onGardeEdit,
    required this.primaryColor,
  }) : super(key: key);

  @override
  _PlanningTableViewState createState() => _PlanningTableViewState();
}

class _PlanningTableViewState extends State<PlanningTableView> {
  // Variables pour filtrer
  Membre? _selectedMembre;
  bool _showRecap = true;

  // Liste des heures (horaires fixes pour le planning) - MODIFIÉ ici pour élargir l'amplitude de 6h à 20h
  final List<String> _heures = [
    '6h',
    '7h',
    '8h',
    '9h',
    '10h',
    '11h',
    '12h',
    '13h',
    '14h',
    '15h',
    '16h',
    '17h',
    '18h',
    '19h',
    '20h'
  ];

  @override
  void initState() {
    super.initState();
    // Initialiser avec tous les membres (pas de filtre)
    _selectedMembre = null;

    // Afficher les gardes pour debug
    Future.delayed(Duration.zero, () {
      _debugPrintGardes();
    });
  }

  void _debugPrintGardes() {
    // Debugging: afficher les gardes dans la console
    final jourSemaine = widget.selectedDate.weekday;
    final gardesDuJour = widget.gardes.where((garde) {
      if (garde.recurrent && garde.jourSemaine == jourSemaine) {
        return true;
      }
      if (!garde.recurrent &&
          garde.dateException != null &&
          garde.dateException!.year == widget.selectedDate.year &&
          garde.dateException!.month == widget.selectedDate.month &&
          garde.dateException!.day == widget.selectedDate.day) {
        return true;
      }
      return false;
    }).toList();

    print("===== DEBUG GARDES DU JOUR (jour ${jourSemaine}) =====");
    print("Nombre de gardes: ${gardesDuJour.length}");
    for (var garde in gardesDuJour) {
      final enfant = widget.enfants.firstWhere(
        (e) => e.id == garde.enfantId,
        orElse: () => Enfant(
            id: '',
            nom: 'Inconnu',
            prenom: 'Inconnu',
            dateNaissance: DateTime.now(),
            membresIds: []),
      );
      final membre = widget.membres.firstWhere(
        (m) => m.id == garde.membreId,
        orElse: () => Membre(
            id: '', nom: 'Inconnu', prenom: 'Inconnu', mamId: '', role: ''),
      );
      print(
          "Garde: ${enfant.prenom} avec ${membre.prenom} de ${garde.heureDebut} à ${garde.heureFin}, jour ${garde.jourSemaine}");
    }
    print("===== FIN DEBUG =====");
  }

// NOUVELLE MÉTHODE À AJOUTER : Calculer la hauteur du récapitulatif en fonction du nombre de membres
  double _calculateRecapHeight() {
    // Hauteur de base pour le titre et les marges
    double baseHeight = 50;

    // Hauteur de l'en-tête du tableau
    double headerHeight = 30;

    // Hauteur pour chaque ligne de membre (30px par ligne)
    double rowHeight = 30;

    // Nombre de membres
    int nombreMembres = widget.membres.length;

    // Hauteur totale = base + en-tête + (nombre de membres × hauteur par ligne)
    double totalHeight =
        baseHeight + headerHeight + (nombreMembres * rowHeight);

    // Hauteur minimum de 135 et maximum de 300 pour éviter que ça devienne trop grand
    return totalHeight.clamp(135.0, 300.0);
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer le jour de la semaine (1 = lundi, etc.)
    final jourSemaine = widget.selectedDate.weekday;

    if (jourSemaine > 5) {
      // Weekend - pas de planning
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
                "Pas de garde le week-end",
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
    final List<Garde> gardesDuJour = widget.gardes.where((garde) {
      if (garde.recurrent && garde.jourSemaine == jourSemaine) {
        return true;
      }
      if (!garde.recurrent &&
          garde.dateException != null &&
          garde.dateException!.year == widget.selectedDate.year &&
          garde.dateException!.month == widget.selectedDate.month &&
          garde.dateException!.day == widget.selectedDate.day) {
        return true;
      }
      return false;
    }).toList();

    // Filtrer par membre si un membre est sélectionné
    List<Garde> gardesFiltrees = _selectedMembre != null
        ? gardesDuJour.where((g) => g.membreId == _selectedMembre!.id).toList()
        : gardesDuJour;

    // Calculer les enfants présents par heure et par assistante
    final enfantsParHeure = _calculerEnfantsParHeure(gardesDuJour);

    // Récupérer les enfants qui ont des gardes aujourd'hui
    final enfantsDuJour = _getEnfantsDuJour(gardesFiltrees);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Barre de filtres
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: widget.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                // Filtre par assistante
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Membre?>(
                        value: _selectedMembre,
                        hint: Text("Toutes les assistantes"),
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down,
                            color: widget.primaryColor),
                        items: [
                          DropdownMenuItem<Membre?>(
                            value: null,
                            child: Text("Toutes les assistantes"),
                          ),
                          ...widget.membres.map((membre) {
                            return DropdownMenuItem<Membre?>(
                              value: membre,
                              child: Text("${membre.prenom} ${membre.nom}"),
                            );
                          }).toList(),
                        ],
                        onChanged: (Membre? value) {
                          setState(() {
                            _selectedMembre = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),

                // Bouton pour afficher/masquer le récapitulatif
                IconButton(
                  icon: Icon(
                    _showRecap
                        ? Icons.visibility_off
                        : Icons.visibility, // Garder cette ligne comme elle est
                    color: widget.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _showRecap = !_showRecap;
                    });
                  },
                  tooltip: _showRecap
                      ? "Masquer le récapitulatif" // Garder cette ligne comme elle est
                      : "Afficher le récapitulatif",
                ),
              ],
            ),
          ),

          // Légende des assistantes (couleurs)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.membres.map((membre) {
                  Color membreColor =
                      _getMemberColor(widget.membres.indexOf(membre));
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
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
                        Text(
                          membre.prenom,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Message si pas d'enfants
          if (enfantsDuJour.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _selectedMembre != null
                      ? "Aucun enfant aujourd'hui pour ${_selectedMembre!.prenom}"
                      : "Aucun enfant présent aujourd'hui",
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

          // Tableau principal - Vue horizontale scrollable
          if (enfantsDuJour.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      headingRowColor:
                          MaterialStateProperty.all(Colors.grey.shade100),
                      columns: [
                        DataColumn(
                          label: Container(
                            width: 80,
                            child: Text(
                              'Enfant',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        ..._heures
                            .map((heure) => DataColumn(
                                  label: Container(
                                    width: 35,
                                    child: Text(
                                      heure,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ],
                      rows: enfantsDuJour.map((enfant) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Container(
                                width: 80,
                                child: Text(
                                  enfant.prenom,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            ..._heures.map((heure) {
                              // Trouver si l'enfant est présent à cette heure
                              final membreId = _getMembreIdForEnfantAndHeure(
                                  enfant.id, heure, gardesFiltrees);
                              if (membreId != null) {
                                // Trouver le membre correspondant
                                final membreIndex = widget.membres
                                    .indexWhere((m) => m.id == membreId);
                                if (membreIndex >= 0) {
                                  final membre = widget.membres[membreIndex];
                                  final membreColor =
                                      _getMemberColor(membreIndex);

                                  // MODIFIÉ: Supprimer l'interaction avec GestureDetector
                                  return DataCell(
                                    Container(
                                      width: 35,
                                      height: 35,
                                      color: membreColor.withOpacity(0.7),
                                    ),
                                  );
                                }
                              }

                              // Cellule vide si pas présent
                              return DataCell(Container(width: 35, height: 35));
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),

          // Récapitulatif en bas (nombre d'enfants par heure)
          if (_showRecap)
            Container(
              // MODIFIÉ: Hauteur dynamique basée sur le nombre de membres
              height: _calculateRecapHeight(),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Nombre d'enfants par heure:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        headingRowHeight: 30,
                        dataRowHeight: 30,
                        headingRowColor:
                            MaterialStateProperty.all(Colors.grey.shade200),
                        columns: [
                          DataColumn(
                            label: Container(
                              width: 80,
                              child: Text(
                                'Assistante',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                          ..._heures
                              .map((heure) => DataColumn(
                                    label: Container(
                                      width: 35,
                                      child: Text(
                                        heure,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ],
                        rows: widget.membres.map((membre) {
                          final membreIndex = widget.membres.indexOf(membre);
                          final membreColor = _getMemberColor(membreIndex);

                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  width: 80,
                                  child: Text(
                                    "${membre.prenom}${membre.nom.isNotEmpty ? ' ' + membre.nom.substring(0, 1) + '.' : ''}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                      color: membreColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              ..._heures.map((heure) {
                                final count =
                                    enfantsParHeure[membre.id]?[heure] ?? 0;
                                final bool isTooMany =
                                    count > 4; // Plus de 4 enfants = trop

                                return DataCell(
                                  Container(
                                    width: 35,
                                    height: 30,
                                    color: isTooMany
                                        ? Colors.red.withOpacity(0.2)
                                        : null,
                                    child: Center(
                                      child: Text(
                                        count.toString(),
                                        style: TextStyle(
                                          fontWeight: count > 0
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isTooMany ? Colors.red : null,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Récupérer uniquement les enfants présents ce jour
  List<Enfant> _getEnfantsDuJour(List<Garde> gardesFiltrees) {
    final Set<String> enfantIds = gardesFiltrees.map((g) => g.enfantId).toSet();
    return widget.enfants.where((e) => enfantIds.contains(e.id)).toList();
  }

  // Calculer le nombre d'enfants par heure et par assistante
  Map<String, Map<String, int>> _calculerEnfantsParHeure(
      List<Garde> gardesDuJour) {
    // Structure: {membreId: {heure: nombreEnfants}}
    Map<String, Map<String, int>> enfantsParHeure = {};

    // Initialiser la structure
    for (var membre in widget.membres) {
      enfantsParHeure[membre.id] = {};
      for (var heure in _heures) {
        enfantsParHeure[membre.id]![heure] = 0;
      }
    }

    // Parcourir toutes les gardes
    for (var garde in gardesDuJour) {
      if (!enfantsParHeure.containsKey(garde.membreId)) continue;

      // Pour chaque heure, vérifier si elle est dans la plage de la garde
      for (var heure in _heures) {
        if (_isHeureInGarde(heure, garde)) {
          enfantsParHeure[garde.membreId]![heure] =
              (enfantsParHeure[garde.membreId]![heure] ?? 0) + 1;
        }
      }
    }

    return enfantsParHeure;
  }

  // Vérifier si une heure est dans la plage de la garde
  bool _isHeureInGarde(String heure, Garde garde) {
    try {
      // Convertir l'heure du format "8h" en heures (8)
      int heureNum = int.parse(heure.replaceAll('h', ''));

      // Convertir heureDebut et heureFin en heures
      List<String> debutParts = garde.heureDebut.split(':');
      List<String> finParts = garde.heureFin.split(':');

      if (debutParts.isEmpty || finParts.isEmpty) return false;

      int debutHeure = int.parse(debutParts[0]);
      int finHeure = int.parse(finParts[0]);

      // Cas spécial: si heureDebut == heureFin, on considère que c'est pour l'heure exacte
      if (debutHeure == finHeure) {
        return heureNum == debutHeure;
      }

      // Si l'heure est dans la plage
      return heureNum >= debutHeure && heureNum < finHeure;
    } catch (e) {
      print("Erreur dans _isHeureInGarde: $e");
      return false;
    }
  }

  // Déterminer si un enfant est présent à une heure donnée, et retourne l'ID du membre responsable
  String? _getMembreIdForEnfantAndHeure(
      String enfantId, String heure, List<Garde> gardesDuJour) {
    // Chercher une garde pour cet enfant à cette heure
    for (var garde in gardesDuJour) {
      if (garde.enfantId != enfantId) continue;

      // Si l'heure est dans la plage de cette garde
      if (_isHeureInGarde(heure, garde)) {
        // Retourner l'ID du membre directement depuis la garde
        return garde.membreId;
      }
    }

    // Si aucune garde n'est trouvée pour cette heure, retourner null
    return null;
  }

  // Obtenir une couleur pour un membre en fonction de son index
  Color _getMemberColor(int index) {
    final colors = [
      Color(0xFF4285F4), // Bleu
      Color(0xFFEA4335), // Rouge
      Color(0xFFFBBC05), // Jaune
      Color(0xFF34A853), // Vert
      Color(0xFF9C27B0), // Violet
      Color(0xFF00BCD4), // Cyan
      Color(0xFFFF9800), // Orange
      Color(0xFF795548), // Marron
    ];

    return colors[index % colors.length];
  }
}
