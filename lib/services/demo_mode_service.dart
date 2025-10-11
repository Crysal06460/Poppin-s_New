import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/user_role_cache.dart';
import 'demo_seed_service.dart';
import '../utils/demo_firestore.dart';

class DemoModeState {
  const DemoModeState({
    required this.isDemo,
    this.sessionId,
    this.sessionEmail,
    this.expiresAt,
    this.remaining,
    this.expired = false,
  });

  factory DemoModeState.inactive() => const DemoModeState(isDemo: false);

  final bool isDemo;
  final String? sessionId;
  final String? sessionEmail;
  final DateTime? expiresAt;
  final Duration? remaining;
  final bool expired;

  DemoModeState copyWith({
    bool? isDemo,
    String? sessionId,
    String? sessionEmail,
    DateTime? expiresAt,
    Duration? remaining,
    bool? expired,
  }) {
    return DemoModeState(
      isDemo: isDemo ?? this.isDemo,
      sessionId: sessionId ?? this.sessionId,
      sessionEmail: sessionEmail ?? this.sessionEmail,
      expiresAt: expiresAt ?? this.expiresAt,
      remaining: remaining ?? this.remaining,
      expired: expired ?? this.expired,
    );
  }
}

class DemoSessionResult {
  const DemoSessionResult.success({
    required this.sessionId,
    required this.email,
    required this.expiresAt,
  })  : success = true,
        errorMessage = null;

  const DemoSessionResult.error(this.errorMessage)
      : success = false,
        sessionId = null,
        email = null,
        expiresAt = null;

  final bool success;
  final String? sessionId;
  final String? email;
  final DateTime? expiresAt;
  final String? errorMessage;
}

class DemoModeService {
  DemoModeService._();

  static final DemoModeService instance = DemoModeService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration defaultDemoDuration = Duration(hours: 2);

  static const String _prefsActiveKey = 'demo_mode_active';
  static const String _prefsSessionIdKey = 'demo_session_id';
  static const String _prefsEmailKey = 'demo_session_email';
  static const String _prefsExpiresKey = 'demo_session_expires_at';

  final StreamController<DemoModeState> _stateController =
      StreamController<DemoModeState>.broadcast();

  DemoModeState _state = DemoModeState.inactive();
  Timer? _ticker;
  bool _initialized = false;
  bool _expiryHandled = false;

  Stream<DemoModeState> get stream => _stateController.stream;
  DemoModeState get state => _state;
  bool get isDemo => _state.isDemo;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final bool storedActive = prefs.getBool(_prefsActiveKey) ?? false;
    if (!storedActive) {
      _state = DemoModeState.inactive();
      return;
    }

    final String? sessionId = prefs.getString(_prefsSessionIdKey);
    final String? sessionEmail = prefs.getString(_prefsEmailKey);
    final int? expiresAtMs = prefs.getInt(_prefsExpiresKey);

    if (sessionId == null || sessionEmail == null || expiresAtMs == null) {
      await _clearPrefs();
      _state = DemoModeState.inactive();
      return;
    }

    final DateTime expiresAt =
        DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true).toLocal();
    if (expiresAt.isBefore(DateTime.now())) {
      await stopDemoSession(expired: true);
      return;
    }

    _state = DemoModeState(
      isDemo: true,
      sessionId: sessionId,
      sessionEmail: sessionEmail,
      expiresAt: expiresAt,
    );

    _stateController.add(_state);
    _startTicker();
  }

  Future<void> syncWithCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (_state.isDemo) {
        await stopDemoSession();
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedEmail = prefs.getString(_prefsEmailKey);
      if (storedEmail != null &&
          storedEmail.toLowerCase() == (user.email ?? '').toLowerCase()) {
        if (!_state.isDemo) {
          final int? expiresAtMs = prefs.getInt(_prefsExpiresKey);
          final String? sessionId = prefs.getString(_prefsSessionIdKey);
          if (expiresAtMs != null) {
            final DateTime expiresAt = DateTime.fromMillisecondsSinceEpoch(
              expiresAtMs,
              isUtc: true,
            ).toLocal();
            _state = DemoModeState(
              isDemo: true,
              sessionId: sessionId,
              sessionEmail: storedEmail,
              expiresAt: expiresAt,
            );
            _stateController.add(_state);
            _startTicker();
          }
        }
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
          .collection('users')
          .doc((user.email ?? '').toLowerCase())
          .get();

      final String accountType =
          (userDoc.data()?['account_type'] ?? '').toString().toLowerCase();
      if (accountType == 'demo') {
        final Timestamp? expiresTs = userDoc.data()?['demo_expires_at'];
        if (expiresTs != null) {
          await _restoreFromRemote(
            sessionId: userDoc.data()?['demo_session_id'] as String?,
            sessionEmail: user.email ?? storedEmail,
            expiresAt: expiresTs.toDate(),
          );
        }
      } else if (_state.isDemo) {
        await stopDemoSession();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ DemoModeService sync failed: $e');
      }
    }
  }

  Future<DemoSessionResult> startDemoSession({
    Duration duration = defaultDemoDuration,
  }) async {
    _expiryHandled = false;
    try {
      if (kDebugMode) {
        print(
            '🧪 DEMO ▶️ Activation demandée (durée ${duration.inMinutes} minutes)');
      }
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        if (kDebugMode) {
          print('🧪 DEMO ▶️ Déconnexion de ${currentUser.email}');
        }
        await _auth.signOut();
      }

      final sessionId = _generateSessionId();
      final sessionEmail = 'demo-$sessionId@demo.poppins.app';
      final sessionPassword = _generateSessionPassword();
      final DateTime expiresAt =
          DateTime.now().add(duration).toUtc(); // store utc

      if (kDebugMode) {
        print('🧪 DEMO ▶️ Création du compte $sessionEmail');
      }

      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: sessionEmail,
        password: sessionPassword,
      );

      final User? demoUser = credential.user;
      if (demoUser == null) {
        await _auth.signOut();
        return const DemoSessionResult.error(
            "Impossible de créer le compte démo.");
      }

      try {
        await demoUser.reload();
        await demoUser.getIdToken(true);
      } catch (e) {
        if (kDebugMode) {
          print('🧪 DEMO ⚠️ Impossible de rafraîchir le token: $e');
        }
      }

      try {
        await demoUser.updateDisplayName("Compte démo Poppin's");
      } catch (_) {}

      final DocumentReference<Map<String, dynamic>> userDoc = _firestore
          .collection('users')
          .doc(sessionEmail.toLowerCase());

      await userDoc.setWithDemo({
        'uid': demoUser.uid,
        'email': sessionEmail,
        'displayName': "Compte démo Poppin's",
        'createdAt': FieldValue.serverTimestamp(),
        'account_type': 'demo',
        'is_demo': true,
        'demo_session_id': sessionId,
        'demo_expires_at': Timestamp.fromDate(expiresAt),
        'structureId': 'demo',
        'role': 'assistant',
      }, options: SetOptions(merge: true), force: true);

      await _firestore
          .collection('demo_sessions')
          .doc(sessionId)
          .setWithDemo({
        'uid': demoUser.uid,
        'email': sessionEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'status': 'active',
        'structureId': 'demo',
      }, options: SetOptions(merge: true), force: true);

      await _persistPrefs(
        sessionId: sessionId,
        email: sessionEmail,
        expiresAt: expiresAt,
      );

      _state = DemoModeState(
        isDemo: true,
        sessionId: sessionId,
        sessionEmail: sessionEmail,
        expiresAt: expiresAt.toLocal(),
      );
      _stateController.add(_state);
      _startTicker();

      await _markLoggedIn();
      UserRoleCache.setRole('structure');
      await DemoSeedService.ensureSeedData(demoUser);

      if (kDebugMode) {
        print('🧪 DEMO ✅ Session prête jusqu\'à ${expiresAt.toLocal()}');
      }

      return DemoSessionResult.success(
        sessionId: sessionId,
        email: sessionEmail,
        expiresAt: expiresAt.toLocal(),
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('🧪 DEMO ❌ FirebaseAuthException (${e.code}): ${e.message}');
      }
      return DemoSessionResult.error(_translateAuthError(e));
    } catch (e, stack) {
      if (kDebugMode) {
        print('🧪 DEMO ❌ Exception inattendue: $e');
        print(stack);
      }
      return DemoSessionResult.error(
          "Erreur inattendue lors de l'activation du mode démo.");
    }
  }

  Future<void> stopDemoSession({bool expired = false}) async {
    _ticker?.cancel();
    _ticker = null;

    final prefs = await SharedPreferences.getInstance();
    await _clearPrefs();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final String? userEmail = user.email;
        if (userEmail != null) {
          await _firestore
              .collection('users')
              .doc(userEmail.toLowerCase())
              .setWithDemo(
                {
                  'account_type': expired ? 'demo_expired' : 'demo',
                  'demo_session_ended_at': FieldValue.serverTimestamp(),
                },
                options: SetOptions(merge: true),
                force: true,
              );
        }
        await _auth.signOut();
      } catch (_) {}
    }

    _state = DemoModeState.inactive();
    _stateController.add(_state);
  }

  Future<void> _restoreFromRemote({
    String? sessionId,
    String? sessionEmail,
    required DateTime expiresAt,
  }) async {
    await _persistPrefs(
      sessionId: sessionId,
      email: sessionEmail,
      expiresAt: expiresAt,
    );
    _state = DemoModeState(
      isDemo: true,
      sessionId: sessionId,
      sessionEmail: sessionEmail,
      expiresAt: expiresAt.toLocal(),
    );
    _stateController.add(_state);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (!_state.isDemo || _state.expiresAt == null) {
      return;
    }

    _refreshRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshRemaining();
    });
  }

  void _refreshRemaining() {
    if (!_state.isDemo || _state.expiresAt == null) {
      return;
    }

    Duration remaining = _state.expiresAt!.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      if (!_expiryHandled) {
        _expiryHandled = true;
        _state = _state.copyWith(
          remaining: Duration.zero,
          expired: true,
        );
        _stateController.add(_state);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          stopDemoSession(expired: true);
        });
      }
      return;
    }

    if (remaining > defaultDemoDuration) {
      remaining = defaultDemoDuration;
    }

    _state = _state.copyWith(
      remaining: remaining,
      expired: false,
    );
    _stateController.add(_state);
  }

  Future<void> _persistPrefs({
    String? sessionId,
    String? email,
    required DateTime expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsActiveKey, true);
    if (sessionId != null) {
      await prefs.setString(_prefsSessionIdKey, sessionId);
    }
    if (email != null) {
      await prefs.setString(_prefsEmailKey, email);
    }
    await prefs.setInt(
      _prefsExpiresKey,
      expiresAt.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<void> _markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    final String today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('last_login_date', today);
    await prefs.setInt(
      'lastSessionTime',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsActiveKey);
    await prefs.remove(_prefsSessionIdKey);
    await prefs.remove(_prefsEmailKey);
    await prefs.remove(_prefsExpiresKey);
    await prefs.setBool('is_logged_in', false);
  }

  String _generateSessionId() {
    final Random random = Random();
    final int suffix = random.nextInt(900000) + 100000;
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'demo${timestamp.toString()}$suffix';
  }

  String _generateSessionPassword() {
    final Random random = Random();
    final int suffix = random.nextInt(9000) + 1000;
    return 'Demo!$suffix';
  }

  String _translateAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return "Connexion internet requise pour activer la démo.";
      case 'too-many-requests':
        return "Trop de tentatives, réessayez dans quelques instants.";
      default:
        return "Impossible de démarrer la démo (${e.code}).";
    }
  }
}
