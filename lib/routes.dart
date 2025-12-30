import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'utils/user_role_cache.dart';
import 'package:poppins_app/screens/signup_screen.dart';
import 'package:poppins_app/screens/structure_details_screen.dart';
import 'package:poppins_app/screens/subscription_screen.dart';
import 'package:poppins_app/screens/congratulations_screen.dart';
import 'package:poppins_app/screens/structure_info_screen.dart';
import 'package:poppins_app/screens/home_screen.dart';
// Importer le nouveau fichier login_screen
import 'package:poppins_app/screens/login_screen_new.dart';
import 'package:poppins_app/screens/child_info_screen.dart';
import 'package:poppins_app/screens/parent_info_screen.dart';
import 'package:poppins_app/screens/parent_address_screen.dart';
import 'package:poppins_app/screens/parent_second_info_screen.dart';
import 'package:poppins_app/screens/schedule_info_screen.dart';
import 'package:poppins_app/screens/add_second_parent_screen.dart';
import 'package:poppins_app/screens/child_final_details_screen.dart';
import 'package:poppins_app/screens/horaires_screen.dart';
import 'package:poppins_app/screens/test_photo_screen.dart'; // Import de la nouvelle page test
import 'package:poppins_app/screens/repas_screen.dart';
import 'package:poppins_app/screens/activity_screen.dart';
import 'package:poppins_app/screens/sieste_screen.dart';
import 'package:poppins_app/screens/sante_screen.dart';
import 'package:poppins_app/screens/change_screen.dart';
import 'package:poppins_app/screens/photo_screen.dart';
import 'package:poppins_app/screens/exchanges_screen.dart';
import 'package:poppins_app/screens/stock_screen.dart';
import 'package:poppins_app/screens/agenda_screen.dart';
import 'package:poppins_app/screens/dashboard_screen.dart';
import 'package:poppins_app/screens/photo_management_screen.dart';
import 'package:poppins_app/screens/child_removal_screen.dart';
import 'package:poppins_app/screens/structure_management_screen.dart';
import 'package:poppins_app/screens/structure_confirmation_screen.dart';
// Importez les nouveaux écrans
import 'package:poppins_app/screens/child_documents_screen.dart';
import 'package:poppins_app/screens/child_pickup_auth_screen.dart';
import 'package:poppins_app/screens/child_meal_info_screen.dart';
import 'package:poppins_app/screens/child_financial_info_screen.dart';
import 'package:poppins_app/screens/recap_enfant_screen.dart';
import 'package:poppins_app/screens/child_profile_details_screen.dart';
import 'package:poppins_app/screens/actualites_screen.dart'; // Import de l'écran Actualités
import 'package:poppins_app/screens/transmissions_screen.dart';
import 'package:poppins_app/screens/monthly_report_generate_screen.dart';
import 'package:poppins_app/screens/monthly_report_selection_screen.dart';
import 'package:poppins_app/screens/child_salary_info_screen.dart';
import 'package:poppins_app/screens/test_data_generator.dart';
import 'package:poppins_app/screens/parent_home_screen.dart';
import 'package:poppins_app/screens/parent_messages_screen.dart';
import 'package:poppins_app/screens/parent_stock_screen.dart';
import 'package:poppins_app/screens/parent_child_photo_screen.dart';
import 'package:poppins_app/screens/add-mam-members.dart';
import 'package:poppins_app/screens/register_screen.dart';
import 'package:poppins_app/screens/pricing_screen.dart';
import 'package:poppins_app/screens/admin_screen.dart';
import 'package:poppins_app/screens/freezer_temperature_screen.dart';
import 'package:poppins_app/screens/trial_pricing_info_screen.dart';

// Nouveaux imports pour le système d'authentification
import 'package:poppins_app/screens/welcome_screen.dart';
import 'package:poppins_app/screens/invitation_code_screen.dart';
import 'package:poppins_app/screens/invitation_validated_screen.dart';
import 'package:poppins_app/screens/invitation_signup_screen.dart';
import 'package:poppins_app/screens/subscription_confirmed_screen.dart';
import 'package:poppins_app/screens/subscription_upgrade_confirmed_screen.dart';
import 'package:poppins_app/screens/subscription_upgrade_screen.dart';
import 'package:poppins_app/screens/fridge_temperature_screen.dart';
import 'package:poppins_app/screens/cleaning_schedule_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:poppins_app/screens/parent_second_address_screen.dart';
import 'package:poppins_app/screens/parent_coordonnees_screen.dart';
import 'package:poppins_app/screens/splash_screen.dart';
import 'package:poppins_app/screens/account_deletion_screen.dart';
import 'package:poppins_app/screens/mam_group_chat_screen.dart';

// 🔒 NOUVEAUX IMPORTS POUR LE SYSTÈME DE SÉCURITÉ
import 'package:poppins_app/screens/auth_check_screen.dart';
import 'package:poppins_app/screens/quick_login_screen.dart';
import 'theme/app_colors.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Ajouter cette fonction dans votre fichier routes.dart
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

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  // 🔒 CHANGEMENT CRITIQUE : Démarrer par AuthCheckScreen
  initialLocation: '/', // AuthCheckScreen gère tout maintenant

  // 🔒 SIMPLIFICATION : Plus de redirection complexe nécessaire
  redirect: _handleRedirect,

  errorBuilder: (context, state) {
    print("❌ ERREUR ROUTE: ${state.uri.toString()}");
    print("❌ ERREUR: ${state.error}");

    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      appBar: AppBar(
        title: const Text("Page non trouvée"),
        backgroundColor: const Color(0xFF3D9DF2),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: const Color(0xFF3D9DF2),
            ),
            SizedBox(height: 20),
            Text(
              "Page non trouvée",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3D9DF2),
              ),
            ),
            SizedBox(height: 10),
            Text(
              "La page demandée n'existe pas ou il manque des paramètres",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),

            // Bouton principal - Retour vers AuthCheck
            ElevatedButton(
              onPressed: () {
                print("🔄 Redirection forcée vers AuthCheck");
                try {
                  context.go('/'); // Rediriger vers AuthCheck
                } catch (e) {
                  print("❌ Erreur redirection vers AuthCheck: $e");
                  // En cas d'échec total, redémarrer l'app
                  context.go('/splash');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D9DF2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                "RETOUR À L'ACCUEIL",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: 20),

            // Bouton secondaire - Redémarrer
            TextButton(
              onPressed: () {
                print("🔄 Redémarrage de l'application");
                try {
                  context.go('/splash');
                } catch (e) {
                  print("❌ Erreur redémarrage: $e");
                  // Forcer le retour à la racine
                  context.go('/');
                }
              },
              child: const Text(
                "Redémarrer l'application",
                style: TextStyle(
                  color: Color(0xFF3D9DF2),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
  routes: [
    // 🔒 NOUVEAUX ÉCRANS DE SÉCURITÉ (EN PREMIER)
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthCheckScreen(),
    ),

    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),

    GoRoute(
      path: '/quick-login',
      builder: (context, state) => QuickLoginScreen(
        data: state.extra as Map<String, String>,
      ),
    ),

    // 🔄 ÉCRANS EXISTANTS (GARDÉS TELS QUELS)

    // Splash screen - maintenant utilisé pour chargement post-authentification
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // Conserver l'ancienne route pour compatibilité
    // GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

    // Nouvelles routes pour le système d'authentification
    GoRoute(
      path: '/invitation-code',
      builder: (context, state) => const InvitationCodeScreen(),
    ),
    GoRoute(
      path: '/parent-second-address',
      builder: (context, state) {
        final childId = state.extra as String;
        return ParentSecondAddressScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/invitation-validated',
      builder: (context, state) {
        final invitationInfo = state.extra as Map<String, dynamic>;
        return InvitationValidatedScreen(invitationInfo: invitationInfo);
      },
    ),
    GoRoute(
      path: '/invitation-signup',
      builder: (context, state) {
        final invitationInfo = state.extra as Map<String, dynamic>;
        return InvitationSignupScreen(invitationInfo: invitationInfo);
      },
    ),

    // Routes existantes
    /*
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    */
    /*
    GoRoute(
      path: '/trial-info',
      builder: (context, state) => const TrialPricingInfoScreen(),
    ),
    */
    GoRoute(
      path: '/freezer-temperature',
      builder: (context, state) => const FreezerTemperatureScreen(),
    ),
    GoRoute(
      path: '/account-deletion',
      builder: (context, state) => const AccountDeletionScreen(),
    ),
    /*
    GoRoute(
      path: '/subscription-confirmed',
      builder: (context, state) => SubscriptionConfirmedScreen(
        structureInfo: state.extra as Map<String, dynamic>? ?? {},
      ),
    ),
    */
    GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),

    // Ajout de la route pour l'écran de tarification
    /*
    GoRoute(
      path: '/pricing',
      builder: (context, state) {
        final structureInfo = state.extra as Map<String, dynamic>? ?? {};

        // Extraire le type de structure
        final String structureType =
            structureInfo['structureType'] ?? 'assistante_maternelle';

        // Extraire le nombre de membres (pour MAM)
        final int mamMembersCount = structureInfo['memberCount'] ??
            structureInfo['mamMembersCount'] ??
            2;

        return PricingScreen(
          structureType: structureType,
          mamMembersCount: mamMembersCount,
        );
      },
    ),
    */

    /*
    GoRoute(
      path: '/structure-details',
      builder: (context, state) => const StructureDetailsScreen(),
    ),
    */
    /*
    GoRoute(
      path: '/structure-confirmation',
      builder: (context, state) {
        final dynamic extra = state.extra;
        String structureType = "Structure inconnue";
        if (extra is Map<String, dynamic>) {
          structureType = (extra['structureType'] ?? structureType).toString();
        } else if (extra is String && extra.isNotEmpty) {
          structureType = extra;
        }
        return StructureConfirmationScreen(structureType: structureType);
      },
    ),
    */
    /*
    GoRoute(
      path: '/subscription',
      builder: (context, state) {
        final structureType = state.extra as String? ?? "Structure inconnue";
        return SubscriptionScreen(structureType: structureType);
      },
    ),
    */
    /*
    GoRoute(
      path: '/congratulations',
      builder: (context, state) {
        final dynamic extra = state.extra;
        String structureType = "Structure inconnue";
        bool skipStructureFlow = false;
        if (extra is Map<String, dynamic>) {
          structureType = (extra['structureType'] ?? structureType).toString();
          final dynamic skipValue = extra['skipStructureFlow'];
          if (skipValue is bool) {
            skipStructureFlow = skipValue;
          }
        } else if (extra is String && extra.isNotEmpty) {
          structureType = extra;
        }
        return CongratulationsScreen(
          structureType: structureType,
          skipStructureFlow: skipStructureFlow,
        );
      },
    ),
    */
    GoRoute(
      path: '/structure-info',
      builder: (context, state) {
        final Map<String, dynamic> extraData =
            state.extra as Map<String, dynamic>? ?? {};
        return StructureInfoScreen(extraData: extraData);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        try {
          return HomeScreen();
        } catch (e) {
          print("❌ Erreur dans HomeScreen: $e");
          return _createErrorScreen(
            "Une erreur s'est produite lors du chargement de l'accueil.\nVeuillez reprendre depuis l'écran de bienvenue.",
            context,
          );
        }
      },
    ),
    GoRoute(
      path: '/child-info',
      builder: (context, state) {
        final Map<String, dynamic> extra =
            state.extra as Map<String, dynamic>? ?? const {};
        final bool parentEmployerFlow = extra['parentEmployerFlow'] == true;
        return ChildInfoScreen(parentEmployerFlow: parentEmployerFlow);
      },
    ),
    GoRoute(
      path: '/parent-info',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour parent-info");
          return Scaffold(
            body: Center(child: Text("Erreur : Aucun ID d'enfant fourni")),
          );
        }
        print("✅ Chargement parent-info avec childId: $childId");
        return ParentInfoScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/parent-address',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour parent-address");
          return Scaffold(
            body: Center(
              child: Text("Erreur : Aucun ID d'enfant fourni pour l'adresse"),
            ),
          );
        }
        print("✅ Chargement parent-address avec childId: $childId");
        return ParentAddressScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/add-second-parent',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour add-second-parent");
          return Scaffold(
            body: Center(child: Text("Erreur : Aucun ID d'enfant fourni")),
          );
        }
        print("✅ Chargement add-second-parent avec childId: $childId");
        return AddSecondParentScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/parent-second-info',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour parent-second-info");
          return Scaffold(
            body: Center(
              child: Text(
                "Erreur : Aucun ID d'enfant fourni pour le second parent",
              ),
            ),
          );
        }
        print("✅ Chargement parent-second-info avec childId: $childId");
        return ParentSecondInfoScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/schedule-info',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour schedule-info");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement schedule-info avec childId: $childId");
        return ScheduleInfoScreen(childId: childId);
      },
    ),
    // Si votre route est définie de cette façon
    GoRoute(
      path: '/child-final-details',
      builder: (context, state) {
        final Map<String, dynamic> extraData =
            state.extra as Map<String, dynamic>? ?? {};
        final String childId = extraData['childId'] ?? '';
        final String structureId = extraData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid ??
            '';

        return ChildFinalDetailsScreen(
          childId: childId,
          structureId: structureId,
        );
      },
    ),
    // Nouvelles routes pour les écrans d'ajout d'enfant complémentaires
    GoRoute(
      path: '/child-documents',
      builder: (context, state) {
        // Modifier cette partie pour gérer à la fois une Map et une chaîne
        Map<String, dynamic> extraData = {};
        if (state.extra is Map<String, dynamic>) {
          extraData = state.extra as Map<String, dynamic>;
        } else if (state.extra is String) {
          extraData = {'childId': state.extra as String};
        }

        final String childId = extraData['childId'] ?? '';
        final String structureId = extraData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid ??
            '';

        if (childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour child-documents");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }

        print("✅ Chargement child-documents avec childId: $childId");
        return ChildDocumentsScreen(
          childId: childId,
          structureId:
              structureId, // Ajouter ce paramètre si ChildDocumentsScreen l'accepte
        );
      },
    ),
    GoRoute(
      path: '/child-pickup-auth',
      builder: (context, state) {
        Map<String, dynamic> extraData = {};
        if (state.extra is Map<String, dynamic>) {
          extraData = state.extra as Map<String, dynamic>;
        } else if (state.extra is String) {
          extraData = {'childId': state.extra as String};
        }

        final String childId = extraData['childId'] ?? '';
        final String structureId = extraData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid ??
            '';

        if (childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour child-pickup-auth");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement child-pickup-auth avec childId: $childId");
        return ChildPickupAuthScreen(
          childId: childId,
          structureId: structureId,
        );
      },
    ),
    GoRoute(
      path: '/child-meal-info',
      builder: (context, state) {
        Map<String, dynamic> extraData = {};
        if (state.extra is Map<String, dynamic>) {
          extraData = state.extra as Map<String, dynamic>;
        } else if (state.extra is String) {
          extraData = {'childId': state.extra as String};
        }

        final String childId = extraData['childId'] ?? '';
        final String structureId = extraData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid ??
            '';

        if (childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour child-meal-info");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement child-meal-info avec childId: $childId");
        return ChildMealInfoScreen(
          childId: childId,
          structureId: structureId,
        );
      },
    ),
    GoRoute(path: '/horaires', builder: (context, state) => HorairesScreen()),
    // Nouvelle route pour la page test
    GoRoute(
      path: '/test-photo',
      builder: (context, state) => TestPhotoScreen(),
    ),
    GoRoute(
      path: '/repas', // Définition de la route pour la page Repas
      builder: (BuildContext context, GoRouterState state) {
        return RepasScreen();
      },
    ),
    GoRoute(
      path: '/activites',
      builder: (BuildContext context, GoRouterState state) {
        return ActivityScreen(context: context);
      },
    ),
    GoRoute(
      path: '/sieste',
      builder: (BuildContext context, GoRouterState state) {
        return SiesteScreen();
      },
    ),
    GoRoute(
      path: '/sante',
      builder: (BuildContext context, GoRouterState state) {
        return SanteScreen();
      },
    ),
    GoRoute(
      path: '/change',
      builder: (BuildContext context, GoRouterState state) {
        return ChangeScreen();
      },
    ),
    GoRoute(
      path: '/photos',
      builder: (BuildContext context, GoRouterState state) {
        return PhotosScreen(); // Changé de PhotoScreen à PhotosScreen
      },
    ),
    GoRoute(
      path: '/exchanges',
      builder: (context, state) => const ExchangesScreen(),
    ),
    GoRoute(
      path: '/agenda',
      builder: (context, state) => const AgendaScreen(),
    ),
    GoRoute(path: '/stock', builder: (context, state) => const StockScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        try {
          return const DashboardScreen();
        } catch (e) {
          print("❌ Erreur dans DashboardScreen: $e");
          return _createErrorScreen(
            "Une erreur s'est produite lors du chargement du tableau de bord.\nVeuillez reprendre depuis l'écran de bienvenue.",
            context,
          );
        }
      },
    ),
    GoRoute(
      path: '/photo-management/:childId?', // Le ? rend le paramètre optionnel
      builder: (context, state) {
        final childId = state.pathParameters['childId'];
        return PhotoManagementScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/structure-management',
      builder: (context, state) => const StructureManagementScreen(),
    ),
    GoRoute(
      path: '/child-financial-info',
      builder: (context, state) {
        Map<String, dynamic> extraData = {};
        if (state.extra is Map<String, dynamic>) {
          extraData = state.extra as Map<String, dynamic>;
        } else if (state.extra is String) {
          extraData = {'childId': state.extra as String};
        }

        final String childId = extraData['childId'] ?? '';
        final String structureId = extraData['structureId'] ??
            FirebaseAuth.instance.currentUser?.uid ??
            '';

        if (childId.isEmpty) {
          print(
            "⚠️ Erreur : Aucun ID d'enfant fourni pour child-financial-info",
          );
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement child-financial-info avec childId: $childId");
        return ChildFinancialInfoScreen(
          childId: childId,
          structureId: structureId,
        );
      },
    ),
    GoRoute(
      path: '/recap-enfant',
      builder: (context, state) => const RecapScreen(),
    ),
    GoRoute(
      path: '/actualites',
      builder: (context, state) => const ActualitesScreen(),
    ),
    GoRoute(
      path: '/transmissions',
      builder: (context, state) => const TransmissionsScreen(),
    ),
    GoRoute(
      path: '/monthly-report-selection',
      builder: (context, state) => const MonthlyReportSelectionScreen(),
    ),
    GoRoute(
      path: '/monthly-report-generate',
      builder: (context, state) {
        final reportParams = state.extra as Map<String, dynamic>? ?? {};
        return MonthlyReportGenerateScreen(reportParams: reportParams);
      },
    ),
    GoRoute(
      path: '/child-salary-info',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        return ChildSalaryInfoScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/test-data-generator',
      builder: (context, state) => const TestDataGeneratorScreen(),
    ),
    GoRoute(
      path: '/parent/home',
      builder: (context, state) {
        try {
          return const ParentHomeScreen();
        } catch (e) {
          print("❌ Erreur dans ParentHomeScreen: $e");
          return _createErrorScreen(
            "Une erreur s'est produite lors du chargement de l'espace parent.\nVeuillez reprendre depuis l'écran de bienvenue.",
            context,
          );
        }
      },
    ),

    GoRoute(
      path: '/cleaning-schedule',
      builder: (context, state) => const CleaningScheduleScreen(),
    ),
    GoRoute(
      path: '/parent/messages',
      builder: (context, state) => const ParentMessagesScreen(),
    ),
    GoRoute(
      path: '/parent/messages/:childId',
      builder: (context, state) {
        // Avec les versions récentes de go_router
        final childId = state.pathParameters['childId'] ?? '';
        print("✅ Chargement messages parent avec childId: $childId");
        return ParentMessagesScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/parent/child-profile',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final String childId = extra['childId']?.toString() ?? '';
        if (childId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        final String structureId =
            extra['structureId']?.toString().trim().isNotEmpty == true
                ? extra['structureId'].toString().trim()
                : FirebaseAuth.instance.currentUser?.uid ?? '';
        return ChildProfileDetailsScreen(
          childId: childId,
          structureId: structureId,
          parentMode: true,
        );
      },
    ),
    GoRoute(
      path: '/parent/child-photo',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final String childId = extra['childId']?.toString() ?? '';
        if (childId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        final String structureId =
            extra['structureId']?.toString().trim().isNotEmpty == true
                ? extra['structureId'].toString().trim()
                : FirebaseAuth.instance.currentUser?.uid ?? '';
        final String childName = extra['childName']?.toString() ?? 'Mon enfant';
        return ParentChildPhotoScreen(
          childId: childId,
          structureId: structureId,
          childName: childName,
        );
      },
    ),
    GoRoute(
      path: '/parent/child-schedule',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final String childId = extra['childId']?.toString() ?? '';
        if (childId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        final String structureId =
            extra['structureId']?.toString().trim().isNotEmpty == true
                ? extra['structureId'].toString().trim()
                : FirebaseAuth.instance.currentUser?.uid ?? '';
        final String childName = extra['childName']?.toString() ?? 'Mon enfant';
        return ScheduleInfoScreen(
          childId: childId,
          parentMode: true,
          structureIdOverride: structureId,
          childName: childName,
        );
      },
    ),
    GoRoute(
      path: '/parent/stocks',
      pageBuilder: (context, state) => MaterialPage(
        key: ValueKey('parent-stocks'), // Clé unique différente
        child: ParentStockScreen(),
      ),
    ),
    GoRoute(
      path: '/add-mam-members',
      builder: (context, state) => const AddMAMMembersScreen(),
    ),
    GoRoute(
      path: '/fridge-temperature',
      builder: (context, state) => const FridgeTemperatureScreen(),
    ),
    GoRoute(
      path: '/subscription-upgrade',
      builder: (context, state) => const SubscriptionUpgradeScreen(),
    ),
    GoRoute(
      path: '/upgrade-confirmed',
      builder: (context, state) => SubscriptionUpgradeConfirmedScreen(
        upgradeInfo: state.extra as Map<String, dynamic>,
      ),
    ),
    GoRoute(
      path: '/create-structure',
      builder: (context, state) =>
          const StructureDetailsScreen(), // Utilisez l'écran existant
    ),
  ],
);

Widget _createErrorScreen(String message, BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text("Erreur"),
      backgroundColor: Color(0xFF3D9DF2),
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Color(0xFF3D9DF2),
          ),
          SizedBox(height: 20),
          Text(
            "Oops !",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D9DF2),
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              context.go('/'); // Retour vers AuthCheck
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3D9DF2),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: Text(
              "RETOUR À L'ACCUEIL",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

// 🔒 FONCTION DE REDIRECTION SIMPLIFIÉE
String? _handleRedirect(BuildContext context, GoRouterState state) {
  print("🔄 _handleRedirect appelée pour: ${state.uri.toString()}");

  // 🎯 STRATÉGIE SIMPLIFIÉE: AuthCheckScreen gère TOUT
  // Cette fonction ne fait plus que vérifier les routes publiques de base

  final String path = state.matchedLocation;

  // Routes qui ne nécessitent AUCUNE vérification
  final List<String> absolutelyPublicRoutes = [
    '/', // AuthCheckScreen
    '/welcome',
    '/quick-login',
    '/login',
    '/trial-info',
    '/register',
    '/signup',
    '/invitation-code',
    '/invitation-validated',
    '/invitation-signup',
    '/pricing',
    '/structure-details',
    '/structure-confirmation',
    '/subscription-confirmed',
    '/splash',
  ];

  // Si c'est une route absolument publique, laisser passer
  if (absolutelyPublicRoutes.contains(path)) {
    print("✅ Route publique autorisée: $path");
    return null;
  }

  // 🔄 POUR TOUTES LES AUTRES ROUTES: Laisser AuthCheckScreen décider
  // AuthCheckScreen vérifiera l'authentification et redirigera si nécessaire

  print("🔄 Route protégée potentielle, laissons AuthCheck décider: $path");

  // Vérification rapide: si pas d'utilisateur connecté, rediriger vers AuthCheck
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null && !absolutelyPublicRoutes.contains(path)) {
    print(
        "❌ Utilisateur non connecté pour route protégée, redirection vers AuthCheck");
    return '/';
  }

  if (path == '/home' && user != null) {
    if (UserRoleCache.isParent) {
      print('🔁 Redirect /home -> /parent/home (cache)');
      return '/parent/home';
    }
  }

  // Sinon, laisser passer - AuthCheckScreen a déjà fait son travail
  print("✅ Utilisateur connecté ou route autorisée: $path");
  return null;
}
// Messagerie interne MAM
