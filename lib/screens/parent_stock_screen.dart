import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/badged_icon.dart';
import '../utils/message_badge_util.dart';

class ParentStockScreen extends StatefulWidget {
  const ParentStockScreen({Key? key}) : super(key: key);

  @override
  _ParentStockScreenState createState() => _ParentStockScreenState();
}

class _ParentStockScreenState extends State<ParentStockScreen>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String _parentFirstName = "";
  String _structureId = "";
  bool _showMessageBadge = false;

  // Variable pour suivre si l'application était en arrière-plan
  bool _wasInBackground = false;

  // Organisation des catégories de stock
  Map<String, List<String>> _stockCategories = {
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
    'Personnalisés': [], // Articles personnalisés de la structure
  };

  // Liste plate de tous les articles (sera peuplée dynamiquement)
  List<String> _stockItems = [];

  // Map pour stocker les icônes selon la catégorie
  Map<String, IconData> _categoryIcons = {
    'Hygiène': Icons.clean_hands,
    'Alimentation': Icons.restaurant,
    'Santé': Icons.health_and_safety,
    'Change': Icons.checkroom,
    'Sommeil': Icons.bed,
    'Sortie': Icons.wb_sunny,
    'Personnalisés': Icons.library_add,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadUserData();
    });
    _checkMessageBadge();
  }

  // Cette méthode est appelée lorsque l'état de l'application change
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasInBackground) {
      // L'application est revenue au premier plan après avoir été en arrière-plan
      _wasInBackground = false;
      print("Application revenue au premier plan - actualisation automatique");

      // Actualiser toutes les données
      _refreshData();
    } else if (state == AppLifecycleState.paused) {
      // L'application est passée en arrière-plan
      _wasInBackground = true;
      print("Application mise en arrière-plan");
    }
  }

  @override
  void dispose() {
    // Supprimer l'observateur lorsque le widget est disposé
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkMessageBadge() async {
    try {
      final shouldShow = await MessageBadgeUtil.shouldShowBadge();
      if (mounted) {
        setState(() {
          _showMessageBadge = shouldShow;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des messages non lus: $e');
    }
  }

  // Initialise et charge les articles personnalisés
  Future<void> _loadCustomItems() async {
    try {
      if (_structureId.isEmpty) return;

      // Charger les articles personnalisés de la structure depuis Firestore
      final customItemsDoc = await _firestore
          .collection('structures')
          .doc(_structureId)
          .collection('settings')
          .doc('customStockItems')
          .get();

      if (customItemsDoc.exists) {
        final customItems =
            List<String>.from(customItemsDoc.data()?['items'] ?? []);

        setState(() {
          _stockCategories['Personnalisés'] = customItems;
          // Mettre à jour la liste plate
          _updateFlatStockItems();
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des articles personnalisés: $e");
    }
  }

  // Met à jour la liste plate des articles
  void _updateFlatStockItems() {
    _stockItems = [];
    _stockCategories.forEach((category, items) {
      _stockItems.addAll(items);
    });
  }

  Future<void> _refreshData() async {
    // Montrer un indicateur de chargement
    setState(() => _isLoading = true);

    // Actualiser les données
    await _loadUserData();

    // Vérifier s'il y a des messages non lus
    await _checkMessageBadge();

    setState(() => _isLoading = false);

    // Afficher un feedback visuel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Données actualisées"),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blueGrey.shade700,
      ),
    );
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }

      // Récupérer les informations du parent
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email?.toLowerCase())
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _structureId = userData['structureId'] ?? '';

        setState(() {
          _parentFirstName = userData['firstName'] ?? '';
        });

        // Charger d'abord les articles personnalisés
        await _loadCustomItems();

        // Récupérer les enfants associés à ce parent
        final childIds = List<String>.from(userData['children'] ?? []);

        if (childIds.isNotEmpty && _structureId.isNotEmpty) {
          List<Map<String, dynamic>> childrenData = [];

          for (final childId in childIds) {
            final childDoc = await _firestore
                .collection('structures')
                .doc(_structureId)
                .collection('children')
                .doc(childId)
                .get();

            if (childDoc.exists) {
              final data = childDoc.data()!;

              // Initialiser un Map avec tous les articles possibles
              Map<String, bool> stockNeeds = {};
              for (var item in _stockItems) {
                stockNeeds[item] = false;
              }

              try {
                final stockDoc = await _firestore
                    .collection('structures')
                    .doc(_structureId)
                    .collection('children')
                    .doc(childId)
                    .collection('stocks')
                    .doc('current')
                    .get();

                if (stockDoc.exists) {
                  final stockData = stockDoc.data() as Map<String, dynamic>;

                  // Mettre à jour les valeurs avec les données de Firestore
                  stockData.forEach((key, value) {
                    if (stockNeeds.containsKey(key)) {
                      stockNeeds[key] = value ?? false;
                    }
                  });
                }
              } catch (e) {
                print("Erreur lors du chargement des stocks: $e");
              }

              childrenData.add({
                'id': childDoc.id,
                'firstName': data['firstName'] ?? 'Sans nom',
                'lastName': data['lastName'] ?? '',
                'photoUrl': data['photoUrl'],
                'structureId': _structureId,
                'gender': data['gender'] ?? 'Non spécifié',
                'stockNeeds': stockNeeds,
              });
            }
          }

          setState(() {
            _children = childrenData;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des données: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des données')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Méthode pour trouver la catégorie d'un article (pour l'icône)
  String _findCategoryForItem(String item) {
    for (var entry in _stockCategories.entries) {
      if (entry.value.contains(item)) {
        return entry.key;
      }
    }
    return 'Personnalisés'; // Catégorie par défaut
  }

  // Récupère seulement la liste des articles nécessaires (sans catégories)
  Map<String, List<String>> _getNeededItemsByCategory(
      Map<String, dynamic> stockNeeds) {
    // On crée simplement une liste d'articles, sans catégories multiples
    List<String> neededItems = [];

    // Ajouter tous les articles nécessaires
    stockNeeds.forEach((item, isNeeded) {
      if (isNeeded == true) {
        neededItems.add(item);
      }
    });

    // Retourner un map avec une seule clé vide
    return {'': neededItems};
  }

  // Obtenir l'icône pour un article spécifique
  IconData _getItemIcon(String item, String category) {
    // Icônes spécifiques pour certains articles courants
    Map<String, IconData> specificIcons = {
      'Couches': Icons.baby_changing_station,
      'Lingette': Icons.cleaning_services,
      'Eau minérale': Icons.water_drop,
      'Lait infantile': Icons.coffee,
      'Petits pots': Icons.child_care,
      'Biberons': Icons.water_drop,
      'Doliprane': Icons.medication,
      'Thermomètre': Icons.thermostat,
      'Body': Icons.checkroom,
      'Pantalon': Icons.checkroom,
      'Teeshirt': Icons.checkroom,
      'Turbulette': Icons.bed,
      'Doudou': Icons.smart_toy,
      'Tétine': Icons.child_friendly,
      'Manteau': Icons.checkroom,
      'Bonnet': Icons.face,
      'Gants': Icons.back_hand,
      'Lunette de soleil': Icons.wb_sunny,
    };

    // Si l'article a une icône spécifique, l'utiliser
    if (specificIcons.containsKey(item)) {
      return specificIcons[item]!;
    }

    // Sinon, utiliser l'icône de la catégorie
    return _categoryIcons[category] ?? Icons.inventory_2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    // Header avec effet parallaxe
                    SliverAppBar(
                      expandedHeight: 180.0,
                      pinned: true,
                      backgroundColor: primaryBlue,
                      actions: [
                        // Bouton d'actualisation
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: _refreshData,
                        ),
                        IconButton(
                          icon: Icon(Icons.logout, color: Colors.white),
                          onPressed: () async {
                            await _auth.signOut();
                            context.go('/');
                          },
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryBlue,
                                primaryBlue.withOpacity(0.85),
                              ],
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bonjour, $_parentFirstName",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                                        .format(DateTime.now())
                                        .toLowerCase(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Titre de la page
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: primaryBlue,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Besoins en fournitures",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "À apporter lors de votre prochaine visite",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Liste des enfants et leurs besoins en stock
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final child = _children[index];
                          final stockNeeds =
                              child['stockNeeds'] as Map<String, dynamic>;
                          final hasNeeds = stockNeeds.values.contains(true);

                          // Récupérer les besoins par catégorie
                          final neededItemsByCategory = hasNeeds
                              ? _getNeededItemsByCategory(stockNeeds)
                              : <String, List<String>>{};

                          return Container(
                            margin: EdgeInsets.fromLTRB(24, 0, 24, 16),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: child['photoUrl'] != null
                                            ? Image.network(
                                                child['photoUrl'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Container(
                                                  color: Colors.grey[200],
                                                  child: Icon(
                                                    child['gender'] == 'Garçon'
                                                        ? Icons.boy
                                                        : Icons.girl,
                                                    color: Colors.grey[400],
                                                    size: 30,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey[200],
                                                child: Icon(
                                                  child['gender'] == 'Garçon'
                                                      ? Icons.boy
                                                      : Icons.girl,
                                                  color: Colors.grey[400],
                                                  size: 30,
                                                ),
                                              ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          child['firstName'],
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          hasNeeds
                                              ? "Des fournitures sont demandées"
                                              : "Aucune fourniture demandée",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: hasNeeds
                                                ? Colors.orange[800]
                                                : Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (hasNeeds) ...[
                                  SizedBox(height: 20),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.orange[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange[800],
                                              size: 22,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Merci d'apporter :",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),

                                        // Afficher les articles sans catégories
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: neededItemsByCategory.values
                                              .expand((items) => items)
                                              .map((item) => Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.orange
                                                              .withOpacity(0.2),
                                                          blurRadius: 4,
                                                          offset: Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          _getItemIcon(
                                                              item,
                                                              _findCategoryForItem(
                                                                  item)),
                                                          size: 16,
                                                          color: Colors
                                                              .orange[700],
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          item,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .orange[900],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.green[700],
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Tout est à jour pour ${child['firstName']}",
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                        childCount: _children.length,
                      ),
                    ),

                    // Espace en bas
                    SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        child: Icon(Icons.refresh),
        onPressed: _refreshData,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Onglet stock actif
        onTap: (index) {
          if (index == 0) {
            // Vers le journal
            context.go('/parent/home');
          } else if (index == 1) {
            // Vers la messagerie
            setState(() {
              _showMessageBadge = false; // Réinitialiser le badge
            });
            context.go('/parent/messages');
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.black87,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.black87),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/maison_icon.png',
              width: 60,
              height: 60,
            ),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_Echanges.png',
                  width: 60,
                  height: 60,
                ),
                if (_showMessageBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_Echanges.png',
                  width: 60,
                  height: 60,
                  color: primaryBlue,
                ),
                if (_showMessageBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                    ),
                  ),
              ],
            ),
            label: "Messages",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_Stock.png',
              width: 60,
              height: 60,
            ),
            activeIcon: Image.asset(
              'assets/images/Icone_Stock.png',
              width: 60,
              height: 60,
            ),
            label: "Stocks",
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              "Aucun enfant associé",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Aucun enfant n'est associé à votre compte pour le moment. Veuillez contacter votre structure d'accueil.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh),
              label: Text("Rafraîchir"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
