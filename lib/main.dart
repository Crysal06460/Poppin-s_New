import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'routes.dart';
import 'theme/app_colors.dart';
import 'firebase_options.dart';
import 'features/aide/aide_floating_button.dart';
import 'features/aide/aide_route_observer.dart';
import 'widgets/remplacement_banner.dart';

import 'services/notification_service.dart';
import 'services/subscription_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const Color primaryRed = Color(0xFFD94350);
const Color primaryBlue = Color(0xFF3D9DF2);
const Color lightBlue = Color(0xFFDFE9F2);
const Color brightCyan = Color(0xFF05C7F2);
const Color primaryYellow = Color(0xFFF2B705);

List<DeviceOrientation>? _preferredOrientationsForCurrentView() {
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final ui.FlutterView? view = dispatcher.views.isNotEmpty
      ? dispatcher.views.first
      : dispatcher.implicitView;
  if (view == null) {
    return null;
  }

  final Size physicalSize = view.physicalSize;
  if (physicalSize.width == 0 || physicalSize.height == 0) {
    return null;
  }

  double devicePixelRatio = view.devicePixelRatio;
  if (devicePixelRatio <= 0) {
    devicePixelRatio = 1;
  }

  final double logicalWidth = physicalSize.width / devicePixelRatio;
  final double logicalHeight = physicalSize.height / devicePixelRatio;
  final double shortestSide = math.min(logicalWidth, logicalHeight);
  final bool isTablet = shortestSide >= 600;

  return isTablet
      ? const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const [
          DeviceOrientation.portraitUp,
        ];
}

Future<void> _setPreferredOrientationsForCurrentView() async {
  final orientations = _preferredOrientationsForCurrentView();
  if (orientations != null) {
    await SystemChrome.setPreferredOrientations(orientations);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _setPreferredOrientationsForCurrentView();

  // ✅ CORRECTION : Firebase.initializeApp() AVANT d'utiliser FirebaseMessaging
  await Firebase.initializeApp();

  // ❌ RETIRE CES LIGNES - NE FONCTIONNE PAS SUR iOS ICI
  // String? token = await FirebaseMessaging.instance.getToken();
  // print('🔑 MON TOKEN FCM : $token');

  try {
    FirebaseFunctions.instanceFor(region: 'europe-west1');
    print('✅ Firebase Functions configuré pour europe-west1');
  } catch (e) {
    print('❌ Erreur configuration Firebase Functions: $e');
  }

  // 🔥 INITIALISER LES NOTIFICATIONS (NON BLOQUANT)
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await NotificationService.initialize().timeout(
      Duration(seconds: 3),
      onTimeout: () {
        print('⚠️ Timeout notifications - continuer sans');
      },
    );
    print('✅ Notifications initialisées');

    // ✅ OBTENIR LE TOKEN ICI (après l'initialisation des notifications)
    try {
      // Attendre un peu pour iOS
      await Future.delayed(Duration(milliseconds: 500));
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('╔═══════════════════════════════════════╗');
        print('🔑 MON TOKEN FCM : $token');
        print('╚═══════════════════════════════════════╝');

        // 💾 Sauvegarder le token pour l'afficher plus tard
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        try {
          await FirebaseMessaging.instance.subscribeToTopic('all_users');
          print('✅ Abonné au topic all_users');
        } catch (e) {
          print('⚠️ Impossible de s\'abonner au topic all_users: $e');
        }
      } else {
        print('⚠️ Token null - sera disponible après autorisation');
      }
    } catch (e) {
      print('⚠️ Token FCM pas encore disponible: $e');
      print('💡 Le token sera disponible après autorisation des notifications');
    }

    try {
      await NotificationService.clearBadge();
    } catch (e) {
      print('⚠️ Impossible de réinitialiser le badge au démarrage: $e');
    }
  } catch (e) {
    print('⚠️ Erreur notifications: $e - continuer sans');
  }

  try {
    print('🚨 FIX ANDROID : Initialisation SubscriptionService...');
    SubscriptionService.setDebugMode(kDebugMode);

    if (Platform.isAndroid) {
      print('🤖 ANDROID détecté : initialisation forcée...');
      await SubscriptionService.initialize().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print(
              '⚠️ Timeout SubscriptionService Android - continuer avec debug');
        },
      );
      print('✅ SubscriptionService initialisé pour Android');
    } else {
      print(
          '📱 iOS détecté : SubscriptionService sera initialisé dans SplashScreen');
    }
  } catch (e) {
    print('⚠️ Erreur SubscriptionService: $e - continuer avec mode debug');
    if (kDebugMode) {
      SubscriptionService.setDebugMode(true);
    }
  }

  print('🚀 Démarrage Poppins - Fix Android appliqué, iOS préservé');
  runApp(const PoppinsApp());
}

class PoppinsApp extends StatefulWidget {
  const PoppinsApp({Key? key}) : super(key: key);

  @override
  State<PoppinsApp> createState() => _PoppinsAppState();
}

class _PoppinsAppState extends State<PoppinsApp> with WidgetsBindingObserver {
  bool? _lastIsTabletForOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    attachAideRouteTracking(router);
    _applyPreferredOrientations(force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPreferredOrientations(force: true);
      NotificationService.synchronizeMissedNotifications();
      NotificationService.showPendingNotificationWhenReady();
    });
  }

  @override
  void dispose() {
    SubscriptionService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _applyPreferredOrientations();
      try {
        NotificationService.clearBadge();
        NotificationService.synchronizeMissedNotifications();
        NotificationService.showPendingNotificationWhenReady();
      } catch (e) {
        print('⚠️ Impossible de clear le badge en reprise: $e');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      print("🔄 Cycle de vie changé: $state");

      switch (state) {
        case AppLifecycleState.paused:
          await prefs.setBool('app_killed', false);
          print("📱 App mise en arrière-plan");
          break;
        case AppLifecycleState.inactive:
          await prefs.setBool('app_killed', false);
          print("⏸️ App temporairement inactive");
          break;
        case AppLifecycleState.detached:
          await prefs.setBool('app_killed', true);
          print("❌ App fermée complètement");
          break;
        case AppLifecycleState.resumed:
          print("✅ App revenue au premier plan");
          break;
        case AppLifecycleState.hidden:
          break;
      }
    } catch (e) {
      print("⚠️ Erreur sauvegarde cycle de vie: $e");
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _applyPreferredOrientations();
  }

  Future<void> _applyPreferredOrientations({bool force = false}) async {
    if (!mounted) return;

    final orientations = _preferredOrientationsForCurrentView();
    if (orientations == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyPreferredOrientations(force: force);
        }
      });
      return;
    }

    final bool isTablet = orientations.length > 1;
    if (!force && _lastIsTabletForOrientation == isTablet) {
      return;
    }

    _lastIsTabletForOrientation = isTablet;
    await SystemChrome.setPreferredOrientations(orientations);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "Poppin's",
      scaffoldMessengerKey: scaffoldMessengerKey,
      builder: (context, child) {
        return ColoredBox(
          color: kAppBackgroundColor,
          child: Stack(
            children: [
              RemplacementBannerOverlay(
                child: child ?? const SizedBox.shrink(),
              ),
              const AideFloatingButton(),
            ],
          ),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      theme: ThemeData(
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.light(
          primary: primaryBlue,
          secondary: brightCyan,
          error: primaryRed,
          background: kAppBackgroundColor,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: kAppBackgroundColor,
        canvasColor: kAppBackgroundColor,
        fontFamily: 'Roboto',
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
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
