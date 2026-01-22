import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:poppins_app/routes.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background handler (recommandé par firebase_messaging)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('📱 (BG) Message Firebase: ${message.notification?.title}');
    await NotificationService.handleBackgroundMessage(message);
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
  static final List<Map<String, dynamic>> _pendingNotificationQueue = [];
  static bool _isDisplayingNotification = false;
  static bool _authLockActive = false;
  static bool _syncInProgress = false;
  static const String _persistedNotificationsKey =
      'notification_service.pending_info_notifications';
  static const String _deliveredNotificationIdsKey =
      'notification_service.delivered_info_ids';
  static bool _restoringPersistedNotifications = false;
  static final Set<String> _processedNotificationIds = <String>{};
  static final List<String> _processedNotificationIdOrder = <String>[];
  static final Set<String> _queuedNotificationIds = <String>{};
  static bool _deliveredIdsLoaded = false;

  /// Initialise le service de notifications
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔔 Initialisation du service de notifications...');

      // 1. Configuration des notifications locales
      await _initializeLocalNotifications();

      // 2. Configuration Firebase commune
      await _initializeFirebase();
      await _loadDeliveredNotificationHistory();
      await _maybeRestorePersistedNotifications();

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

      const AndroidNotificationChannel agendaChannel =
          AndroidNotificationChannel(
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

    // ANDROID : Vérifier les doublons
    final String msgId = message.messageId ?? '';
    if (msgId.isNotEmpty && _processedNotificationIds.contains(msgId)) {
      print('🔕 Notification foreground ignorée (déjà traitée): $msgId');
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

    final Map<String, dynamic> payloadData = {
      ...message.data,
      '_notificationTitle': message.notification?.title ?? '',
      '_notificationBody': message.notification?.body ?? '',
    };

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nouveau message',
      message.notification?.body ?? 'Vous avez reçu un nouveau message',
      notificationDetails,
      payload: jsonEncode(payloadData),
    );

    // Marquer comme traité pour éviter redite
    if (msgId.isNotEmpty) {
      _markNotificationAsDelivered(msgId);
    }
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
      if (_shouldDisplayInfoPopup(type, message.data)) {
        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            'Notification';
        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            '';
        _queueInformationalNotification(
          title: title,
          body: body,
          data: {
            ...message.data,
            if (!message.data.containsKey('notificationId') &&
                message.messageId != null &&
                message.messageId!.isNotEmpty)
              'notificationId': message.messageId!,
            '_notificationTitle': title,
            '_notificationBody': body,
          },
        );
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

  static bool _shouldDisplayInfoPopup(
      String rawType, Map<String, dynamic> data) {
    final type = rawType.toLowerCase().trim();

    if (_looksLikeMessageNotification(type, data)) {
      return false;
    }

    const suppressedTypes = {
      'stock',
    };
    if (suppressedTypes.contains(type)) {
      return false;
    }

    const infoTypes = {
      'info',
      'broadcast',
      'announcement',
      'news',
      'general',
      'general_notification',
      'general-notification',
      'generalnotif',
      'alert',
      'test',
    };

    if (type.isEmpty) {
      return true;
    }

    if (infoTypes.contains(type)) {
      return true;
    }

    return true;
  }

  // Offre une heuristique souple pour reconnaître les notifications de messagerie
  // (messages privés, conversations, chat, etc.) afin d'éviter les popups bloquants.
  static bool _looksLikeMessageNotification(
      String lowerType, Map<String, dynamic> data) {
    final normalizedType = lowerType.toLowerCase();
    const typeHints = {
      'message',
      'messages',
      'message_parent',
      'message-parent',
      'parent_message',
      'parent-message',
      'new_message',
      'new-message',
      'chat',
      'chat_message',
      'chat-message',
      'conversation',
      'conversation_message',
      'conversation-message',
      'direct_message',
      'direct-message',
    };
    if (typeHints.contains(normalizedType)) {
      return true;
    }

    if (normalizedType.contains('message') ||
        normalizedType.contains('chat') ||
        normalizedType.contains('conversation')) {
      return true;
    }

    if (data.isEmpty) {
      return false;
    }

    final Set<String> lowerCaseKeys =
        data.keys.map((key) => key.toString().toLowerCase()).toSet();
    const keyHints = {
      'messageid',
      'message_id',
      'messagekey',
      'message_key',
      'messageref',
      'message_ref',
      'messagetype',
      'message_type',
      'conversationid',
      'conversation_id',
      'conversationpath',
      'conversation_path',
      'chatid',
      'chat_id',
      'threadid',
      'thread_id',
      'senderid',
      'sender_id',
      'receiverid',
      'receiver_id',
      'recipientid',
      'recipient_id',
      'exchangeid',
      'exchange_id',
    };
    if (lowerCaseKeys.any((key) =>
        keyHints.contains(key) ||
        key.contains('message') ||
        key.contains('chat') ||
        key.contains('conversation'))) {
      return true;
    }

    final List<String> indicatorFields = [
      'category',
      'notificationCategory',
      'notificationcategory',
      'notificationType',
      'notificationtype',
      'notification_type',
      'messageCategory',
      'messagecategory',
      'messageType',
      'messagetype',
      'eventType',
      'eventtype',
    ];

    for (final field in indicatorFields) {
      final dynamic value = data[field];
      if (value == null) continue;
      final String normalizedValue = value.toString().toLowerCase();
      if (normalizedValue.contains('message') ||
          normalizedValue.contains('chat') ||
          normalizedValue.contains('conversation')) {
        return true;
      }
    }

    // Conserver l'ancienne heuristique basée sur childId/messageId.
    if (data.containsKey('messageId') ||
        data.containsKey('message_id') ||
        data.containsKey('childId') ||
        data.containsKey('child_id')) {
      return true;
    }

    return false;
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
        if (_shouldDisplayInfoPopup(type, data)) {
          final title =
              (data['_notificationTitle'] ?? data['title'] ?? 'Notification')
                  .toString();
          final body =
              (data['_notificationBody'] ?? data['body'] ?? '').toString();
          _queueInformationalNotification(
            title: title,
            body: body,
            data: data,
          );
          return;
        }
      }
    } catch (e) {
      // Fallback si payload n'est pas du JSON
      final payload = response.payload ?? '';
      if (payload.contains('type') && payload.contains('stock')) {
        router.go('/parent/stocks');
        return;
      }
      final trimmed = payload.trim();
      if (trimmed.isNotEmpty && trimmed != '{}') {
        _queueInformationalNotification(
          title: 'Notification',
          body: trimmed,
          data: {'rawPayload': trimmed},
        );
      }
      print('⚠️ Payload non JSON ou navigation non traitée');
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

  static void _queueInformationalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final sanitizedData = Map<String, dynamic>.from(data);
    final notificationId = _extractNotificationId(sanitizedData);

    if (notificationId != null &&
        (_processedNotificationIds.contains(notificationId) ||
            _queuedNotificationIds.contains(notificationId))) {
      print('ℹ️ Notification ignorée (doublon en mémoire) ($notificationId)');
      return;
    }

    _pendingNotificationQueue.add({
      'title': title,
      'body': body,
      'data': sanitizedData,
    });
    if (notificationId != null) {
      _queuedNotificationIds.add(notificationId);
    }

    if (_authLockActive) {
      print('🔒 Notification en attente (auth requise)');
      unawaited(_persistNotificationRecord(
        title: title,
        body: body,
        data: sanitizedData,
      ));
      return;
    }

    showPendingNotificationWhenReady();
  }

  static String? _extractNotificationId(Map<String, dynamic> data) {
    final dynamic directId = data['notificationId'] ??
        data['notification_id'] ??
        data['id'];
    if (directId == null) {
      return null;
    }
    final String candidate = directId.toString().trim();
    if (candidate.isEmpty) {
      return null;
    }
    return candidate;
  }

  static Future<void> _loadDeliveredNotificationHistory() async {
    if (_deliveredIdsLoaded) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> storedIds =
          prefs.getStringList(_deliveredNotificationIdsKey) ?? <String>[];
      for (final rawId in storedIds) {
        final id = rawId.trim();
        if (id.isEmpty) continue;
        _processedNotificationIds.add(id);
        _processedNotificationIdOrder.add(id);
      }
      // Garder la même taille max que la mémoire
      const int maxHistory = 120;
      if (_processedNotificationIdOrder.length > maxHistory) {
        _processedNotificationIdOrder.removeRange(
            0, _processedNotificationIdOrder.length - maxHistory);
        _processedNotificationIds
          ..clear()
          ..addAll(_processedNotificationIdOrder);
      }
      _deliveredIdsLoaded = true;
      print(
          '📦 Historique de notifications livrées chargé (${_processedNotificationIdOrder.length})');
    } catch (e) {
      print(
          '⚠️ Impossible de charger l\'historique des notifications livrées: $e');
    }
  }

  static Future<void> _persistDeliveredNotificationHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _deliveredNotificationIdsKey,
        List<String>.from(_processedNotificationIdOrder),
      );
    } catch (e) {
      print(
          '⚠️ Impossible de persister l\'historique des notifications livrées: $e');
    }
  }

  static void _markNotificationAsDelivered(String id) {
    if (id.isEmpty) {
      return;
    }
    if (_processedNotificationIds.contains(id)) {
      return;
    }
    _processedNotificationIds.add(id);
    _processedNotificationIdOrder.add(id);
    const int maxHistory = 120;
    if (_processedNotificationIdOrder.length > maxHistory) {
      final String oldest = _processedNotificationIdOrder.removeAt(0);
      _processedNotificationIds.remove(oldest);
    }
    // Persister pour éviter les doublons multiplateformes et multi-lancements
    unawaited(_persistDeliveredNotificationHistory());
  }

  static void showPendingNotificationWhenReady() {
    Future.microtask(_maybeRestorePersistedNotifications);
    if (_pendingNotificationQueue.isEmpty) {
      return;
    }

    Future.microtask(() async {
      await _displayNextPendingNotification();
    });
  }

  static void setAuthenticationRequired(bool required) {
    _authLockActive = required;
    if (!required) {
      showPendingNotificationWhenReady();
    } else {
      for (final payload in _pendingNotificationQueue) {
        try {
          final Map<String, dynamic> data = Map<String, dynamic>.from(
              payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
          final String title = (payload['title'] ?? '').toString();
          final String body = (payload['body'] ?? '').toString();
          unawaited(_persistNotificationRecord(
            title: title.isEmpty ? 'Notification' : title,
            body: body,
            data: data,
          ));
        } catch (e) {
          print('⚠️ Impossible de persister une notification en attente: $e');
        }
      }
      print('🔒 Verrou notifications activé (auth requise)');
    }
  }

  static Future<void> _displayNextPendingNotification() async {
    if (_authLockActive) {
      print('🔒 Notification différée (auth non validée)');
      return;
    }

    if (_isDisplayingNotification) {
      return;
    }

    if (_pendingNotificationQueue.isEmpty) {
      return;
    }

    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null || !navigatorState.mounted) {
      print('⚠️ Navigator non prêt - notification conservée');
      Future.delayed(
          const Duration(milliseconds: 300), showPendingNotificationWhenReady);
      return;
    }

    _isDisplayingNotification = true;
    final payload = _pendingNotificationQueue.removeAt(0);
    final title = (payload['title'] ?? '').toString();
    final body = (payload['body'] ?? '').toString();
    final Map<String, dynamic> payloadData = Map<String, dynamic>.from(
        payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final String? deliveredNotificationId =
        _extractNotificationId(payloadData);

    try {
      await showDialog<void>(
        context: navigatorState.context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              title.isEmpty ? 'Notification' : title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Text(
                body.isEmpty
                    ? 'Vous avez reçu une nouvelle notification.'
                    : body,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('FERMER'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('⚠️ Affichage notification impossible: $e');
      _pendingNotificationQueue.insert(0, payload);
      Future.delayed(
          const Duration(milliseconds: 300), showPendingNotificationWhenReady);
      return;
    } finally {
      _isDisplayingNotification = false;
    }

    if (deliveredNotificationId != null) {
      _queuedNotificationIds.remove(deliveredNotificationId);
      _markNotificationAsDelivered(deliveredNotificationId);
    }

    if (_pendingNotificationQueue.isNotEmpty) {
      Future.delayed(
          const Duration(milliseconds: 120), showPendingNotificationWhenReady);
    }
  }

  static Future<void> _maybeRestorePersistedNotifications() async {
    if (_restoringPersistedNotifications) {
      return;
    }
    if (_authLockActive) {
      return;
    }
    _restoringPersistedNotifications = true;
    try {
      final List<Map<String, dynamic>> records =
          await _consumePersistedNotifications();
      if (records.isEmpty) {
        return;
      }

      print('🔁 Restauration ${records.length} notification(s) persistées');
      for (final record in records) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
            record['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
        data['restoredFromPersistence'] = true;
        final title = (record['title'] ?? '').toString();
        final body = (record['body'] ?? '').toString();
        _queueInformationalNotification(
          title: title.isEmpty ? 'Notification' : title,
          body: body,
          data: data,
        );
      }
    } finally {
      _restoringPersistedNotifications = false;
    }
  }

  static Future<void> _persistNotificationRecord({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> rawRecords =
          prefs.getStringList(_persistedNotificationsKey) ?? <String>[];
      final String? recordId = _extractNotificationId(data);

      if (recordId != null) {
        rawRecords.removeWhere((encoded) {
          try {
            final dynamic decoded = jsonDecode(encoded);
            if (decoded is! Map) return false;
            final dynamic storedData = decoded['data'];
            if (storedData is Map) {
              final storedId =
                  (storedData['notificationId'] ??
                          storedData['notification_id'] ??
                          storedData['id'])
                      ?.toString();
              return storedId != null && storedId == recordId;
            }
          } catch (_) {
            return false;
          }
          return false;
        });
      }

      rawRecords.add(jsonEncode({
        'title': title,
        'body': body,
        'data': data,
        'savedAt': DateTime.now().toIso8601String(),
      }));

      const int maxPersistedRecords = 25;
      if (rawRecords.length > maxPersistedRecords) {
        rawRecords.removeRange(
            0, rawRecords.length - maxPersistedRecords);
      }

      await prefs.setStringList(_persistedNotificationsKey, rawRecords);
      print('💾 Notification persistée (${recordId ?? 'sans id'})');
    } on MissingPluginException catch (e) {
      print(
          '⚠️ SharedPreferences indisponible (background) - notification non persistée: $e');
    } catch (e) {
      print('⚠️ Impossible de persister la notification: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _consumePersistedNotifications() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> rawRecords =
          prefs.getStringList(_persistedNotificationsKey) ?? <String>[];
      if (rawRecords.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      await prefs.remove(_persistedNotificationsKey);

      final List<Map<String, dynamic>> parsed = <Map<String, dynamic>>[];
      for (final encoded in rawRecords) {
        try {
          final dynamic decoded = jsonDecode(encoded);
          if (decoded is! Map) continue;
          final Map<String, dynamic> data = decoded['data'] is Map
              ? Map<String, dynamic>.from(
                  decoded['data'] as Map<dynamic, dynamic>)
              : <String, dynamic>{};
          parsed.add({
            'title': (decoded['title'] ?? '').toString(),
            'body': (decoded['body'] ?? '').toString(),
            'data': data,
          });
        } catch (e) {
          print('⚠️ Impossible de décoder une notification persistée: $e');
        }
      }
      return parsed;
    } on MissingPluginException catch (e) {
      print(
          '⚠️ SharedPreferences indisponible (restore) - notifications ignorées: $e');
      return <Map<String, dynamic>>[];
    } catch (e) {
      print('⚠️ Impossible de restaurer les notifications persistées: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(message.data);
      final String type = (data['type'] ?? '').toString();
      if (!_shouldDisplayInfoPopup(type, data)) {
        return;
      }

      final String title = (message.notification?.title ??
              data['_notificationTitle']?.toString() ??
              data['title']?.toString() ??
              '')
          .trim();
      final String body = (message.notification?.body ??
              data['_notificationBody']?.toString() ??
              data['body']?.toString() ??
              '')
          .trim();

      data['_notificationTitle'] = title;
      data['_notificationBody'] = body;
      data['persistedFromBackground'] = true;
      if (!data.containsKey('notificationId') &&
          message.messageId != null &&
          message.messageId!.isNotEmpty) {
        data['notificationId'] = message.messageId!;
      }

      await _persistNotificationRecord(
        title: title.isEmpty ? 'Notification' : title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('⚠️ Erreur traitement notification en background: $e');
    }
  }

  static Future<void> synchronizeMissedNotifications() async {
    if (_authLockActive) {
      print('🔒 Synchronisation notifications reportée (auth requise)');
      return;
    }
    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email?.toLowerCase();
      if (email == null || email.isEmpty) {
        return;
      }

      if (currentUser == null) {
        return;
      }

      print(
          '🔄 Synchronisation notifications (email=$email, uid=${currentUser.uid})');

      final recipientsToCheck = <String>{};
      if (email.isNotEmpty) {
        recipientsToCheck.add(email);
      }
      recipientsToCheck.add(currentUser.uid);
      final fetchedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final seenDocIds = <String>{};

      for (final recipient in recipientsToCheck) {
        if (recipient == null || recipient.isEmpty) continue;
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('notifications')
              .where('recipientUserId', isEqualTo: recipient)
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get();

          for (final doc in snapshot.docs) {
            if (seenDocIds.add(doc.id)) {
              fetchedDocs.add(doc);
            }
          }
        } on FirebaseException catch (e) {
          print(
              '⚠️ Erreur lecture notifications pour $recipient: ${e.message}');
        }
      }

      if (fetchedDocs.isEmpty) {
        print('ℹ️ Aucune notification à synchroniser');
        return;
      }

      fetchedDocs.sort((a, b) {
        final tsA = a.data()['timestamp'] as Timestamp?;
        final tsB = b.data()['timestamp'] as Timestamp?;
        final dateA = tsA?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = tsB?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      print('📬 Notifications candidates: ${fetchedDocs.length}');
      // Traiter des plus anciennes aux plus récentes
      final docs = fetchedDocs;
      for (final doc in docs) {
        final data = doc.data();
        final alreadyDelivered = data['appDelivered'] == true;
        if (alreadyDelivered) {
          continue;
        }

        final Map<String, dynamic> payload =
            Map<String, dynamic>.from(data['data'] ?? <String, dynamic>{});
        final type = (payload['type'] ?? '').toString();
        final shouldDisplay = _shouldDisplayInfoPopup(type, payload);

        if (!shouldDisplay) {
          try {
            await doc.reference.set(
              {
                'appDelivered': true,
                'appDeliveredAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          } catch (_) {}
          continue;
        }

        final title = (data['title'] ?? '').toString();
        final body = (data['body'] ?? '').toString();
        print('📨 Notification hors-ligne détectée: ${doc.id} ($title)');

        _queueInformationalNotification(
          title: title,
          body: body,
          data: payload,
        );

        try {
          await doc.reference.set(
            {
              'appDelivered': true,
              'appDeliveredAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          print('⚠️ Impossible de marquer la notification comme livrée: $e');
        }
      }
    } catch (e) {
      print('⚠️ Erreur synchronisation notifications: $e');
    } finally {
      _syncInProgress = false;
    }
  }
}
