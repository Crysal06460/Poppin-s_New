import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/badged_icon.dart';
import '../utils/stock_badge_util.dart';
import '../utils/message_badge_util.dart';
import '../utils/actualites_badge_util.dart';
import '../utils/photos_badge_util.dart';
import '../utils/session_util.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/photo_cleanup_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({Key? key}) : super(key: key);

  @override
  _ParentHomeScreenState createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _selectedPhotoDate = DateTime.now();
  bool _showingPhotoHistory = false;
  List<Map<String, dynamic>> _pastPhotos = [];
  bool _loadingPhotoHistory = false;
  // Couleurs officielles de l'application
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Variables pour les actualités
  Map<String, List<String>> _menuSemaine = {
    'Lundi': [],
    'Mardi': [],
    'Mercredi': [],
    'Jeudi': [],
    'Vendredi': [],
    'Samedi': [],
    'Dimanche': [],
  };
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _sorties = [];

  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String _parentFirstName = ""; // Stocke uniquement le prénom
  Map<String, dynamic>? _selectedChild;
  List<Map<String, dynamic>> _timelineEvents =
      []; // Pour stocker les événements du jour
  bool _loadingTimeline = false;
  bool _showStockBadge = false;
  bool _showMessageBadge = false;
  bool _showEventsBadge = false;
  bool _showSortiesBadge = false;
  bool _showActualitesBadge = false; // global: events OR sorties
  bool _showPhotosBadge = false;

  // Variable pour suivre si l'application était en arrière-plan
  bool _wasInBackground = false;

  // Ajouter ces déclarations pour la gestion des streams
  List<StreamSubscription> _subscriptions = [];
  Map<String, List<Map<String, dynamic>>> _eventsMap = {
    'activity': [],
    'meal': [],
    'sleep': [],
    'change': [],
    'health': [],
    'photo': [],
    'hour': [],
    'transmission': [],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    initializeDateFormatting('fr_FR', null).then((_) {
      _loadUserData();
      // Déclencher le nettoyage automatique des photos anciennes
      _performPhotoCleanup();
    });

    _checkStockBadge();
    _checkMessageBadge();
    _checkActualitesBadges();
    _checkPhotosBadge();
  }

  Future<void> _performPhotoCleanup() async {
    try {
      await PhotoCleanupService.checkAndCleanupPhotos();
    } catch (e) {
      print("Erreur lors du nettoyage automatique des photos: $e");
      // Ne pas montrer d'erreur à l'utilisateur car c'est un processus en arrière-plan
    }
  }

  // Remplacer la méthode _checkMessageBadge actuelle par celle-ci
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

// Remplacer la méthode _setupMessageListener par celle-ci
  // Conservez UNIQUEMENT cette version de la méthode et supprimez l'autre
  // Dans le fichier parent_home_screen.dart, modifiez la méthode _setupMessageListener :

  void _setupMessageListener() {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Annuler les écouteurs précédents
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();

      print("🎧 Configuration des écouteurs de messages pour: ${user.email}");

      // 1. Écouter les changements dans le document utilisateur
      final userEmail = user.email?.toLowerCase();
      if (userEmail != null) {
        final userDocStream =
            _firestore.collection('users').doc(userEmail).snapshots();

        _subscriptions.add(userDocStream.listen((snapshot) {
          if (snapshot.exists) {
            final userData = snapshot.data()!;
            final unreadMessages = userData['unreadMessages'] ?? 0;

            print(
                "📬 Messages non lus détectés dans le document: $unreadMessages");

            if (unreadMessages > 0 && mounted) {
              setState(() {
                _showMessageBadge = true;
              });
              print("🔔 Badge activé via document utilisateur!");
            } else if (unreadMessages == 0 && _showMessageBadge && mounted) {
              setState(() {
                _showMessageBadge = false;
              });
              print("🔕 Badge de notification désactivé");
            }
          } else {
            print("⚠️ Document utilisateur non trouvé pour: $userEmail");
          }
        }, onError: (error) {
          print("❌ Erreur dans l'écouteur de messages: $error");
        }));
      }

      // 2. Écouter directement les nouveaux messages dans exchanges
      if (_children.isNotEmpty) {
        // Récupérer tous les IDs des enfants
        final List<String> childIds =
            _children.map((child) => child['id'] as String).toList();

        if (childIds.isNotEmpty) {
          print("🎧 Configuration de l'écouteur pour les enfants: $childIds");

          final exchangesStream = _firestore
              .collection('exchanges')
              .where('childId', whereIn: childIds)
              .where('nonLu', isEqualTo: true)
              .where('senderType',
                  isEqualTo:
                      'staff') // Uniquement les messages de l'assistante maternelle
              .snapshots();

          _subscriptions.add(exchangesStream.listen((snapshot) {
            final count = snapshot.docs.length;
            print("📨 Messages non lus détectés dans exchanges: $count");

            if (count > 0 && mounted) {
              setState(() {
                _showMessageBadge = true;
              });
              print("🔔 Badge activé via exchanges!");
            }
          }, onError: (error) {
            print("❌ Erreur dans l'écouteur d'exchanges: $error");
          }));
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la configuration des écouteurs: $e');
    }
  }

  // Conservez UNIQUEMENT cette version de la méthode et supprimez l'autre
  void _showPhotoHistory() {
    // Marquer les photos comme vues et retirer le badge avant d'ouvrir
    PhotosBadgeUtil.markSeen().catchError((e) => print('📸 markSeen error: $e'));
    if (mounted && _showPhotosBadge) {
      setState(() => _showPhotosBadge = false);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Barre de drag
                      Container(
                        width: 40,
                        height: 5,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),

                      // En-tête
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.photo_library,
                                color: primaryBlue,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Photos passées",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showPhotoDatePicker(setModalState),
                              icon: Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _showingPhotoHistory
                                    ? DateFormat('dd MMM', 'fr_FR')
                                        .format(_selectedPhotoDate)
                                    : "Choisir une date",
                                style: TextStyle(fontSize: 14),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: primaryBlue.withOpacity(0.1),
                                foregroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenu
                      Expanded(
                        child: _loadingPhotoHistory
                            ? Center(child: CircularProgressIndicator())
                            : !_showingPhotoHistory
                                ? _buildPhotoHistoryPrompt()
                                : _pastPhotos.isEmpty
                                    ? _buildNoPhotosFound()
                                    : _buildPhotoGrid(controller),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _checkPhotosBadge() async {
    try {
      final should = await PhotosBadgeUtil.shouldShowBadge();
      if (mounted) setState(() => _showPhotosBadge = should);
    } catch (e) {
      print('📸 ❌ Erreur vérification badge Photos: $e');
      if (mounted) setState(() => _showPhotosBadge = false);
    }
  }

  Future<void> _showPhotoDatePicker(StateSetter setModalState) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now.subtract(Duration(days: 9));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _showingPhotoHistory
          ? _selectedPhotoDate
          : now.subtract(Duration(days: 1)),
      firstDate: firstDate,
      lastDate: now.subtract(Duration(days: 1)),
      locale: Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setModalState(() {
        _selectedPhotoDate = picked;
        _showingPhotoHistory = true;
        _loadingPhotoHistory = true;
      });

      await _loadPhotoHistory(picked);

      setModalState(() {
        _loadingPhotoHistory = false;
      });
    }
  }

// Méthode pour charger l'historique des photos
  Future<void> _loadPhotoHistory(DateTime date) async {
    try {
      if (_selectedChild == null) return;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final photosSnapshot = await _firestore
          .collection('structures')
          .doc(_selectedChild!['structureId'])
          .collection('children')
          .doc(_selectedChild!['id'])
          .collection('medias')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay.add(Duration(days: 1)))
          .orderBy('date', descending: true)
          .get();

      _pastPhotos = photosSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    } catch (e) {
      print("Erreur lors du chargement de l'historique des photos: $e");
      _pastPhotos = [];
    }
  }

// Widget pour l'invite de sélection de date
  Widget _buildPhotoHistoryPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 24),
            Text(
              "Explorez les souvenirs",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Choisissez une date pour voir les photos des 10 derniers jours",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDFE9F2).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 8,
                children: const [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF3D9DF2)),
                  SizedBox(width: 2),
                  // Le texte se replie automatiquement si nécessaire (pas d'overflow)
                  Text(
                    "Les photos et vidéos sont conservées 10 jours",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF3D9DF2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Widget quand aucune photo n'est trouvée
  Widget _buildNoPhotosFound() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16),
            Text(
              "Aucune photo trouvée",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "pour le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_selectedPhotoDate)}",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Widget pour la grille de photos
  Widget _buildPhotoGrid(ScrollController controller) {
    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _pastPhotos.length,
      itemBuilder: (context, index) {
        final photo = _pastPhotos[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop(); // Fermer la modal
            _openPhotoViewer(photo['url'], photo['description'] ?? '');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Heure
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Text(
                    photo['heure'] ?? 'Heure inconnue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                      fontSize: 14,
                    ),
                  ),
                ),

                // Photo
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photo['url'],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryBlue),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  color: Colors.grey.shade400),
                              SizedBox(height: 4),
                              Text(
                                'Erreur',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkStockBadge() async {
    try {
      // Forcer une vérification complète depuis Firestore
      final shouldShow = await StockBadgeUtil.shouldShowBadge();
      if (mounted) {
        setState(() {
          _showStockBadge = shouldShow;
        });
      }
      print('📦 Badge stock état: $shouldShow');
    } catch (e) {
      print('❌ Erreur lors de la vérification des besoins de stock: $e');
      if (mounted) {
        setState(() {
          _showStockBadge = false;
        });
      }
    }
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

      // Vérifier les besoins en stock
      _checkStockBadge();
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
    _disposeCurrentSubscriptions();
    super.dispose();
  }

  void _disposeCurrentSubscriptions() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Réinitialiser les événements
    _eventsMap = {
      'activity': [],
      'meal': [],
      'sleep': [],
      'change': [],
      'health': [],
      'photo': [],
      'hour': [],
      'transmission': [],
    };
  }

  void _openPhotoViewer(String imageUrl, String? description) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PhotoViewerScreen(
          imageUrl: imageUrl,
          description: description,
          childName: _selectedChild?['firstName'],
          photoDate: DateTime.now(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_selectedChild != null) {
      // Montrer un indicateur de chargement
      setState(() => _loadingTimeline = true);

      // Actualiser la timeline
      await _loadChildTimeline(
          _selectedChild!['id'], _selectedChild!['structureId']);

      // Actualiser les actualités
      await _loadActualites(_selectedChild!['structureId']);

      // Vérifier s'il y a des besoins en stock
      await _checkStockBadge();

      // Vérifier s'il y a des messages non lus
      await _checkMessageBadge();

      // Vérifier les badges Actualités
      await _checkActualitesBadges();

      // Vérifier badge Photos
      await _checkPhotosBadge();

      setState(() => _loadingTimeline = false);

      // Afficher un feedback visuel
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Données actualisées"),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blueGrey.shade700,
        ),
      );
    }
  }

  Future<void> _checkActualitesBadges() async {
    try {
      Map<String, bool> badges;
      if (_selectedChild != null && _selectedChild!['structureId'] != null) {
        final sid = _selectedChild!['structureId'] as String;
        badges = await ActualitesBadgeUtil.shouldShowBadgesFor(sid);
      } else {
        badges = await ActualitesBadgeUtil.shouldShowBadges();
      }
      if (mounted) {
        setState(() {
          _showEventsBadge = badges['events'] ?? false;
          _showSortiesBadge = badges['sorties'] ?? false;
          _showActualitesBadge = _showEventsBadge || _showSortiesBadge;
        });
      }
    } catch (e) {
      print('📰 ❌ Erreur vérification badges Actualités: $e');
      if (mounted) {
        setState(() {
          _showEventsBadge = false;
          _showSortiesBadge = false;
          _showActualitesBadge = false;
        });
      }
    }
  }

  Future<void> _loadActualites(String structureId) async {
    try {
      print("=== DÉBUT CHARGEMENT ACTUALITÉS ===");
      print("StructureId: $structureId");

      // 1. Chargement du menu
      final menuSnapshot = await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('actualites')
          .doc('menu')
          .get();

      // Traitement du menu
      Map<String, List<String>> tempMenuSemaine = {
        'Lundi': [],
        'Mardi': [],
        'Mercredi': [],
        'Jeudi': [],
        'Vendredi': [],
        'Samedi': [],
        'Dimanche': [],
      };

      if (menuSnapshot.exists) {
        final data = menuSnapshot.data();
        if (data != null) {
          for (var day in tempMenuSemaine.keys) {
            if (data[day] != null && data[day] is List) {
              tempMenuSemaine[day] = List<String>.from(data[day]);
            }
          }
        }
        print("Menu chargé avec succès");
      } else {
        print("Menu non trouvé");
      }

      // 2. Chargement des événements
      final eventsSnapshot = await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('actualites')
          .doc('events')
          .collection('items')
          .orderBy('date')
          .get();

      // Traitement des événements
      final List<Map<String, dynamic>> tempEvents = [];
      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        tempEvents.add({
          'id': doc.id,
          'titre': data['titre'] ?? 'Sans titre',
          'description': data['description'] ?? '',
          'date': data['date'] as Timestamp,
          'imageUrl': data['imageUrl'],
        });
      }
      print("Événements chargés: ${tempEvents.length}");

      // 3. Chargement des sorties
      final sortiesSnapshot = await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('actualites')
          .doc('sorties')
          .collection('items')
          .orderBy('date')
          .get();

      // Traitement des sorties
      final List<Map<String, dynamic>> tempSorties = [];
      for (var doc in sortiesSnapshot.docs) {
        final data = doc.data();
        tempSorties.add({
          'id': doc.id,
          'titre': data['titre'] ?? 'Sans titre',
          'lieu': data['lieu'] ?? '',
          'description': data['description'] ?? '',
          'date': data['date'] as Timestamp,
          'imageUrl': data['imageUrl'],
        });
      }
      print("Sorties chargées: ${tempSorties.length}");

      // Mise à jour de l'état avec les données chargées
      setState(() {
        _menuSemaine = tempMenuSemaine;
        _events = tempEvents;
        _sorties = tempSorties;
      });

      print("=== CHARGEMENT TERMINÉ AVEC SUCCÈS ===");
    } catch (e) {
      print('❌ Erreur lors du chargement des actualités: $e');
    }
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
        setState(() {
          // Extraire uniquement le prénom pour un ton plus amical
          _parentFirstName = userData['firstName'] ?? '';
        });

        // Récupérer les enfants associés à ce parent
        final childIds = List<String>.from(userData['children'] ?? []);
        final structureId = userData['structureId'];

        print("📱 Parent: $_parentFirstName, Structure: $structureId");
        print("📱 IDs des enfants trouvés: $childIds");

        if (childIds.isNotEmpty && structureId != null) {
          List<Map<String, dynamic>> childrenData = [];

          for (final childId in childIds) {
            final childDoc = await _firestore
                .collection('structures')
                .doc(structureId)
                .collection('children')
                .doc(childId)
                .get();

            if (childDoc.exists) {
              final data = childDoc.data()!;
              childrenData.add({
                'id': childDoc.id,
                'firstName': data['firstName'] ?? 'Sans nom',
                'lastName': data['lastName'] ?? '',
                'photoUrl': data['photoUrl'],
                'structureId': structureId,
                'gender': data['gender'] ?? 'Non spécifié',
                'birthdate': data['birthdate'],
                'parentId': data['parentId'] ?? '',
              });
              print(
                  "📱 Enfant chargé: ${data['firstName']} (ID: ${childDoc.id})");
            } else {
              print("⚠️ Enfant non trouvé: $childId");
            }
          }

          setState(() {
            _children = childrenData;
            if (childrenData.isNotEmpty) {
              _selectedChild = childrenData.first;
              // Charger automatiquement la timeline du premier enfant
              _loadChildTimeline(
                  _selectedChild!['id'], _selectedChild!['structureId']);
            }
          });

          print("📱 Nombre total d'enfants chargés: ${_children.length}");

          // Chargement des actualités après avoir récupéré la structure
          if (structureId != null) {
            await _loadActualites(structureId);
            print("📱 Actualités chargées pour structureId: $structureId");
            // Vérifier/mettre à jour les badges Actualités maintenant que la structure est connue
            await _checkActualitesBadges();
          }
        } else {
          print(
              "⚠️ Aucun enfant trouvé pour ce parent ou structureId manquant");
        }
      } else {
        print("⚠️ Document utilisateur non trouvé: ${user.email}");
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

  void _selectChild(Map<String, dynamic> child) {
    setState(() {
      _selectedChild = child;
      _loadChildTimeline(child['id'], child['structureId']);
      _loadActualites(child['structureId']); // Charger aussi les actualités
    });
  }

  Future<void> _loadChildTimeline(String childId, String structureId) async {
    print(
        "🔍 Chargement de la timeline pour enfant ID: $childId, structure: $structureId");
    setState(() => _loadingTimeline = true);

    try {
      // Définir la plage de dates pour aujourd'hui
      final now = DateTime.now();
      // Convertir les DateTime en Timestamp directement pour Firestore
      final todayStart =
          Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final todayEnd = Timestamp.fromDate(
          DateTime(now.year, now.month, now.day, 23, 59, 59));

      print(
          "📅 Chargement des événements pour le ${DateFormat('dd/MM/yyyy').format(now)}");
      print("⏰ Plage horaire: ${todayStart.toDate()} - ${todayEnd.toDate()}");

      // Utiliser des StreamSubscriptions pour écouter les changements
      _disposeCurrentSubscriptions(); // Méthode pour annuler les abonnements précédents

      // 1. Écouter les activités
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('activites')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("📝 Activités reçues: ${snapshot.docs.length}");
        _processActivitiesSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur d'activités: $error");
      }));

      // 2. Écouter les repas
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('repas')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("🍔 Repas reçus: ${snapshot.docs.length}");
        _processMealsSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de repas: $error");
      }));

      // 3. Écouter les siestes
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('siestes')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("😴 Siestes reçues: ${snapshot.docs.length}");
        _processSleepsSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de siestes: $error");
      }));

      // 4. Écouter les changes
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('changes')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("👶 Changes reçus: ${snapshot.docs.length}");
        _processChangesSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de changes: $error");
      }));

      // 5. Écouter les soins de santé
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('sante')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("🏥 Soins santé reçus: ${snapshot.docs.length}");
        _processHealthSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de santé: $error");
      }));

      // 6. Écouter les photos
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('medias')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("📷 Photos reçues: ${snapshot.docs.length}");
        _processPhotosSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de photos: $error");
      }));

      // 7. Écouter les horaires du jour (source d'état courant, évite les doublons)
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('horaires')
          .doc(DateFormat('yyyy-MM-dd').format(now))
          .snapshots()
          .listen((doc) {
        print("⏱️ Document horaires reçu: ${doc.exists}");
        _processHoursDocSnapshot(doc, childId);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur d'horaires (doc): $error");
      }));

      // 8. Écouter les transmissions
      _subscriptions.add(_firestore
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .doc(childId)
          .collection('transmissions')
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThanOrEqualTo: todayEnd)
          .snapshots()
          .listen((snapshot) {
        print("📣 Transmissions reçues: ${snapshot.docs.length}");
        _processTransmissionsSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de transmissions: $error");
      }));

      setState(() => _loadingTimeline = false);
    } catch (e) {
      print('❌ Erreur lors du chargement de la timeline: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement de la timeline')),
      );
      setState(() => _loadingTimeline = false);
    }
  }

  void _processActivitiesSnapshot(QuerySnapshot snapshot) {
    _eventsMap['activity'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Ajouter cette partie pour gérer l'heure
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        // Si l'heure est stockée comme "13:00", l'utiliser
        eventTime = data['heure'];
      }

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': 'activity',
        'title': 'Activité: ${data['type'] ?? ""}',
        'details': data['duration'] ?? "",
        'participation': data['participation'] ?? "",
        'attitude': data['attitude'] ?? "",
        'iconData': Icons.directions_run,
        'color': Colors.green,
        'observations': data['observations'],
      };
    }).toList();
  }

  void _processMealsSnapshot(QuerySnapshot snapshot) {
    _eventsMap['meal'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer l'heure réelle si disponible
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }

      String details = '';
      if (data['biberon'] == true) {
        details = '${data['ml']?.toInt() ?? 0} ml';
      } else if (data['allaitement'] == true) {
        details = 'Allaitement';
      } else {
        details = data['qualite'] ?? '';
      }

      IconData icon = Icons.restaurant;
      if (data['biberon'] == true) {
        icon = Icons.local_drink;
      } else if (data['allaitement'] == true) {
        icon = Icons.child_care;
      }

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': 'meal',
        'title': data['biberon'] == true
            ? 'Biberon'
            : data['allaitement'] == true
                ? 'Allaitement'
                : 'Repas',
        'details': details,
        'iconData': icon,
        'color': Colors.orange,
        'observations': data['observations'],
      };
    }).toList();
  }

  void _processSleepsSnapshot(QuerySnapshot snapshot) {
    _eventsMap['sleep'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer l'heure réelle si disponible
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': 'sleep',
        'title': 'Sieste',
        'details': data['duration'] ?? "",
        'qualite': data['qualite'] ?? "",
        'iconData': Icons.nightlight_round,
        'color': Colors.indigo,
        'observations': data['observations'],
      };
    }).toList();
  }

  void _processChangesSnapshot(QuerySnapshot snapshot) {
    _eventsMap['change'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer l'heure réelle si disponible
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }

      String details = '';
      if (data['pipi'] == true) details += 'Pipi ';
      if (data['selles'] == true) details += 'Selles';

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': 'change',
        'title': 'Change',
        'details': details.trim(),
        'changeType': data['type'] ?? '',
        'soins': (data['soins'] is List) ? List<String>.from(data['soins']) : [],
        'iconData': Icons.baby_changing_station,
        'color': Colors.brown,
        'observations': data['observations'],
      };
    }).toList();
  }

  void _processHealthSnapshot(QuerySnapshot snapshot) {
    _eventsMap['health'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer l'heure réelle si disponible
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }

      String details = '';
      if (data['type'] == 'Température') {
        details = '${data['temperature']}° - ${data['route'] ?? ""}';
      } else if (data['type'] == 'Poids') {
        details = '${data['weight']} kg';
      } else if (data['type'] == 'Médicaments') {
        details = '${data['medicationType'] ?? ""}';
      } else {
        details = data['type'] ?? '';
      }

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': 'health',
        'title': 'Santé: ${data['type'] ?? ""}',
        'details': details,
        'iconData': Icons.healing,
        'color': Colors.red,
        'observations': data['observations'],
      };
    }).toList();
  }

  void _processPhotosSnapshot(QuerySnapshot snapshot) {
    _eventsMap['photo'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer l'heure réelle si disponible
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }

      final isVideo = (data['type']?.toString().toLowerCase() == 'video');

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': isVideo ? 'video' : 'photo',
        'title': isVideo ? 'Vidéo' : 'Photo',
        'details': data['description'] ?? '',
        'iconData': Icons.photo,
        'color': Colors.purple,
        'url': data['url'],
      };
    }).toList();
  }

  void _processHoursSnapshot(QuerySnapshot snapshot) {
    // Conservé pour compatibilité si utilisé ailleurs, mais non appelé désormais.
    final events = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final action = (data['actionType'] ?? '').toString();

      // Normaliser les types et ignorer les écritures non pertinentes
      String? normalized;
      if (action == 'arrivee' || action == 'arrivee_modifiee') {
        normalized = 'arrival';
      } else if (action == 'depart' || action == 'depart_modifiee') {
        normalized = 'departure';
      } else {
        // absent, annuler_absent, etc. → pas d'événement dans la timeline
        continue;
      }

      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }
      final timestamp =
          data['exactTime'] as Timestamp? ?? data['timestamp'] as Timestamp?;

      events.add({
        'id': doc.id,
        'time': eventTime.isNotEmpty ? eventTime : timestamp,
        'type': normalized,
        'title': normalized == 'arrival' ? 'Arrivée' : 'Départ',
        'details': normalized == 'arrival' ? (data['arrivee'] ?? '') : (data['depart'] ?? ''),
        'iconData': normalized == 'arrival' ? Icons.login : Icons.logout,
        'color': normalized == 'arrival' ? Colors.green.shade700 : Colors.red.shade700,
      });
    }
    _eventsMap['hour'] = events;
  }

  // Nouvelle méthode: construit les événements horaires depuis le document d'état courant
  void _processHoursDocSnapshot(DocumentSnapshot doc, String childId) {
    final events = <Map<String, dynamic>>[];

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey(childId)) {
        final childData = data[childId] as Map<String, dynamic>;

        // Si absent: ne rien afficher
        if (childData['absent'] == true) {
          _eventsMap['hour'] = [];
          return;
        }

        // Format segments (nouveau)
        if (childData['segments'] is List) {
          final segments = List<Map<String, dynamic>>.from(childData['segments']);
          for (final seg in segments) {
            final arr = seg['arrivee'];
            final dep = seg['depart'];
            if (arr != null && arr.toString().isNotEmpty) {
              events.add({
                'id': 'arr_${arr}_${events.length}',
                'time': arr,
                'type': 'arrival',
                'title': 'Arrivée',
                'details': arr,
                'iconData': Icons.login,
                'color': Colors.green.shade700,
              });
            }
            if (dep != null && dep.toString().isNotEmpty) {
              events.add({
                'id': 'dep_${dep}_${events.length}',
                'time': dep,
                'type': 'departure',
                'title': 'Départ',
                'details': dep,
                'iconData': Icons.logout,
                'color': Colors.red.shade700,
              });
            }
          }
        } else {
          // Compat: ancien format
          final arr = childData['arrivee'];
          final dep = childData['depart'];
          if (arr != null && arr.toString().isNotEmpty) {
            events.add({
              'id': 'arr_${arr}_0',
              'time': arr,
              'type': 'arrival',
              'title': 'Arrivée',
              'details': arr,
              'iconData': Icons.login,
              'color': Colors.green.shade700,
            });
          }
          if (dep != null && dep.toString().isNotEmpty) {
            events.add({
              'id': 'dep_${dep}_0',
              'time': dep,
              'type': 'departure',
              'title': 'Départ',
              'details': dep,
              'iconData': Icons.logout,
              'color': Colors.red.shade700,
            });
          }
        }
      }
    }

    _eventsMap['hour'] = events;
  }

  void _processTransmissionsSnapshot(QuerySnapshot snapshot) {
    _eventsMap['transmission'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Récupérer l'heure réelle si disponible
      String eventTime = '';
      if (data['heure'] != null && data['heure'] is String) {
        eventTime = data['heure'];
      }

      IconData icon = Icons.info_outline;
      switch (data['category']) {
        case 'Santé':
          icon = Icons.medical_services_outlined;
          break;
        case 'Objets':
          icon = Icons.inventory_2_outlined;
          break;
        case 'Comportement':
          icon = Icons.psychology_outlined;
          break;
        case 'Général':
          icon = Icons.info_outline;
          break;
      }

      return {
        'id': doc.id,
        'time': eventTime.isNotEmpty
            ? eventTime
            : data['eventTime'] ?? data['date'],
        'type': 'transmission',
        'title': 'Message: ${data['category'] ?? ""}',
        'details': data['content'] ?? '',
        'iconData': icon,
        'color': Colors.teal,
      };
    }).toList();
  }

  void _updateTimelineEvents() {
    // Ajouter des logs pour le débogage
    print(
        "🔄 Mise à jour de la timeline avec ${_eventsMap.values.expand((e) => e).length} événements");

    // Combiner tous les événements
    List<Map<String, dynamic>> allEvents = [];
    _eventsMap.forEach((key, events) {
      allEvents.addAll(events);
      print("  - $key: ${events.length} événements");
    });

    // Trier tous les événements par heure réelle (minutes depuis minuit)
    int toMinutes(dynamic value) {
      // Chaîne HH:mm
      if (value is String && value.contains(':')) {
        final parts = value.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }
      // Timestamp
      if (value is Timestamp) {
        final dt = value.toDate();
        return dt.hour * 60 + dt.minute;
      }
      // DateTime
      if (value is DateTime) {
        return value.hour * 60 + value.minute;
      }
      return 0;
    }

    allEvents.sort((a, b) {
      final aMin = toMinutes(a['time']);
      final bMin = toMinutes(b['time']);
      final cmp = aMin.compareTo(bMin);
      if (cmp != 0) return cmp; // Ordre chronologique croissant
      // En cas d'égalité parfaite (même minute), garder un ordre stable
      // en comparant éventuellement sur le titre pour éviter les sauts visuels
      final at = (a['title'] ?? '').toString();
      final bt = (b['title'] ?? '').toString();
      return at.compareTo(bt);
    });

    // Créer une nouvelle liste pour forcer le rafraîchissement
    final newTimelineEvents = List<Map<String, dynamic>>.from(allEvents);

    // Mettre à jour l'état uniquement si les données ont changé
    if (!_areListsEqual(_timelineEvents, newTimelineEvents)) {
      setState(() {
        _timelineEvents = newTimelineEvents;
      });
      print("✅ Timeline mise à jour avec ${_timelineEvents.length} événements");
    } else {
      print(
          "ℹ️ Pas de changement dans la timeline, rafraîchissement non nécessaire");
    }
  }

  // Méthode pour comparer deux listes d'événements
  bool _areListsEqual(
      List<Map<String, dynamic>> list1, List<Map<String, dynamic>> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      final map1 = list1[i];
      final map2 = list2[i];

      // Comparer les ID si disponibles
      if (map1['id'] != null &&
          map2['id'] != null &&
          map1['id'] != map2['id']) {
        return false;
      }

      // Sinon comparer le type et l'heure
      if (map1['type'] != map2['type']) return false;

      final time1 = map1['time'];
      final time2 = map2['time'];

      if (time1 is Timestamp && time2 is Timestamp) {
        if (time1.seconds != time2.seconds) return false;
      } else if (time1 != time2) {
        return false;
      }
    }

    return true;
  }

  Widget _buildHeaderIcon(String label, IconData icon, VoidCallback onTap,
      {bool showBadge = false}) {
    // Obtenir la largeur de l'écran
    final screenWidth = MediaQuery.of(context).size.width;
    // Ajuster la taille selon la largeur de l'écran
    final iconSize = screenWidth < 360 ? 20.0 : 24.0;
    final containerPadding = screenWidth < 360 ? 8.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              if (showBadge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth < 360 ? 10 : 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActualiteCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap,
      {bool showBadge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: EdgeInsets.all(16),
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
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showActualiteDetails(String type) async {
    // Marquer comme vu avant d'afficher les détails
    try {
      final sid = (_selectedChild != null)
          ? _selectedChild!['structureId'] as String?
          : null;
      // Badge global: ouvrir l'un ou l'autre marque tout comme vu
      if (type == 'evenement' || type == 'sortie') {
        await ActualitesBadgeUtil.markAllSeen(structureId: sid);
        if (mounted) {
          setState(() {
            _showEventsBadge = false;
            _showSortiesBadge = false;
            _showActualitesBadge = false;
          });
        }
      }
    } catch (e) {
      // Pas bloquant
      print('📰 ❌ Erreur mark seen ($type): $e');
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _buildActualiteContent(type, controller),
            );
          },
        );
      },
    );
  }

  Widget _buildActualiteContent(String type, ScrollController controller) {
    String title;
    IconData icon;
    Color color;

    switch (type) {
      case "menu":
        title = "Menu de la semaine";
        icon = Icons.restaurant_menu;
        color = Colors.green.shade400;
        break;
      case "evenement":
        title = "Événements à venir";
        icon = Icons.event;
        color = Colors.orange.shade400;
        break;
      case "sortie":
        title = "Sorties prévues";
        icon = Icons.directions_bus;
        color = Colors.blue.shade400;
        break;
      default:
        title = "Actualités";
        icon = Icons.info_outline;
        color = Colors.purple.shade400;
    }

    return Column(
      children: [
        // Barre de drag
        Container(
          width: 40,
          height: 5,
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        // En-tête
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        // Contenu avec défilement
        Expanded(
          child: ListView(
            controller: controller,
            children: [
              // Afficher le contenu correspondant au type
              if (type == "menu") ...[
                // Affichage des menus réels depuis _menuSemaine
                for (var day in [
                  'Lundi',
                  'Mardi',
                  'Mercredi',
                  'Jeudi',
                  'Vendredi'
                ]) ...[
                  if (_menuSemaine[day]!.isNotEmpty)
                    _buildMenuSection(day, _menuSemaine[day]!.join(", "))
                  else
                    _buildMenuSection(day, "Aucun menu défini pour ce jour"),
                ],
              ] else if (type == "evenement") ...[
                // Affichage des événements réels depuis _events
                if (_events.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Aucun événement prévu pour le moment",
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                else
                  for (var event in _events) ...[
                    _buildEventSection(
                      event['titre'],
                      event['date'] != null
                          ? DateFormat('dd MMMM yyyy', 'fr_FR')
                              .format(event['date'].toDate())
                          : 'Date non définie',
                      event['description'] ?? '',
                    ),
                  ],
              ] else if (type == "sortie") ...[
                // Affichage des sorties réelles depuis _sorties
                if (_sorties.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Aucune sortie prévue pour le moment",
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  )
                else
                  for (var sortie in _sorties) ...[
                    _buildEventSection(
                      "${sortie['titre']} (${sortie['lieu']})",
                      sortie['date'] != null
                          ? DateFormat('dd MMMM yyyy', 'fr_FR')
                              .format(sortie['date'].toDate())
                          : 'Date non définie',
                      sortie['description'] ?? '',
                    ),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(String day, String menu) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            menu,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSection(String title, String date, String description) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.event,
                size: 16,
                color: Colors.orange.shade800,
              ),
              SizedBox(width: 6),
              Text(
                date,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FA), // Couleur de fond légère et moderne
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    // Header avec effet parallaxe
                    SliverAppBar(
                      expandedHeight: 200.0,
                      pinned: true,
                      backgroundColor: primaryBlue,
                      actions: [
                        // Bouton d'actualisation
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            // Utiliser _refreshData pour actualiser toutes les données
                            _refreshData();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.logout, color: Colors.white),
                          onPressed: () async {
                            await SessionUtil.signOut();
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
                              padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
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
                                  SizedBox(height: 20),
                                  // Icônes pour Menu, Événements, Sorties
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildHeaderIcon(
                                        "Menu",
                                        Icons.restaurant_menu,
                                        () => _showActualiteDetails("menu"),
                                      ),
                                      _buildHeaderIcon(
                                        "Événements",
                                        Icons.event,
                                        () => _showActualiteDetails("evenement"),
                                        showBadge: _showActualitesBadge,
                                      ),
                                      _buildHeaderIcon(
                                        "Sorties",
                                        Icons.directions_bus,
                                        () => _showActualiteDetails("sortie"),
                                        showBadge: _showActualitesBadge,
                                      ),
                                      _buildHeaderIcon(
                                        "Photos",
                                        Icons.photo_library,
                                        () => _showPhotoHistory(),
                                        showBadge: _showPhotosBadge,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sélecteur d'enfant (si plusieurs enfants)
                    if (_children.length > 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF0FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.campaign_outlined,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Actualités",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildActualiteCard(
                                      "Menu de la semaine",
                                      "Découvrez les repas prévus",
                                      Icons.restaurant_menu,
                                      Colors.green.shade400,
                                      () {
                                        // Navigation vers les menus
                                        _showActualiteDetails("menu");
                                      },
                                    ),
                                    SizedBox(width: 12),
                                    _buildActualiteCard(
                                      "Événements",
                                      "Activités spéciales à venir",
                                      Icons.event,
                                      Colors.orange.shade400,
                                      () {
                                        // Navigation vers les événements
                                        _showActualiteDetails("evenement");
                                      },
                                      showBadge: _showActualitesBadge,
                                    ),
                                    SizedBox(width: 12),
                                    _buildActualiteCard(
                                      "Sorties",
                                      "Prévisions de sorties",
                                      Icons.directions_bus,
                                      Colors.blue.shade400,
                                      () {
                                        // Navigation vers les sorties
                                        _showActualiteDetails("sortie");
                                      },
                                      showBadge: _showActualitesBadge,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Résumé de la journée - En-tête
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icône et informations du journal
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.event_note_rounded,
                                color: primaryBlue,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedChild != null
                                        ? "Journée de ${_selectedChild!['firstName']}"
                                        : "Journée",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "Activités, repas, siestes et plus",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Photo de l'enfant sélectionné
                            if (_selectedChild != null)
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _selectedChild!['photoUrl'] != null
                                      ? Image.network(
                                          _selectedChild!['photoUrl'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            color: Colors.grey[200],
                                            child: Icon(
                                              _selectedChild!['gender'] ==
                                                      'Garçon'
                                                  ? Icons.boy
                                                  : Icons.girl,
                                              color: Colors.grey[400],
                                              size: 40,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            _selectedChild!['gender'] ==
                                                    'Garçon'
                                                ? Icons.boy
                                                : Icons.girl,
                                            color: Colors.grey[400],
                                            size: 40,
                                          ),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Timeline des événements avec info de mise à jour
                    _loadingTimeline
                        ? SliverToBoxAdapter(
                            child: Container(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        : _timelineEvents.isEmpty
                            ? SliverToBoxAdapter(
                                child: Container(
                                  margin: EdgeInsets.all(24),
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
                                    children: [
                                      Image.asset(
                                        'assets/images/no_activities.png', // Remplacer par votre image
                                        height: 120,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                          Icons.event_busy,
                                          size: 80,
                                          color: Colors.grey[300],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "Aucune activité enregistrée aujourd'hui",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Consultez cette page plus tard pour voir les mises à jour",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final event = _timelineEvents[index];
                                    return _buildTimelineItem(event);
                                  },
                                  childCount: _timelineEvents.length,
                                ),
                              ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryBlue,
        child: Icon(Icons.refresh),
        onPressed: () {
          // Utiliser _refreshData pour actualiser toutes les données
          _refreshData();
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            // Vers la messagerie - réinitialiser le badge
            setState(() {
              _showMessageBadge = false; // Réinitialiser le badge
            });
            context.go('/parent/messages');
          } else if (index == 2) {
            // Vers les stocks
            setState(() {
              _showStockBadge = false; // Réinitialiser le badge
            });
            context.go('/parent/stocks');
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue, // Couleur pour l'élément sélectionné
        unselectedItemColor: Colors
            .black87, // Changer à une couleur plus foncée pour les éléments non sélectionnés
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(
            fontSize: 12,
            color: Colors.black87), // Ajouter couleur noire explicite
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
            icon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_Stock.png',
                  width: 60,
                  height: 60,
                ),
                if (_showStockBadge)
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
                  'assets/images/Icone_Stock.png',
                  width: 60,
                  height: 60,
                  color: primaryBlue,
                ),
                if (_showStockBadge)
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
            // Image ou icône
            Icon(
              Icons.child_care,
              size: 120,
              color: Colors.grey[400],
            ),
            SizedBox(height: 32),
            Text(
              "Aucun enfant n'est associé à votre compte",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Si vous pensez qu'il s'agit d'une erreur, veuillez contacter votre structure d'accueil pour qu'elle associe votre enfant à votre compte.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Action pour rafraîchir ou contacter
                _loadUserData();
              },
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

  Widget _buildTimelineItem(Map<String, dynamic> event) {
    String time = '';
    if (event['time'] is Timestamp) {
      time = DateFormat('HH:mm').format((event['time'] as Timestamp).toDate());
    } else if (event['time'] is DateTime) {
      time = DateFormat('HH:mm').format(event['time']);
    } else if (event['time'] is String && event['time'].contains(':')) {
      // Si c'est déjà une chaîne formatée HH:mm
      time = event['time'];
    }

    return Container(
      margin: EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heure
          Container(
            width: 50,
            padding: EdgeInsets.only(top: 14),
            child: Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),

          // Ligne verticale de timeline
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: event['color'],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: event['color'].withOpacity(0.4),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),

          // Contenu de l'événement
          Expanded(
            child: Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.all(16),
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
                  // En-tête avec icône et titre
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: event['color'].withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          event['iconData'],
                          color: event['color'],
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Détails de l'événement
                  if (event['details'] != null &&
                      event['details'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 2),
                      child: Text(
                        event['details'],
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                    ),

                  // Informations additionnelles spécifiques aux types d'événements
                  if (event['type'] == 'activity' &&
                      event['participation'] != null &&
                      event['participation'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 2),
                      child: Text(
                        "Participation: ${event['participation']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  if (event['type'] == 'activity' &&
                      event['attitude'] != null &&
                      event['attitude'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, left: 2),
                      child: Text(
                        "Attitude: ${event['attitude']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  if (event['type'] == 'sleep' &&
                      event['qualite'] != null &&
                      event['qualite'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 2),
                      child: Text(
                        "Qualité: ${event['qualite']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  if (event['type'] == 'change' &&
                      event['changeType'] != null &&
                      event['changeType'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 2),
                      child: Text(
                        "Type: ${event['changeType']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),

                  if (event['type'] == 'change' &&
                      event['soins'] != null &&
                      (event['soins'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (event['soins'] as List)
                            .map<Widget>((s) => Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            Colors.brown.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    s.toString(),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.brown),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),

                  // Observations (si présentes)
                  if (event['observations'] != null &&
                      event['observations'].toString().isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.comment_outlined,
                              size: 16, color: Colors.grey[500]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event['observations'],
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Affichage des médias (photo/vidéo)
                  if (event['type'] == 'photo' && event['url'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: GestureDetector(
                        onTap: () =>
                            _openPhotoViewer(event['url'], event['details']),
                        child: Stack(
                          children: [
                            Hero(
                              tag: 'photo_${event['url']}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  event['url'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 180,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 100,
                                    width: double.infinity,
                                    color: Colors.grey[200],
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined,
                                            color: Colors.grey[400], size: 32),
                                        SizedBox(height: 8),
                                        Text(
                                          "Impossible de charger l'image",
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Overlay pour indiquer qu'on peut appuyer
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (event['type'] == 'video' && event['url'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: GestureDetector(
                        onTap: () async {
                          final url = Uri.parse(event['url']);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(Icons.play_circle_fill,
                                size: 56, color: Colors.purple),
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

// À ajouter après la fermeture de la classe _ParentHomeScreenState
class PhotoViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String? description;
  final String? childName;
  final DateTime? photoDate;

  const PhotoViewerScreen({
    Key? key,
    required this.imageUrl,
    this.description,
    this.childName,
    this.photoDate,
  }) : super(key: key);

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  bool _isLoading = false;

  Future<void> _saveImage() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        await Gal.putImageBytes(
          Uint8List.fromList(response.bodyBytes),
          name:
              "photo_${widget.childName}_${DateTime.now().millisecondsSinceEpoch}",
        );

        _showSuccessSnackBar('Photo sauvegardée dans la galerie');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sauvegarde: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            'photo_${widget.childName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        final shareText = widget.description != null &&
                widget.description!.isNotEmpty
            ? '📸 Photo de ${widget.childName ?? "mon enfant"}\n${widget.description}'
            : '📸 Photo de ${widget.childName ?? "mon enfant"}';

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du partage: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(date);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.childName != null
            ? Text(
                'Photo de ${widget.childName}',
                style: TextStyle(color: Colors.white),
              )
            : null,
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(Icons.share, color: Colors.white),
              onPressed: _shareImage,
              tooltip: 'Partager',
            ),
            IconButton(
              icon: Icon(Icons.download, color: Colors.white),
              onPressed: _saveImage,
              tooltip: 'Sauvegarder',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: 'photo_${widget.imageUrl}',
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Impossible de charger l\'image',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.description != null && widget.description!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.photoDate != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '📅 ${_formatDate(widget.photoDate!)}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withOpacity(0.8),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.download_rounded,
                label: 'Sauvegarder',
                onPressed: _isLoading ? null : _saveImage,
              ),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Partager',
                onPressed: _isLoading ? null : _shareImage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
