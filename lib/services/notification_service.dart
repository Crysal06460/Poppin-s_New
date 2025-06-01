import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Dans notification_service.dart, remplacez le début de la méthode initialize() :

  static Future<void> initialize() async {
    try {
      print('🔔 Initialisation du service de notifications...');

      // 1. 🔥 NOUVEAU : Demander les permissions avec gestion améliorée
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        carPlay: false,
        criticalAlert: false,
        announcement: false,
      );

      print('🔔 Permissions accordées: ${settings.authorizationStatus}');

      // 🔥 CORRECTION : Accepter aussi 'provisional' et 'notDetermined' sur iOS
      bool permissionsOk =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      // Sur iOS, parfois les permissions restent 'notDetermined' mais fonctionnent quand même
      if (Platform.isIOS &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        print('⚠️ Permissions iOS notDetermined, tentative de continuation...');
        permissionsOk = true; // Essayer quand même sur iOS
      }

      if (!permissionsOk &&
          settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ Permissions notifications refusées définitivement');
        print('⚠️ L\'app continue sans notifications push');
        await _setupLocalNotificationsOnly();
        return;
      }

      // 2. Configuration spéciale iOS avec APNS
      if (Platform.isIOS) {
        print('📱 Configuration iOS avec APNS...');

        // 🔥 NOUVEAU : Attendre un peu plus longtemps pour iOS
        await Future.delayed(Duration(seconds: 1));

        // Attendre que le token APNS soit disponible
        String? apnsToken = await _messaging.getAPNSToken();
        int retryCount = 0;
        const maxRetries = 8; // Augmenté de 5 à 8

        while (apnsToken == null && retryCount < maxRetries) {
          print(
              '⏳ Attente du token APNS (tentative ${retryCount + 1}/$maxRetries)...');
          await Future.delayed(
              Duration(seconds: 3)); // Augmenté de 2 à 3 secondes
          apnsToken = await _messaging.getAPNSToken();
          retryCount++;
        }

        if (apnsToken != null) {
          print('✅ Token APNS obtenu: ${apnsToken.substring(0, 20)}...');
        } else {
          print(
              '❌ Impossible d\'obtenir le token APNS après $maxRetries tentatives');
          print('⚠️ L\'app continue sans notifications push');
          await _setupLocalNotificationsOnly();
          return;
        }
      }

      // 3. Configuration des notifications locales
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true, // 🔥 CHANGÉ : Redemander ici aussi
        requestBadgePermission: true, // 🔥 CHANGÉ : Redemander ici aussi
        requestSoundPermission: true, // 🔥 CHANGÉ : Redemander ici aussi
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // 4. 🔥 AMÉLIORÉ : Récupérer le token FCM avec gestion d'erreur SSL
      print('🔄 Récupération du token FCM...');
      String? token;

      try {
        // Attendre un peu avant de demander le token FCM
        await Future.delayed(Duration(seconds: 2));
        token = await _messaging.getToken();
      } catch (e) {
        if (e.toString().contains('SSL error') ||
            e.toString().contains('-1200')) {
          print('⚠️ Erreur SSL détectée, tentative de récupération...');

          // Attendre plus longtemps et réessayer
          await Future.delayed(Duration(seconds: 5));

          try {
            token = await _messaging.getToken();
            print('✅ Token FCM récupéré après retry');
          } catch (e2) {
            print('❌ Échec retry token FCM: $e2');
            print('⚠️ L\'app continue sans notifications push');

            // Continuer avec les notifications locales uniquement
            await _setupLocalNotificationsOnly();
            return;
          }
        } else {
          print('❌ Erreur non-SSL lors récupération token: $e');
          print('⚠️ L\'app continue sans notifications push');
          await _setupLocalNotificationsOnly();
          return;
        }
      }

      if (token != null) {
        print('🔥 TOKEN FCM OBTENU: ${token.substring(0, 50)}...');
        await _saveTokenToFirestore(token);
      } else {
        print('❌ Token FCM non disponible');
        print('⚠️ L\'app continue sans notifications push');
        await _setupLocalNotificationsOnly();
        return;
      }

      // 5. Écouter les messages en foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6. Écouter les clics sur notifications
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      // 7. Gérer les messages reçus quand l'app était fermée
      try {
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageClick(initialMessage);
        }
      } catch (e) {
        print('⚠️ Erreur getInitialMessage: $e');
      }

      // 8. Écouter les changements de token
      _messaging.onTokenRefresh.listen((String token) {
        print('🔄 Token FCM mis à jour: ${token.substring(0, 50)}...');
        _saveTokenToFirestore(token);
      });

      print('✅ Service de notifications initialisé avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des notifications: $e');

      // Si c'est une erreur SSL ou permissions, continuer sans crash
      if (e.toString().contains('SSL error') ||
          e.toString().contains('-1200') ||
          e.toString().contains('permission')) {
        print('⚠️ L\'app continue sans notifications push à cause de: $e');
        await _setupLocalNotificationsOnly();
        return;
      }

      // Pour les autres erreurs, ne pas crasher non plus
      print('⚠️ L\'app continue malgré l\'erreur: $e');
      await _setupLocalNotificationsOnly();
    }
  }

// 🔥 NOUVELLE MÉTHODE : Configuration notifications locales uniquement
  static Future<void> _setupLocalNotificationsOnly() async {
    try {
      print('🔧 Configuration notifications locales uniquement...');

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      print('✅ Notifications locales configurées (sans push)');
    } catch (e) {
      print('❌ Erreur configuration notifications locales: $e');
    }
  }

  static Future<void> clearBadge() async {
    try {
      print('🔧 Début clearBadge...');

      // Réinitialiser le badge avec flutter_app_badger
      await FlutterAppBadger.removeBadge();
      print('✅ FlutterAppBadger.removeBadge() terminé');

      // Force à 0 explicitement
      await FlutterAppBadger.updateBadgeCount(0);
      print('✅ FlutterAppBadger.updateBadgeCount(0) terminé');

      // Annuler toutes les notifications locales
      await _localNotifications.cancelAll();
      print('✅ _localNotifications.cancelAll() terminé');

      print('✅ Badge réinitialisé complètement');
    } catch (e) {
      print('❌ Erreur réinitialisation badge: $e');
    }
  }

// Méthode pour définir le nombre du badge
  static Future<void> setBadgeCount(int count) async {
    try {
      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
      } else {
        await FlutterAppBadger.removeBadge();
      }
      print('✅ Badge mis à jour: $count');
    } catch (e) {
      print('❌ Erreur mise à jour badge: $e');
    }
  }

// Méthode pour vérifier si les badges sont supportés
  static Future<bool> isBadgeSupported() async {
    return await FlutterAppBadger.isAppBadgeSupported();
  }

  // Callback pour les notifications locales iOS (anciennes versions)
  static void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    print('📱 Notification locale reçue: $title - $body');
  }

  // Callback pour les réponses aux notifications
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    print('🔔 Réponse notification: ${response.payload}');
    // Ici vous pouvez naviguer vers l'écran approprié
  }

  // Sauvegarder le token FCM dans Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email?.toLowerCase())
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        });
        print('✅ Token FCM sauvegardé pour ${user.email}');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde token: $e');
    }
  }

  // Gérer les messages en foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Message reçu en foreground: ${message.notification?.title}');

    // Afficher notification locale
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications pour les nouveaux messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'message_category',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nouveau message',
      message.notification?.body ?? 'Vous avez reçu un nouveau message',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // Gérer les clics sur notifications
  static void _handleMessageClick(RemoteMessage message) {
    print('🔔 Notification cliquée: ${message.data}');
    // Ici vous pouvez naviguer vers l'écran approprié
    // Exemple: NavigationService.navigateToMessages(message.data['childId']);
  }

  // Envoyer une notification à un utilisateur spécifique
  static Future<void> sendNotificationToUser({
    required String recipientUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Envoi notification vers: $recipientUserId');

      // Créer le document dans Firestore pour déclencher la Cloud Function
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUserId': recipientUserId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      print('✅ Document notification créé dans Firestore');
    } catch (e) {
      print('❌ Erreur envoi notification: $e');
    }
  }

  // Méthode pour tester les notifications
  static Future<void> testNotification() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'test_channel',
        'Test',
        channelDescription: 'Notifications de test',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        123,
        'Test Notification',
        'Ceci est un test des notifications',
        notificationDetails,
      );

      print('✅ Notification de test envoyée');
    } catch (e) {
      print('❌ Erreur test notification: $e');
    }
  }
}
