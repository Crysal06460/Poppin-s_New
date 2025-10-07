import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _credentialKeyPrefix = 'biometric_credential_';
  static const String _enabledFlagPrefix = 'biometric_enabled_';
  static const String _accountsKey = 'biometric_accounts';
  static const String _lastAccountKey = 'biometric_last_email';

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final bool isSupported = await _localAuth.isDeviceSupported();
      final bool canCheck = await _localAuth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException catch (error) {
      debugPrint('Biometric availability error: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('Biometric availability error: $error');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return const [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (error) {
      debugPrint('Biometric listing error: ${error.message}');
      return const [];
    } catch (error) {
      debugPrint('Biometric listing error: $error');
      return const [];
    }
  }

  Future<bool> authenticate({
    String reason = 'Confirmez votre identité pour continuer',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (error) {
      debugPrint('Biometric authenticate error: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('Biometric authenticate error: $error');
      return false;
    }
  }

  Future<void> enableBiometrics(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty || kIsWeb) return;

    await _secureStorage.write(
      key: '$_credentialKeyPrefix$normalizedEmail',
      value: password,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledFlagPrefix$normalizedEmail', true);

    final accounts = prefs.getStringList(_accountsKey) ?? <String>[];
    if (!accounts.contains(normalizedEmail)) {
      accounts.add(normalizedEmail);
      await prefs.setStringList(_accountsKey, accounts);
    }

    await prefs.setString(_lastAccountKey, normalizedEmail);
  }

  Future<void> disableBiometrics(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty || kIsWeb) return;

    await _secureStorage.delete(key: '$_credentialKeyPrefix$normalizedEmail');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledFlagPrefix$normalizedEmail', false);

    final accounts = prefs.getStringList(_accountsKey) ?? <String>[];
    if (accounts.remove(normalizedEmail)) {
      await prefs.setStringList(_accountsKey, accounts);
    }

    final lastEmail = prefs.getString(_lastAccountKey);
    if (lastEmail == normalizedEmail) {
      if (accounts.isNotEmpty) {
        await prefs.setString(_lastAccountKey, accounts.last);
      } else {
        await prefs.remove(_lastAccountKey);
      }
    }
  }

  Future<bool> isBiometricEnabled(String email) async {
    if (kIsWeb) return false;
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final bool enabled =
        prefs.getBool('$_enabledFlagPrefix$normalizedEmail') ?? false;
    if (!enabled) return false;

    final savedPassword =
        await _secureStorage.read(key: '$_credentialKeyPrefix$normalizedEmail');
    return savedPassword != null && savedPassword.isNotEmpty;
  }

  Future<String?> getSavedPassword(String email) async {
    if (kIsWeb) return null;
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return null;

    return _secureStorage.read(
      key: '$_credentialKeyPrefix$normalizedEmail',
    );
  }

  Future<List<String>> getEnabledEmails() async {
    if (kIsWeb) return const [];
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList(_accountsKey) ?? const [];
    return accounts;
  }

  Future<String?> getLastEnabledEmail() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString(_lastAccountKey);
    return lastEmail;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}
