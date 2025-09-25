import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../utils/stock_badge_util.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../widgets/common_app_bar.dart';
import '../utils/structure_context.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  _StockScreenState createState() => _StockScreenState();
}

bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide >= 600;
}

class _StockScreenState extends State<StockScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  String structureId = "";
  int _selectedIndex = 1;
  TextEditingController newItemController = TextEditingController();

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Couleurs de l'application
  Color primaryColor = Color(0xFF3D9DF2); // Bleu #3D9DF2
  Color secondaryColor = Color(0xFFDFE9F2); // Bleu clair #DFE9F2

  // Structure pour organiser les articles de stock par catégorie
  Map<String, List<String>> stockCategories = {
    'Hygiène': [
      'Couches',
      'Lait de change',
      'Liniment',
      'Eau nettoyante',
      'Coton',
      'Lingettes',
      'Mouchoirs'
    ],
    'Alimentation': [
      'Eau minérale',
      'Lait infantile',
      'Petits pots',
      'Biberons',
      'Gourde',
      'Tétine de biberon'
    ],
    'Santé': [
      'Crème de change',
      'Doliprane',
      'Sérum physiologique',
      'Thermomètre'
    ],
    'Change': [
      'Change complet',
      'Body',
      'Pantalon',
      'Sweat',
      'T-shirt',
      'Short',
      'Chaussettes',
      'Chaussons',
      'Bavoir'
    ],
    'Sommeil': ['Turbulette', 'Doudou', 'Tétine'],
    'Sortie': [
      'Manteau',
      'Bonnet',
      'Gants',
      'Casquette',
      'Lunettes de soleil',
      'Bottes de pluie',
      'K-way'
    ],
    'Personnalisés':
        [], // Cette catégorie contiendra les articles personnalisés de la MAM
  };

  List<String> stockItems = [];

  // Garde en mémoire quelles catégories sont développées
  Map<String, bool> expandedCategories = {};

  @override
  void initState() {
    super.initState();

    // Initialiser toutes les catégories comme repliées par défaut
    stockCategories.keys.forEach((category) {
      expandedCategories[category] = false;
    });

    // Développer la première catégorie par défaut
    if (stockCategories.isNotEmpty) {
      expandedCategories[stockCategories.keys.first] = true;
    }

    initializeDateFormatting('fr_FR', null).then((_) {
      _initializeStockItems();
      _loadAllChildren();
    });
  }

  @override
  void dispose() {
    newItemController.dispose();
    super.dispose();
  }

  // Initialise la liste des articles et charge les articles personnalisés
  Future<void> _initializeStockItems() async {
    // D'abord, aplatir les catégories standard dans stockItems
    stockItems = [];
    stockCategories.forEach((category, items) {
      if (category != 'Personnalisés') {
        stockItems.addAll(items);
      }
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final structureContext = await StructureResolver().resolve();
      structureId = structureContext.structureId;

      // Charger les articles personnalisés de la MAM depuis Firestore
      final customItemsDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customStockItems')
          .get();

      if (customItemsDoc.exists) {
        final customItems =
            List<String>.from(customItemsDoc.data()?['items'] ?? []);

        // Mettre à jour la liste des articles personnalisés
        setState(() {
          stockCategories['Personnalisés'] = customItems;
          // Ajouter les articles personnalisés à la liste plate
          stockItems.addAll(customItems);
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des articles personnalisés: $e");
    }
  }

  // Obtient l'ID de la structure de l'utilisateur
  Future<String> _getStructureId(User user) async {
    try {
      final structureContext = await StructureResolver().resolve();
      return structureContext.structureId;
    } catch (e) {
      print('⚠️ Stock: impossible de résoudre la structure via helper: $e');
      return user.uid;
    }
  }

  // Ajoute un nouvel article personnalisé
  Future<void> _addCustomStockItem(String newItem) async {
    if (newItem.trim().isEmpty) return;

    try {
      // Ajouter l'élément à la liste locale
      setState(() {
        stockCategories['Personnalisés'] = [
          ...stockCategories['Personnalisés'] ?? [],
          newItem.trim()
        ];
        stockItems.add(newItem.trim());
      });

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customStockItems')
          .set({
        'items': stockCategories['Personnalisés'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produit ajouté avec succès'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur lors de l'ajout d'un article personnalisé: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ajout du produit'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Supprimer un article personnalisé
  Future<void> _removeCustomStockItem(String item) async {
    try {
      // Vérifier si l'élément est utilisé par un enfant
      bool isUsed = false;

      for (var enfant in enfants) {
        Map<String, bool> stockNeeds =
            enfant['stockNeeds'] as Map<String, bool>;
        if (stockNeeds.containsKey(item) && stockNeeds[item] == true) {
          isUsed = true;
          break;
        }
      }

      if (isUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de supprimer : ce produit est utilisé'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Supprimer l'élément de la liste locale
      setState(() {
        stockCategories['Personnalisés']?.remove(item);
        stockItems.remove(item);
      });

      // Mettre à jour dans Firestore
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('settings')
          .doc('customStockItems')
          .set({
        'items': stockCategories['Personnalisés'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produit supprimé avec succès'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      print("Erreur lors de la suppression d'un article personnalisé: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression du produit'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAllChildren() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final structureContext = await StructureResolver().resolve();
      structureId = structureContext.structureId;
      final String currentUserEmail = structureContext.currentUserEmail;
      final String structureType = structureContext.normalizedStructureType;

      setState(() {
        structureName = structureContext.structureName;
      });

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? photoUrl = data['photoUrl'];

        // Chargement des stocks existants depuis Firestore
        Map<String, bool> stockNeeds = {};

        // Initialiser avec tous les articles (y compris personnalisés)
        for (var item in stockItems) {
          stockNeeds[item] = false;
        }

        try {
          final stockDoc = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .doc(doc.id)
              .collection('stocks')
              .doc('current')
              .get();

          if (stockDoc.exists) {
            final stockData = stockDoc.data() as Map<String, dynamic>;

            // Mise à jour des valeurs existantes
            stockData.forEach((key, value) {
              if (stockNeeds.containsKey(key)) {
                stockNeeds[key] = value;
              }
            });
          }
        } catch (e) {
          print("Erreur lors du chargement des stocks: $e");
        }

        allChildren.add({
          'id': doc.id,
          'prenom': data['firstName'],
          'genre': data['gender'],
          'photoUrl': photoUrl,
          'stockNeeds': stockNeeds,
          'assignedMemberEmail':
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '',
          'structureId': structureId,
        });
      }

      // Appliquer le filtrage selon le type de structure
      List<Map<String, dynamic>> filteredChildren = [];

      if (structureType == 'mam') {
        // Pour une MAM: filtrer par assignedMemberEmail
        filteredChildren = allChildren.where((child) {
          return child['assignedMemberEmail'] == currentUserEmail;
        }).toList();

        print(
            "👨‍👧‍👦 Stock: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Stock: Assistante Maternelle - affichage de tous les enfants");
      }

      setState(() {
        enfants = filteredChildren;
        isLoading = false;
      });
      await _cleanCorruptedStockData();
    } catch (e) {
      print("❌ Erreur détaillée: $e");
      setState(() => isLoading = false);
    }
  }

  void _showAddCustomItemDialog() {
    newItemController.text = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Ajouter un produit personnalisé'),
          content: TextField(
            controller: newItemController,
            decoration: InputDecoration(
              hintText: 'Nom du produit',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ANNULER',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (newItemController.text.trim().isNotEmpty) {
                  _addCustomStockItem(newItemController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'AJOUTER',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveStockConfirmation(
      String childId, String item, String childName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Confirmation'),
          content: Text('Voulez-vous retirer "$item" de la demande de stock ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'ANNULER',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Mise à jour des stocks avec l'élément décoché
                final index = enfants.indexWhere((e) => e['id'] == childId);
                if (index != -1) {
                  Map<String, bool> updatedStocks =
                      Map<String, bool>.from(enfants[index]['stockNeeds']);
                  updatedStocks[item] = false;
                  _updateStockNeeds(childId, updatedStocks);
                }
              },
              child: Text(
                'OUI',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showManageCustomItemsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            List<String> customItems = stockCategories['Personnalisés'] ?? [];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('Gérer les produits personnalisés'),
              content: Container(
                width: double.maxFinite,
                child: customItems.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun produit personnalisé',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: customItems.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(customItems[index]),
                            trailing: IconButton(
                              icon:
                                  Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                _removeCustomStockItem(customItems[index]);
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'FERMER',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddCustomItemDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'AJOUTER',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStockPopup(Map<String, dynamic> enfant) {
    // Copier les besoins actuels
    Map<String, bool> selectedItems = Map.from(enfant['stockNeeds']);

    // État de l'expansion des catégories pour ce dialogue
    Map<String, bool> localExpandedCategories = Map.from(expandedCategories);

    // Déterminer si nous sommes sur iPad
    final bool isTabletDevice = isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              // Largeur adaptée pour iPad
              insetPadding: isTabletDevice
                  ? EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.25)
                  : EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête avec dégradé
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isTabletDevice ? 20 : 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTabletDevice ? 12 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.white,
                                size: isTabletDevice ? 30 : 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Gestion des stocks - ${enfant['prenom']}",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 22 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (isTabletDevice) SizedBox(height: 4),
                                  if (isTabletDevice)
                                    Text(
                                      "Le ${DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.now())}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenu avec les catégories
                      Padding(
                        padding: EdgeInsets.all(isTabletDevice ? 24 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 16),

                            // Liste des catégories
                            ...stockCategories.entries.map((entry) {
                              final category = entry.key;
                              final items = entry.value;

                              // Ne pas afficher si la catégorie est vide
                              if (items.isEmpty &&
                                  category == 'Personnalisés') {
                                return Container();
                              }

                              return Container(
                                margin: EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Titre de la catégorie (cliquable pour développer/réduire)
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          localExpandedCategories[category] =
                                              !(localExpandedCategories[
                                                      category] ??
                                                  false);
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: lightBlue.withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                primaryColor.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  fontSize:
                                                      isTabletDevice ? 18 : 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              localExpandedCategories[
                                                          category] ??
                                                      false
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                              color: primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Éléments de la catégorie (si développée)
                                    if (localExpandedCategories[category] ??
                                        false)
                                      Container(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          itemCount: items.length,
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            return CheckboxListTile(
                                              title: Text(
                                                item,
                                                style: TextStyle(
                                                  fontSize:
                                                      isTabletDevice ? 16 : 14,
                                                ),
                                              ),
                                              value:
                                                  selectedItems[item] ?? false,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  selectedItems[item] =
                                                      value ?? false;
                                                });
                                              },
                                              activeColor: primaryColor,
                                              checkColor: Colors.white,
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .trailing,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8),
                                            );
                                          },
                                        ),
                                      ),

                                    // Bouton pour ajouter un produit personnalisé (uniquement pour la catégorie "Personnalisés")
                                    if (category == 'Personnalisés' &&
                                        (localExpandedCategories[category] ??
                                            false))
                                      Padding(
                                        padding:
                                            EdgeInsets.only(top: 8, left: 8),
                                        child: TextButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showAddCustomItemDialog();
                                          },
                                          icon: Icon(Icons.add_circle,
                                              color: primaryColor),
                                          label: Text(
                                            "Ajouter un produit personnalisé",
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize:
                                                  isTabletDevice ? 15 : 14,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8),
                                            alignment: Alignment.centerLeft,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),

                            // Boutons d'action
                            SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Bouton Annuler
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isTabletDevice ? 24 : 16,
                                        vertical: isTabletDevice ? 16 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    "ANNULER",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),

                                // Bouton Enregistrer
                                ElevatedButton(
                                  onPressed: () {
                                    _updateStockNeeds(
                                        enfant['id'], selectedItems);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    elevation: 2,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isTabletDevice ? 32 : 24,
                                        vertical: isTabletDevice ? 16 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    "ENREGISTRER",
                                    style: TextStyle(
                                      fontSize: isTabletDevice ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStockNeeds(
      String childId, Map<String, bool> stockNeeds) async {
    try {
      // Trouver l'enfant pour récupérer l'ID de structure
      final enfant = enfants.firstWhere((e) => e['id'] == childId);
      final String structureId =
          enfant['structureId'] ?? FirebaseAuth.instance.currentUser?.uid;

      // CORRECTION : Ne sauvegarder que les items qui sont true
      final stockData = Map<String, dynamic>();
      stockNeeds.forEach((key, value) {
        if (value == true) {
          stockData[key] = value;
        }
      });

      // IMPORTANT : Remplacer complètement le document au lieu de merger
      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('stocks')
          .doc('current')
          .set(stockData); // Retirer SetOptions(merge: true)

      // Mettre à jour l'état local
      setState(() {
        final index = enfants.indexWhere((e) => e['id'] == childId);
        if (index != -1) {
          enfants[index]['stockNeeds'] = Map<String, bool>.from(stockNeeds);
        }
      });

      // Vérifier si ce changement a activé des besoins
      bool hasActiveNeeds = stockNeeds.values.contains(true);
      if (hasActiveNeeds) {
        // On active la notification pour les parents
        await StockBadgeUtil.setStockNeeds(true);
        print("✅ Badge activé dans les SharedPreferences");
      } else {
        // AJOUTER : Si plus aucun besoin, désactiver le badge
        await StockBadgeUtil.setStockNeeds(false);
        print("❌ Badge désactivé dans les SharedPreferences");
      }
    } catch (e) {
      print("Erreur lors de la mise à jour des stocks: $e");
    }
  }

// Méthode pour nettoyer les anciennes données corrompues
  Future<void> _cleanCorruptedStockData() async {
    try {
      for (var enfant in enfants) {
        final String structureId = enfant['structureId'] ?? '';
        final String childId = enfant['id'];

        // Lire le document actuel
        final stockDoc = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .doc(childId)
            .collection('stocks')
            .doc('current')
            .get();

        if (stockDoc.exists) {
          final stockData = stockDoc.data() as Map<String, dynamic>;

          // Ne garder que les entrées true
          final cleanedData = Map<String, dynamic>();
          stockData.forEach((key, value) {
            if (value == true) {
              cleanedData[key] = value;
            }
          });

          // Remplacer complètement le document avec les données nettoyées
          await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('children')
              .doc(childId)
              .collection('stocks')
              .doc('current')
              .set(cleanedData);

          print("🧹 Données nettoyées pour ${enfant['prenom']}: $cleanedData");
        }
      }
    } catch (e) {
      print("❌ Erreur lors du nettoyage: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/exchanges');
    }
  }

  // Avatar par défaut avec l'initiale du prénom
  Widget _buildFallbackAvatar(String name) {
    final isBoy = enfants.firstWhere((e) => e['prenom'] == name,
            orElse: () => {'genre': 'Garçon'})['genre'] ==
        'Garçon';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isBoy ? primaryBlue : primaryRed,
          ),
        ),
      ),
    );
  }

  Widget _buildEnfantCard(BuildContext context, int index) {
    final enfant = enfants[index];
    final stockNeeds = enfant['stockNeeds'] as Map<String, bool>;
    final hasNeeds = stockNeeds.values.any((value) => value);
    final isBoy = enfant['genre'] == 'Garçon';
    final avatarColor = isBoy ? primaryBlue : primaryRed;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            // En-tête avec photo et nom
            Row(
              children: [
                // Photo de l'enfant avec dégradé selon le genre
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isBoy
                          ? [primaryBlue.withOpacity(0.7), primaryBlue]
                          : [primaryRed.withOpacity(0.7), primaryRed],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isBoy ? primaryBlue : primaryRed).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              enfant['photoUrl'],
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackAvatar(enfant['prenom']),
                            ),
                          )
                        : _buildFallbackAvatar(enfant['prenom']),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isBoy ? primaryBlue : primaryRed,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: primaryColor, size: 30),
                  onPressed: () => _showStockPopup(enfant),
                  tooltip: 'Ajouter un besoin',
                ),
              ],
            ),

            // Besoins en stock actuels (s'il y en a)
            if (hasNeeds) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Besoins actuels :",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: stockNeeds.entries
                          .where((entry) => entry.value)
                          .map((entry) => GestureDetector(
                                onTap: () => _showRemoveStockConfirmation(
                                  enfant['id'],
                                  entry.key,
                                  enfant['prenom'],
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: primaryColor,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.close,
                                        color: primaryColor,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // État vide (aucun enfant)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Icone_Stock.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: primaryColor.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Aucun enfant inscrit',
            style: TextStyle(
              fontSize: 18,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cartes par ligne
        childAspectRatio: 1.2, // Ajustement du ratio pour les cartes
        crossAxisSpacing: 20, // Espace horizontal entre les cartes
        mainAxisSpacing: 20, // Espace vertical entre les cartes
      ),
      itemCount: enfants.length,
      itemBuilder: (context, index) =>
          _buildEnfantCardForTablet(context, index),
    );
  }

  Widget _buildEnfantCardForTablet(BuildContext context, int index) {
    final enfant = enfants[index];
    final stockNeeds = enfant['stockNeeds'] as Map<String, bool>;
    final hasNeeds = stockNeeds.values.any((value) => value);
    final isBoy = enfant['genre'] == 'Garçon';
    final avatarColor = isBoy ? primaryBlue : primaryRed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec gradient et infos enfant
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [avatarColor, avatarColor.withOpacity(0.85)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar avec photo de l'enfant
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: enfant['photoUrl'] != null &&
                            enfant['photoUrl'].isNotEmpty
                        ? Image.network(
                            enfant['photoUrl'],
                            width: 65,
                            height: 65,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              enfant['prenom'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            enfant['prenom'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    enfant['prenom'],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Bouton d'ajout de besoins
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: avatarColor, size: 24),
                      onPressed: () => _showStockPopup(enfant),
                      tooltip: "Ajouter un besoin",
                      padding: EdgeInsets.all(10),
                      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des besoins en stock
          Expanded(
            child: hasNeeds
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Besoins actuels :",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: stockNeeds.entries
                                    .where((entry) => entry.value)
                                    .map((entry) => GestureDetector(
                                          onTap: () =>
                                              _showRemoveStockConfirmation(
                                            enfant['id'],
                                            entry.key,
                                            enfant['prenom'],
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: primaryColor
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  entry.key,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(
                                                  Icons.close,
                                                  color: primaryColor,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Aucun besoin en stock",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Détection de l'iPad/tablette
    final bool isTabletDevice = isTablet(context);

    return SwipeNavigationWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ✨ NOUVEAU : CommonAppBar remplace _buildAppBar()
            CommonAppBar(
              title: 'Stock',
              structureName: structureName,
              iconPath: 'assets/images/Icone_Stock.png',
              primaryColor: primaryColor,
            ),

            // 🔄 GARDÉ IDENTIQUE : tout votre contenu existant
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : enfants.isEmpty
                      ? _buildEmptyState()
                      : isTabletDevice
                          ? _buildTabletLayout() // Layout adapté pour iPad
                          : ListView.builder(
                              itemCount: enfants.length,
                              itemBuilder: _buildEnfantCard,
                            ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: FloatingActionButton(
          onPressed: _showManageCustomItemsDialog,
          backgroundColor: primaryColor,
          child: Icon(Icons.add_shopping_cart, color: Colors.white),
          tooltip: 'Gérer les produits personnalisés',
        ),
      ),
    );
  }

  // Navigation du bas
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      items: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Dashboard.png',
            width: 60,
            height: 60,
          ),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/maison_icon.png',
            width: 60,
            height: 60,
          ),
          label: "Accueil",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Echanges.png',
            width: 60,
            height: 60,
          ),
          label: "Messages",
        ),
      ],
    );
  }
}
