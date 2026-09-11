import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sécurité de l'application : verrouillage par code confidentiel et/ou
/// biométrie (empreinte / Face ID selon le matériel de l'appareil).
class LockService extends GetxService {
  static LockService get to => Get.find();

  final RxBool enabled = false.obs; // verrouillage activé
  final RxBool biometric = false.obs; // déverrouillage biométrique autorisé
  final RxBool unlocked = false.obs; // session déverrouillée
  final RxBool biometricAvailable = false.obs;

  static const String _salt = 'chatme_lock_salt_v1';
  String? _pinHash;

  Future<LockService> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool('lock_enabled') ?? false;
    biometric.value = prefs.getBool('lock_biometric') ?? false;
    _pinHash = prefs.getString('lock_pin_hash');
    await _checkBiometricAvailability();
    return this;
  }

  Future<void> _checkBiometricAvailability() async {
    final local = LocalAuthentication();
    try {
      final isSupported = await local.isDeviceSupported();
      final canCheck = await local.canCheckBiometrics;
      final availableBiometrics = await local.getAvailableBiometrics();
      
      biometricAvailable.value = isSupported && canCheck && availableBiometrics.isNotEmpty;
      
      if (kDebugMode) {
        print('Biometric: supported=$isSupported, canCheck=$canCheck, available=$availableBiometrics');
      }
    } catch (e) {
      biometricAvailable.value = false;
      if (kDebugMode) print('Biometric check error: $e');
    }
  }

  Future<void> refreshBiometricAvailability() async {
    await _checkBiometricAvailability();
  }

  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;

  bool get isLocked => enabled.value && !unlocked.value;

  void markUnlocked() => unlocked.value = true;
  void markLocked() => unlocked.value = false;

  // Fix sécurité: 1500 itérations SHA256 + sel aléatoire par PIN (stocké), au lieu de sel statique simple
  String _hash(String pin, {String? salt}) {
    final s = salt ?? _salt;
    var digest = sha256.convert(utf8.encode(pin + s)).toString();
    // 1500 itérations pour ralentir brute-force (4 chiffres = 10k combos)
    for (int i = 1; i < 1500; i++) {
      digest = sha256.convert(utf8.encode(digest + s)).toString();
    }
    return digest;
  }

  bool verifyPin(String pin) {
    if (!hasPin || _pinHash == null) return false;
    // Format stocké: salt$hash ou hash simple (compat)
    if (_pinHash!.contains('\$')) {
      final parts = _pinHash!.split('\$');
      return _hash(pin, salt: parts[0]) == parts[1];
    }
    return _hash(pin) == _pinHash;
  }

  Future<void> setPin(String pin) async {
    // Génère sel aléatoire hex 16 chars
    final salt = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(8, '0') +
        (pin.hashCode.toRadixString(16).padLeft(8, '0'));
    final hash = _hash(pin, salt: salt);
    _pinHash = '$salt\$$hash';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lock_pin_hash', _pinHash!);
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    if (!value) unlocked.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock_enabled', value);
  }

  Future<void> setBiometric(bool value) async {
    biometric.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock_biometric', value);
  }

  Future<bool> authenticateBiometric() async {
    final local = LocalAuthentication();
    try {
      // Rafraîchir dispo au moment de l'auth (au cas où l'utilisateur vient d'enroller)
      await _checkBiometricAvailability();
      if (!biometricAvailable.value) return false;
      return await local.authenticate(
        localizedReason: 'Déverrouillez ChatMe',
        options: const AuthenticationOptions(
          biometricOnly: false, // autorise code PIN système en fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Biometric auth error: $e');
      return false;
    }
  }
}
