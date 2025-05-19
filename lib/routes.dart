import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:poppins_app/screens/add-mam-members.dart';
import 'package:poppins_app/screens/register_screen.dart';
import 'package:poppins_app/screens/pricing_screen.dart';

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
  initialLocation: '/',
  redirect: _handleRedirect,
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Page non trouvée",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text("Retour à l'accueil"),
          ),
        ],
      ),
    ),
  ),
  routes: [
    // Écran d'accueil principal (premier écran)
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    // Conserver l'ancienne route pour compatibilité
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Nouvelles routes pour le système d'authentification
    GoRoute(
      path: '/invitation-code',
      builder: (context, state) => const InvitationCodeScreen(),
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
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/subscription-confirmed',
      builder: (context, state) {
        final structureInfo = state.extra as Map<String, dynamic>? ?? {};
        return SubscriptionConfirmedScreen(structureInfo: structureInfo);
      },
    ),
    // Ajout de la route pour l'écran de tarification
    GoRoute(
      path: '/pricing',
      builder: (context, state) {
        final structureInfo = state.extra as Map<String, dynamic>? ?? {};
        return PricingScreen(structureInfo: structureInfo);
      },
    ),
    GoRoute(
      path: '/structure-details',
      builder: (context, state) => const StructureDetailsScreen(),
    ),
    GoRoute(
      path: '/structure-confirmation',
      builder: (context, state) {
        final Map<String, dynamic> structureInfo =
            state.extra as Map<String, dynamic>? ?? {};
        // Extraire le type de structure de structureInfo
        final String structureType =
            structureInfo['structureType'] ?? "Structure inconnue";
        return StructureConfirmationScreen(structureType: structureType);
      },
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) {
        final structureType = state.extra as String? ?? "Structure inconnue";
        return SubscriptionScreen(structureType: structureType);
      },
    ),
    GoRoute(
      path: '/congratulations',
      builder: (context, state) {
        final Map<String, dynamic> structureInfo =
            state.extra as Map<String, dynamic>? ?? {};
        // Extraire le type de structure de structureInfo
        final String structureType =
            structureInfo['structureType'] ?? "Structure inconnue";
        return CongratulationsScreen(structureType: structureType);
      },
    ),
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
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/child-info',
      builder: (context, state) => ChildInfoScreen(),
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
                child:
                    Text("Erreur : Aucun ID d'enfant fourni pour l'adresse")),
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
                  "Erreur : Aucun ID d'enfant fourni pour le second parent"),
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
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour child-pickup-auth");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement child-pickup-auth avec childId: $childId");
        return ChildPickupAuthScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/child-meal-info',
      builder: (context, state) {
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print("⚠️ Erreur : Aucun ID d'enfant fourni pour child-meal-info");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement child-meal-info avec childId: $childId");
        return ChildMealInfoScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/horaires',
      builder: (context, state) => HorairesScreen(),
    ),
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
      path: '/stock',
      builder: (context, state) => const StockScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
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
        final String? childId = state.extra as String?;
        if (childId == null || childId.isEmpty) {
          print(
              "⚠️ Erreur : Aucun ID d'enfant fourni pour child-financial-info");
          return const Scaffold(
            body: Center(child: Text("Erreur : ID d'enfant manquant")),
          );
        }
        print("✅ Chargement child-financial-info avec childId: $childId");
        return ChildFinancialInfoScreen(childId: childId);
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
      builder: (context, state) => const ParentHomeScreen(),
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
    )
  ],
);

// Fonction de redirection pour gérer l'authentification
String? _handleRedirect(BuildContext context, GoRouterState state) {
  // Obtenir l'utilisateur actuel
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Liste des routes accessibles sans authentification
  final List<String> publicRoutes = [
    '/',
    '/signup',
    '/login',
    '/register',
    '/invitation-code',
    '/invitation-validated',
    '/invitation-signup',
    '/pricing',
    '/structure-confirmation',
    '/subscription-confirmed',
  ];

  // Si la route est publique, ne pas rediriger
  if (publicRoutes.contains(state.matchedLocation)) {
    return null;
  }

  // Si l'utilisateur n'est pas connecté et tente d'accéder à une route protégée
  if (currentUser == null) {
    return '/';
  }

  // L'utilisateur est connecté et accède à une route protégée, pas de redirection
  return null;
}
