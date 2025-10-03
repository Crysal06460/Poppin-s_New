import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:poppins_app/routes.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Top-level background handler (recommandé par firebase_messaging)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('📱 (BG) Message Firebase: ${message.notification?.title}');
  } catch (e) {
    // Garder minimal pour l'isolement background
    // ignore: avoid_print
    print('⚠️ Erreur handler BG: $e');
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static bool _timezoneInitialized = false;

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
      _isInitialized = false;
      rethrow;
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

    // Création explicite du canal Android utilisé par FCM et les locales
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'messages_channel', // DOIT correspondre au Manifest et aux payloads FCM
        'Messages',
        description: 'Notifications pour les nouveaux messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      const AndroidNotificationChannel agendaChannel = AndroidNotificationChannel(
        'agenda_reminders_channel',
        'Agenda',
        description: 'Notifications pour les rappels agenda',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.createNotificationChannel(agendaChannel);
      print('✅ Canal Android créé');

      // Android 13+ : demander explicitement la permission via permission_handler
      if (Platform.isAndroid) {
        try {
          final status = await Permission.notification.status;
          if (!status.isGranted) {
            final result = await Permission.notification.request();
            print('🔔 Permission notifications Android: $result');
          }
        } catch (e) {
          print('⚠️ Impossible de demander la permission Android: $e');
        }
      }
    } catch (e) {
      print(
          '⚠️ Impossible de créer le canal Android ou de demander la permission: $e');
    }

    print('✅ Flutter Local Notifications initialisé');
    await _ensureTimezoneInitialized();
  }

  static Future<void> _ensureTimezoneInitialized() async {
    if (_timezoneInitialized) return;
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _timezoneInitialized = true;
      print('🕑 Fuseau horaire initialisé: $timeZoneName');
    } catch (e) {
      print('⚠️ Impossible de récupérer le fuseau horaire local: $e');
      try {
        const fallbackZone = 'Europe/Paris';
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation(fallbackZone));
        _timezoneInitialized = true;
        print('🕑 Fuseau horaire fallback utilisé: $fallbackZone');
      } catch (fallbackError) {
        print('⚠️ Échec fallback fuseau horaire: $fallbackError');
        tz.initializeTimeZones();
        _timezoneInitialized = true;
        print('🕑 Fuseau horaire UTC appliqué par défaut');
      }
    }
  }

  /// 🔥 NOUVELLES MÉTHODES : Force la sauvegarde des tokens
  static Future<void> refreshTokenForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseMessaging.instance.deleteToken();
      final newToken = await FirebaseMessaging.instance.getToken();

      if (newToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email?.toLowerCase())
            .update({
          'fcmToken': newToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Token FCM mis à jour: ${newToken.substring(0, 20)}...');
      }
    } catch (e) {
      print('❌ Erreur refresh token: $e');
    }
  }

  /// Méthode de diagnostic des tokens
  static Future<void> diagnoseTokens() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('🔑 Token FCM actuel: $fcmToken');

      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      print('🍎 Token APNs: $apnsToken');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email?.toLowerCase())
            .get();

        print('💾 Token en base: ${userDoc.data()?['fcmToken']}');
      }
    } catch (e) {
      print('❌ Erreur diagnostic: $e');
    }
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
        // Ne pas supprimer le token FCM existant. On s'appuie sur onTokenRefresh.
        // Tenter de récupérer APNS (non bloquant). Ne pas quitter en cas d'échec.
        try {
          await Future.delayed(Duration(seconds: 2));
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
            print('⚠️ Token APNS indisponible pour le moment – on poursuit.');
          }
        } catch (e) {
          print('⚠️ Erreur récupération APNS: $e – on poursuit');
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
          print(
              '⚠️ Token FCM non disponible pour le moment – en attente onTokenRefresh');
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
            print('⚠️ On attendra onTokenRefresh');
          }
        } else {
          print('❌ Erreur token FCM: $e');
          print('⚠️ On attendra onTokenRefresh');
        }
      }

      // iOS: afficher notifications APNS en foreground
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        print('⚠️ Erreur setForegroundNotificationPresentationOptions: $e');
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

  /// Planifie une notification locale pour un rappel agenda
  static Future<void> scheduleAgendaReminder({
    required String entryId,
    required DateTime scheduledAt,
    required String title,
    String? body,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      await _ensureTimezoneInitialized();

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime scheduledDate =
          tz.TZDateTime.from(scheduledAt, tz.local);

      if (!scheduledDate.isAfter(now)) {
        await cancelAgendaReminder(entryId);
        print('⏳ Rappel agenda ignoré (date passée) : $scheduledDate');
        return;
      }

      await cancelAgendaReminder(entryId);

      final int notificationId = _agendaNotificationId(entryId);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'agenda_reminders_channel',
        'Agenda',
        channelDescription: 'Notifications pour les rappels agenda',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.zonedSchedule(
        notificationId,
        title.isEmpty ? 'Rappel agenda' : title,
        (body != null && body.trim().isNotEmpty)
            ? body
            : 'N\'oublie pas ton rappel',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        payload: jsonEncode({
          'type': 'agenda',
          'entryId': entryId,
        }),
      );

      print('✅ Rappel agenda planifié pour $scheduledDate (id=$entryId)');
    } catch (e) {
      print('⚠️ Impossible de planifier le rappel agenda ($entryId): $e');
    }
  }

  /// Annule une notification locale pour un rappel agenda
  static Future<void> cancelAgendaReminder(String entryId) async {
    try {
      final int notificationId = _agendaNotificationId(entryId);
      await _localNotifications.cancel(notificationId);
      print('🧹 Rappel agenda annulé (id=$entryId)');
    } catch (e) {
      print('⚠️ Impossible d\'annuler le rappel agenda ($entryId): $e');
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

    // iOS: on a activé setForegroundNotificationPresentationOptions(alert: true)
    // pour laisser iOS afficher la notif distante. Ne pas dupliquer avec une locale.
    if (Platform.isIOS) {
      return;
    }

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
      // Utiliser JSON pour décodage fiable lors du clic
      payload: jsonEncode(message.data),
    );
  }

  /// Gérer les clics sur notifications
  static void _handleMessageClick(RemoteMessage message) {
    print('🔔 Notification cliquée: ${message.data}');
    try {
      final type = (message.data['type'] ?? '').toString();
      if (type == 'stock') {
        // Ouvrir l'écran stocks parent
        router.go('/parent/stocks');
        return;
      }
      // À défaut, ne rien faire (ou ouvrir messages si vous le souhaitez)
    } catch (e) {
      print('⚠️ Erreur navigation clic notification: $e');
    }
  }

  // notification_service.dart
  static Future<void> sendNotificationToUser({
    required String recipientUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final normalizedRecipient =
          recipientUserId.trim().toLowerCase(); // ⬅️ clé
      print('📤 Envoi notification vers: $normalizedRecipient');

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUserId': normalizedRecipient,
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('❌ Erreur envoi notif: $e');
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
    // Gestion du clic sur notification locale (Android foreground)
    try {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        final type = (data['type'] ?? '').toString();
        if (type == 'stock') {
          router.go('/parent/stocks');
          return;
        }
      }
    } catch (e) {
      // Fallback si payload n'est pas du JSON
      final payload = response.payload ?? '';
      if (payload.contains('type') && payload.contains('stock')) {
        router.go('/parent/stocks');
      } else {
        print('⚠️ Payload non JSON ou navigation non traitée');
      }
    }
  }

  /// Handler global pour les messages Firebase en arrière-plan
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print(
        '📱 Message Firebase en arrière-plan: ${message.notification?.title}');
  }

  static int _agendaNotificationId(String entryId) =>
      entryId.hashCode & 0x7fffffff;
}
