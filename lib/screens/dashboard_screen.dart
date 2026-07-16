import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poppins_app/screens/edit_schedule_screen.dart';
import 'package:poppins_app/screens/child_profile_details_screen.dart';
import 'package:poppins_app/screens/photo_management_screen.dart';
import 'package:poppins_app/screens/child_removal_screen.dart';
import 'package:poppins_app/screens/mam_member_add_screen.dart';
import 'package:poppins_app/screens/mam_group_chat_screen.dart';
import 'package:poppins_app/screens/mam_member_removal_screen.dart';
import 'package:poppins_app/screens/fridge_temperature_screen.dart';
import 'package:poppins_app/screens/planning_screen.dart';
import 'package:poppins_app/screens/delegations_screen.dart';
import 'package:poppins_app/screens/admin_screen.dart';
import 'package:poppins_app/screens/freezer_temperature_screen.dart';
import 'package:poppins_app/screens/child_history_detail_screen.dart';
import 'package:poppins_app/screens/history_date_selection_screen.dart';
import '../services/photo_cleanup_service.dart';
import '../screens/admin_cleanup_screen.dart';
import 'package:poppins_app/screens/parent_coordonnees_screen.dart';
import '../services/subscription_service.dart';
import '../services/firebase_trial_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../theme/app_colors.dart';
import '../services/structure_notification_service.dart';
import 'admin_broadcast_notification_screen.dart';
import 'admin_subscription_dashboard_screen.dart';
import 'package:poppins_app/screens/documents_screen.dart';
import 'package:poppins_app/features/documents/screens/engagement_list_screen.dart';
import 'package:poppins_app/features/documents/screens/contrat_cdi_list_screen.dart';
import 'package:poppins_app/features/documents/screens/contrat_cdd_list_screen.dart';
import 'package:poppins_app/features/documents/screens/avenant_list_screen.dart';
import 'package:poppins_app/features/calculs/screens/calculs_home_screen.dart';

const Set<String> _dashboardAdminEmails = {
  'cbeylet06@gmail.com',
  'chrisgugu1101@gmail.com',
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _RssHeadline {
  const _RssHeadline({
    required this.title,
    required this.link,
    this.published,
  });

  final String title;
  final String link;
  final DateTime? published;
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> enfants = [];
  bool isLoading = true;
  String structureName = "Chargement...";
  bool showMonthlyTableReports = false;
  bool isMAMStructure = false;
  bool isParentEmployeurStructure = false;
  int maxMemberCount = 0;
  int currentMemberCount = 0;
  bool needFridgeTemperatureCheck = false;
  bool needFreezerTemperatureCheck = false; // NOUVEAU
  bool? hasFreezer;
  int _abacusClickCount = 0;
  int _selectedSection = 0;
  bool? hasAssmatFridge; // null = pas encore défini, true = oui, false = non
  bool? hasAssmatFreezer; // null = pas encore défini, true = oui, false = non
  bool showAssmatFridgeChoice = false;
  bool showAssmatFreezerChoice = false;
  bool needAssmatFridgeTemperatureCheck = false;
  bool needAssmatFreezerTemperatureCheck = false;
  int _pendingDelegationsCount = 0;
  String _currentUserEmail = '';
  String? _structureOwnerEmail;
  bool _currentMemberIsAdmin = false;
  bool _allowAllChildren = true;
  Set<String> _delegatedChildIds = {};
  String? _structureId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _structureNotificationSub;
  Map<String, dynamic>? _latestStructureNotification;
  String? _latestStructureNotificationId;
  bool _hasUnreadStructureNotification = false;
  bool _showNotificationAdminButton = false;
  bool _showSubscriptionAdminButton = false;

  static const int _rssMaxItems = 1;
  static const Duration _rssRefreshCooldown = Duration(minutes: 15);
  static const Duration _rssRequestTimeout = Duration(seconds: 8);
  static const String _defaultRssFeedUrl = 'https://www.lassmat.fr/rss.xml';

  String? _rssFeedUrl;
  List<_RssHeadline> _rssItems = const [];
  bool _isRssLoading = false;
  String? _rssError;
  DateTime? _lastRssFetch;
  bool _showDashboardNews = true;
  bool _isSubscriptionLoading = true;
  bool _isSubscribed = true;
  TrialStatus? _trialStatus;

  // Couleurs dédiées aux tuiles de la grille (style 2025)
  final Color _tileBlue = const Color(0xFF3D9DF2);
  final Color _tileRed = const Color(0xFFD94350);
  final Color _tileYellow = const Color(0xFFF2B705);
  final Color _tileCyan = const Color(0xFF05C7F2);

  // Définition des couleurs de la palette
  static const Color primaryRed = Color(0xFFD94350); // #D94350
  static const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
  static const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
  static const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
  static const Color primaryYellow = Color(0xFFF2B705); // #F2B705

  // Couleurs du thème actuel
  late Color primaryColor;
  late Color secondaryColor;

  @override
  void initState() {
    super.initState();
    // Définir les couleurs par défaut
    primaryColor = primaryBlue;
    secondaryColor = lightBlue;

    // Initialiser avec les valeurs par défaut CORRIGÉES
    isMAMStructure = false;
    maxMemberCount = 1; // Pour AssistanteMaternelle seule
    currentMemberCount = 1;
    needFridgeTemperatureCheck = false;
    needFreezerTemperatureCheck = false;
    hasAssmatFridge = null;
    hasAssmatFreezer = null;
    needAssmatFridgeTemperatureCheck = false;
    needAssmatFreezerTemperatureCheck = false;

    Future.wait([
      initializeDateFormatting('fr_FR', null),
      initializeDateFormatting('en_US', null),
    ]).then((_) {
      _loadData();
      _checkMonthlyTableEnabled();
      _checkIfMAMStructure();
      _refreshDelegationsCount();
    });
    _checkSubscriptionStatus();
  }

  @override
  void dispose() {
    _structureNotificationSub?.cancel();
    super.dispose();
  }

  void _showPhotoAdministration() {
    // Sécurité supplémentaire
    if (!kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fonction disponible uniquement en mode développeur"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCleanupScreen(),
      ),
    );
  }

  String _getSubscriptionTitle(bool trialStarted, bool trialExpired) {
    if (trialExpired && trialStarted) {
      return "Votre essai est terminé";
    } else if (trialStarted && !trialExpired) {
      return "Profitez de votre essai gratuit";
    }
    return "Débloquez le tableau de bord";
  }

  String _getSubscriptionDescription(bool trialStarted, bool trialExpired,
      int daysLeft, TrialStatus? trialStatus) {
    if (trialExpired && trialStarted) {
      String expiryText = "";
      if (trialStatus?.endAt != null) {
        try {
          expiryText =
              DateFormat('d MMMM yyyy', 'fr_FR').format(trialStatus!.endAt!);
        } catch (_) {
          expiryText = "";
        }
      }
      return expiryText.isNotEmpty
          ? "Votre essai gratuit s'est terminé le $expiryText. Pour continuer à profiter du tableau de bord et de toutes ses fonctionnalités, activez votre abonnement."
          : "Votre essai gratuit est terminé. Pour continuer à profiter du tableau de bord, activez votre abonnement.";
    } else if (trialStarted && !trialExpired) {
      return "Découvrez toutes les fonctionnalités du tableau de bord gratuitement pendant votre période d'essai. Prenez le temps d'explorer !";
    }
    return "Accédez à la gestion complète de votre structure avec un tableau de bord intuitif et des outils professionnels.";
  }

  Widget _buildTrialProgressBar(int daysLeft, Size screenSize, bool isTablet) {
    final int totalTrialDays = 30; // ou récupérer depuis trialStatus
    final double progress = (daysLeft / totalTrialDays).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "$daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}",
                style: TextStyle(
                  fontSize: screenSize.width * (isTablet ? 0.02 : 0.038),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards(Size screenSize, bool isTablet) {
    final features = [
      {
        'icon': Icons.dashboard_customize_rounded,
        'title': 'Tableau de bord complet',
        'description': 'Visualisez toute votre activité',
        'color': const Color(0xFF3D9DF2),
      },
      {
        'icon': Icons.groups_rounded,
        'title': 'Gestion des enfants',
        'description': 'Suivez chaque enfant facilement',
        'color': const Color(0xFF05C7F2),
      },
      {
        'icon': Icons.calendar_month_rounded,
        'title': 'Planning intégré',
        'description': 'Organisez vos journées',
        'color': const Color(0xFFF2B705),
      },
      {
        'icon': Icons.insert_chart_rounded,
        'title': 'Rapports mensuels',
        'description': 'Suivez votre activité',
        'color': const Color(0xFFD94350),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: screenSize.width * (isTablet ? 0.02 : 0.03),
        mainAxisSpacing: screenSize.width * (isTablet ? 0.02 : 0.03),
        childAspectRatio: isTablet ? 1.2 : 1.0,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          padding: EdgeInsets.all(screenSize.width * (isTablet ? 0.025 : 0.04)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (feature['color'] as Color).withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (feature['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: feature['color'] as Color,
                  size: screenSize.width * (isTablet ? 0.04 : 0.08),
                ),
              ),
              SizedBox(height: screenSize.height * 0.012),
              Text(
                feature['title'] as String,
                style: TextStyle(
                  fontSize: screenSize.width * (isTablet ? 0.018 : 0.036),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D3436),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: screenSize.height * 0.006),
              Text(
                feature['description'] as String,
                style: TextStyle(
                  fontSize: screenSize.width * (isTablet ? 0.016 : 0.03),
                  color: const Color(0xFF636E72),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final bool result = await SubscriptionService.isUserSubscribed();
      final TrialStatus trialStatus =
          await FirebaseTrialService.fetchTrialStatusForCurrentUser();
      bool isAllowed = result;
      final bool hasActivePaidSubscription = result && !trialStatus.hasStarted;

      if (trialStatus.isActive) {
        isAllowed = true;
      } else if (trialStatus.isExpired) {
        await FirebaseTrialService.markTrialExpiredForCurrentUser();
        isAllowed = hasActivePaidSubscription;
      } else {
        isAllowed = result;
      }

      if (!mounted) return;
      setState(() {
        _isSubscribed = isAllowed;
        _trialStatus = trialStatus;
        _isSubscriptionLoading = false;
      });
    } catch (e) {
      print('Erreur vérification abonnement Dashboard: $e');
      if (!mounted) return;
      setState(() {
        _isSubscribed = true;
        _trialStatus ??= TrialStatus.empty();
        _isSubscriptionLoading = false;
      });
    }
  }

  Widget _buildSubscriptionRequired() {
    final TrialStatus? trialStatus = _trialStatus;
    final bool trialStarted = trialStatus?.hasStarted ?? false;
    final bool trialExpired = trialStatus?.isExpired ?? false;
    final int daysLeft = trialStatus?.daysRemaining ?? 0;
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header avec gradient moderne
            SliverToBoxAdapter(
              child: Container(
                margin:
                    EdgeInsets.all(screenSize.width * (isTablet ? 0.03 : 0.04)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.8),
                      brightCyan.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      offset: const Offset(0, 10),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * (isTablet ? 0.04 : 0.06),
                    vertical: screenSize.height * (isTablet ? 0.04 : 0.05),
                  ),
                  child: Column(
                    children: [
                      // Icône moderne avec effet glassmorphism
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: screenSize.width * (isTablet ? 0.08 : 0.16),
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: screenSize.height * 0.025),

                      // Titre principal
                      Text(
                        _getSubscriptionTitle(trialStarted, trialExpired),
                        style: TextStyle(
                          fontSize:
                              screenSize.width * (isTablet ? 0.032 : 0.065),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (trialStarted && !trialExpired) ...[
                        SizedBox(height: screenSize.height * 0.02),
                        // Progress bar pour l'essai
                        _buildTrialProgressBar(daysLeft, screenSize, isTablet),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Description et avantages
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * (isTablet ? 0.03 : 0.04),
                ),
                child: Column(
                  children: [
                    SizedBox(height: screenSize.height * 0.02),

                    // Card description principale
                    Container(
                      padding: EdgeInsets.all(
                          screenSize.width * (isTablet ? 0.03 : 0.05)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            offset: const Offset(0, 4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getSubscriptionDescription(trialStarted,
                                trialExpired, daysLeft, trialStatus),
                            style: TextStyle(
                              fontSize:
                                  screenSize.width * (isTablet ? 0.02 : 0.04),
                              color: const Color(0xFF2D3436),
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (trialExpired && trialStarted) ...[
                            SizedBox(height: screenSize.height * 0.02),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Aucune facturation automatique. Vous restez maître de votre abonnement.",
                                      style: TextStyle(
                                        fontSize: screenSize.width *
                                            (isTablet ? 0.018 : 0.034),
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: screenSize.height * 0.025),

                    // Avantages en cards modernes
                    _buildFeatureCards(screenSize, isTablet),

                    SizedBox(height: screenSize.height * 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom bar avec CTA fixe
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenSize.width * (isTablet ? 0.03 : 0.04),
          vertical: screenSize.height * 0.02,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, -4),
              blurRadius: 20,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CTA principal
              SizedBox(
                width: double.infinity,
                height: screenSize.height * (isTablet ? 0.07 : 0.065),
                child: ElevatedButton(
                  onPressed: _openPricing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: primaryColor.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        trialExpired
                            ? "Activer mon abonnement"
                            : "Découvrir les offres",
                        style: TextStyle(
                          fontSize:
                              screenSize.width * (isTablet ? 0.022 : 0.042),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: screenSize.width * (isTablet ? 0.025 : 0.05),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenSize.height * 0.012),

              // Lien secondaire
              TextButton(
                onPressed: () => context.go('/home'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF636E72),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  "Retourner à l'accueil",
                  style: TextStyle(
                    fontSize: screenSize.width * (isTablet ? 0.02 : 0.037),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPricing() async {
    final Map<String, dynamic> extra = await _buildPricingExtras();
    if (!mounted) return;
    context.go('/pricing', extra: extra);
  }

  Future<Map<String, dynamic>> _buildPricingExtras() async {
    try {
      final String structureId = await _getStructureId();
      if (structureId.isEmpty) {
        return {
          'structureType': isMAMStructure ? 'mam' : 'assistante_maternelle'
        };
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (!snapshot.exists) {
        return {
          'structureType': isMAMStructure ? 'mam' : 'assistante_maternelle'
        };
      }

      final data = snapshot.data() ?? {};
      final String rawType = (data['structureType'] ??
              (isMAMStructure ? 'MAM' : 'AssistanteMaternelle'))
          .toString();
      final String routingType = rawType.toLowerCase().contains('mam')
          ? 'mam'
          : 'assistante_maternelle';

      final Map<String, dynamic> payload = {'structureType': routingType};
      if (routingType == 'mam') {
        final int? plan = _resolveMamPlanFromData(data);
        if (plan != null) {
          payload['memberCount'] = plan;
        }
      }
      return payload;
    } catch (e) {
      print('⚠️ Erreur préparation pricing (dashboard): $e');
      return {
        'structureType': isMAMStructure ? 'mam' : 'assistante_maternelle'
      };
    }
  }

  int? _resolveMamPlanFromData(Map<String, dynamic> data) {
    final dynamic preferredPlan = data['mamPreferredPlan'];
    final dynamic memberCount = data['memberCount'];
    final dynamic maxMemberCount = data['maxMemberCount'];

    if (preferredPlan is int && preferredPlan >= 3) {
      return preferredPlan >= 4 ? 4 : 3;
    }

    if (memberCount is int && memberCount >= 3) {
      return memberCount >= 4 ? 4 : 3;
    }

    if (maxMemberCount is int && maxMemberCount >= 3) {
      return maxMemberCount >= 4 ? 4 : 3;
    }

    return null;
  }

  Widget _wrapWithLoadingOverlay(Widget child) {
    if (!isLoading) {
      return child;
    }
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: kAppBackgroundColor.withOpacity(0.5),
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  // Compteur des délégations à traiter aujourd'hui pour le membre courant
  Future<int> _fetchPendingDelegationsCountToday() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      final String currentUserEmail = user.email?.toLowerCase() ?? '';
      // Trouver la structure
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserEmail)
          .get();
      final String structureId = (userDoc.exists &&
              (userDoc.data()?['structureId'] ?? '').toString().isNotEmpty)
          ? userDoc.data()!['structureId']
          : user.uid;

      // Trouver le memberId correspondant à l'email
      final memSnap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('members')
          .where('email', isEqualTo: currentUserEmail)
          .limit(1)
          .get();
      if (memSnap.docs.isEmpty) return 0;
      final memberId = memSnap.docs.first.id;

      // Filtrer les délégations proposées pour aujourd'hui
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final snap = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('delegations')
          .where('status', isEqualTo: 'proposed')
          .where('amDelegateId', isEqualTo: memberId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();
      return snap.size;
    } catch (e) {
      print('Erreur compteur délégations: $e');
      return 0;
    }
  }

  Future<void> _refreshDelegationsCount() async {
    final int count = await _fetchPendingDelegationsCountToday();
    if (!mounted) return;
    setState(() {
      _pendingDelegationsCount = count;
    });
  }

  bool get _shouldDisplayRssSection =>
      _showDashboardNews &&
      _rssFeedUrl != null &&
      _rssFeedUrl!.trim().isNotEmpty;

  String? _resolveRssFeedUrl(Map<String, dynamic> structureData) {
    const candidateKeys = ['dashboardRssUrl', 'rssFeedUrl', 'rssUrl'];
    for (final key in candidateKeys) {
      final value = structureData[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return _defaultRssFeedUrl;
  }

  DateTime? _parseRssDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return parsed.toLocal();
    }

    const patterns = [
      "EEE, dd MMM yyyy HH:mm:ss Z",
      "EEE, dd MMM yyyy HH:mm:ss zzz",
      "yyyy-MM-dd'T'HH:mm:ss'Z'",
      "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    ];

    for (final pattern in patterns) {
      try {
        final format = DateFormat(pattern, 'en_US');
        return format.parseUtc(trimmed).toLocal();
      } catch (_) {}
    }

    return null;
  }

  _RssHeadline? _parseRssElement(xml.XmlElement element) {
    xml.XmlElement? titleElement = element.getElement('title');
    if (titleElement == null) {
      for (final child in element.children.whereType<xml.XmlElement>()) {
        if (child.name.local.toLowerCase() == 'title') {
          titleElement = child;
          break;
        }
      }
    }

    final String title = titleElement?.innerText.trim() ?? '';
    if (title.isEmpty) {
      return null;
    }

    String? link;
    final directLink = element.getElement('link');
    if (directLink != null) {
      link = (directLink.getAttribute('href') ?? directLink.innerText).trim();
    }

    if (link == null || link.isEmpty) {
      for (final candidate in element.findElements('link')) {
        final rel = candidate.getAttribute('rel');
        final candidateLink =
            (candidate.getAttribute('href') ?? candidate.innerText).trim();
        if (candidateLink.isEmpty) {
          continue;
        }
        if (rel == null || rel == 'alternate') {
          link = candidateLink;
          break;
        }
      }
    }

    if (link == null || link.isEmpty) {
      final enclosure = element.getElement('enclosure');
      if (enclosure != null) {
        link = (enclosure.getAttribute('url') ?? '').trim();
      }
    }

    if (link == null || link.isEmpty) {
      return null;
    }

    final rawDate = element.getElement('pubDate')?.innerText ??
        element.getElement('published')?.innerText ??
        element.getElement('updated')?.innerText;

    return _RssHeadline(
      title: title,
      link: link,
      published: _parseRssDate(rawDate),
    );
  }

  Future<void> _fetchRssFeed({bool force = false}) async {
    if (!_shouldDisplayRssSection) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRssFetch != null &&
        now.difference(_lastRssFetch!) < _rssRefreshCooldown) {
      return;
    }

    if (_isRssLoading) {
      return;
    }

    setState(() {
      _isRssLoading = true;
      if (force) {
        _rssError = null;
      }
    });

    try {
      final response =
          await http.get(Uri.parse(_rssFeedUrl!)).timeout(_rssRequestTimeout);

      if (response.statusCode != 200) {
        throw Exception('Statut HTTP ${response.statusCode}');
      }

      final document = xml.XmlDocument.parse(response.body);
      Iterable<xml.XmlElement> itemElements = document.findAllElements('item');
      if (itemElements.isEmpty) {
        itemElements = document.findAllElements('entry');
      }

      final parsedItems = itemElements
          .map(_parseRssElement)
          .whereType<_RssHeadline>()
          .take(_rssMaxItems)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _rssItems = parsedItems;
        _rssError = parsedItems.isEmpty ? 'Aucune actualité trouvée.' : null;
        _lastRssFetch = now;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rssError = "Impossible de charger le fil.";
        if (_rssItems.isEmpty) {
          _rssItems = const [];
        }
        _lastRssFetch = now;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isRssLoading = false;
      });
    }
  }

  String? _formatRssDate(DateTime? date) {
    if (date == null) {
      return null;
    }
    return DateFormat('dd MMM', 'fr_FR').format(date);
  }

  Future<void> _openRssItem(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      return;
    }

    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible d'ouvrir l'article"),
            backgroundColor: primaryRed,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'ouvrir l'article"),
          backgroundColor: primaryRed,
        ),
      );
    }
  }

  Widget _buildDelegationsBadgeFuture() {
    return FutureBuilder<int>(
      future: _fetchPendingDelegationsCountToday(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) return SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  // Ajout de la méthode pour gérer le fonctionnement de la MAM
  void _showMAMFunctioning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Température à relever", textAlign: TextAlign.center),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Frigo - TOUJOURS en premier
                ListTile(
                  leading: Icon(Icons.thermostat,
                      color: needFridgeTemperatureCheck
                          ? Colors.red
                          : primaryColor),
                  title: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Température réfrigérateur",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: needFridgeTemperatureCheck
                              ? Colors.red
                              : Colors.black87,
                        ),
                      ),
                      if (needFridgeTemperatureCheck)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "À relever aujourd'hui",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToFridgeTemperature();
                  },
                ),

                // Congélateur - Affiché seulement si pas encore configuré OU si la MAM en a un
                // hasFreezer == null = pas encore configuré (première fois)
                // hasFreezer == true = la MAM a un congélateur
                // hasFreezer == false = la MAM n'a PAS de congélateur (ne pas afficher)
                if (hasFreezer == null || hasFreezer == true)
                  ListTile(
                    leading: Icon(Icons.kitchen,
                        color: needFreezerTemperatureCheck
                            ? Colors.red
                            : primaryColor),
                    title: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Température congélateur",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: needFreezerTemperatureCheck
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                        if (needFreezerTemperatureCheck && hasFreezer == true)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "À relever aujourd'hui",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToFreezerTemperature();
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToFreezerTemperature() {
    context.go('/freezer-temperature');
  }

  // Méthode pour naviguer vers l'écran de température du frigo
  void _navigateToFridgeTemperature() {
    // Utiliser context.go pour naviguer avec GoRouter
    context.go('/fridge-temperature');
  }

  // ✅ VERSION AMÉLIORÉE de _showMemberManagement (fusion)
  void _showMemberManagement() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Gestion des membres", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AJOUTER UN MEMBRE avec logique intelligente
              ListTile(
                leading: Icon(
                  // Icône adaptée selon la situation
                  currentMemberCount >= maxMemberCount
                      ? (maxMemberCount >= 4 && maxMemberCount < 50
                          ? Icons.block
                          : Icons.upgrade)
                      : Icons.person_add,
                  color: currentMemberCount >= maxMemberCount &&
                          maxMemberCount >= 4 &&
                          maxMemberCount < 50
                      ? Colors.grey
                      : primaryColor, // BLEU au lieu de rouge
                ),
                title: Text(
                  _getAddMemberTitle(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: currentMemberCount >= maxMemberCount &&
                            maxMemberCount >= 4 &&
                            maxMemberCount < 50
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                onTap: currentMemberCount >= maxMemberCount &&
                        maxMemberCount >= 4 &&
                        maxMemberCount < 50
                    ? null // Désactiver seulement si on est déjà à 4 membres (limite absolue)
                    : () {
                        Navigator.pop(context);
                        _handleAddMember();
                      },
              ),

              // RETIRER UN MEMBRE (toujours disponible)
              ListTile(
                leading: Icon(Icons.person_remove, color: primaryColor), // BLEU
                title: Text(
                  "Retirer un membre",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToRemoveMember();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// ✅ NOUVELLES MÉTHODES AMÉLIORÉES (fusion)
  String _getAddMemberTitle() {
    if (isMAMStructure) {
      // Pour une MAM, minimum 2 membres
      if (currentMemberCount >= maxMemberCount) {
        if (maxMemberCount >= 50) {
          return "Limite atteinte (plan illimité)";
        } else if (maxMemberCount >= 4) {
          return "Limite atteinte (${maxMemberCount} membres max)";
        } else {
          return "Membres $currentMemberCount/$maxMemberCount - Passer à l'abonnement supérieur";
        }
      } else {
        // Si on a moins de membres que la limite, on peut ajouter
        return "Ajouter un membre (${currentMemberCount}/${maxMemberCount})";
      }
    } else {
      // Pour AssistanteMaternelle seule
      return "Cette fonction est réservée aux MAM";
    }
  }

  void _handleAddMember() {
    // ✅ TOUJOURS aller vers MAMMemberAddScreen
    // Cet écran gère intelligemment tous les cas : ajout normal, limite atteinte, upgrade
    _navigateToAddMember();
  }

  // Méthode _checkIfMAMStructure modifiée pour vérifier aussi la température du frigo
  Future<void> _checkIfMAMStructure() async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      print("Vérification MAM pour la structure: $structureId");

      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data() ?? {};
        print("Structure data: $data");

        // Vérifier le type de structure
        String structureType = data['structureType'] ?? 'AssistanteMaternelle';
        bool isMam = structureType == 'MAM';
        int? overrideMaxMembers;

        // 🛡️ SÉCURITÉ ANTI-WEBHOOK : On vérifie l'ID produit directement
        try {
           final subQuery = await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('structureId', isEqualTo: structureId)
              .limit(1)
              .get();
           
           if (subQuery.docs.isNotEmpty) {
               final subData = subQuery.docs.first.data();
               final String productId = (subData['productId'] ?? subData['planId'] ?? '').toString().toLowerCase();
               
               // Exactement les mêmes sets que HomeScreen
               const Set<String> mamSmallPriceIds = {
                'price_1sfkuilid2pa5i1c75uu1tch',
                'price_1sflcbppvdnoe6wk9jqndswp', 
              };
              const Set<String> mamLargePriceIds = {
                'price_1sfkwulid2pa5i1cmsdrrf0c',
                'price_1sflcjpgpvnoe6wkfd6blign',
                'price_1sflcjppvdnoe6wkfd6blign', // MAM 4+
              };
              
              if (mamLargePriceIds.contains(productId)) {
                  isMam = true;
                  overrideMaxMembers = 50;
                  print("🛡️ Dashboard: FORCE MAM 50 (ID reconnu: $productId)");
              } else if (mamSmallPriceIds.contains(productId)) {
                  isMam = true;
                   // CORRECTION: price_1sflcbppvdnoe6wk9jqndswp est le forfait 3 membres !
                   if (productId == 'price_1sflcbppvdnoe6wk9jqndswp') {
                      overrideMaxMembers = 3;
                   } else if (productId.contains('mam_2') || productId.contains('mam2')) {
                      overrideMaxMembers = 2;
                   } else {
                      overrideMaxMembers = 3;
                   }
                  print("🛡️ Dashboard: FORCE MAM $overrideMaxMembers (ID reconnu: $productId)");
              } else if (productId.contains('assistante_maternelle') || productId.contains('assmat')) {
                   // Si l'ID est Assmat, mais la DB dit MAM, on devrait pê forcer Assmat ?
                   // Mais ici le problème c'est l'inverse (DB dit Assmat alors que c'est MAM).
              }
           }
        } catch (e) {
            print("Erreur check ID dashboard: $e");
        }

        print("Type de structure trouvé (DB): $structureType, isMAM (Final): $isMam");

        if (isMam) {
          // ✅ CORRECTION : MAM minimum 2 membres
          int maxMembers = 2; // MINIMUM 2 pour MAM
          int currentMembers = 1;
          bool? structureHasFreezer;

          if (overrideMaxMembers != null) {
              maxMembers = overrideMaxMembers;
          } else if (data.containsKey('maxMemberCount')) {
            maxMembers = data['maxMemberCount'] ?? 2;
            // ✅ S'assurer que c'est au minimum 2 pour une MAM
            if (maxMembers < 2) {
              maxMembers = 2;
              // Mettre à jour en base pour corriger la valeur
              await FirebaseFirestore.instance
                  .collection('structures')
                  .doc(structureId)
                  .update({'maxMemberCount': 2});
            }
          } else if (data.containsKey('subscription') &&
              data['subscription'] != null) {
            maxMembers = data['subscription']['maxMembers'] ?? 2;
            // ✅ S'assurer que c'est au minimum 2 pour une MAM
            if (maxMembers < 2) maxMembers = 2;
          } else {
            maxMembers = 2; // ✅ MINIMUM 2 pour MAM
            // Mettre à jour en base
            await FirebaseFirestore.instance
                .collection('structures')
                .doc(structureId)
                .update({'maxMemberCount': 2});
          }

          final membersSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('members')
              .get();

          currentMembers = membersSnapshot.docs.length;
          // ✅ S'assurer qu'on a au minimum 1 membre même si la collection est vide
          if (currentMembers < 1) currentMembers = 1;

          if (data.containsKey('hasFreezer')) {
            structureHasFreezer = data['hasFreezer'] as bool;
          } else {
            structureHasFreezer = null;
          }

          print(
              "MAM détectée: $currentMembers/$maxMembers membres, congélateur: $structureHasFreezer");

          _checkFridgeTemperatureStatus(structureId);
          if (structureHasFreezer == true) {
            _checkFreezerTemperatureStatus(structureId);
          }

          setState(() {
            isMAMStructure = isMam;
            maxMemberCount = maxMembers;
            currentMemberCount = currentMembers;
            hasFreezer = structureHasFreezer;
          });
        } else {
          // Code existant pour Assistante Maternelle (pas de changement)
          print("AssistanteMaternelle détectée, vérification des équipements");
          // Toujours compter les membres réels, même ici : une structure peut
          // déjà fonctionner avec plusieurs membres réels sans que le champ
          // structureType ait jamais été correctement positionné en 'MAM'
          // (constaté en prod). Forcer currentMemberCount à 1 sans vérifier
          // masquait cet état réel — ex: le bouton "Passer en MAM" continuait
          // d'apparaître pour une structure ayant déjà 2 membres.
          final membersSnapshot = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('members')
              .get();
          final int realMemberCount = membersSnapshot.docs.length;

          setState(() {
            isMAMStructure = false;
            maxMemberCount = data['maxMemberCount'] is int
                ? data['maxMemberCount'] as int
                : 1;
            currentMemberCount = realMemberCount > 0 ? realMemberCount : 1;
          });
        }
      }
    } catch (e) {
      print("Erreur lors de la vérification si MAM: $e");
      setState(() {
        isMAMStructure = false;
      });
    }
  }

  void _showParentCoordonneeSelection() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Obtenir l'ID de structure avant de naviguer
                    String structId = await _getStructureId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParentCoordonneesScreen(
                          childId: child['id'],
                          childName: child['firstName'],
                          structureId: structId,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkAssmatFridgeTemperatureStatus(String structureId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        needAssmatFridgeTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température réfrigérateur Assistante Maternelle: ${needAssmatFridgeTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du réfrigérateur AssistanteMaternelle: $e");
    }
  }

// Méthode pour ouvrir les liens légaux
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible d'ouvrir le lien"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de l'ouverture du lien: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'ouverture du lien"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

// Widget moderne pour les liens légaux (Design 2025)
  Widget _buildLegalButtons({required bool isTablet}) {
    final double fontSize = isTablet ? 14 : 16;
    final double buttonHeight = isTablet ? 45 : 52;
    final double spacing = isTablet ? 12 : 16;

    return Column(
      children: [
        // Bouton Politique de Confidentialité
        Container(
          width: double.infinity,
          height: buttonHeight,
          margin: EdgeInsets.only(bottom: spacing),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _launchURL(
                  'https://www.poppin-s.fr/politique-de-confidentialite/'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      brightCyan,
                      brightCyan.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: brightCyan.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.white,
                      size: isTablet ? 18 : 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Politique de Confidentialité",
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bouton Conditions d'Utilisation
        Container(
          width: double.infinity,
          height: buttonHeight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  _launchURL('https://www.poppin-s.fr/condition-dutilisation/'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryBlue,
                      primaryBlue.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: isTablet ? 18 : 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Conditions d'Utilisation",
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkAssmatFreezerTemperatureStatus(String structureId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('freezerTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        needAssmatFreezerTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température congélateur Assistante Maternelle: ${needAssmatFreezerTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du congélateur AssistanteMaternelle: $e");
    }
  }

  // NOUVELLES MÉTHODES pour sauvegarder les préférences Assistante Maternelle
  Future<void> _saveAssmatFridgePreference(bool hasFridgeChoice) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({'hasAssmatFridge': hasFridgeChoice});

      setState(() {
        hasAssmatFridge = hasFridgeChoice;
        showAssmatFridgeChoice = false;
      });

      if (hasFridgeChoice) {
        await _checkAssmatFridgeTemperatureStatus(structureId);
      }
    } catch (e) {
      print(
          "Erreur lors de la sauvegarde de la préférence réfrigérateur AssistanteMaternelle: $e");
    }
  }

  Future<void> _saveAssmatFreezerPreference(bool hasFreezerChoice) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({'hasAssmatFreezer': hasFreezerChoice});

      setState(() {
        hasAssmatFreezer = hasFreezerChoice;
        showAssmatFreezerChoice = false;
      });

      if (hasFreezerChoice) {
        await _checkAssmatFreezerTemperatureStatus(structureId);
      }
    } catch (e) {
      print(
          "Erreur lors de la sauvegarde de la préférence congélateur AssistanteMaternelle: $e");
    }
  }

  // NOUVEAU WIDGET pour le choix des équipements Assistante Maternelle
  Widget _buildAssmatEquipmentChoiceDialog() {
    if (!showAssmatFridgeChoice && !showAssmatFreezerChoice) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.kitchen,
                  size: 64,
                  color: primaryColor,
                ),
                SizedBox(height: 20),
                Text(
                  "Configuration des équipements",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),

                // Choix du frigo si nécessaire
                if (showAssmatFridgeChoice) ...[
                  Text(
                    "Avez-vous un réfrigérateur dans votre structure ?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFridgePreference(false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                "NON",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFridgePreference(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "OUI",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Choix du congélateur si nécessaire
                if (showAssmatFreezerChoice) ...[
                  if (showAssmatFridgeChoice) SizedBox(height: 32),
                  Text(
                    "Avez-vous un congélateur dans votre structure ?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFreezerPreference(false),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                "NON",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _saveAssmatFreezerPreference(true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "OUI",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOUVELLE MÉTHODE pour le fonctionnement quotidien Assistante Maternelle
  void _showAssmatDailyFunctioning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Fonctionnement quotidien", textAlign: TextAlign.center),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Section équipements avec indicateur visuel moderne
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        lightBlue.withOpacity(0.3),
                        lightBlue.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: primaryColor.withOpacity(0.3), width: 2),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.kitchen,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      "Gérer les équipements",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        "Ajouter/retirer réfrigérateur et congélateur",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.settings,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showEquipmentManagement();
                    },
                  ),
                ),

                // Frigo - Affiché seulement si configuré ET la structure en a un
                if (hasAssmatFridge == true)
                  ListTile(
                    leading: Icon(Icons.thermostat,
                        color: needAssmatFridgeTemperatureCheck
                            ? Colors.red
                            : primaryColor),
                    title: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Température réfrigérateur",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: needAssmatFridgeTemperatureCheck
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                        if (needAssmatFridgeTemperatureCheck)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "À relever aujourd'hui",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToFridgeTemperature();
                    },
                  ),

                // Congélateur - Affiché seulement si configuré ET la structure en a un
                if (hasAssmatFreezer == true)
                  ListTile(
                    leading: Icon(Icons.kitchen,
                        color: needAssmatFreezerTemperatureCheck
                            ? Colors.red
                            : primaryColor),
                    title: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Température congélateur",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: needAssmatFreezerTemperatureCheck
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                        if (needAssmatFreezerTemperatureCheck)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "À relever aujourd'hui",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToFreezerTemperature();
                    },
                  ),

                // Planning enfant - TOUJOURS affiché pour Assistante Maternelle
                ListTile(
                  leading: Icon(Icons.calendar_month, color: primaryColor),
                  title: Text(
                    "Planning enfant",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlanningScreen(),
                      ),
                    );
                  },
                ),

                // Délégations MAM - gestion des délégations à la journée
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: primaryColor),
                  title: Text(
                    "Délégations (MAM)",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: _buildDelegationsBadgeFuture(),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DelegationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ====== Quick actions (Grille + feuilles) ======
  Widget _sheetAction({
    required String label,
    required VoidCallback onTap,
    Color? bulletColor,
    String? badgeText,
    Widget? trailing,
    bool enabled = true,
    String? disabledMessage,
  }) {
    final bool showBadge = badgeText != null && badgeText!.isNotEmpty;
    Widget? trailingWidget = trailing ??
        (showBadge
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null);

    if (!enabled && trailingWidget == null) {
      trailingWidget = const Icon(Icons.lock_outline, color: Colors.grey);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      horizontalTitleGap: 8,
      minLeadingWidth: 0,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: enabled
              ? (bulletColor ?? primaryColor).withOpacity(0.85)
              : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: enabled ? Colors.black87 : Colors.grey,
        ),
      ),
      trailing: trailingWidget,
      onTap: () {
        if (!enabled) {
          if (disabledMessage != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(disabledMessage)),
            );
          }
          return;
        }
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showCategorySheet({
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...children,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDocuments() async {
    final structureId = await _getStructureId();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentsScreen(structureId: structureId),
      ),
    );
  }

  void _openEngagementReciproque() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EngagementListScreen(userId: userId),
      ),
    );
  }

  void _openContratCdi() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContratCdiListScreen(userId: userId),
      ),
    );
  }

  void _openContratCdd() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContratCddListScreen(userId: userId),
      ),
    );
  }

  void _openAvenant() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvenantListScreen(userId: userId),
      ),
    );
  }

  void _openCalculs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalculsHomeScreen()),
    );
  }

  void _openContratsMenu() {
    _showCategorySheet(
      title: 'Documents contractuels',
      color: _tileBlue,
      children: [
        _sheetAction(
          label: 'Engagement Réciproque',
          onTap: _openEngagementReciproque,
          bulletColor: _tileBlue,
        ),
        _sheetAction(
          label: 'Contrat CDI',
          onTap: _openContratCdi,
          bulletColor: _tileBlue,
        ),
        _sheetAction(
          label: 'Contrat CDD',
          onTap: _openContratCdd,
          bulletColor: _tileBlue,
        ),
        _sheetAction(
          label: 'Avenant au contrat',
          onTap: _openAvenant,
          bulletColor: _tileBlue,
        ),
      ],
    );
  }

  void _openMamAdministration() {
    final List<Widget> actions = [
      _sheetAction(
        label: 'Modifier coordonnées',
        onTap: () => context.go('/structure-management'),
        bulletColor: _tileBlue,
      ),
    ];

    const String lockedMessage =
        'Fonctionnalité disponible avec l\'abonnement professionnel.';

    if (isMAMStructure) {
      actions.addAll([
        _sheetAction(
          label: 'Gérer membres (Ajouter / Retirer)',
          onTap: _showMemberManagement,
          bulletColor: _tileBlue,
        ),
        _sheetAction(
          label: 'Gestion des enfants',
          onTap: _showChildDisplaySettings,
          bulletColor: _tileBlue,
        ),
        _sheetAction(
          label: 'Actualités',
          onTap: _showDashboardNewsSettings,
          bulletColor: _tileBlue,
        ),
      ]);
    } else if (isParentEmployeurStructure) {
      actions.addAll([
        _sheetAction(
          label: 'Gérer membres (Ajouter / Retirer)',
          onTap: () {},
          bulletColor: _tileBlue,
          enabled: false,
          disabledMessage: lockedMessage,
        ),
        _sheetAction(
          label: 'Gestion des enfants',
          onTap: () {},
          bulletColor: _tileBlue,
          enabled: false,
          disabledMessage: lockedMessage,
        ),
        _sheetAction(
          label: 'Actualités',
          onTap: () {},
          bulletColor: _tileBlue,
          enabled: false,
          disabledMessage: lockedMessage,
        ),
      ]);
    } else if (currentMemberCount <= 1 && maxMemberCount <= 1) {
      // Assistante Maternelle solo (ni MAM, ni parent-employeur) : aucune
      // entrée de menu ne menait jusqu'ici vers la conversion en MAM — le
      // seul écran capable de le faire (/subscription-upgrade) était de plus
      // inaccessible tant qu'on n'était pas déjà une MAM. Sans ce bouton,
      // aucune utilisatrice solo ne pouvait jamais devenir une MAM depuis
      // l'app (signalé par une utilisatrice bloquée depuis 3 semaines).
      //
      // Condition sur currentMemberCount/maxMemberCount, PAS uniquement sur
      // isMAMStructure (structureType == 'MAM') : une structure peut déjà
      // fonctionner avec plusieurs membres réels sans que ce champ ait
      // jamais été correctement positionné (cas constaté en prod — une
      // structure à 2 membres réels restée en structureType
      // 'AssistanteMaternelle'), auquel cas proposer "Passer en MAM" à
      // nouveau n'aurait aucun sens.
      actions.add(
        _sheetAction(
          label: 'Passer en MAM',
          onTap: () => context.go('/subscription-upgrade'),
          bulletColor: _tileBlue,
        ),
      );
    }

    actions.addAll([
      _sheetAction(
        label: 'Mes Documents',
        onTap: _openDocuments,
        bulletColor: _tileBlue,
      ),
      _sheetAction(
        label: 'Documents contractuels',
        onTap: _openContratsMenu,
        bulletColor: _tileBlue,
      ),
      _sheetAction(
        label: 'Calculs',
        onTap: _openCalculs,
        bulletColor: _tileBlue,
      ),
      _sheetAction(
        label: 'Politique de confidentialité',
        onTap: () =>
            _launchURL('https://www.poppin-s.fr/politique-de-confidentialite/'),
        bulletColor: _tileBlue,
      ),
      _sheetAction(
        label: "Conditions d'utilisation",
        onTap: () =>
            _launchURL('https://www.poppin-s.fr/condition-dutilisation/'),
        bulletColor: _tileBlue,
      ),
    ]);

    _showCategorySheet(
      title: 'Administration',
      color: _tileBlue,
      children: actions,
    );
  }

  void _openDailyOps() {
    _refreshDelegationsCount();
    final String temperatureBadge = _getTemperatureNotificationCount();
    if (isMAMStructure) {
      _showCategorySheet(
        title: 'Fonctionnement quotidien',
        color: _tileRed,
        children: [
          _sheetAction(
            label: 'Planning entretien',
            onTap: () => context.go('/cleaning-schedule'),
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Planning enfants / horaires',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlanningScreen()),
            ),
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Délégations',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const DelegationsScreen()),
            ),
            bulletColor: _tileRed,
            trailing: _buildDelegationsBadgeFuture(),
          ),
          _sheetAction(
            label: 'Messagerie interne MAM',
            onTap: _openMamGroupChat,
            bulletColor: _tileRed,
          ),
          _sheetAction(
            label: 'Température réfrigérateur / congélateur',
            onTap: _showMAMFunctioning,
            bulletColor: _tileRed,
            badgeText: temperatureBadge,
          ),
          _sheetAction(
            label: 'Gestion équipements / matériel',
            onTap: _showEquipmentManagement,
            bulletColor: _tileRed,
          ),
        ],
      );
    } else {
      final List<Widget> actions = [
        _sheetAction(
          label: 'Planning enfants / horaires',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PlanningScreen()),
          ),
          bulletColor: _tileRed,
        ),
        _sheetAction(
          label: 'Température réfrigérateur / congélateur',
          onTap: _showAssmatDailyFunctioning,
          bulletColor: _tileRed,
          badgeText: temperatureBadge,
        ),
        _sheetAction(
          label: 'Gestion équipements / matériel',
          onTap: _showEquipmentManagement,
          bulletColor: _tileRed,
        ),
      ];

      if (isParentEmployeurStructure) {
        const String lockedMessage =
            'Fonctionnalité disponible avec l\'abonnement professionnel.';
        actions.addAll([
          _sheetAction(
            label: 'Planning entretien',
            onTap: () {},
            bulletColor: _tileRed,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Délégations',
            onTap: () {},
            bulletColor: _tileRed,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Messagerie interne',
            onTap: () {},
            bulletColor: _tileRed,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
        ]);
      }

      _showCategorySheet(
        title: 'Fonctionnement quotidien',
        color: _tileRed,
        children: actions,
      );
    }
  }

  Future<void> _openMamGroupChat() async {
    final structureId = await _getStructureId();
    if (!mounted) return;
    if (structureId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MamGroupChatScreen(structureId: structureId),
      ),
    );
  }

  void _openChildrenParents() {
    if (isParentEmployeurStructure) {
      const String lockedMessage =
          'Gestion disponible avec l\'abonnement professionnel.';
      _showCategorySheet(
        title: 'Enfants et Parents',
        color: _tileCyan,
        children: [
          _sheetAction(
            label: 'Ajouter un enfant',
            onTap: () {},
            bulletColor: _tileCyan,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Profils enfants (santé, besoins, alimentation…)',
            onTap: () {},
            bulletColor: _tileCyan,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Modifier horaires enfants',
            onTap: () {},
            bulletColor: _tileCyan,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Coordonnées des parents',
            onTap: () {},
            bulletColor: _tileCyan,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Modifier photo profil enfant',
            onTap: () {},
            bulletColor: _tileCyan,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
          _sheetAction(
            label: 'Retirer un enfant',
            onTap: () {},
            bulletColor: _tileCyan,
            enabled: false,
            disabledMessage: lockedMessage,
          ),
        ],
      );
      return;
    }

    _showCategorySheet(
      title: 'Enfants et Parents',
      color: _tileCyan,
      children: [
        _sheetAction(
          label: 'Ajouter un enfant',
          onTap: () => context.go('/child-info'),
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Profils enfants (santé, besoins, alimentation…)',
          onTap: _showChildProfilesSelection,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Modifier horaires enfants',
          onTap: _showScheduleModification,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Coordonnées des parents',
          onTap: _showParentCoordonneeSelection,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Modifier photo profil enfant',
          onTap: _showPhotoManagement,
          bulletColor: _tileCyan,
        ),
        _sheetAction(
          label: 'Retirer un enfant',
          onTap: _showChildRemoval,
          bulletColor: _tileCyan,
        ),
      ],
    );
  }

  void _openReportsHistory() {
    _showCategorySheet(
      title: 'Mémo et Historique',
      color: _tileYellow,
      children: [
        _sheetAction(
          label: 'Mémo mensuel',
          onTap: () => context.go('/monthly-report-selection'),
          bulletColor: _tileYellow,
        ),
        _sheetAction(
          label: 'Historique (présences, repas, sieste…)',
          onTap: _showHistorySelection,
          bulletColor: _tileYellow,
        ),
      ],
    );
  }

  Widget _quickTile({
    List<String>? lines,
    required Color color,
    required VoidCallback onTap,
    required double size,
    String? badgeCount,
    String? assetPath,
  }) {
    final bool showImage = assetPath != null && assetPath.isNotEmpty;
    final BorderRadius borderRadius = BorderRadius.circular(28);
    final List<Widget> titleLines = lines != null
        ? List<Widget>.generate(
            lines.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                lines[i],
                textAlign: TextAlign.center,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: 0.0,
                ),
              ),
            ),
          )
        : const [];

    final Widget badge = (badgeCount == null || badgeCount.isEmpty)
        ? const SizedBox.shrink()
        : Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                badgeCount!,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );

    final List<BoxShadow> shadows = [
      BoxShadow(
        color: color.withOpacity(0.15),
        blurRadius: 25,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 15,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 6,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ];

    if (showImage) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: SizedBox(
              height: size,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      assetPath!,
                      fit: BoxFit.cover,
                    ),
                    badge,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: SizedBox(
              height: size,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.transparent,
                            Colors.black.withOpacity(0.05),
                          ],
                          stops: const [0.0, 0.3, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: titleLines,
                        ),
                      ),
                    ),
                    badge,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _getTemperatureAlertCount() {
    int notificationCount = 0;

    if (isMAMStructure) {
      // Pour MAM
      if (needFridgeTemperatureCheck) notificationCount++;
      if (needFreezerTemperatureCheck && hasFreezer == true)
        notificationCount++;
    } else {
      // Pour Assistante Maternelle
      if (needAssmatFridgeTemperatureCheck && hasAssmatFridge == true)
        notificationCount++;
      if (needAssmatFreezerTemperatureCheck && hasAssmatFreezer == true)
        notificationCount++;
    }
    return notificationCount;
  }

  String _formatBadgeCount(int count) => count > 0 ? count.toString() : '';

  String _getTemperatureNotificationCount() {
    return _formatBadgeCount(_getTemperatureAlertCount());
  }

  String _getDailyOpsTileBadge() {
    final int total = _getTemperatureAlertCount() + _pendingDelegationsCount;
    return _formatBadgeCount(total);
  }

  Widget _buildRssSection() {
    if (!_shouldDisplayRssSection) {
      return const SizedBox.shrink();
    }

    final bool showLoading = _isRssLoading && _rssItems.isEmpty;
    final bool hasItems = _rssItems.isNotEmpty;
    final String? error = _rssError;

    // Détecter si on est sur mobile ou tablette
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Réduit de 20 à 16
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), // Ombre plus légère
            offset: const Offset(0, 2), // Réduit de 3 à 2
            blurRadius: 8, // Réduit de 12 à 8
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16), // Padding réduit sur mobile
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 14 : 18, // Plus petit sur mobile
                backgroundColor: primaryColor.withOpacity(0.12),
                child: Icon(
                  Icons.rss_feed,
                  color: primaryColor,
                  size: isMobile ? 16 : 20, // Icône plus petite sur mobile
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Text(
                  'Fil d\'actualité',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 18, // Texte plus petit sur mobile
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    _isRssLoading ? null : () => _fetchRssFeed(force: true),
                tooltip: 'Actualiser le fil',
                padding: EdgeInsets.all(isMobile ? 4 : 8),
                constraints: BoxConstraints(
                  minWidth: isMobile ? 32 : 40,
                  minHeight: isMobile ? 32 : 40,
                ),
                icon: _isRssLoading
                    ? SizedBox(
                        width: isMobile ? 16 : 20,
                        height: isMobile ? 16 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Icon(Icons.refresh, size: isMobile ? 18 : 20),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: isMobile ? 6 : 12),
              child: Text(
                error,
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (showLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 24),
              child: Center(
                child: SizedBox(
                  width: isMobile ? 20 : 24,
                  height: isMobile ? 20 : 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
              ),
            )
          else if (hasItems) ...[
            SizedBox(height: isMobile ? 6 : 12),
            for (int i = 0; i < _rssItems.length; i++) ...[
              if (i > 0) const Divider(height: 8),
              _buildRssItemRow(_rssItems[i], isMobile: isMobile),
            ],
          ] else if (error == null)
            Padding(
              padding: EdgeInsets.only(top: isMobile ? 6 : 12),
              child: Text(
                'Aucune actualité disponible pour le moment.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRssItemRow(_RssHeadline item, {bool isMobile = false}) {
    final String? dateLabel = _formatRssDate(item.published);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openRssItem(item.link),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.article_outlined,
              color: primaryColor,
              size: isMobile ? 16 : 18, // Icône plus petite sur mobile
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize:
                          isMobile ? 13 : 14, // Texte plus petit sur mobile
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateLabel != null)
                    Padding(
                      padding: EdgeInsets.only(top: isMobile ? 2 : 4),
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize:
                              isMobile ? 11 : 12, // Date plus petite sur mobile
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 6 : 12),
            Icon(
              Icons.open_in_new,
              color: Colors.grey.shade500,
              size: isMobile ? 14 : 18, // Icône plus petite sur mobile
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tileWidth =
            (constraints.maxWidth - 16) / 2; // Espacement optimisé
        final double tileSize = tileWidth;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12), // Padding ajusté
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16, // Espacement vertical augmenté
            crossAxisSpacing: 16, // Espacement horizontal augmenté
            childAspectRatio: 1,
          ),
          children: [
            _quickTile(
              assetPath: 'assets/images/Icone_administration.png',
              color: _tileBlue,
              onTap: _openMamAdministration,
              size: tileSize,
            ),
            _quickTile(
              assetPath: 'assets/images/Icone_fonctionnement.png',
              color: _tileRed,
              onTap: _openDailyOps,
              size: tileSize,
              badgeCount: _getDailyOpsTileBadge(),
            ),
            _quickTile(
              assetPath: 'assets/images/Icone_enfant.png',
              color: _tileCyan,
              onTap: _openChildrenParents,
              size: tileSize,
            ),
            _quickTile(
              assetPath: 'assets/images/Icone_memo.png',
              color: _tileYellow,
              onTap: _openReportsHistory,
              size: tileSize,
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkFreezerTemperatureStatus(String structureId) async {
    try {
      // Obtenir la date d'aujourd'hui à minuit pour la comparaison
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Rechercher s'il y a un relevé de température du congélateur pour aujourd'hui
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('freezerTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        // S'il n'y a pas de relevé aujourd'hui, indiquer qu'un relevé est nécessaire
        needFreezerTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température congélateur: ${needFreezerTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du congélateur: $e");
    }
  }

  // Nouvelle méthode pour vérifier si la température du frigo a été relevée aujourd'hui
  Future<void> _checkFridgeTemperatureStatus(String structureId) async {
    try {
      // Obtenir la date d'aujourd'hui à minuit pour la comparaison
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Rechercher s'il y a un relevé de température pour aujourd'hui
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('fridgeTemperatures')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      setState(() {
        // S'il n'y a pas de relevé aujourd'hui, indiquer qu'un relevé est nécessaire
        needFridgeTemperatureCheck = snapshot.docs.isEmpty;
      });

      print(
          "Vérification température réfrigérateur: ${needFridgeTemperatureCheck ? 'À relever aujourd\'hui' : 'Déjà relevée'}");
    } catch (e) {
      print(
          "Erreur lors de la vérification du statut de température du réfrigérateur: $e");
    }
  }

  void _navigateToAddMember() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MAMMemberAddScreen(),
      ),
    ).then((_) {
      // Rafraîchir les données après ajout
      _checkIfMAMStructure();
    });
  }

  // Méthode pour naviguer vers l'écran de suppression de membre
  void _navigateToRemoveMember() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MAMMemberRemovalScreen(),
      ),
    ).then((_) {
      // Rafraîchir les données après suppression
      _checkIfMAMStructure();
    });
  }

  // Modifiez la méthode _showChildProfilesSelection pour la rendre async
  void _showChildProfilesSelection() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    final bool canEdit = _canCurrentUserEditChild(child);
                    if (!canEdit) {
                      final String childName =
                          child['firstName']?.toString() ?? '';
                      _showChildReadOnlyMessage(childName);
                    }

                    final String childId = (child['id'] ?? '').toString();
                    if (childId.isEmpty) {
                      return;
                    }

                    final String structId = await _getStructureId();
                    if (!mounted || structId.isEmpty) {
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChildProfileDetailsScreen(
                          childId: childId,
                          structureId: structId,
                          allowEditing: canEdit,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

// Ajouter cette méthode pour naviguer vers l'historique
  void _showHistorySelection() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Obtenir l'ID de structure avant de naviguer
                    String structId = await _getStructureId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryDateSelectionScreen(
                          childId: child['id'],
                          childName: child['firstName'],
                          structureId: structId,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPhotoManagement() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // Naviguer directement vers PhotoManagementScreen avec l'ID de l'enfant
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoManagementScreen(
                          childId: child['id'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChildRemoval() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // CORRECTION: Récupérer l'ID de structure avant de naviguer
                    String structId = await _getStructureId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChildRemovalScreen(
                          childId: child['id'],
                          structureId:
                              structId, // ← AJOUT DU PARAMÈTRE MANQUANT
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkMonthlyTableEnabled() async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      // Récupérer l'email de l'utilisateur actuel
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Récupérer le type de structure (MAM ou AssistanteMaternelle)
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final Map<String, dynamic> structureData =
          structureDoc.data() ?? <String, dynamic>{};
      final String structureType =
          (structureData['structureType'] ?? "AssistanteMaternelle").toString();

      String? structureOwnerEmail;
      final ownerCandidates = [
        structureData['ownerEmail'],
        structureData['ownerMail'],
        structureData['email'],
      ];
      for (final candidate in ownerCandidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          structureOwnerEmail = candidate.toLowerCase().trim();
          break;
        }
      }

      bool memberIsAdmin = false;
      Set<String> delegatedChildIds = {};
      final bool isMamStructure = structureType.toUpperCase() == "MAM";
      if (isMamStructure) {
        final membersSnap = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('members')
            .where('email', isEqualTo: currentUserEmail)
            .limit(1)
            .get();

        if (membersSnap.docs.isNotEmpty) {
          final Map<String, dynamic> memberData =
              membersSnap.docs.first.data() as Map<String, dynamic>;
          final String roleValue =
              (memberData['role'] ?? '').toString().toLowerCase().trim();
          if (roleValue == 'admin' || roleValue == 'owner') {
            memberIsAdmin = true;
          }

          final String memberId = membersSnap.docs.first.id;
          final DateTime now = DateTime.now();
          final DateTime start = DateTime(now.year, now.month, now.day);
          final DateTime end = start.add(const Duration(days: 1));
          final delegationsSnap = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('delegations')
              .where('status', isEqualTo: 'accepted')
              .where('amDelegateId', isEqualTo: memberId)
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where('date', isLessThan: Timestamp.fromDate(end))
              .get();

          delegatedChildIds = delegationsSnap.docs
              .map((doc) => (doc.data()['childId'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();
        }
      }

      final dynamic showAllField = structureData['showAllChildrenOnHome'];
      bool allowAllChildren = true;
      if (showAllField is bool) {
        allowAllChildren = showAllField;
      } else {
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .set({'showAllChildrenOnHome': true}, SetOptions(merge: true));
      }

      // Récupérer tous les enfants de la structure
      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Aucun enfant trouvé
      if (childrenSnapshot.docs.isEmpty) {
        setState(() {
          showMonthlyTableReports = false;
        });
        return;
      }

      bool hasMonthlyTableEnabled = false;

      // Pour chaque enfant dans la structure
      for (var doc in childrenSnapshot.docs) {
        final data = doc.data();

        // Vérifier si l'enfant utilise le mémo mensuel
        bool usesMonthlyTable = data.containsKey('financialInfo') &&
            data['financialInfo'] != null &&
            data['financialInfo']['useMonthlyTable'] == true;

        // Si c'est une MAM, vérifier en plus si l'enfant est assigné au membre connecté
        if (structureType == "MAM") {
          String assignedEmail =
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '';

          // L'enfant doit à la fois utiliser le mémo mensuel ET être assigné au membre connecté
          if (usesMonthlyTable && assignedEmail == currentUserEmail) {
            hasMonthlyTableEnabled = true;
            print(
                "✅ Enfant ${data['firstName']} assigné au membre actuel utilise le mémo mensuel");
            break; // Un seul enfant suffit pour activer la section Rapports
          }
        } else {
          // Pour une assistante maternelle, il suffit qu'un enfant utilise le mémo mensuel
          if (usesMonthlyTable) {
            hasMonthlyTableEnabled = true;
            print("✅ Enfant ${data['firstName']} utilise le mémo mensuel");
            break; // Un seul enfant suffit pour activer la section Rapports
          }
        }
      }

      setState(() {
        showMonthlyTableReports = hasMonthlyTableEnabled;
      });

      print("📊 Affichage de la section Rapports: $hasMonthlyTableEnabled");
    } catch (e) {
      print("❌ Erreur lors de la vérification du mémo mensuel: $e");
      // En cas d'erreur, par précaution, ne pas afficher la section
      setState(() {
        showMonthlyTableReports = false;
      });
    }
  }

  Future<String> _getStructureId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    // Vérifier si l'utilisateur est un membre MAM
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.email?.toLowerCase() ?? '')
        .get();

    // Si c'est un membre MAM, obtenir l'ID de la structure associée
    if (userDoc.exists &&
        userDoc.data() != null &&
        userDoc.data()!.containsKey('structureId')) {
      return userDoc.data()!['structureId'];
    }

    // Par défaut, utiliser l'ID de l'utilisateur
    return user.uid;
  }

  Future<List<Map<String, dynamic>>> _loadChildren() async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return [];

      // Récupérer l'email de l'utilisateur actuel
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final String currentUserEmail = user.email?.toLowerCase() ?? '';

      // Récupérer le type de structure (MAM ou AssistanteMaternelle)
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final Map<String, dynamic> structureData =
          structureDoc.data() ?? <String, dynamic>{};
      final String structureType =
          (structureData['structureType'] ?? "AssistanteMaternelle").toString();

      final bool isMam = structureType.toUpperCase() == "MAM";

      String? structureOwnerEmail;
      final ownerCandidates = [
        structureData['ownerEmail'],
        structureData['ownerMail'],
        structureData['email'],
      ];
      for (final candidate in ownerCandidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          structureOwnerEmail = candidate.toLowerCase().trim();
          break;
        }
      }

      bool memberIsAdmin = false;
      Set<String> delegatedChildIds = {};
      if (isMam) {
        final membersSnap = await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .collection('members')
            .where('email', isEqualTo: currentUserEmail)
            .limit(1)
            .get();

        if (membersSnap.docs.isNotEmpty) {
          final Map<String, dynamic> memberData =
              membersSnap.docs.first.data() as Map<String, dynamic>;
          final String roleValue =
              (memberData['role'] ?? '').toString().toLowerCase().trim();
          if (roleValue == 'admin' || roleValue == 'owner') {
            memberIsAdmin = true;
          }

          final String memberId = membersSnap.docs.first.id;
          final DateTime now = DateTime.now();
          final DateTime start = DateTime(now.year, now.month, now.day);
          final DateTime end = start.add(const Duration(days: 1));
          final delegationsSnap = await FirebaseFirestore.instance
              .collection('structures')
              .doc(structureId)
              .collection('delegations')
              .where('status', isEqualTo: 'accepted')
              .where('amDelegateId', isEqualTo: memberId)
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where('date', isLessThan: Timestamp.fromDate(end))
              .get();

          delegatedChildIds = delegationsSnap.docs
              .map((doc) => (doc.data()['childId'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();
        }
      }

      final dynamic showAllField = structureData['showAllChildrenOnHome'];
      bool allowAllChildren = true;
      if (showAllField is bool) {
        allowAllChildren = showAllField;
      } else {
        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .set({'showAllChildrenOnHome': true}, SetOptions(merge: true));
      }

      // Récupérer tous les enfants de la structure
      final snapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      // Liste complète de tous les enfants
      List<Map<String, dynamic>> allChildren = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'firstName': data['firstName'] ?? 'Sans nom',
          'photoUrl': data['photoUrl'],
          'schedule': data['schedule'],
          'assignedMemberEmail':
              data['assignedMemberEmail']?.toString().toLowerCase() ?? '',
        };
      }).toList();

      // Appliquer le filtrage selon le type de structure
      List<Map<String, dynamic>> filteredChildren = [];

      if (isMam) {
        if (allowAllChildren) {
          filteredChildren = List<Map<String, dynamic>>.from(allChildren);
          print(
              "👨‍👧‍👦 Dashboard: Membre MAM - affichage de tous les enfants de la structure");
        } else {
          filteredChildren = allChildren.where((child) {
            return child['assignedMemberEmail'] == currentUserEmail;
          }).toList();

          print(
              "👨‍👧‍👦 Dashboard: Membre MAM - affichage de ${filteredChildren.length} enfant(s) assigné(s)");
        }
      } else {
        // Pour une assistante maternelle individuelle: tous les enfants sont affichés
        filteredChildren = allChildren;
        print(
            "👩‍👧‍👦 Dashboard: Assistante Maternelle - affichage de tous les enfants");
      }

      if (mounted) {
        setState(() {
          _currentUserEmail = currentUserEmail;
          _structureOwnerEmail = structureOwnerEmail;
          _currentMemberIsAdmin = memberIsAdmin;
          _allowAllChildren = allowAllChildren;
          _delegatedChildIds = delegatedChildIds;
          isMAMStructure = isMam;
        });
      }

      return filteredChildren;
    } catch (e) {
      print("Erreur lors du chargement des enfants: $e");
      return [];
    }
  }

  bool _canCurrentUserEditChild(Map<String, dynamic> child) {
    if (!isMAMStructure) {
      return true;
    }

    if (_allowAllChildren) {
      return true;
    }

    final String assignedEmail =
        child['assignedMemberEmail']?.toString().toLowerCase() ?? '';
    if (assignedEmail.isEmpty || assignedEmail == _currentUserEmail) {
      return true;
    }

    if (_structureOwnerEmail != null &&
        _structureOwnerEmail == _currentUserEmail) {
      return true;
    }

    if (_currentMemberIsAdmin) {
      return true;
    }

    final String childId = (child['id'] ?? '').toString();
    if (childId.isNotEmpty && _delegatedChildIds.contains(childId)) {
      return true;
    }

    return false;
  }

  void _showChildReadOnlyMessage(String childName) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Accès en lecture seule pour ${childName.isNotEmpty ? childName : 'cet enfant'}.",
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
        });
        context.go('/login');
        return;
      }

      _currentUserEmail = user.email?.toLowerCase() ?? '';

      // D'abord, vérifier si l'utilisateur est un membre MAM
      final userEmail = user.email?.toLowerCase() ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      // Si c'est un membre MAM, obtenir l'ID de la structure associée
      String structureId =
          user.uid; // Par défaut, utiliser l'ID de l'utilisateur

      if (userDoc.exists &&
          userDoc.data() != null &&
          userDoc.data()!.containsKey('structureId')) {
        structureId = userDoc.data()!['structureId'];
      }

      // Utiliser le bon ID de structure
      final structureSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      if (!structureSnapshot.exists) {
        print("Le document de structure n'existe pas pour l'ID: $structureId");
        setState(() {
          structureName = 'Structure introuvable';
          isLoading = false;
        });

        // Rediriger vers la création de structure
        context.go('/create-structure');
        return;
      }

      final Map<String, dynamic> structureData =
          structureSnapshot.data() ?? <String, dynamic>{};

      _structureId = structureId;
      _listenToStructureNotifications(structureId);

      final String normalizedEmail = userEmail.toLowerCase().trim();
      final bool isDashboardAdmin =
          _dashboardAdminEmails.contains(normalizedEmail);
      final bool canBroadcastNotifications =
          isDashboardAdmin ||
              structureId == 'e5udQot4UtYxsrOoqaHZ2n4VEkk1';
      final bool canViewSubscriptionStats =
          isDashboardAdmin && normalizedEmail != 'chrisgugu1101@gmail.com';

      final dynamic showNewsRaw = structureData['showDashboardNews'];
      final bool hasNewsPreference = showNewsRaw is bool;
      final bool showNewsPreference = hasNewsPreference ? showNewsRaw : true;

      if (!hasNewsPreference) {
        try {
          await structureSnapshot.reference
              .set({'showDashboardNews': true}, SetOptions(merge: true));
        } catch (e) {
          print(
              '⚠️ Impossible de définir la préférence Actualités par défaut: $e');
        }
      }

      final childrenSnapshot = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .collection('children')
          .get();

      List<Map<String, dynamic>> tempEnfants = [];
      for (var doc in childrenSnapshot.docs) {
        final data = doc.data();
        tempEnfants.add({
          'id': doc.id,
          'firstName': data['firstName'],
          'photoUrl': data['photoUrl'],
          'schedule': data['schedule'],
        });
      }

      final String structureType =
          (structureData['structureType'] ?? '').toString().toLowerCase();
      final String? resolvedRssUrl = _resolveRssFeedUrl(structureData);
      final String currentRss = _rssFeedUrl?.trim() ?? '';
      final String newRss = resolvedRssUrl?.trim() ?? '';
      final bool rssUrlChanged = currentRss != newRss;

      setState(() {
        structureName = structureData['structureName'] ?? 'Ma Structure';
        enfants = tempEnfants;
        isParentEmployeurStructure = structureType == 'parent_employeur' ||
            structureType == 'parentemployeur';
        _rssFeedUrl = resolvedRssUrl;
        _showDashboardNews = showNewsPreference;
        if (rssUrlChanged) {
          _rssItems = const [];
          _rssError = null;
          _lastRssFetch = null;
        }
        isLoading = false;
        _showNotificationAdminButton = canBroadcastNotifications;
        _showSubscriptionAdminButton = canViewSubscriptionStats;
      });

      if (newRss.isNotEmpty && showNewsPreference) {
        final bool mustForce = rssUrlChanged || _rssItems.isEmpty;
        _fetchRssFeed(force: mustForce);
      }
    } catch (e) {
      print("Erreur lors du chargement: $e");
      setState(() => isLoading = false);
    }
  }

  void _listenToStructureNotifications(String structureId) {
    if (structureId.isEmpty) return;
    _structureNotificationSub?.cancel();
    _structureNotificationSub =
        StructureNotificationService.collection(structureId)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots()
            .listen(
      (snapshot) {
        if (!mounted) return;
        if (snapshot.docs.isEmpty) {
          setState(() {
            _latestStructureNotification = null;
            _latestStructureNotificationId = null;
            _hasUnreadStructureNotification = false;
          });
          return;
        }

        final doc = snapshot.docs.first;
        final data = doc.data();
        final List<dynamic> readByRaw;
        if (data['readBy'] is List) {
          readByRaw = List<dynamic>.from(data['readBy'] as List);
        } else {
          readByRaw = const [];
        }
        final List<String> readBy =
            readByRaw.map((e) => e.toString()).toList(growable: false);
        final String normalizedEmail = _currentUserEmail.toLowerCase();
        final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final bool isRead = (normalizedEmail.isNotEmpty &&
                readBy.map((e) => e.toLowerCase()).contains(normalizedEmail)) ||
            (uid.isNotEmpty && readBy.contains(uid));

        setState(() {
          _latestStructureNotification = data;
          _latestStructureNotificationId = doc.id;
          _hasUnreadStructureNotification = !isRead;
        });
      },
      onError: (error) {
        print('Erreur écoute notifications structure: $error');
        _structureNotificationSub?.cancel();
        _structureNotificationSub = null;
      },
    );
  }

  Future<void> _markLatestNotificationAsRead() async {
    final structureId = _structureId;
    final notificationId = _latestStructureNotificationId;
    if (structureId == null ||
        structureId.isEmpty ||
        notificationId == null ||
        notificationId.isEmpty) {
      return;
    }

    String readerId = _currentUserEmail;
    if (readerId.isEmpty) {
      readerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    if (readerId.isEmpty) return;

    try {
      await StructureNotificationService.markAsRead(
        structureId: structureId,
        notificationId: notificationId,
        readerId: readerId,
      );
      if (mounted) {
        setState(() {
          _hasUnreadStructureNotification = false;
        });
      }
    } catch (e) {
      print('Erreur marquage notification lue: $e');
    }
  }

  Future<void> _showNotificationsPopup() async {
    if (!mounted) return;
    final notification = _latestStructureNotification;
    if (notification == null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text('Notifications'),
            content: const Text('Aucune notification récente à afficher.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('FERMER'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (_hasUnreadStructureNotification) {
      await _markLatestNotificationAsRead();
    }

    final String title =
        (notification['title'] ?? 'Notification').toString().trim();
    final String body = (notification['body'] ?? '').toString().trim();
    final dynamic createdAtRaw = notification['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    final String? formattedDate = createdAt != null
        ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(createdAt)
        : null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title.isEmpty ? 'Notification' : title,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formattedDate != null) ...[
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                body.isEmpty ? 'Aucun contenu supplémentaire.' : body,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FERMER'),
            ),
          ],
        );
      },
    );
  }

  void _openNotificationsAdminPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminBroadcastNotificationScreen(),
      ),
    );
  }

  void _openSubscriptionAdminPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminSubscriptionDashboardScreen(),
      ),
    );
  }

  Widget _buildNotificationAdminButton(bool isTablet) {
    final double fontSize =
        (isTablet ? 14.0 : 12.0) * MediaQuery.of(context).textScaleFactor;
    return OutlinedButton.icon(
      onPressed: _openNotificationsAdminPage,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.notifications_active),
      label: Text(
        'Publier',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSubscriptionAdminButton(bool isTablet) {
    final double fontSize =
        (isTablet ? 14.0 : 12.0) * MediaQuery.of(context).textScaleFactor;
    return OutlinedButton.icon(
      onPressed: _openSubscriptionAdminPage,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.insights),
      label: Text(
        'Stats',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNotificationChip(Size screenSize, bool isTablet) {
    final bool hasNotification = _latestStructureNotification != null;
    final bool hasUnread = _hasUnreadStructureNotification;

    final double horizontalPadding =
        screenSize.width * (isTablet ? 0.015 : 0.035);
    final double verticalPadding =
        screenSize.height * (isTablet ? 0.008 : 0.006);
    final double rawFontSize = screenSize.width * (isTablet ? 0.018 : 0.032);
    final double fontSize = rawFontSize.clamp(12.0, 18.0).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: _showNotificationsPopup,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(hasNotification ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withOpacity(hasUnread ? 0.95 : 0.5),
            width: hasUnread ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasUnread)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize * 0.75,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showScheduleModification() async {
    // Charger les enfants d'abord
    final children = await _loadChildren();

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun enfant trouvé"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Afficher directement le dialogue avec les enfants chargés
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Sélectionnez un enfant", textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.7),
                    backgroundImage: child['photoUrl'] != null &&
                            child['photoUrl'].toString().isNotEmpty
                        ? NetworkImage(child['photoUrl'])
                        : null,
                    child: child['photoUrl'] == null ||
                            child['photoUrl'].toString().isEmpty
                        ? Text(
                            child['firstName'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    child['firstName'],
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editChildSchedule(child);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ANNULER",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _editChildSchedule(Map<String, dynamic> child) {
    try {
      // Sécuriser la conversion du schedule
      Map<String, dynamic> safeSchedule = {};

      // Vérifier si schedule existe et est du bon type
      if (child['schedule'] != null) {
        try {
          // Si c'est déjà un Map
          if (child['schedule'] is Map) {
            safeSchedule = Map<String, dynamic>.from(child['schedule'] as Map);
          }
        } catch (e) {
          print("Erreur lors de la conversion du schedule: $e");
          // En cas d'erreur, utiliser un Map vide
          safeSchedule = {};
        }
      }

      // Utiliser NavigatorState.push pour avoir plus de contrôle
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditScheduleScreen(
            childId: child['id'],
            childName: child['firstName'],
            currentSchedule: safeSchedule,
          ),
        ),
      ).then((_) {
        // Rafraîchir les données après modification des horaires
        _loadData();
      });
    } catch (e) {
      print("Erreur lors de la navigation vers EditScheduleScreen: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'édition des horaires: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Méthode de construction des éléments d'action avec support pour les badges
  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? badge, // Ajout du paramètre badge optionnel
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (badge != null) badge, // Afficher le badge s'il est fourni
                SizedBox(
                    width: badge != null
                        ? 8
                        : 0), // Ajouter un espace si un badge est présent
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      context.go('/dashboard');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/exchanges');
    }
  }

  Widget _buildTabletContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        // 🔍 Détection de l'orientation
        final isLandscape = screenWidth > screenHeight;

        // 📐 Calculs adaptés selon l'orientation (UX 2025)
        final int crossAxisCount =
            isLandscape ? 4 : 2; // 4 colonnes en paysage, 2 en portrait
        final double horizontalPadding =
            isLandscape ? screenWidth * 0.05 : 24.0;
        final double maxGridWidth = isLandscape
            ? screenWidth * 0.9 // 90% de la largeur en paysage
            : screenWidth * 0.75; // 75% en portrait

        final double gridWidth =
            maxGridWidth.clamp(400.0, isLandscape ? 1200.0 : 600.0);

        // Espacement adaptatif
        final double spacing = isLandscape ? 16.0 : 24.0;

        // Ratio d'aspect optimisé pour chaque mode
        final double aspectRatio = isLandscape ? 0.95 : 1.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Espacement adaptatif en haut
                SizedBox(height: screenHeight * (isLandscape ? 0.03 : 0.02)),

                if (_shouldDisplayRssSection) ...[
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: gridWidth,
                      ),
                      child: _buildRssSection(),
                    ),
                  ),
                  SizedBox(height: isLandscape ? 16.0 : 10.0),
                ],

                // 🎨 Grille des tuiles - Adaptée à l'orientation
                Container(
                  width: gridWidth,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        crossAxisCount, // ✨ Dynamique: 2 ou 4 colonnes
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                    children: [
                      _buildTabletTile(
                        color: _tileBlue,
                        onTap: _openMamAdministration,
                        size: (gridWidth -
                                (spacing * (crossAxisCount - 1)) -
                                (horizontalPadding * 2)) /
                            crossAxisCount,
                        assetPath: 'assets/images/Icone_administration.png',
                      ),
                      _buildTabletTile(
                        color: _tileRed,
                        onTap: _openDailyOps,
                        size: (gridWidth -
                                (spacing * (crossAxisCount - 1)) -
                                (horizontalPadding * 2)) /
                            crossAxisCount,
                        assetPath: 'assets/images/Icone_fonctionnement.png',
                      ),
                      _buildTabletTile(
                        color: _tileCyan,
                        onTap: _openChildrenParents,
                        size: (gridWidth -
                                (spacing * (crossAxisCount - 1)) -
                                (horizontalPadding * 2)) /
                            crossAxisCount,
                        assetPath: 'assets/images/Icone_enfant.png',
                      ),
                      _buildTabletTile(
                        color: _tileYellow,
                        onTap: _openReportsHistory,
                        size: (gridWidth -
                                (spacing * (crossAxisCount - 1)) -
                                (horizontalPadding * 2)) /
                            crossAxisCount,
                        assetPath: 'assets/images/Icone_memo.png',
                      ),
                    ],
                  ),
                ),

                // Espacement adaptatif en bas
                SizedBox(height: screenHeight * (isLandscape ? 0.08 : 0.12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletTile({
    List<String>? lines,
    required Color color,
    required VoidCallback onTap,
    required double size,
    String? assetPath,
  }) {
    final borderRadius = BorderRadius.circular(32);
    final List<BoxShadow> shadows = [
      BoxShadow(
        color: color.withOpacity(0.18),
        blurRadius: 30,
        spreadRadius: 0,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ];

    final bool showImage = assetPath != null && assetPath.isNotEmpty;
    final List<String> tileLines = lines ?? const <String>[];
    final List<Widget> titleLines = List<Widget>.generate(
      tileLines.length,
      (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          tileLines[i],
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    if (showImage) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: SizedBox(
              height: size,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Image.asset(
                  assetPath!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            highlightColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.2),
            child: Container(
              height: size,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: titleLines,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Nouvelle méthode pour construire un élément de section
  Widget _buildSectionItem({
    required String title,
    required IconData icon,
    required String imagePath,
    required int index,
    required double maxWidth,
    String? badge,
  }) {
    final bool isSelected = _selectedSection == index;

    // Calculer le nombre de notifications pour la section Structure
    String? sectionBadge = badge;
    if (index == 0 && isMAMStructure) {
      int notificationCount = 0;
      if (needFridgeTemperatureCheck) notificationCount++;
      // Afficher badge congélateur seulement si configuré ET nécessaire
      if (needFreezerTemperatureCheck && hasFreezer == true)
        notificationCount++;

      if (notificationCount > 0) {
        sectionBadge = notificationCount.toString();
      }
    }

    return Material(
      color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSection = index;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(maxWidth * 0.02),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                isSelected ? Border.all(color: primaryColor, width: 2) : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Image.asset(
                    imagePath,
                    width: maxWidth * 0.06,
                    height: maxWidth * 0.06,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      icon,
                      color: isSelected ? primaryColor : Colors.grey.shade600,
                      size: maxWidth * 0.06,
                    ),
                  ),
                  if (sectionBadge != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: EdgeInsets.all(maxWidth * 0.008),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          sectionBadge,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: maxWidth * 0.012,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: maxWidth * 0.018,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? primaryColor : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.chevron_right,
                  color: primaryColor,
                  size: maxWidth * 0.025,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Modifier la méthode _getSectionTitle pour inclure Historique
  String _getSectionTitle(int sectionIndex) {
    switch (sectionIndex) {
      case 0:
        return isMAMStructure ? "Gestion de la MAM" : "Gestion administrative";
      case 1:
        return "Gestion des Enfants";
      case 2:
        return "Gestion des Tableaux mensuels";
      case 3:
        return "Historique";
      default:
        return "Actions";
    }
  }

  // Modifier la méthode _buildSectionDetails pour inclure Historique
  Widget _buildSectionDetails(
      int sectionIndex, double maxWidth, double maxHeight) {
    switch (sectionIndex) {
      case 0:
        return _buildStructureActions(maxWidth, maxHeight);
      case 1:
        return _buildChildrenActions(maxWidth, maxHeight);
      case 2:
        return _buildReportsActions(maxWidth, maxHeight);
      case 3:
        return _buildHistoryActions(maxWidth, maxHeight);
      default:
        return Container();
    }
  }

// Ajouter cette nouvelle méthode pour les actions d'historique
  Widget _buildHistoryActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.history,
          title: "Consulter l'historique",
          description: "Voir l'historique par enfant et par date",
          onTap: _showHistorySelection,
          maxWidth: maxWidth,
        ),
      ],
    );
  }

// Méthode pour les actions de structure
  Widget _buildStructureActions(double maxWidth, double maxHeight) {
    // Calculer le nombre de notifications
    int notificationCount = 0;

    if (isMAMStructure) {
      // Code existant pour MAM
      if (needFridgeTemperatureCheck) notificationCount++;
      if (needFreezerTemperatureCheck && hasFreezer == true)
        notificationCount++;
    } else {
      // NOUVEAU pour Assistante Maternelle
      if (needAssmatFridgeTemperatureCheck && hasAssmatFridge == true)
        notificationCount++;
      if (needAssmatFreezerTemperatureCheck && hasAssmatFreezer == true)
        notificationCount++;
    }

    String? functioningBadge;
    if (notificationCount > 0) {
      functioningBadge = notificationCount.toString();
    }

    return ListView(
      children: [
        // Modifier les coordonnées - TOUJOURS DISPONIBLE
        _buildTabletActionItem(
          icon: Icons.edit_note,
          title: "Modifier les coordonnées",
          description: "Changer les informations de la structure",
          onTap: () => context.go('/structure-management'),
          maxWidth: maxWidth,
        ),

        // Actions spécifiques selon le type de structure
        if (isMAMStructure) ...[
          // ✅ POUR MAM : Membres + Fonctionnement + Équipements
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.people,
            title: "Modifier les membres",
            description:
                "Gérer les membres de la MAM ($currentMemberCount/$maxMemberCount)",
            onTap: _showMemberManagement,
            maxWidth: maxWidth,
          ),

          // ✅ NOUVEAU : Gestion équipements pour MAM aussi
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.kitchen,
            title: "Gestion des équipements",
            description: "Ajouter ou retirer réfrigérateur et congélateur",
            onTap: _showEquipmentManagement,
            maxWidth: maxWidth,
          ),
        ] else ...[
          // ✅ POUR ASSISTANTE MATERNELLE : Fonctionnement + Équipements
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.settings,
            title: "Fonctionnement quotidien",
            description:
                "Température réfrigérateur, congélateur, planning enfant...",
            onTap: _showAssmatDailyFunctioning,
            maxWidth: maxWidth,
            badge: functioningBadge,
          ),

          // ✅ MAINTENU : Gestion équipements pour Assistante Maternelle
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.kitchen,
            title: "Gestion des équipements",
            description: "Ajouter ou retirer réfrigérateur et congélateur",
            onTap: _showEquipmentManagement,
            maxWidth: maxWidth,
          ),
        ],

        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.folder_rounded,
          title: "Mes Documents",
          description: "Diplôme, agrément, assurances, autres...",
          onTap: _openDocuments,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.description_outlined,
          title: "Documents contractuels",
          description: "Engagement, CDI, CDD, Avenant",
          onTap: _openContratsMenu,
          maxWidth: maxWidth,
        ),
      ],
    );
  }

  // Méthode pour les actions enfants
  Widget _buildChildrenActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.access_time,
          title: "Modifier les horaires",
          description: "Ajuster les horaires de garde",
          onTap: _showScheduleModification,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.photo_library,
          title: "Gestion des photos",
          description: "Ajouter ou supprimer des photos",
          onTap: _showPhotoManagement,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.edit_note,
          title: "Modifier les profils",
          description: "Éditer toutes les informations de l'enfant",
          onTap: _showChildProfilesSelection,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.person_remove,
          title: "Retirer un enfant",
          description: "Gérer le départ d'un enfant",
          onTap: _showChildRemoval,
          maxWidth: maxWidth,
        ),
        SizedBox(height: maxHeight * 0.02),
        _buildTabletActionItem(
          icon: Icons.contact_page,
          title: "Coordonnées des parents",
          description: "Consulter les coordonnées des parents",
          onTap: _showParentCoordonneeSelection,
          maxWidth: maxWidth,
        ),
        if (kDebugMode) ...[
          SizedBox(height: maxHeight * 0.02),
          _buildTabletActionItem(
            icon: Icons.admin_panel_settings,
            title: "🔧 Administration des photos (DEBUG)",
            description:
                "Nettoyage et statistiques des photos - Mode développeur",
            onTap: _showPhotoAdministration,
            maxWidth: maxWidth,
          ),
        ],
      ],
    );
  }

// Nouvelle méthode pour afficher la gestion des équipements
  void _showEquipmentManagement() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.kitchen,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Gestion des équipements",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ MESSAGE EXPLICATIF SIMPLIFIÉ
                    Container(
                      padding: EdgeInsets.all(10), // Réduit de 12 à 10
                      margin: EdgeInsets.only(bottom: 12), // Réduit de 16 à 12
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: primaryColor,
                            size: 18, // Réduit de 20 à 18
                          ),
                          SizedBox(width: 10), // Réduit de 12 à 10
                          Expanded(
                            child: Text(
                              // ✅ TEXTE PLUS COURT
                              isMAMStructure
                                  ? "Équipements MAM"
                                  : "Vos équipements",
                              style: TextStyle(
                                fontSize: 13, // Réduit de 14 à 13
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Équipement Réfrigérateur
                    _buildEquipmentCard(
                      icon: Icons.thermostat,
                      title: "Réfrigérateur",
                      description: "", // ✅ DESCRIPTION GÉRÉE DANS LA MÉTHODE
                      isEnabled:
                          isMAMStructure ? true : (hasAssmatFridge == true),
                      onChanged: (value) {
                        setDialogState(() {});
                        if (isMAMStructure) {
                          _updateMAMEquipmentPreference('fridge', value);
                        } else {
                          _updateEquipmentPreference('fridge', value);
                        }
                      },
                    ),

                    SizedBox(height: 12), // Réduit de 16 à 12

                    // Équipement Congélateur
                    _buildEquipmentCard(
                      icon: Icons.kitchen,
                      title: "Congélateur",
                      description: "", // ✅ DESCRIPTION GÉRÉE DANS LA MÉTHODE
                      isEnabled: isMAMStructure
                          ? (hasFreezer == true)
                          : (hasAssmatFreezer == true),
                      onChanged: (value) {
                        setDialogState(() {});
                        if (isMAMStructure) {
                          _updateMAMEquipmentPreference('freezer', value);
                        } else {
                          _updateEquipmentPreference('freezer', value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "FERMER",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDashboardNewsSettings() async {
    final structureId = await _getStructureId();

    if (structureId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Structure introuvable'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool currentValue = _showDashboardNews;
    try {
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final data = structureDoc.data();
      if (data != null && data['showDashboardNews'] is bool) {
        currentValue = data['showDashboardNews'] as bool;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de récupérer la préférence Actualités.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool tempValue = currentValue;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Actualités sur le tableau de bord',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Afficher les actualités'),
                    value: tempValue,
                    onChanged: (value) {
                      setLocalState(() {
                        tempValue = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('ANNULER'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('structures')
                          .doc(structureId)
                          .set({'showDashboardNews': tempValue},
                              SetOptions(merge: true));

                      if (!mounted) return;
                      setState(() {
                        _showDashboardNews = tempValue;
                      });

                      if (tempValue &&
                          (_rssFeedUrl?.trim().isNotEmpty ?? false)) {
                        Future.microtask(
                          () => _fetchRssFeed(force: _rssItems.isEmpty),
                        );
                      }

                      Navigator.of(dialogContext).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tempValue
                              ? 'Les actualités sont désormais affichées.'
                              : 'Les actualités sont masquées sur le tableau de bord.'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Impossible d\'enregistrer la préférence.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: const Text('ENREGISTRER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChildDisplaySettings() async {
    final structureId = await _getStructureId();

    if (structureId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Structure introuvable"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool showAllChildren = true;
    bool hasExplicitPreference = false;
    try {
      final structureDoc = await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .get();

      final data = structureDoc.data();
      if (data != null && data['showAllChildrenOnHome'] is bool) {
        showAllChildren = data['showAllChildrenOnHome'] as bool;
        hasExplicitPreference = true;
      }

      if (!hasExplicitPreference) {
        await structureDoc.reference.set(
          {'showAllChildrenOnHome': true},
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de récupérer les préférences d'affichage."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int selectedValue = showAllChildren ? 1 : 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Détecter iPad vs iPhone
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;
            final bool isTablet = screenWidth >= 600;

            // Tailles adaptées selon l'appareil
            final double dialogWidth = isTablet ? 500.0 : screenWidth * 0.9;
            final double horizontalPadding =
                isTablet ? 32.0 : screenWidth * 0.06;
            final double verticalPadding =
                isTablet ? 24.0 : screenHeight * 0.025;
            final double iconSize = isTablet ? 32.0 : screenWidth * 0.08;
            final double titleFontSize = isTablet ? 22.0 : screenWidth * 0.055;
            final double subtitleFontSize =
                isTablet ? 16.0 : screenWidth * 0.035;
            final double bodyFontSize = isTablet ? 16.0 : screenWidth * 0.04;
            final double cardPadding = isTablet ? 20.0 : screenWidth * 0.04;
            final double buttonHeight = isTablet ? 50.0 : screenHeight * 0.06;

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * (isTablet ? 0.7 : 0.84),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(0, 10),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En-tête moderne
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(verticalPadding),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.visibility_outlined,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Gestion des enfants',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Personnalisez votre page d'accueil",
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenu principal
                      Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          children: [
                            Text(
                              "Choisissez les enfants à afficher sur votre page d'accueil",
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),

                            // Options de sélection
                            Column(
                              children: [
                                // Option "Seulement mes enfants"
                                _buildTabletOptionCard(
                                  icon: Icons.person_outline,
                                  title: "Mes enfants seulement",
                                  subtitle:
                                      "Afficher uniquement les enfants qui vous sont assignés",
                                  isSelected: selectedValue == 0,
                                  onTap: () {
                                    setState(() {
                                      selectedValue = 0;
                                    });
                                  },
                                  cardPadding: cardPadding,
                                  bodyFontSize: bodyFontSize,
                                  subtitleFontSize: subtitleFontSize,
                                  iconSize: iconSize * 0.7,
                                ),

                                SizedBox(height: 16),

                                // Option "Tous les enfants"
                                _buildTabletOptionCard(
                                  icon: Icons.group_outlined,
                                  title: "Tous les enfants",
                                  subtitle:
                                      "Afficher tous les enfants de la structure",
                                  isSelected: selectedValue == 1,
                                  onTap: () {
                                    setState(() {
                                      selectedValue = 1;
                                    });
                                  },
                                  cardPadding: cardPadding,
                                  bodyFontSize: bodyFontSize,
                                  subtitleFontSize: subtitleFontSize,
                                  iconSize: iconSize * 0.7,
                                ),
                              ],
                            ),

                            SizedBox(height: 32),

                            // Boutons d'action
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: buttonHeight,
                                    child: TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.grey.shade100,
                                        foregroundColor: Colors.grey.shade700,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'ANNULER',
                                        style: TextStyle(
                                          fontSize: bodyFontSize * 0.9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    height: buttonHeight,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final bool newValue =
                                            selectedValue == 1;
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('structures')
                                              .doc(structureId)
                                              .update({
                                            'showAllChildrenOnHome': newValue
                                          });

                                          if (!mounted) return;
                                          Navigator.of(dialogContext).pop();

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .check_circle_outline,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      newValue
                                                          ? "Tous les enfants seront affichés"
                                                          : "Seuls vos enfants seront affichés",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor:
                                                  Colors.green.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              margin: EdgeInsets.all(16),
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(Icons.error_outline,
                                                      color: Colors.white),
                                                  SizedBox(width: 12),
                                                  Text(
                                                      'Échec de la mise à jour des préférences.'),
                                                ],
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade600,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              margin: EdgeInsets.all(16),
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'VALIDER',
                                        style: TextStyle(
                                          fontSize: bodyFontSize * 0.9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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

  Widget _buildTabletOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required double cardPadding,
    required double bodyFontSize,
    required double subtitleFontSize,
    required double iconSize,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryColor : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    size: iconSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(screenWidth *
                (isSmallScreen ? 0.04 : 0.05)), // 4-5% padding adaptatif
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.all(screenWidth * 0.03), // 3% padding
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: screenWidth *
                        (isSmallScreen
                            ? 0.055
                            : 0.06), // 5.5-6% de largeur écran
                  ),
                ),
                SizedBox(width: screenWidth * 0.04), // 4% de largeur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: screenWidth *
                              (isSmallScreen
                                  ? 0.04
                                  : 0.045), // 4-4.5% de largeur
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryColor : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: screenWidth *
                              (isSmallScreen
                                  ? 0.032
                                  : 0.035), // 3.2-3.5% de largeur
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    size: screenWidth *
                        (isSmallScreen
                            ? 0.055
                            : 0.06), // 5.5-6% de largeur écran
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateMAMEquipmentPreference(
      String equipmentType, bool hasEquipment) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      if (equipmentType == 'fridge') {
        // ✅ CORRECTION: Pour MAM, permettre d'activer/désactiver le frigo
        // On pourrait créer un champ 'hasMAMFridge' si nécessaire
        // Pour l'instant, message informatif mais on pourrait étendre la logique

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasEquipment ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasEquipment
                        ? "Réfrigérateur activé pour la MAM"
                        : "Réfrigérateur désactivé pour la MAM",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: hasEquipment ? Colors.green : primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Congélateur MAM - utiliser la logique existante
        String fieldName = 'hasFreezer';

        await FirebaseFirestore.instance
            .collection('structures')
            .doc(structureId)
            .update({fieldName: hasEquipment});

        setState(() {
          hasFreezer = hasEquipment;
          if (hasEquipment) {
            _checkFreezerTemperatureStatus(structureId);
          } else {
            needFreezerTemperatureCheck = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasEquipment ? Icons.check_circle : Icons.remove_circle,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasEquipment
                        ? "Congélateur ajouté à la MAM avec succès"
                        : "Congélateur retiré de la MAM avec succès",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: hasEquipment ? Colors.green : primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de la mise à jour de l'équipement MAM: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

// Widget pour créer une carte d'équipement moderne
  Widget _buildEquipmentCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isEnabled,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16), // Réduit de 20 à 16
      decoration: BoxDecoration(
        color: isEnabled ? primaryColor.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isEnabled ? primaryColor.withOpacity(0.3) : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10), // Réduit de 12 à 10
            decoration: BoxDecoration(
              color: isEnabled
                  ? primaryColor.withOpacity(0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isEnabled ? primaryColor : Colors.grey.shade600,
              size: 22, // Réduit de 24 à 22
            ),
          ),
          SizedBox(width: 12), // Réduit de 16 à 12
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ✅ AJOUTÉ pour compacter
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15, // Réduit de 16 à 15
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2), // Réduit de 4 à 2
                Text(
                  // ✅ TEXTE SIMPLIFIÉ selon le type de structure
                  isMAMStructure
                      ? "Température quotidienne"
                      : "Suivi quotidien",
                  style: TextStyle(
                    fontSize: 12, // Réduit de 14 à 12
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1, // ✅ FORCE UNE SEULE LIGNE
                  overflow: TextOverflow.ellipsis, // ✅ COUPE SI TROP LONG
                ),
              ],
            ),
          ),
          SizedBox(width: 12), // Réduit de 16 à 12
          Transform.scale(
            scale: 1.1, // Réduit de 1.2 à 1.1
            child: Switch(
              value: isEnabled,
              onChanged: onChanged,
              activeColor: primaryColor,
              activeTrackColor: primaryColor.withOpacity(0.3),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

// Méthode pour mettre à jour les préférences d'équipement
  Future<void> _updateEquipmentPreference(
      String equipmentType, bool hasEquipment) async {
    try {
      final structureId = await _getStructureId();
      if (structureId.isEmpty) return;

      String fieldName =
          equipmentType == 'fridge' ? 'hasAssmatFridge' : 'hasAssmatFreezer';

      await FirebaseFirestore.instance
          .collection('structures')
          .doc(structureId)
          .update({fieldName: hasEquipment});

      setState(() {
        if (equipmentType == 'fridge') {
          hasAssmatFridge = hasEquipment;
          if (hasEquipment) {
            _checkAssmatFridgeTemperatureStatus(structureId);
          } else {
            needAssmatFridgeTemperatureCheck = false;
          }
        } else {
          hasAssmatFreezer = hasEquipment;
          if (hasEquipment) {
            _checkAssmatFreezerTemperatureStatus(structureId);
          } else {
            needAssmatFreezerTemperatureCheck = false;
          }
        }
      });

      // Feedback utilisateur avec animation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                hasEquipment ? Icons.check_circle : Icons.remove_circle,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasEquipment
                      ? "${equipmentType == 'fridge' ? 'Réfrigérateur' : 'Congélateur'} ajouté avec succès"
                      : "${equipmentType == 'fridge' ? 'Réfrigérateur' : 'Congélateur'} retiré avec succès",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: hasEquipment ? Colors.green : primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print("Erreur lors de la mise à jour de l'équipement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Méthode pour les actions rapports
  Widget _buildReportsActions(double maxWidth, double maxHeight) {
    return ListView(
      children: [
        _buildTabletActionItem(
          icon: Icons.calendar_month,
          title: "Mémo mensuel",
          description: "Consulter les tableaux mensuels",
          onTap: () => context.go('/monthly-report-selection'),
          maxWidth: maxWidth,
        ),
      ],
    );
  }

  // Méthode pour construire un élément d'action pour tablette
  Widget _buildTabletActionItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required double maxWidth,
    String? badge,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(maxWidth * 0.025),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(maxWidth * 0.015),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: primaryColor,
                      size: maxWidth * 0.025,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(maxWidth * 0.008),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: maxWidth * 0.012,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: maxWidth * 0.02),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: maxWidth * 0.018,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: maxWidth * 0.005),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: maxWidth * 0.014,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: maxWidth * 0.025,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Espace pour décoller la grille du header
            const SizedBox(height: 12),
            if (_shouldDisplayRssSection) ...[
              _buildRssSection(),
              const SizedBox(height: 18),
            ],
            // Grille d'accès rapide (nouvelle UI inspirée des maquettes)
            _buildQuickGrid(),
            const SizedBox(height: 16),
            // Masqué: anciennes sections détaillées (remplacées par la grille)
            if (false) // garde-fou pour ne rien afficher
              ...[
              // Section Gestion de la Structure
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _abacusClickCount++;
                              print(
                                  "🧮 Image structure cliquée: $_abacusClickCount fois");
                              if (_abacusClickCount >= 5) {
                                _abacusClickCount = 0;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Accès administrateur déverrouillé"),
                                    duration: Duration(seconds: 1),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => AdminScreen()),
                                );
                              }
                            });
                          },
                          child: Image.asset(
                            'assets/images/Icone_Structure.png',
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.business,
                              color: primaryColor,
                              size: 60,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isMAMStructure
                                ? "Gestion de la MAM"
                                : "Gestion administrative",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Modifier les coordonnées - TOUJOURS disponible
                    _buildActionItem(
                      icon: Icons.edit_note,
                      title: "Modifier les coordonnées",
                      onTap: () => context.go('/structure-management'),
                    ),

                    // Sections spécifiques selon le type de structure
                    if (isMAMStructure) ...[
                      // ✅ POUR MAM : Membres + Fonctionnement + Équipements
                      _buildActionItem(
                        icon: Icons.people,
                        title: "Modifier les membres",
                        onTap: _showMemberManagement,
                      ),

                      _buildActionItem(
                        icon: Icons.settings,
                        title: "Fonctionnement de la MAM",
                        onTap: _showMAMFunctioning,
                        badge: (needFridgeTemperatureCheck ||
                                (needFreezerTemperatureCheck &&
                                    hasFreezer == true))
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ((needFridgeTemperatureCheck ? 1 : 0) +
                                          (needFreezerTemperatureCheck &&
                                                  hasFreezer == true
                                              ? 1
                                              : 0))
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // ✅ NOUVEAU : Gestion équipements pour MAM aussi
                      _buildActionItem(
                        icon: Icons.kitchen,
                        title: "Gestion des équipements",
                        onTap: _showEquipmentManagement,
                      ),
                    ] else ...[
                      // ✅ POUR ASSISTANTE MATERNELLE : Fonctionnement + Équipements
                      _buildActionItem(
                        icon: Icons.settings,
                        title: "Fonctionnement quotidien",
                        onTap: _showAssmatDailyFunctioning,
                        badge: ((needAssmatFridgeTemperatureCheck &&
                                    hasAssmatFridge == true) ||
                                (needAssmatFreezerTemperatureCheck &&
                                    hasAssmatFreezer == true))
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ((needAssmatFridgeTemperatureCheck &&
                                                  hasAssmatFridge == true
                                              ? 1
                                              : 0) +
                                          (needAssmatFreezerTemperatureCheck &&
                                                  hasAssmatFreezer == true
                                              ? 1
                                              : 0))
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // ✅ MAINTENU : Gestion équipements pour Assistante Maternelle
                      _buildActionItem(
                        icon: Icons.kitchen,
                        title: "Gestion des équipements",
                        onTap: _showEquipmentManagement,
                      ),
                    ],
                  ],
                ),
              ),

              // Section Gestion des Enfants
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _abacusClickCount++;
                              print(
                                  "🧮 Image enfant cliquée: $_abacusClickCount fois");
                              if (_abacusClickCount >= 5) {
                                _abacusClickCount = 0;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Accès administrateur déverrouillé"),
                                    duration: Duration(seconds: 1),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => AdminScreen()),
                                );
                              }
                            });
                          },
                          child: Image.asset(
                            'assets/images/Icone_Enfant_Present.png',
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.child_care,
                              color: primaryColor,
                              size: 60,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Gestion des enfants",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildActionItem(
                      icon: Icons.access_time,
                      title: "Modifier les horaires",
                      onTap: _showScheduleModification,
                    ),
                    _buildActionItem(
                      icon: Icons.contact_page,
                      title: "Coordonnées des parents",
                      onTap: _showParentCoordonneeSelection,
                    ),
                    _buildActionItem(
                      icon: Icons.photo_library,
                      title: "Gestion des photos",
                      onTap: _showPhotoManagement,
                    ),
                    _buildActionItem(
                      icon: Icons.edit_note,
                      title: "Modifier les profils",
                      onTap: _showChildProfilesSelection,
                    ),
                    _buildActionItem(
                      icon: Icons.person_remove,
                      title: "Retirer un enfant",
                      onTap: _showChildRemoval,
                    ),
                    if (kDebugMode)
                      _buildActionItem(
                        icon: Icons.admin_panel_settings,
                        title: "🔧 Administration des photos (DEBUG)",
                        onTap: _showPhotoAdministration,
                      ),
                  ],
                ),
              ),

              // Section Rapports - Affichée conditionnellement
              if (showMonthlyTableReports)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        offset: const Offset(0, 3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/Icone_recap.png',
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.assessment,
                              color: primaryColor,
                              size: 60,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Mémo mensuel",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildActionItem(
                        icon: Icons.calendar_month,
                        title: "Mémo mensuel",
                        onTap: () => context.go('/monthly-report-selection'),
                      ),
                    ],
                  ),
                ),

              /*// Section Historique
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    offset: const Offset(0, 3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/Icone_historique.png',
                        width: 60,
                        height: 60,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.history,
                          color: primaryColor,
                          size: 60,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Historique",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildActionItem(
                    icon: Icons.history,
                    title: "Consulter l'historique",
                    onTap: _showHistorySelection,
                  ),
                ],
              ),
            ),*/
            ],

            // Section légale déplacée dans la tuile Administration
            /*Container(
              margin: EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.policy_outlined,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Informations légales",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildLegalButtons(isTablet: false),
                ],
              ),
            ),*/
          ],
        ),
      ),
    );
  }

  // Version centrée verticalement de la grille pour mobile
  Widget _buildPhoneContentCentered() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridOuterWidth = constraints.maxWidth - 32;
        final tileWidth = (gridOuterWidth - 14) / 2;
        final tileSize = tileWidth;
        final gridHeight = 12 + tileSize + 14 + tileSize + 8;
        final available = constraints.maxHeight;

        // Nouvelles estimations de hauteur plus réduites pour mobile
        final double rssHeightEstimate = !_shouldDisplayRssSection
            ? 0
            : (_rssItems.isNotEmpty
                ? 120 // Réduit de 190 à 120
                : (_rssError != null
                    ? 90
                    : (_isRssLoading ? 100 : 90))); // Toutes réduites

        final double combinedHeight = gridHeight +
            rssHeightEstimate +
            (_shouldDisplayRssSection ? 16 : 0); // Réduit de 24 à 16

        final topGap = (available > combinedHeight)
            ? ((available - combinedHeight) / 2).clamp(12.0, 140.0)
            : 12.0;

        return SingleChildScrollView(
          physics: available > combinedHeight
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topGap, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_shouldDisplayRssSection) ...[
                  _buildRssSection(),
                  const SizedBox(height: 12), // Réduit de 16 à 12
                ],
                _buildQuickGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMAMStatusText() {
    if (currentMemberCount < maxMemberCount) {
      // Exemple: "1 membre sur 2 autorisés" ou "2 membres sur 3 autorisés"
      return "$currentMemberCount membre${currentMemberCount > 1 ? 's' : ''} sur $maxMemberCount autorisé${maxMemberCount > 1 ? 's' : ''}";
    } else {
      // Exemple: "2/2 membres" ou "3/3 membres"
      return "$currentMemberCount/$maxMemberCount membres";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubscriptionLoading) {
      return Scaffold(
        backgroundColor: kAppBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (!_isSubscribed) {
      return _buildSubscriptionRequired();
    }

    // NOUVEAU: Vérifier s'il faut afficher les dialogues de choix pour Assistante Maternelle
    if (!isMAMStructure &&
        (showAssmatFridgeChoice || showAssmatFreezerChoice)) {
      final scaffold = Scaffold(
        backgroundColor: kAppBackgroundColor,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primaryColor, primaryColor.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft:
                      Radius.circular(MediaQuery.of(context).size.width * 0.06),
                  bottomRight:
                      Radius.circular(MediaQuery.of(context).size.width * 0.06),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Configuration",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        structureName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildAssmatEquipmentChoiceDialog(),
            ),
          ],
        ),
      );
      return _wrapWithLoadingOverlay(scaffold);
    }

    // Récupérer les dimensions de l'écran
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;

    final scaffold = Scaffold(
      backgroundColor: kAppBackgroundColor,
      body: Column(
        children: [
          // En-tête avec fond de couleur - identique pour phone et tablet
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
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(screenSize.width * 0.06),
                bottomRight: Radius.circular(screenSize.width * 0.06),
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
                padding: EdgeInsets.fromLTRB(
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * 0.02,
                  screenSize.width * (isTablet ? 0.03 : 0.04),
                  screenSize.height * (isTablet ? 0.02 : 0.025),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date du jour (sans le titre 'Tableau de bord')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              screenSize.width * (isTablet ? 0.018 : 0.03),
                          vertical:
                              screenSize.height * (isTablet ? 0.01 : 0.006),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            screenSize.width * (isTablet ? 0.025 : 0.05),
                          ),
                        ),
                        child: Text(
                          DateFormat('EEEE d MMMM', 'fr_FR')
                              .format(DateTime.now()),
                          style: TextStyle(
                            fontSize:
                                screenSize.width * (isTablet ? 0.018 : 0.035),
                            color: Colors.white.withOpacity(0.95),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    // Nom de la structure + accès notifications
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            structureName,
                            style: TextStyle(
                              fontSize:
                                  screenSize.width * (isTablet ? 0.024 : 0.045),
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((_structureId ?? '').isNotEmpty) ...[
                          SizedBox(
                            width: screenSize.width * (isTablet ? 0.02 : 0.04),
                          ),
                          _buildNotificationChip(screenSize, isTablet),
                        ],
                        if (_showNotificationAdminButton) ...[
                          SizedBox(
                            width: screenSize.width * (isTablet ? 0.015 : 0.03),
                          ),
                          _buildNotificationAdminButton(isTablet),
                        ],
                        if (_showSubscriptionAdminButton) ...[
                          SizedBox(
                            width: screenSize.width * (isTablet ? 0.015 : 0.03),
                          ),
                          _buildSubscriptionAdminButton(isTablet),
                        ],
                      ],
                    ),
                    // Afficher le type de structure si c'est une MAM
                    if (isMAMStructure)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "MAM",
                                style: TextStyle(
                                  fontSize: screenSize.width *
                                      (isTablet ? 0.016 : 0.03),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              // ✅ CORRECTION : Affichage correct selon la situation
                              _getMAMStatusText(),
                              style: TextStyle(
                                fontSize: screenSize.width *
                                    (isTablet ? 0.016 : 0.03),
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal avec adaptation pour iPad
          Expanded(
            child:
                isTablet ? _buildTabletContent() : _buildPhoneContentCentered(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // Dashboard est sélectionné
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_dashboard.png',
              width: screenSize.width * (isTablet ? 0.07 : 0.14),
              height: screenSize.width * (isTablet ? 0.07 : 0.14),
            ),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_home.png',
              width: screenSize.width * (isTablet ? 0.07 : 0.14),
              height: screenSize.width * (isTablet ? 0.07 : 0.14),
            ),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/Icone_message.png',
              width: screenSize.width * (isTablet ? 0.07 : 0.14),
              height: screenSize.width * (isTablet ? 0.07 : 0.14),
            ),
            label: "Messages",
          ),
        ],
      ),
    );

    return _wrapWithLoadingOverlay(scaffold);
  }
}
