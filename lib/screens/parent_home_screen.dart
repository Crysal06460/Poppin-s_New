import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/stock_badge_util.dart';
import '../utils/message_badge_util.dart';
import '../utils/actualites_badge_util.dart';
import '../utils/photos_badge_util.dart';
import '../utils/session_util.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/photo_cleanup_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'parent_coordonnees_screen.dart';

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
  static const int _timelineHistoryLimitDays = 10;
  DateTime _selectedTimelineDate = DateTime.now();
  List<Map<String, dynamic>> _hourDocEvents = [];
  List<Map<String, dynamic>> _hourHistoryEvents = [];
  final RegExp _timeExtractRegex = RegExp(r'(\d{1,2})[hH:]?(\d{0,2})');
  final RegExp _rangeIndicatorRegex = RegExp(r'[-–…]');
  static const List<String> _timeCandidateKeys = [
    'heure',
    'start',
    'startTime',
    'startHour',
    'arrivee',
    'depart',
    'time',
    'hour',
    'eventTime',
    'heureDebut',
    'heureFin',
    'debut',
    'fin',
  ];
  bool _loadingTimeline = false;
  bool _showStockBadge = false;
  bool _showMessageBadge = false;
  bool _showEventsBadge = false;
  bool _showSortiesBadge = false;
  bool _showPhotosBadge = false;

  static const String _assistantPopupPrefPrefix =
      'parent_emp_assistant_prompt_';
  static const String _childPopupPrefPrefix = 'parent_emp_child_prompt_';

  bool _isParentEmployeur = false;
  bool _hasAssistant = false;
  Map<String, dynamic>? _assistantInfo;
  String _structureId = '';
  String _structureName = '';
  String _parentLastName = '';
  bool _parentOnboardingScheduled = false;

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
    _selectedTimelineDate = _normalizeDate(DateTime.now());

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
      final User? user = _auth.currentUser;
      if (user == null) {
        print("🧹 Nettoyage des médias ignoré: aucun utilisateur connecté");
        return;
      }

      String? structureId;
      final String email = user.email?.toLowerCase() ?? '';

      if (email.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(email).get();
        final data = userDoc.data();
        final storedStructureId = data?['structureId']?.toString().trim();
        if (storedStructureId != null && storedStructureId.isNotEmpty) {
          structureId = storedStructureId;
        }
      }

      structureId ??= user.uid;

      if (structureId.isEmpty) {
        print(
            "🧹 Nettoyage des médias ignoré: structure introuvable pour l'utilisateur courant");
        return;
      }

      await PhotoCleanupService.checkAndCleanupPhotos(
          structureIds: [structureId]);
    } catch (e) {
      print("Erreur lors du nettoyage automatique des photos: $e");
      // Ne pas montrer d'erreur à l'utilisateur car c'est un processus en arrière-plan
    }
  }

  void _scheduleParentEmployeurOnboarding() {
    if (!_isParentEmployeur || _parentOnboardingScheduled) return;
    _parentOnboardingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runParentEmployeurOnboarding();
    });
  }

  Widget _buildDashboardSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ...children.map((child) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: child,
            )),
      ],
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    bool enabled = true,
    bool badge = false,
  }) {
    final isEnabled = enabled && onTap != null;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEnabled
                    ? color.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.08),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? color.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: isEnabled ? color : Colors.grey[400],
                        size: 24,
                      ),
                    ),
                    if (badge)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.priority_high,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isEnabled ? Colors.black87 : Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isEnabled ? Colors.grey[600] : Colors.grey[400],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isEnabled ? color : Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runParentEmployeurOnboarding() async {
    if (!_isParentEmployeur) return;

    final prefs = await SharedPreferences.getInstance();
    final String keyBase = _structureId.isNotEmpty
        ? _structureId
        : (_auth.currentUser?.uid ?? 'default');
    final String assistantKey = '$_assistantPopupPrefPrefix$keyBase';
    final String childKey = '$_childPopupPrefPrefix$keyBase';

    if (!_hasAssistant) {
      final bool assistantPromptShown = prefs.getBool(assistantKey) ?? false;
      if (!assistantPromptShown) {
        await prefs.setBool(assistantKey, true);
        _showParentAssistantPrompt();
        return;
      }
    }

    // Les parents employeurs ne sont plus invités à ajouter un enfant.
    // L'assistante maternelle gère désormais l'ajout depuis son compte.
  }

  void _showParentAssistantPrompt() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Ajouter votre assistante maternelle",
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Icone_Ajout_Enfant.png', height: 100),
              const SizedBox(height: 12),
              const Text(
                "Invitez l'assistante maternelle qui accueille votre enfant afin qu'elle rejoigne Poppin's.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("PLUS TARD",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showParentAssistantForm();
              },
              child: Text("INVITER",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue)),
            ),
          ],
        );
      },
    );
  }

  void _showParentAssistantForm() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Inviter votre assistante",
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Prénom',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Prénom requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nom requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email requis';
                          }
                          final emailRegex = RegExp(
                              r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Téléphone (optionnel)',
                          hintText: '0601020304',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          if (value.trim().length != 10) {
                            return '10 chiffres requis';
                          }
                          return null;
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('ANNULER'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            await _submitParentAssistantInvitation(
                              firstNameController.text.trim(),
                              lastNameController.text.trim(),
                              emailController.text.trim().toLowerCase(),
                              phoneController.text.trim(),
                            );

                            if (!mounted) return;
                            Navigator.of(context).pop();

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Invitation envoyée à l'assistante"),
                              ),
                            );

                            _parentOnboardingScheduled = false;
                            await _loadUserData();
                          } catch (e) {
                            setModalState(() {
                              errorMessage =
                                  e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: primaryBlue.withOpacity(0.5),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Text('ENVOYER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitParentAssistantInvitation(
      String firstName, String lastName, String email, String phone) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String digitsPhone = phone.replaceAll(RegExp(r'\D'), '');
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("Utilisateur non connecté");
    }

    final String structureId =
        _structureId.isNotEmpty ? _structureId : user.uid;

    final DocumentReference structureRef =
        _firestore.collection('structures').doc(structureId);

    await structureRef.set({
      'assistantFirstName': firstName,
      'assistantLastName': lastName,
      'assistantEmail': normalizedEmail,
      'assistantPhone': digitsPhone,
      'assistantInvitationStatus': 'pending',
      'assistantInvitationSentAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final DateTime expirationDate =
        DateTime.now().add(const Duration(days: 30));
    final String parentFullName = ('$_parentFirstName $_parentLastName')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    await _firestore.collection('invitations').add({
      'email': normalizedEmail,
      'type': 'assistant',
      'structureId': structureId,
      'structureName': _structureName,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expirationDate),
      'status': 'active',
      'assistantFirstName': firstName,
      'assistantLastName': lastName,
      'assistantPhone': digitsPhone,
      'parentFullName': parentFullName,
      'invitedBy': user.email?.toLowerCase() ?? user.uid,
      'invitationSource': 'parent_employeur',
    });

    await _firestore.collection('users').doc(normalizedEmail).set({
      'email': normalizedEmail,
      'role': 'assistantFromParent',
      'structureId': structureId,
      'structureName': _structureName,
      'invitedByParent': true,
      'isFirstLogin': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('structures')
        .doc(structureId)
        .collection('assistants')
        .doc(normalizedEmail)
        .set({
      'firstName': firstName,
      'lastName': lastName,
      'email': normalizedEmail,
      'phone': digitsPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final templateData = {
      'assistantFirstName': firstName,
      'assistantLastName': lastName,
      'assistantEmail': normalizedEmail,
      'parentFullName':
          parentFullName.isEmpty ? (user.email ?? '') : parentFullName,
      'childFirstName': '',
      'structureName': _structureName,
      'iosLink': 'https://apps.apple.com/app/id123456789',
      'androidLink':
          'https://play.google.com/store/apps/details?id=com.example.poppins_app',
      'year': DateTime.now().year.toString(),
    };

    await _firestore.collection('emailQueue').add({
      'to': normalizedEmail,
      'template': 'parent-assistant-invitation',
      'subject':
          "Invitation Poppins - Famille ${_structureName.isEmpty ? parentFullName : _structureName}",
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'priority': 'high',
      'retryCount': 0,
      'templateData': templateData,
    });

    if (mounted) {
      setState(() {
        _hasAssistant = true;
        _assistantInfo = {
          'email': normalizedEmail,
          'firstName': firstName,
          'lastName': lastName,
          'phone': digitsPhone,
          'status': 'pending',
          'linkedUserId': '',
        };
      });
    }
  }

  void _showAddParentChildPopup() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              const Text("Ajouter votre enfant ?", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Icone_Ajout_Enfant.png', height: 100),
              const SizedBox(height: 10),
              const Text(
                "Vous pourrez ainsi partager les transmissions et documents avec votre assistante.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("PLUS TARD",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                this
                    .context
                    .go('/child-info', extra: {'parentEmployerFlow': true});
              },
              child: Text("AJOUTER",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue)),
            ),
          ],
        );
      },
    );
  }

  void _openParentEmployeurDashboard() {
    if (!mounted) return;

    final BuildContext navigatorContext = context;
    final selectedChild = _selectedChild;
    final bool hasChild = selectedChild != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                const Color(0xFFF8FAFC),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle moderne
              Container(
                width: 48,
                height: 5,
                margin: EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Header avec animation
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.dashboard_customize_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tableau de bord",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Gérez votre espace parent employeur",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Assistante
                      _buildDashboardSection(
                        title: "Mon assistante",
                        subtitle: hasChild
                            ? "Gérer la relation de travail"
                            : "Inviter une assistante",
                        children: [
                          _buildModernTile(
                            icon: Icons.handshake_rounded,
                            title: _hasAssistant
                                ? "Gérer mon assistante"
                                : "Inviter une assistante",
                            subtitle: _hasAssistant && _assistantInfo != null
                                ? '${_assistantInfo?['firstName'] ?? ''} ${_assistantInfo?['lastName'] ?? ''}'
                                : "Commencez par inviter votre assistante",
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              _showManageAssistantSheet();
                            },
                            badge: !_hasAssistant,
                          ),
                        ],
                      ),

                      SizedBox(height: 32),

                      // Section Enfant
                      _buildDashboardSection(
                        title: "Mon enfant",
                        subtitle: hasChild
                            ? "Informations et paramètres"
                            : "Ajouter votre enfant",
                        children: [
                          if (!hasChild)
                            _buildModernTile(
                              icon: Icons.child_friendly_rounded,
                              title: "Ajouter un enfant",
                              subtitle: "Créer le profil de votre enfant",
                              color: Colors.pink,
                              onTap: () {
                                Navigator.pop(context);
                                _showAddParentChildPopup();
                              },
                              badge: true,
                            ),
                          _buildModernTile(
                            icon: Icons.contact_mail_rounded,
                            title: "Mes coordonnées",
                            subtitle: "Modifier vos informations de contact",
                            color: Colors.orange,
                            enabled: hasChild,
                            onTap: hasChild
                                ? () {
                                    Navigator.pop(context);
                                    final child =
                                        selectedChild as Map<String, dynamic>;
                                    _openParentCoordonnees(child);
                                  }
                                : null,
                          ),
                          _buildModernTile(
                            icon: Icons.family_restroom_rounded,
                            title: "Parent 2",
                            subtitle: "Ajouter ou gérer le deuxième parent",
                            color: Colors.purple,
                            enabled: hasChild,
                            onTap: hasChild
                                ? () {
                                    Navigator.pop(context);
                                    final child =
                                        selectedChild as Map<String, dynamic>;
                                    _showParentTwoDialog(child['id']);
                                  }
                                : null,
                          ),
                        ],
                      ),

                      SizedBox(height: 32),

                      // Section Profil enfant
                      if (hasChild) ...[
                        _buildDashboardSection(
                          title: "Profil enfant",
                          subtitle:
                              "Personnaliser le profil de ${selectedChild?['firstName'] ?? 'votre enfant'}",
                          children: [
                            _buildModernTile(
                              icon: Icons.assignment_ind_rounded,
                              title: "Fiche enfant",
                              subtitle:
                                  "Informations personnelles et médicales",
                              color: Colors.teal,
                              onTap: () async {
                                Navigator.pop(context);
                                final child =
                                    selectedChild as Map<String, dynamic>;
                                await navigatorContext.push(
                                  '/parent/child-profile',
                                  extra: {
                                    'childId': child['id'],
                                    'structureId':
                                        child['structureId'] ?? _structureId,
                                  },
                                );
                              },
                            ),
                            _buildModernTile(
                              icon: Icons.schedule_rounded,
                              title: "Horaires de l'enfant",
                              subtitle: "Définir les créneaux d'accueil",
                              color: Colors.amber,
                              onTap: () async {
                                Navigator.pop(context);
                                final child =
                                    selectedChild as Map<String, dynamic>;
                                final result = await navigatorContext.push(
                                  '/parent/child-schedule',
                                  extra: {
                                    'childId': child['id'],
                                    'structureId':
                                        child['structureId'] ?? _structureId,
                                    'childName':
                                        child['firstName'] ?? 'Mon enfant',
                                  },
                                );
                                if (result == true && mounted) {
                                  ScaffoldMessenger.of(navigatorContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                              'Horaires mis à jour avec succès'),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],

                      // Espacement final
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openParentCoordonnees(Map<String, dynamic> child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentCoordonneesScreen(
          childId: child['id'],
          childName: child['firstName'] ?? '',
          structureId: _structureId,
        ),
      ),
    );
  }

  Future<void> _showParentTwoDialog(String childId) async {
    if (_structureId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Structure introuvable pour cet enfant')),
      );
      return;
    }

    Map<String, dynamic> existingParent2 = {};
    String childFirstName = _selectedChild?['firstName']?.toString() ?? '';
    try {
      final snapshot = await _firestore
          .collection('structures')
          .doc(_structureId)
          .collection('children')
          .doc(childId)
          .get();
      final data = snapshot.data() ?? {};
      existingParent2 = Map<String, dynamic>.from(
          data['parent2'] ?? const <String, dynamic>{});
      if (childFirstName.isEmpty) {
        childFirstName = (data['firstName'] ?? '').toString();
      }
    } catch (_) {}

    final firstNameController = TextEditingController(
        text: (existingParent2['firstName'] ?? '').toString());
    final lastNameController = TextEditingController(
        text: (existingParent2['lastName'] ?? '').toString());
    final emailController = TextEditingController(
        text: (existingParent2['email'] ?? '').toString().toLowerCase());
    final phoneController = TextEditingController(
        text: (existingParent2['phone'] ?? '').toString());

    String? errorMessage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Ajouter ou modifier le Parent 2',
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (facultatif)',
                        hintText: '0601020304',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('ANNULER'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final firstName = firstNameController.text.trim();
                          final lastName = lastNameController.text.trim();
                          final email =
                              emailController.text.trim().toLowerCase();
                          final phoneDigits = phoneController.text
                              .replaceAll(RegExp(r'\D'), '');

                          if (firstName.isEmpty || lastName.isEmpty) {
                            setState(() {
                              errorMessage = 'Prénom et nom sont requis';
                            });
                            return;
                          }

                          if (email.isEmpty ||
                              !RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                                  .hasMatch(email)) {
                            setState(() {
                              errorMessage = 'Adresse email invalide';
                            });
                            return;
                          }

                          if (phoneController.text.isNotEmpty &&
                              phoneDigits.length != 10) {
                            setState(() {
                              errorMessage =
                                  'Téléphone invalide (10 chiffres requis)';
                            });
                            return;
                          }

                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            await _saveParentTwoDetails(
                              childId,
                              childFirstName,
                              {
                                'firstName': firstName,
                                'lastName': lastName,
                                'email': email,
                                'phone': phoneDigits,
                              },
                            );

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Parent 2 enregistré et invitation envoyée à $email',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );

                            await _loadUserData();
                          } catch (e) {
                            setState(() {
                              errorMessage = e.toString();
                              isSaving = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: primaryBlue.withOpacity(0.5),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ENREGISTRER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveParentTwoDetails(
      String childId, String childName, Map<String, String> parentData) async {
    final String structureId = _structureId;
    if (structureId.isEmpty) {
      throw Exception('Structure introuvable');
    }

    final childRef = _firestore
        .collection('structures')
        .doc(structureId)
        .collection('children')
        .doc(childId);

    Map<String, dynamic> existingParent2 = {};
    try {
      final snapshot = await childRef.get();
      existingParent2 = Map<String, dynamic>.from(
          snapshot.data()?['parent2'] ?? const <String, dynamic>{});
    } catch (_) {}

    final updatedParent2 = {
      ...existingParent2,
      ...parentData,
    }..removeWhere((key, value) => value is String && value.trim().isEmpty);

    await childRef.set({'parent2': updatedParent2}, SetOptions(merge: true));

    final String email = parentData['email']?.toLowerCase() ?? '';
    if (email.isEmpty) return;

    final String firstName = parentData['firstName'] ?? '';
    final String lastName = parentData['lastName'] ?? '';

    await _firestore.collection('users').doc(email).set({
      'role': 'parent',
      'email': email,
      'children': FieldValue.arrayUnion([childId]),
      'structureId': structureId,
      'structureName': _structureName,
      'firstName': firstName,
      'lastName': lastName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore.collection('invitations').add({
      'email': email,
      'type': 'parent',
      'structureId': structureId,
      'structureName': _structureName,
      'childId': childId,
      'childName': childName,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      'status': 'active',
      'invitationSource': 'parent_employeur',
      'parentFullName': ('$_parentFirstName $_parentLastName').trim(),
    });

    await _firestore.collection('emailQueue').add({
      'to': email,
      'template': 'parent-invitation',
      'subject': "Invitation Poppins - Pour $childName",
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'priority': 'high',
      'retryCount': 0,
      'templateData': {
        'firstName': firstName,
        'lastName': lastName,
        'childName': childName,
        'structureName': _structureName,
        'structureId': structureId,
        'androidLink':
            'https://play.google.com/store/apps/details?id=com.example.poppins_app',
        'iosLink': 'https://apps.apple.com/us/app/poppins/id6744274953',
        'email': email,
        'year': DateTime.now().year.toString(),
      },
    });
  }

  void _showManageAssistantSheet() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            final assistant = _assistantInfo;
            return SafeArea(
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 5,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.handshake, color: primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Mon assistante",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (assistant != null && _hasAssistant)
                            Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        primaryBlue.withOpacity(0.1),
                                    child: const Icon(Icons.person,
                                        color: primaryBlue),
                                  ),
                                  title: Text(
                                    '${assistant['firstName'] ?? ''} ${assistant['lastName'] ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((assistant['email'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(assistant['email']),
                                      if ((assistant['phone'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                            'Téléphone : ${assistant['phone']}'),
                                      if ((assistant['status'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text('Statut : ${assistant['status']}'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showParentAssistantForm();
                                        },
                                        icon: const Icon(Icons.send),
                                        label: const Text(
                                            'Renvoyer une invitation'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryRed,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _confirmRemoveAssistant();
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Supprimer'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                const Text(
                                  "Aucune assistante n'est encore associée à votre compte.",
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showParentAssistantForm();
                                  },
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Inviter une assistante'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRemoveAssistant() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer l\'assistante ?'),
          content: const Text(
              "Cette action retirera l'assistante liée à votre compte. Vous pourrez en inviter une autre ensuite."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULER'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeAssistant();
              },
              child:
                  const Text('SUPPRIMER', style: TextStyle(color: primaryRed)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeAssistant() async {
    final assistant = _assistantInfo;
    if (assistant == null) return;

    try {
      final WriteBatch batch = _firestore.batch();
      final String structureId = _structureId.isNotEmpty
          ? _structureId
          : (_auth.currentUser?.uid ?? '');
      final DocumentReference structureRef =
          _firestore.collection('structures').doc(structureId);

      batch.update(structureRef, {
        'assistantFirstName': FieldValue.delete(),
        'assistantLastName': FieldValue.delete(),
        'assistantEmail': FieldValue.delete(),
        'assistantPhone': FieldValue.delete(),
        'assistantInvitationStatus': FieldValue.delete(),
        'assistantInvitationSentAt': FieldValue.delete(),
        'assistantLinkedUserId': FieldValue.delete(),
      });

      final String assistantEmail =
          (assistant['email'] ?? '').toString().trim().toLowerCase();
      if (assistantEmail.isNotEmpty) {
        final DocumentReference assistantUserRef =
            _firestore.collection('users').doc(assistantEmail);
        batch.set(
            assistantUserRef,
            {
              'structureId': FieldValue.delete(),
              'structureName': FieldValue.delete(),
              'invitedByParent': FieldValue.delete(),
              'role': 'assistantFromParentRemoved',
            },
            SetOptions(merge: true));

        final DocumentReference assistantDocRef =
            structureRef.collection('assistants').doc(assistantEmail);
        batch.delete(assistantDocRef);
      }

      await batch.commit();

      final prefs = await SharedPreferences.getInstance();
      final String keyBase = structureId.isNotEmpty
          ? structureId
          : (_auth.currentUser?.uid ?? 'default');
      await prefs.remove('$_assistantPopupPrefPrefix$keyBase');

      if (mounted) {
        setState(() {
          _hasAssistant = false;
          _assistantInfo = null;
        });
      }

      _parentOnboardingScheduled = false;
      await _loadUserData();
    } catch (e) {
      print('❌ Erreur suppression assistante: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Erreur lors de la suppression de l'assistante. Réessayez plus tard"),
          ),
        );
      }
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
    PhotosBadgeUtil.markSeen()
        .catchError((e) => print('📸 markSeen error: $e'));
    // Nettoyer le badge de l'icône (iOS/Android)
    NotificationService.clearBadge();
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
    _hourDocEvents = [];
    _hourHistoryEvents = [];

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
        _selectedChild!['id'],
        _selectedChild!['structureId'],
        selectedDay: _selectedTimelineDate,
      );

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
        });
      }
    } catch (e) {
      print('📰 ❌ Erreur vérification badges Actualités: $e');
      if (mounted) {
        setState(() {
          _showEventsBadge = false;
          _showSortiesBadge = false;
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

      // 2. Chargement des événements (uniquement à venir)
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final eventsSnapshot = await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('actualites')
          .doc('events')
          .collection('items')
          .where('date', isGreaterThanOrEqualTo: startOfToday)
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

      // 3. Chargement des sorties (uniquement à venir)
      final sortiesSnapshot = await _firestore
          .collection('structures')
          .doc(structureId)
          .collection('actualites')
          .doc('sorties')
          .collection('items')
          .where('date', isGreaterThanOrEqualTo: startOfToday)
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
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      final String userEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await _firestore.collection('users').doc(userEmail).get();
      final Map<String, dynamic> userData = userDoc.data() ?? {};

      String structureId = (userData['structureId'] ?? '').toString().trim();
      List<String> childIds =
          List<String>.from(userData['children'] ?? const <String>[]);
      String parentFirstName = (userData['firstName'] ?? '').toString();
      String parentLastName = (userData['lastName'] ?? '').toString();

      Future<String> inferStructureId({
        required String candidate,
      }) async {
        if (candidate.isNotEmpty) {
          return candidate;
        }

        final Set<String> potentialChildIds = {
          ...childIds.where((id) => id.isNotEmpty),
        };

        final createdChildren = userData['createdChildren'];
        if (createdChildren is List) {
          potentialChildIds.addAll(createdChildren
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty));
        }

        for (final childId in potentialChildIds) {
          try {
            final query = await _firestore
                .collectionGroup('children')
                .where(FieldPath.documentId, isEqualTo: childId)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) {
              final segments = query.docs.first.reference.path.split('/');
              final index = segments.indexOf('structures');
              if (index != -1 && index + 1 < segments.length) {
                return segments[index + 1];
              }
            }
          } catch (e) {
            print('⚠️ Impossible de déterminer la structure via $childId: $e');
          }
        }

        return user.uid;
      }

      structureId = await inferStructureId(candidate: structureId);

      Map<String, dynamic>? structureData;
      DocumentSnapshot<Map<String, dynamic>>? structureDoc;
      if (structureId.isNotEmpty) {
        structureDoc =
            await _firestore.collection('structures').doc(structureId).get();
        if (structureDoc.exists) {
          structureData = structureDoc.data();
        } else {
          final resolvedId = await inferStructureId(candidate: '');
          if (resolvedId != structureId) {
            structureId = resolvedId;
            structureDoc = await _firestore
                .collection('structures')
                .doc(structureId)
                .get();
            if (structureDoc.exists) {
              structureData = structureDoc.data();
            }
          }
        }
      }

      if (structureData == null && structureId.isEmpty) {
        structureId = user.uid;
      }

      bool isParentEmployeur = false;
      bool hasAssistant = false;
      Map<String, dynamic>? assistantInfo;
      String structureName = '';

      if (structureData != null) {
        structureName = (structureData['structureName'] ?? '').toString();

        final String structureType = (structureData['structureType'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (structureType == 'parent_employeur' ||
            structureType == 'parentemployeur') {
          isParentEmployeur = true;
        }

        if (parentFirstName.isEmpty) {
          parentFirstName = (structureData['firstName'] ??
                  structureData['ownerFirstName'] ??
                  '')
              .toString();
        }
        if (parentLastName.isEmpty) {
          parentLastName = (structureData['lastName'] ??
                  structureData['ownerLastName'] ??
                  '')
              .toString();
        }

        final String assistantEmail =
            (structureData['assistantEmail'] ?? '').toString().trim();
        final String assistantStatus =
            (structureData['assistantInvitationStatus'] ?? '')
                .toString()
                .trim();

        if (assistantEmail.isNotEmpty || assistantStatus.isNotEmpty) {
          hasAssistant = true;
          assistantInfo = {
            'email': assistantEmail,
            'firstName': structureData['assistantFirstName'] ?? '',
            'lastName': structureData['assistantLastName'] ?? '',
            'phone': structureData['assistantPhone'] ?? '',
            'status': assistantStatus,
            'linkedUserId':
                (structureData['assistantLinkedUserId'] ?? '').toString(),
          };
        }
      }

      final String storedStructureId =
          (userData['structureId'] ?? '').toString().trim();
      if (structureId.isNotEmpty && structureId != storedStructureId) {
        await _firestore.collection('users').doc(userEmail).set({
          'structureId': structureId,
          if (structureName.isNotEmpty) 'structureName': structureName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (structureId.isEmpty) {
        structureId = user.uid;
      }

      final List<Map<String, dynamic>> childrenData = [];
      final Set<String> knownChildIds = {};
      final Set<String> syncedChildIds = {};
      List<String> effectiveChildIds = List<String>.from(childIds);

      void addChildFromSnapshot(DocumentSnapshot<Map<String, dynamic>> childDoc,
          {bool markForSync = false}) {
        final data = childDoc.data() ?? {};
        if (!knownChildIds.add(childDoc.id)) {
          return;
        }
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
        if (markForSync) {
          syncedChildIds.add(childDoc.id);
        }
      }

      if (structureId.isNotEmpty) {
        if (effectiveChildIds.isEmpty && userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            if (userData['createdChildren'] is List) {
              effectiveChildIds.addAll((userData['createdChildren'] as List)
                  .map((e) => e.toString()));
            }
          }
        }

        if (effectiveChildIds.isNotEmpty) {
          final chunks = <List<String>>[];
          for (var i = 0; i < effectiveChildIds.length; i += 10) {
            chunks.add(effectiveChildIds.sublist(
                i,
                i + 10 > effectiveChildIds.length
                    ? effectiveChildIds.length
                    : i + 10));
          }
          for (final chunk in chunks) {
            final childDocs = await _firestore
                .collection('structures')
                .doc(structureId)
                .collection('children')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final childDoc in childDocs.docs) {
              addChildFromSnapshot(childDoc);
            }
          }
        }

        final createdChildrenSnap = await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .where('createdByEmail', isEqualTo: userEmail)
            .get();
        for (final childDoc in createdChildrenSnap.docs) {
          addChildFromSnapshot(childDoc, markForSync: true);
        }

        final parent1Snap = await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .where('parent1.email', isEqualTo: userEmail)
            .get();
        for (final childDoc in parent1Snap.docs) {
          addChildFromSnapshot(childDoc, markForSync: true);
        }

        final parent2Snap = await _firestore
            .collection('structures')
            .doc(structureId)
            .collection('children')
            .where('parent2.email', isEqualTo: userEmail)
            .get();
        for (final childDoc in parent2Snap.docs) {
          addChildFromSnapshot(childDoc, markForSync: true);
        }

        if (syncedChildIds.isNotEmpty) {
          final List<String> idsToSync = syncedChildIds.toList();
          await _firestore.collection('users').doc(userEmail).set({
            'children': FieldValue.arrayUnion(idsToSync),
            'createdChildren': FieldValue.arrayUnion(idsToSync),
            'structureId': structureId,
            'structureName': structureName,
            'role': 'parent',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      Map<String, dynamic>? newSelectedChild;
      if (childrenData.isNotEmpty) {
        final String? currentSelectedId = _selectedChild?['id'];
        newSelectedChild = childrenData.firstWhere(
          (child) => child['id'] == currentSelectedId,
          orElse: () => childrenData.first,
        );
      }

      if (mounted) {
        setState(() {
          _parentFirstName = parentFirstName;
          _parentLastName = parentLastName;
          _children = childrenData;
          _selectedChild = newSelectedChild;
          _selectedTimelineDate = _normalizeDate(DateTime.now());
          _isParentEmployeur = isParentEmployeur;
          _hasAssistant = hasAssistant;
          _assistantInfo = assistantInfo;
          _structureId = structureId;
          _structureName = structureName;
        });
      }

      if (childrenData.isNotEmpty && newSelectedChild != null) {
        await _loadChildTimeline(
          newSelectedChild['id'],
          newSelectedChild['structureId'],
          selectedDay: _selectedTimelineDate,
        );
      } else {
        _disposeCurrentSubscriptions();
        if (mounted) {
          setState(() {
            _timelineEvents = [];
          });
        }
      }

      if (structureId.isNotEmpty) {
        await _loadActualites(structureId);
        await _checkActualitesBadges();
      }

      _setupMessageListener();
    } catch (e) {
      print('❌ Erreur lors du chargement des données: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des données')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _parentOnboardingScheduled = false;
        _scheduleParentEmployeurOnboarding();
      }
    }
  }

  Future<void> _loadChildTimeline(String childId, String structureId,
      {DateTime? selectedDay}) async {
    final targetDate = _normalizeDate(selectedDay ?? _selectedTimelineDate);
    final formattedDate = DateFormat('dd/MM/yyyy').format(targetDate);
    print(
        "🔍 Chargement de la timeline pour enfant ID: $childId, structure: $structureId, date: $formattedDate");
    setState(() {
      _loadingTimeline = true;
      _selectedTimelineDate = targetDate;
    });

    try {
      final dayStart =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd =
          dayStart.add(Duration(days: 1)).subtract(Duration(milliseconds: 1));
      final dayStartTimestamp = Timestamp.fromDate(dayStart);
      final dayEndTimestamp = Timestamp.fromDate(dayEnd);
      final dayKey = DateFormat('yyyy-MM-dd').format(targetDate);

      print(
          "⏰ Plage horaire: ${dayStartTimestamp.toDate()} - ${dayEndTimestamp.toDate()}");

      _disposeCurrentSubscriptions();
      _updateTimelineEvents();

      final structureRef = _firestore.collection('structures').doc(structureId);
      final childRef = structureRef.collection('children').doc(childId);

      // 1. Écouter les activités
      _subscriptions.add(childRef
          .collection('activites')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
          .snapshots()
          .listen((snapshot) {
        print("📝 Activités reçues: ${snapshot.docs.length}");
        _processActivitiesSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur d'activités: $error");
      }));

      // 2. Écouter les repas
      _subscriptions.add(childRef
          .collection('repas')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
          .snapshots()
          .listen((snapshot) {
        print("🍔 Repas reçus: ${snapshot.docs.length}");
        _processMealsSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de repas: $error");
      }));

      // 3. Écouter les siestes
      _subscriptions.add(childRef
          .collection('siestes')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
          .snapshots()
          .listen((snapshot) {
        print("😴 Siestes reçues: ${snapshot.docs.length}");
        _processSleepsSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de siestes: $error");
      }));

      // 4. Écouter les changes
      _subscriptions.add(childRef
          .collection('changes')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
          .snapshots()
          .listen((snapshot) {
        print("👶 Changes reçus: ${snapshot.docs.length}");
        _processChangesSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de changes: $error");
      }));

      // 5. Écouter les soins de santé
      _subscriptions.add(childRef
          .collection('sante')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
          .snapshots()
          .listen((snapshot) {
        print("🏥 Soins santé reçus: ${snapshot.docs.length}");
        _processHealthSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de santé: $error");
      }));

      // 6. Écouter les photos
      _subscriptions.add(childRef
          .collection('medias')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
          .snapshots()
          .listen((snapshot) {
        print("📷 Photos reçues: ${snapshot.docs.length}");
        _processPhotosSnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur de photos: $error");
      }));

      // 7. Écouter les horaires du jour (source d'état courant, évite les doublons)
      _subscriptions.add(structureRef
          .collection('horaires')
          .doc(dayKey)
          .snapshots()
          .listen((doc) {
        // print("⏱️ Document horaires reçu: ${doc.exists}");
        _processHoursDocSnapshot(doc, childId);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur d'horaires (doc): $error");
      }));

      // 8. Historique des horaires (arrivée/départ)
      _subscriptions.add(structureRef
          .collection('horaires_history')
          .where('childId', isEqualTo: childId)
          .where('date', isEqualTo: dayKey)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        print("📚 Historique horaires reçu: ${snapshot.docs.length}");
        _processHoursHistorySnapshot(snapshot);
        _updateTimelineEvents();
      }, onError: (error) {
        print("❌ Erreur dans l'écouteur d'horaires (history): $error");
      }));

      // 9. Écouter les transmissions
      _subscriptions.add(childRef
          .collection('transmissions')
          .where('date', isGreaterThanOrEqualTo: dayStartTimestamp)
          .where('date', isLessThanOrEqualTo: dayEndTimestamp)
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

  Map<String, dynamic> _resolveTimeInfo({
    dynamic primary,
    Map<String, dynamic>? data,
    List<dynamic> extraCandidates = const [],
  }) {
    final List<dynamic> candidates = [];

    void addCandidate(dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      candidates.add(value);
    }

    addCandidate(primary);
    for (final extra in extraCandidates) {
      addCandidate(extra);
    }

    if (data != null) {
      for (final key in _timeCandidateKeys) {
        if (data.containsKey(key)) {
          addCandidate(data[key]);
        }
      }
      addCandidate(data['date']);
      addCandidate(data['timestamp']);
      addCandidate(data['createdAt']);
    }

    String label = '';
    for (final candidate in candidates) {
      final formatted = _formatTimeLabel(candidate);
      if (formatted.isNotEmpty) {
        label = formatted;
        break;
      }
    }

    int? minutes;
    for (final candidate in candidates) {
      minutes = _extractMinutes(candidate);
      if (minutes != null) break;
    }

    if ((label.isEmpty || minutes == null) && data != null) {
      final fallback = data['date'] ?? data['timestamp'] ?? data['createdAt'];
      if (label.isEmpty) {
        label = _formatTimeLabel(fallback);
      }
      minutes ??= _extractMinutes(fallback);
    }

    return {
      'label': label,
      'minutes': minutes ?? 0,
    };
  }

  String _formatTimeLabel(dynamic raw) {
    if (raw == null) return '';

    if (raw is Timestamp) {
      final dt = raw.toDate();
      return DateFormat('HH:mm').format(dt);
    }

    if (raw is DateTime) {
      return DateFormat('HH:mm').format(raw);
    }

    if (raw is num) {
      if (!raw.isFinite) return '';
      final totalMinutes = raw.toInt();
      final hour = ((totalMinutes ~/ 60) % 24);
      final minute = totalMinutes % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return '';

      final match = _timeExtractRegex.firstMatch(trimmed);
      if (match != null) {
        final int hourValue = int.tryParse(match.group(1)!) ?? 0;
        final String minuteGroup = match.group(2) ?? '';
        int minuteValue = 0;
        if (minuteGroup.isNotEmpty) {
          final padded = minuteGroup.padRight(2, '0');
          minuteValue = int.tryParse(padded) ?? 0;
        }

        final int hour = hourValue < 0 ? 0 : (hourValue > 23 ? 23 : hourValue);
        final int minute =
            minuteValue < 0 ? 0 : (minuteValue > 59 ? 59 : minuteValue);

        final normalized =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

        final bool hasRangeIndicator =
            _rangeIndicatorRegex.hasMatch(trimmed) || trimmed.contains('...');
        final bool hasStatusIndicator =
            trimmed.toLowerCase().contains('en cours') || trimmed.contains('…');

        if (trimmed.length > (match.group(0)?.length ?? 0) &&
            (hasRangeIndicator || hasStatusIndicator)) {
          return trimmed;
        }

        return normalized;
      }

      return trimmed;
    }

    return '';
  }

  int? _extractMinutes(dynamic raw) {
    if (raw == null) return null;

    if (raw is int) return raw;
    if (raw is double) {
      if (!raw.isFinite) return null;
      return raw.round();
    }

    if (raw is Timestamp) {
      final dt = raw.toDate();
      return dt.hour * 60 + dt.minute;
    }

    if (raw is DateTime) {
      return raw.hour * 60 + raw.minute;
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      final match = _timeExtractRegex.firstMatch(trimmed);
      if (match != null) {
        final int? hourParsed = int.tryParse(match.group(1)!);
        if (hourParsed == null) return null;

        final String minuteGroup = match.group(2) ?? '';
        int minuteParsed = 0;
        if (minuteGroup.isNotEmpty) {
          final padded = minuteGroup.padRight(2, '0');
          minuteParsed = int.tryParse(padded) ?? 0;
        }

        final int hour =
            hourParsed < 0 ? 0 : (hourParsed > 23 ? 23 : hourParsed);
        final int minute =
            minuteParsed < 0 ? 0 : (minuteParsed > 59 ? 59 : minuteParsed);

        return hour * 60 + minute;
      }
    }

    return null;
  }

  void _processActivitiesSnapshot(QuerySnapshot snapshot) {
    _eventsMap['activity'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
      );

      return {
        'id': doc.id,
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
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

      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
      );

      final String rawMoment = (data['moment'] ?? '').toString();
      final String momentLabel = rawMoment.isNotEmpty
          ? rawMoment
          : (data['gouter'] == true ? 'Goûter' : '');
      final String rawType = (data['typeAlimentation'] ?? '').toString();
      final bool isBiberon = rawType == 'Biberon' || data['biberon'] == true;
      final bool isAllaitement =
          rawType == 'Allaitement' || data['allaitement'] == true;
      final bool isSolide = rawType == 'Solide';
      final bool isMixte = rawType == 'Mixte';
      final String typeLabel = rawType.isNotEmpty
          ? rawType
          : isBiberon
              ? 'Biberon'
              : isAllaitement
                  ? 'Allaitement'
                  : (momentLabel.isNotEmpty ? momentLabel : 'Repas');
      final String description =
          (data['alimentationDescription'] ?? '').toString();
      final String qualite = (data['qualite'] ?? '').toString();

      String details = '';
      if (isBiberon) {
        details = '${data['ml']?.toInt() ?? 0} ml';
      } else if (isAllaitement) {
        details = 'Allaitement';
      } else if (isSolide || isMixte) {
        details = description.isNotEmpty ? description : qualite;
      } else {
        details = qualite.isNotEmpty ? qualite : description;
      }
      if (details.trim().isEmpty) {
        details = typeLabel;
      }

      IconData icon = Icons.restaurant;
      if (isBiberon) {
        icon = Icons.local_drink;
      } else if (isAllaitement) {
        icon = Icons.child_care;
      } else if (isSolide || isMixte) {
        icon = Icons.restaurant_menu;
      } else if (momentLabel == 'Goûter') {
        icon = Icons.icecream;
      }

      final String title = momentLabel.isNotEmpty ? momentLabel : typeLabel;

      return {
        'id': doc.id,
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
        'type': 'meal',
        'title': title,
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

      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
        extraCandidates: [data['start']],
      );

      return {
        'id': doc.id,
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
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

      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
      );

      String details = '';
      if (data['pipi'] == true) details += 'Pipi ';
      if (data['selles'] == true) details += 'Selles';

      return {
        'id': doc.id,
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
        'type': 'change',
        'title': 'Change',
        'details': details.trim(),
        'changeType': data['type'] ?? '',
        'soins':
            (data['soins'] is List) ? List<String>.from(data['soins']) : [],
        'iconData': Icons.baby_changing_station,
        'color': Colors.brown,
        'observations': data['observations'],
      };
    }).toList();
  }

  void _processHealthSnapshot(QuerySnapshot snapshot) {
    _eventsMap['health'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
      );

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
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
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

      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
      );

      final isVideo = (data['type']?.toString().toLowerCase() == 'video');

      return {
        'id': doc.id,
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
        'type': isVideo ? 'video' : 'photo',
        'title': isVideo ? 'Vidéo' : 'Photo',
        'details': data['description'] ?? '',
        'iconData': Icons.photo,
        'color': Colors.purple,
        'url': data['url'],
      };
    }).toList();
  }

  // ignore: unused_element
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

      final timeInfo = _resolveTimeInfo(
        primary: eventTime.isNotEmpty ? eventTime : timestamp,
        data: {
          'date': timestamp,
        },
      );

      events.add({
        'id': doc.id,
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
        'type': normalized,
        'title': normalized == 'arrival' ? 'Arrivée' : 'Départ',
        'details': normalized == 'arrival'
            ? (data['arrivee'] ?? '')
            : (data['depart'] ?? ''),
        'iconData': normalized == 'arrival' ? Icons.login : Icons.logout,
        'color': normalized == 'arrival'
            ? Colors.green.shade700
            : Colors.red.shade700,
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
          print("  ℹ️ Child is marked absent");
          _hourDocEvents = [];
          _updateHourEvents();
          return;
        }

        // Format segments (nouveau)
        if (childData['segments'] is List) {
          final segments =
              List<Map<String, dynamic>>.from(childData['segments']);
          for (final seg in segments) {
            final arr = seg['arrivee'];
            final dep = seg['depart'];
            if (arr != null && arr.toString().isNotEmpty) {
              final timeInfo = _resolveTimeInfo(primary: arr);
              events.add({
                'id': 'arr_${arr}_${events.length}',
                'time': timeInfo['label'],
                'sortKey': timeInfo['minutes'],
                'type': 'arrival',
                'title': 'Arrivée',
                'details': arr,
                'iconData': Icons.login,
                'color': Colors.green.shade700,
              });
            }
            if (dep != null && dep.toString().isNotEmpty) {
              final timeInfo = _resolveTimeInfo(primary: dep);
              events.add({
                'id': 'dep_${dep}_${events.length}',
                'time': timeInfo['label'],
                'sortKey': timeInfo['minutes'],
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
            final timeInfo = _resolveTimeInfo(primary: arr);
            events.add({
              'id': 'arr_${arr}_0',
              'time': timeInfo['label'],
              'sortKey': timeInfo['minutes'],
              'type': 'arrival',
              'title': 'Arrivée',
              'details': arr,
              'iconData': Icons.login,
              'color': Colors.green.shade700,
            });
          }
          if (dep != null && dep.toString().isNotEmpty) {
            final timeInfo = _resolveTimeInfo(primary: dep);
            events.add({
              'id': 'dep_${dep}_0',
              'time': timeInfo['label'],
              'sortKey': timeInfo['minutes'],
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

    _hourDocEvents = events;
    _updateHourEvents();
  }

  void _processHoursHistorySnapshot(QuerySnapshot snapshot) {
    String? arrival;
    String? departure;

    String? extractHour(Map<String, dynamic> data) {
      final rawHour = data['heure'];
      if (rawHour != null && rawHour.toString().isNotEmpty) {
        return rawHour.toString();
      }
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return DateFormat('HH:mm').format(dt);
      }
      return null;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final action = (data['actionType'] ?? '').toString();
      final hour = extractHour(data);
      if (hour == null) continue;

      if ((action == 'arrivee' || action == 'arrivee_modifiee') &&
          arrival == null) {
        arrival = hour;
      } else if ((action == 'depart' || action == 'depart_modifiee') &&
          departure == null) {
        departure = hour;
      }
    }

    final events = <Map<String, dynamic>>[];
    if (arrival != null && arrival!.isNotEmpty) {
      final timeInfo = _resolveTimeInfo(primary: arrival);
      events.add({
        'id': 'history_arrival',
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
        'type': 'arrival',
        'title': 'Arrivée',
        'details': arrival,
        'iconData': Icons.login,
        'color': Colors.green.shade700,
      });
    }
    if (departure != null && departure!.isNotEmpty) {
      final timeInfo = _resolveTimeInfo(primary: departure);
      events.add({
        'id': 'history_departure',
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
        'type': 'departure',
        'title': 'Départ',
        'details': departure,
        'iconData': Icons.logout,
        'color': Colors.red.shade700,
      });
    }

    _hourHistoryEvents = events;
    _updateHourEvents();
  }

  void _updateHourEvents() {
    final combined = <Map<String, dynamic>>[];
    if (_hourDocEvents.isNotEmpty) {
      combined.addAll(_hourDocEvents);
    }

    if (_hourHistoryEvents.isNotEmpty) {
      final existing = combined
          .map((event) =>
              '${event['type']}_${event['time']}_${event['details'] ?? ''}')
          .toSet();
      for (final event in _hourHistoryEvents) {
        final signature =
            '${event['type']}_${event['time']}_${event['details'] ?? ''}';
        if (!existing.contains(signature)) {
          combined.add(event);
        }
      }
    }

    _eventsMap['hour'] = combined;
  }

  void _processTransmissionsSnapshot(QuerySnapshot snapshot) {
    _eventsMap['transmission'] = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final timeInfo = _resolveTimeInfo(
        primary: data['heure'],
        data: data,
      );

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
        'time': timeInfo['label'],
        'sortKey': timeInfo['minutes'],
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

    allEvents.sort((a, b) {
      int resolveMinutes(Map<String, dynamic> event) {
        if (event['sortKey'] is int) {
          return event['sortKey'] as int;
        }
        final extracted = _extractMinutes(event['time']);
        return extracted ?? 0;
      }

      final aMin = resolveMinutes(a);
      final bMin = resolveMinutes(b);
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

      if ((map1['sortKey'] ?? 0) != (map2['sortKey'] ?? 0)) return false;

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

  void _onChildSelected(Map<String, dynamic> child) async {
    final alreadySelected =
        _selectedChild != null && _selectedChild!['id'] == child['id'];
    if (alreadySelected) return;

    setState(() {
      _selectedChild = child;
      _selectedTimelineDate = _normalizeDate(DateTime.now());
    });

    await _loadChildTimeline(
      child['id'],
      child['structureId'],
      selectedDay: _selectedTimelineDate,
    );

    final structureId = child['structureId']?.toString() ?? '';
    if (structureId.isNotEmpty) {
      await _loadActualites(structureId);
      await _checkActualitesBadges();
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime get _earliestTimelineDate => _normalizeDate(
      DateTime.now().subtract(Duration(days: _timelineHistoryLimitDays)));

  bool get _canGoToPreviousDay =>
      _normalizeDate(_selectedTimelineDate).isAfter(_earliestTimelineDate);

  bool get _canGoToNextDay =>
      _selectedTimelineDate.isBefore(_normalizeDate(DateTime.now()));

  Future<void> _changeTimelineDay(int deltaDays) async {
    if (_selectedChild == null) return;

    final target =
        _normalizeDate(_selectedTimelineDate.add(Duration(days: deltaDays)));
    final earliest = _earliestTimelineDate;
    final today = _normalizeDate(DateTime.now());

    if (target.isBefore(earliest) || target.isAfter(today)) {
      return;
    }

    if (_isSameDay(target, _selectedTimelineDate)) {
      return;
    }

    final childIdValue = _selectedChild!['id'];
    final structureIdValue = _selectedChild!['structureId'];
    final childId = childIdValue != null ? childIdValue.toString() : null;
    final structureId =
        structureIdValue != null ? structureIdValue.toString() : null;
    if (childId == null ||
        childId.isEmpty ||
        structureId == null ||
        structureId.isEmpty) {
      return;
    }

    await _loadChildTimeline(
      childId,
      structureId,
      selectedDay: target,
    );
  }

  Widget _buildHeaderIcon(String label, IconData icon, VoidCallback onTap,
      {bool showBadge = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;

        // Calculs plus conservateurs pour éviter l'overflow
        final maxWidth = constraints.maxWidth > 0
            ? constraints.maxWidth.clamp(52.0, screenWidth * 0.2)
            : screenWidth * 0.2;
        final maxHeight = constraints.maxHeight > 0
            ? constraints.maxHeight.clamp(48.0, 68.0)
            : 60.0;

        // Ajuster les tailles selon l'espace disponible
        final iconSize = (maxWidth * 0.48).clamp(20.0, 26.0);
        final containerPadding = (maxWidth * 0.08).clamp(5.0, 10.0);
        final fontSize = (maxWidth * 0.18).clamp(10.0, 13.0);
        final badgeSize = (maxWidth * 0.16).clamp(9.0, 14.0);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: maxWidth,
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: maxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Container pour l'icône avec taille fixe
                Flexible(
                  flex: 3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(containerPadding),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                      if (showBadge)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: badgeSize,
                            height: badgeSize,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Espacement adaptatif
                SizedBox(height: 2),

                // Texte avec contrainte de hauteur
                Flexible(
                  flex: 2,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.0, // Réduire l'interligne
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

  Widget _buildTimelineDateSelector() {
    final today = _normalizeDate(DateTime.now());
    final isToday = _isSameDay(_selectedTimelineDate, today);

    final rawMainLabel =
        DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedTimelineDate);
    final mainLabel = isToday
        ? "Aujourd'hui"
        : toBeginningOfSentenceCase(rawMainLabel) ?? rawMainLabel;
    final secondaryLabel =
        DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedTimelineDate);

    Widget navButton({
      required IconData icon,
      required bool enabled,
      required VoidCallback? onTap,
    }) {
      final backgroundColor =
          enabled ? primaryBlue.withOpacity(0.15) : Colors.grey.shade200;
      final iconColor = enabled ? primaryBlue : Colors.grey.shade500;

      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, color: iconColor),
          splashRadius: 24,
          padding: EdgeInsets.all(8),
          constraints: BoxConstraints(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              navButton(
                icon: Icons.chevron_left,
                enabled: _canGoToPreviousDay,
                onTap: () => _changeTimelineDay(-1),
              ),
              Column(
                children: [
                  Text(
                    mainLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2),
                  Text(
                    secondaryLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              navButton(
                icon: Icons.chevron_right,
                enabled: _canGoToNextDay,
                onTap: () => _changeTimelineDay(1),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Historique visible sur ${_timelineHistoryLimitDays} jours",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPrimaryHeaderIcons() {
    final iconConfigs = [
      _buildHeaderIcon(
        "Menu",
        Icons.restaurant_menu,
        () => _showActualiteDetails("menu"),
      ),
      _buildHeaderIcon(
        "Événement",
        Icons.event,
        () => _showActualiteDetails("evenement"),
        showBadge: _showEventsBadge,
      ),
      _buildHeaderIcon(
        "Sortie",
        Icons.directions_bus,
        () => _showActualiteDetails("sortie"),
        showBadge: _showSortiesBadge,
      ),
      _buildHeaderIcon(
        "Photos",
        Icons.photo_library,
        () => _showPhotoHistory(),
        showBadge: _showPhotosBadge,
      ),
    ];

    return iconConfigs
        .map(
          (widget) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: widget,
            ),
          ),
        )
        .toList();
  }

  Widget _buildChildSwitcher() {
    if (_children.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF3FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE4FF), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final child = _children[index];
                final bool isSelected = _selectedChild != null &&
                    _selectedChild!['id'] == child['id'];

                final Color tileColor = isSelected ? primaryBlue : Colors.white;
                final Color textColor =
                    isSelected ? Colors.white : Colors.black87;
                final Color badgeColor =
                    isSelected ? Colors.white : primaryBlue;

                return GestureDetector(
                  onTap: () => _onChildSelected(child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color:
                            isSelected ? primaryBlue : const Color(0xFFDCE4FF),
                        width: isSelected ? 1.8 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 12),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [Colors.white, Colors.white70]
                                      : const [Color(0xFFEEF3FF), Colors.white],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: badgeColor.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: child['photoUrl'] != null
                                  ? ClipOval(
                                      child: Image.network(
                                        child['photoUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(Icons.child_care,
                                                    color: badgeColor),
                                      ),
                                    )
                                  : Icon(Icons.child_care, color: badgeColor),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              child['firstName']?.toString() ?? 'Enfant',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1.0 : 0.8,
                          child: Text(
                            isSelected ? "Fil en cours" : "Voir la journée",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
          });
        }
      }
    } catch (e) {
      // Pas bloquant
      print('📰 ❌ Erreur mark seen ($type): $e');
    }
    // Nettoyer le badge de l'icône quand l'utilisateur ouvre la section
    NotificationService.clearBadge();
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
      backgroundColor: kAppBackgroundColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header avec effet parallaxe
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height *
                      0.25, // 25% de la hauteur d'écran
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final screenHeight =
                                MediaQuery.of(context).size.height;
                            final availableHeight = constraints.maxHeight;

                            // Ajuster les espacements selon la hauteur disponible
                            final topPadding =
                                availableHeight > 150 ? 30.0 : 20.0;
                            final titleFontSize =
                                availableHeight > 150 ? 28.0 : 24.0;
                            final dateFontSize =
                                availableHeight > 150 ? 16.0 : 14.0;
                            final middleSpacing =
                                availableHeight > 150 ? 20.0 : 12.0;

                            return Padding(
                              padding:
                                  EdgeInsets.fromLTRB(24, topPadding, 24, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Titre avec taille adaptative
                                  Flexible(
                                    child: Text(
                                      "Bonjour, $_parentFirstName",
                                      style: TextStyle(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  SizedBox(height: 8),

                                  // Date avec taille adaptative
                                  Flexible(
                                    child: Text(
                                      DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                                          .format(DateTime.now())
                                          .toLowerCase(),
                                      style: TextStyle(
                                        fontSize: dateFontSize,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  SizedBox(height: middleSpacing),

                                  // Icônes avec espacement adaptatif
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            availableHeight > 150 ? 50.0 : 40.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: _buildPrimaryHeaderIcons(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_children.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  if (_children.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: _buildChildSwitcher(),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                          _selectedChild!['gender'] == 'Garçon'
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
                  SliverToBoxAdapter(
                    child: _selectedChild != null
                        ? _buildTimelineDateSelector()
                        : SizedBox.shrink(),
                  ),
                  _loadingTimeline
                      ? SliverToBoxAdapter(
                          child: SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
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
                                      'assets/images/no_activities.png',
                                      height: 120,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
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
            NotificationService.clearBadge();
            context.go('/parent/messages');
          } else if (index == 2) {
            // Vers les stocks
            setState(() {
              _showStockBadge = false; // Réinitialiser le badge
            });
            NotificationService.clearBadge();
            context.go('/parent/stocks');
          } else if (index == 3) {
            // Vers les paramètres
            context.go('/parent/settings');
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
              'assets/images/Icone_home.png',
              width: 60,
              height: 60,
            ),
            activeIcon: Image.asset(
              'assets/images/Icone_home.png',
              width: 60,
              height: 60,
            ),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_message.png',
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
                  'assets/images/Icone_message.png',
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
            label: "Messages",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Image.asset(
                  'assets/images/Icone_stock.png',
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
                  'assets/images/Icone_stock.png',
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
            label: "Stocks",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone-parametres.png',
              width: 50,
              height: 50,
            ),
            activeIcon: Image.asset(
              'assets/images/Icone-parametres.png',
              width: 50,
              height: 50,
            ),
            label: "Paramètres",
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
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await SessionUtil.signOut();
                if (!mounted) return;
                context.go('/');
              },
              icon: const Icon(Icons.logout, color: primaryBlue),
              label: const Text(
                "Se déconnecter",
                style:
                    TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event) {
    final dynamic rawTime = event['time'];
    String time = _formatTimeLabel(rawTime);
    if (time.isEmpty && rawTime is String) {
      time = rawTime.trim();
    }
    if (time.isEmpty) {
      time = '--';
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
                                        color: Colors.brown.withOpacity(0.15)),
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
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
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
