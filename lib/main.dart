import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'routes.dart';

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

  // Initialisation de Firebase avec les options spécifiques à la plateforme
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Lance l'application après que Firebase soit initialisé
  runApp(const PoppinsApp());
}

class PoppinsApp extends StatelessWidget {
  const PoppinsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Poppins', // Nom mis à jour de l'application
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
        cardTheme: CardTheme(
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
