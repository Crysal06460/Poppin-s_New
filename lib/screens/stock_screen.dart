import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../utils/stock_badge_util.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  _StockScreenState createState() => _StockScreenState();
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
      'Lingette',
      'Mouchoirs'
    ],
    'Alimentation': [
      'Eau minérale',
      'Lait infantile',
      'Petits pots',
      'Biberons',
      'Gourde',
      'Tétine biberon'
    ],
    'Santé': [
      'Crème de change',
      'Doliprane',
      'Serum physiologique',
      'Thermomètre'
    ],
    'Change': [
      'Change complet',
      'Body',
      'Pantalon',
      'Sweat',
      'Teeshirt',
      'Short',
      'Chaussette',
      'Chausson',
      'Bavoirs'
    ],
    'Sommeil': ['Turbulette', 'Doudou', 'Tétine'],
    'Sortie': [
      'Manteau',
      'Bonnet',
      'Gants',
      'Casquette',
      'Lunette de soleil',
      'Bottes de pluie',
      'Kway'
    ],
    'Personnalisés':
        [], // Cette catégorie contiendra les articles personnalisés de la MAM
  };

  // Liste plate de tous les articles pour compatibilité avec le code existant
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

      // Obtenir l'ID de structure
      structureId = await _getStructureId(user);

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
    String userStructureId = user.uid;

    final String currentUserEmail = user.email?.toLowerCase() ?? '';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserEmail)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data() ?? {};
      if (userData['role'] == 'mamMember' && userData['structureId'] != null) {
        userStructureId = userData['structureId'];
      }
    }

    return userStructureId;
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

      // Récupérer l'email de l'utilisateur actuel
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Utiliser l'ID de structure déjà obtenu ou l'obtenir si pas encore fait
      if (structureId.isEmpty) {
        structureId = await _getStructureId(user);
      }

      // Récupérer la structure pour déterminer le type
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureSnapshot.exists) {
        setState(() {
          structureName =
              structureSnapshot['structureName'] ?? 'Structure inconnue';
        });
      }

      final String structureType = structureSnapshot.exists
          ? (structureSnapshot.data()?['structureType'] ??
              "AssistanteMaternelle")
          : "AssistanteMaternelle";

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

      if (structureType == "MAM") {
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: double.maxFinite,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Besoins en stock pour ${enfant['prenom']}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Cochez ce qui va bientôt manquer :",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Container avec défilement pour les catégories et items
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Pour chaque catégorie, créer un ExpansionPanel
                            ...stockCategories.entries.map((entry) {
                              final category = entry.key;
                              final items = entry.value;

                              // Ne pas afficher si la catégorie est vide
                              if (items.isEmpty &&
                                  category == 'Personnalisés') {
                                return Container(); // Widget vide
                              }

                              return Card(
                                elevation: 1,
                                margin: EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ExpansionTile(
                                  initiallyExpanded:
                                      localExpandedCategories[category] ??
                                          false,
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      localExpandedCategories[category] =
                                          expanded;
                                    });
                                  },
                                  title: Text(
                                    category,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  children: [
                                    // Afficher les éléments de la catégorie
                                    ...items
                                        .map((item) => CheckboxListTile(
                                              title: Text(item),
                                              value:
                                                  selectedItems[item] ?? false,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  selectedItems[item] =
                                                      value ?? false;
                                                });
                                              },
                                              activeColor: primaryColor,
                                              dense: true,
                                            ))
                                        .toList(),

                                    // Bouton pour ajouter un produit personnalisé
                                    if (category == 'Personnalisés')
                                      ListTile(
                                        leading: Icon(Icons.add_circle_outline,
                                            color: primaryColor),
                                        title: Text(
                                          'Ajouter un produit personnalisé',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showAddCustomItemDialog();
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "ANNULER",
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _updateStockNeeds(enfant['id'], selectedItems);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12), // Padding horizontal réduit
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "ENREGISTRER",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

      // Convertir en Map<String, dynamic> pour Firestore
      final stockData = Map<String, dynamic>.fromEntries(
          stockNeeds.entries.map((e) => MapEntry(e.key, e.value)));

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('stocks')
          .doc('current')
          .set(stockData, SetOptions(merge: true));

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
      }
    } catch (e) {
      print("Erreur lors de la mise à jour des stocks: $e");
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
      context.go('/child-info');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : enfants.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: enfants.length,
                        itemBuilder: _buildEnfantCard,
                      ),
          )
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      // Bouton pour gérer les produits personnalisés
      floatingActionButton: FloatingActionButton(
        onPressed: _showManageCustomItemsDialog,
        backgroundColor: primaryColor,
        child: Icon(Icons.add_shopping_cart, color: Colors.white),
        tooltip: 'Gérer les produits personnalisés',
      ),
    );
  }

  // AppBar personnalisé avec gradient
  Widget _buildAppBar() {
    return Container(
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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              // Première ligne: nom structure et date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      structureName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              // Icône et titre de la page
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/Icone_Stock.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.inventory_2_outlined,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Stock',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      showSelectedLabels: false,
      showUnselectedLabels: false,
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
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/Icone_Ajout_Enfant.png',
            width: 60,
            height: 60,
          ),
          label: "Ajouter",
        ),
      ],
    );
  }
}
