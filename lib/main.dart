import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // AJOUT : Import pour SystemChrome
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; // 🔥 AJOUT : Import Firebase Functions
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // NOUVEAU : Import pour achats intégrés
import 'package:shared_preferences/shared_preferences.dart'; // ✅ AJOUT CRUCIAL
import 'firebase_options.dart';
import 'routes.dart';

// 🔥 NOUVEL IMPORT POUR LES NOTIFICATIONS
import 'services/notification_service.dart';

// 🛒 NOUVEAU : Import pour les achats intégrés
import 'services/subscription_service.dart';

// Clé globale pour le ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Palette de couleurs officielles de l'application
const Color primaryRed = Color(0xFFD94350); // #D94350
const Color primaryBlue = Color(0xFF3D9DF2); // #3D9DF2
const Color lightBlue = Color(0xFFDFE9F2); // #DFE9F2
const Color brightCyan = Color(0xFF05C7F2); // #05C7F2
const Color primaryYellow = Color(0xFFF2B705); // #F2B705

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOUVEAU : Forcer l'orientation portrait pour toute l'application
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // Suppression de portraitDown pour éviter la rotation 180°
  ]);

  // Initialisation Firebase (utilise les fichiers natifs: GoogleService-Info.plist / google-services.json)
  // Évite les incohérences de bundleId iOS vs firebase_options.dart
  await Firebase.initializeApp();

  // 🔥 NOUVEAU : Configuration Firebase Functions pour la région europe-west1
  // Vos Cloud Functions sont déployées dans cette région
  try {
    // Configuration pour la production (région europe-west1)
    FirebaseFunctions.instanceFor(region: 'europe-west1');
    print('✅ Firebase Functions configuré pour europe-west1');
  } catch (e) {
    print('❌ Erreur configuration Firebase Functions: $e');
  }

  // 🔥 INITIALISER LES NOTIFICATIONS (NON BLOQUANT)
  try {
    // Handler background Android/iOS enregistré au plus tôt (top-level)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await NotificationService.initialize().timeout(
      Duration(seconds: 3),
      onTimeout: () {
        print('⚠️ Timeout notifications - continuer sans');
      },
    );
    print('✅ Notifications initialisées');
  } catch (e) {
    print('⚠️ Erreur notifications: $e - continuer sans');
  }

  // 🔧 FORCER LE MODE DEV pour les tests (INSTANTANÉ)
  SubscriptionService.setDebugMode(true);
  print('🧪 Mode debug activé pour SubscriptionService');

  // ⚡ SUPPRIMÉ LA LIGNE QUI BLOQUAIT LE DÉMARRAGE :
  // await SubscriptionService.initialize(); // ← Cette ligne prenait 10-30 secondes !

  // ✅ MAINTENANT : Services initialisés dans SplashScreen avec feedback utilisateur

  print('🚀 Démarrage rapide de Poppins - Services en arrière-plan');

  // Lance l'application après que Firebase soit initialisé
  runApp(const PoppinsApp());
}

// MODIFICATION : Changement de StatelessWidget vers StatefulWidget
class PoppinsApp extends StatefulWidget {
  const PoppinsApp({Key? key}) : super(key: key);

  @override
  State<PoppinsApp> createState() => _PoppinsAppState();
}

// NOUVEAU : State class avec WidgetsBindingObserver
class _PoppinsAppState extends State<PoppinsApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Forcer l'orientation au démarrage
    _setPortraitOrientation();
  }

  @override
  void dispose() {
    // 🛒 AJOUT : Nettoyer les ressources SubscriptionService
    SubscriptionService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🔑 GESTION CRITIQUE DU CYCLE DE VIE - MODIFIÉE POUR LE SYSTÈME DE SÉCURITÉ
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    // Remettre en portrait si nécessaire
    if (state == AppLifecycleState.resumed) {
      _setPortraitOrientation();
    }

    // 🔒 GESTION DU CYCLE DE VIE POUR LA SÉCURITÉ
    try {
      final prefs = await SharedPreferences.getInstance();

      print("🔄 Cycle de vie changé: $state");

      switch (state) {
        case AppLifecycleState.paused:
          // App mise en arrière-plan (pas fermée)
          await prefs.setBool('app_killed', false);
          print("📱 App mise en arrière-plan");
          break;

        case AppLifecycleState.inactive:
          // App temporairement inactive (ex: bouton Home)
          await prefs.setBool('app_killed', false);
          print("⏸️ App temporairement inactive");
          break;

        case AppLifecycleState.detached:
          // App fermée complètement
          await prefs.setBool('app_killed', true);
          print("❌ App fermée complètement");
          break;

        case AppLifecycleState.resumed:
          // App revenue au premier plan
          print("✅ App revenue au premier plan");
          break;

        case AppLifecycleState.hidden:
          break;
      }
    } catch (e) {
      print("⚠️ Erreur sauvegarde cycle de vie: $e");
    }
  }

  // NOUVEAU : Méthode pour forcer l'orientation portrait
  void _setPortraitOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "Poppin's", // Nom mis à jour de l'application
      scaffoldMessengerKey: scaffoldMessengerKey, // Ajout de la clé globale

      // Ajout des délégués de localisation
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Prise en charge des locales
      supportedLocales: const [
        Locale('fr', 'FR'), // Français (primaire)
        Locale('en', 'US'), // Anglais (secondaire)
      ],
      // Définir le français comme locale par défaut
      locale: const Locale('fr', 'FR'),

      theme: ThemeData(
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.light(
          primary: primaryBlue,
          secondary: brightCyan,
          error: primaryRed,
          background: Colors.white,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: primaryBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: BorderSide(color: primaryBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBlue,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          labelStyle: TextStyle(color: primaryBlue),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey[300],
          thickness: 1,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
        ),
      ),
      routerConfig: router,
    );
  }
}
