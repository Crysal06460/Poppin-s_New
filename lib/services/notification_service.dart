import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialise le service de notifications
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔔 Initialisation du service de notifications...');

      // 1. Configuration des notifications locales
      await _initializeLocalNotifications();

      // 2. Configuration Firebase commune
      await _initializeFirebase();

      _isInitialized = true;
      print('✅ Service de notifications initialisé avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation des notifications: $e');
      _isInitialized = true;
    }
  }

  /// Initialisation des notifications locales (iOS + Android)
  static Future<void> _initializeLocalNotifications() async {
    print('📱 Initialisation Flutter Local Notifications (iOS + Android)...');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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

    print('✅ Flutter Local Notifications initialisé');
  }

  /// Initialisation Firebase commune
  static Future<void> _initializeFirebase() async {
    print('🔥 Initialisation Firebase...');

    try {
      // Demander les permissions Firebase
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

      // Configuration spéciale iOS avec APNS
      if (Platform.isIOS) {
        await Future.delayed(Duration(seconds: 1));
        String? apnsToken = await _messaging.getAPNSToken();
        int retryCount = 0;
        const maxRetries = 8;

        while (apnsToken == null && retryCount < maxRetries) {
          print(
              '⏳ Attente du token APNS (tentative ${retryCount + 1}/$maxRetries)...');
          await Future.delayed(Duration(seconds: 3));
          apnsToken = await _messaging.getAPNSToken();
          retryCount++;
        }

        if (apnsToken != null) {
          print('✅ Token APNS obtenu: ${apnsToken.substring(0, 20)}...');
        } else {
          print(
              '❌ Impossible d\'obtenir le token APNS après $maxRetries tentatives');
          print('⚠️ L\'app continue sans notifications push');
          return;
        }
      }

      // Récupérer le token FCM
      try {
        await Future.delayed(Duration(seconds: 2));
        String? token = await _messaging.getToken();

        if (token != null) {
          print('🔥 TOKEN FCM OBTENU: ${token.substring(0, 50)}...');
          await _saveTokenToFirestore(token);
        } else {
          print('❌ Token FCM non disponible');
          print('⚠️ L\'app continue sans notifications push');
          return;
        }
      } catch (e) {
        if (e.toString().contains('SSL error') ||
            e.toString().contains('-1200')) {
          print('⚠️ Erreur SSL détectée, tentative de récupération...');
          await Future.delayed(Duration(seconds: 5));

          try {
            String? token = await _messaging.getToken();
            if (token != null) {
              print('✅ Token FCM récupéré après retry');
              await _saveTokenToFirestore(token);
            }
          } catch (e2) {
            print('❌ Échec retry token FCM: $e2');
            print('⚠️ L\'app continue sans notifications push');
            return;
          }
        } else {
          print('❌ Erreur token FCM: $e');
          print('⚠️ L\'app continue sans notifications push');
          return;
        }
      }

      // Configurer les listeners Firebase
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      try {
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageClick(initialMessage);
        }
      } catch (e) {
        print('⚠️ Erreur getInitialMessage: $e');
      }

      _messaging.onTokenRefresh.listen((String token) {
        print('🔄 Token FCM mis à jour: ${token.substring(0, 50)}...');
        _saveTokenToFirestore(token);
      });

      print('✅ Firebase configuré avec succès');
    } catch (e) {
      print('❌ Erreur Firebase: $e');
      print('⚠️ L\'app continue sans notifications push');
    }
  }

  /// Effacer le badge de notification
  static Future<void> clearBadge() async {
    try {
      print('🔧 Début clearBadge...');

      // Badge unifié avec app_badge_plus
      await AppBadgePlus.updateBadge(0);
      print('✅ Badge réinitialisé');

      // Annuler toutes les notifications
      await _localNotifications.cancelAll();
      print('✅ Toutes les notifications annulées');
    } catch (e) {
      print('❌ Erreur réinitialisation badge: $e');
    }
  }

  /// Définir le badge de notification
  static Future<void> setBadgeCount(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
      print('✅ Badge mis à jour: $count');
    } catch (e) {
      print('❌ Erreur mise à jour badge: $e');
    }
  }

  /// Vérifier si les badges sont supportés
  static Future<bool> isBadgeSupported() async {
    try {
      return await AppBadgePlus.isSupported();
    } catch (e) {
      print('❌ Erreur vérification support badge: $e');
      return false;
    }
  }

  /// Sauvegarder le token FCM dans Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // CORRECTION: Utiliser set avec merge pour créer le document s'il n'existe pas
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email?.toLowerCase())
            .set(
                {
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
              'platform': Platform.isIOS ? 'ios' : 'android',
            },
                SetOptions(
                    merge:
                        true)); // ✅ merge: true crée le document s'il n'existe pas

        print('✅ Token FCM sauvegardé pour ${user.email}');
      } else {
        print('⚠️ Aucun utilisateur connecté pour sauvegarder le token FCM');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde token: $e');
    }
  }

  /// Gérer les messages en foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Message reçu en foreground: ${message.notification?.title}');

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

  /// Gérer les clics sur notifications
  static void _handleMessageClick(RemoteMessage message) {
    print('🔔 Notification cliquée: ${message.data}');
    // Ici vous pouvez naviguer vers l'écran approprié
    // Exemple: NavigationService.navigateToMessages(message.data['childId']);
  }

  /// Envoyer une notification à un utilisateur spécifique
  static Future<void> sendNotificationToUser({
    required String recipientUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Envoi notification vers: $recipientUserId');

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

  /// Méthode pour tester les notifications
  static Future<void> testNotification() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'test_channel',
        'Test',
        channelDescription: 'Notifications de test',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
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

  // === CALLBACKS (iOS + Android) ===

  static void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    print('📱 Notification locale reçue: $title - $body');
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    print('🔔 Réponse notification: ${response.payload}');
  }

  /// Handler global pour les messages Firebase en arrière-plan
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print(
        '📱 Message Firebase en arrière-plan: ${message.notification?.title}');
  }
}
