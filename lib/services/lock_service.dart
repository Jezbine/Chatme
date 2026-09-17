import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatme/screens/app_lock_screen.dart';

/// Sécurité de l'application : verrouillage par code confidentiel et/ou
/// biométrie (empreinte / Face ID selon le matériel de l'appareil).
class LockService extends GetxService with WidgetsBindingObserver {
  static LockService get to => Get.find();

  final RxBool enabled = false.obs; // verrouillage activé
  final RxBool biometric = false.obs; // déverrouillage biométrique autorisé
  final RxBool unlocked = false.obs; // session déverrouillée
  final RxBool biometricAvailable = false.obs;

  static const String _salt = 'chatme_lock_salt_v1';
  static const _secureStorage = FlutterSecureStorage();
  String? _pinHash;
  DateTime? _backgroundedAt;
  bool _isPromptingLock = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedAt != null && enabled.value && hasPin) {
        final elapsed = DateTime.now().difference(_backgroundedAt!).inSeconds;
        // Si l'application a passé plus d'une seconde en arrière-plan, reverrouiller
        if (elapsed >= 1) {
          markLocked();
          _showLockScreenIfNeeded();
        }
      }
      _backgroundedAt = null;
    }
  }

  void _showLockScreenIfNeeded() {
    if (!isLocked || _isPromptingLock) return;
    _isPromptingLock = true;
    Get.to(
      () => AppLockScreen(
        mode: 'unlock',
        onSuccess: () {
          markUnlocked();
          _isPromptingLock = false;
          Get.back();
        },
      ),
      fullscreenDialog: true,
      transition: Transition.fadeIn,
    )?.then((_) {
      _isPromptingLock = false;
    });
  }

  Future<LockService> init() async {
    // Lire depuis le stockage sécurisé (Android Keystore / iOS Keychain)
    final secEnabled = await _secureStorage.read(key: 'lock_enabled');
    final secBiometric = await _secureStorage.read(key: 'lock_biometric');
    final secPinHash = await _secureStorage.read(key: 'lock_pin_hash');

    if (secEnabled != null || secBiometric != null || secPinHash != null) {
      // Données déjà dans le stockage sécurisé
      enabled.value = secEnabled == 'true';
      biometric.value = secBiometric == 'true';
      _pinHash = secPinHash;
    } else {
      // Migration depuis SharedPreferences (première exécution après mise à jour)
      try {
        final prefs = await SharedPreferences.getInstance();
        enabled.value = prefs.getBool('lock_enabled') ?? false;
        biometric.value = prefs.getBool('lock_biometric') ?? false;
        _pinHash = prefs.getString('lock_pin_hash');
        // Migrer vers le stockage sécurisé et supprimer l'ancien
        await _secureStorage.write(key: 'lock_enabled', value: enabled.value.toString());
        await _secureStorage.write(key: 'lock_biometric', value: biometric.value.toString());
        if (_pinHash != null) await _secureStorage.write(key: 'lock_pin_hash', value: _pinHash!);
        await prefs.remove('lock_pin_hash');
      } catch (_) {}
    }
    await _checkBiometricAvailability();
    return this;
  }

  Future<void> _checkBiometricAvailability() async {
    final local = LocalAuthentication();
    try {
      final isSupported = await local.isDeviceSupported();
      final canCheck = await local.canCheckBiometrics;
      final availableBiometrics = await local.getAvailableBiometrics();
      
      biometricAvailable.value = isSupported || canCheck || availableBiometrics.isNotEmpty;
      
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

  // 1500 itérations SHA256 + sel aléatoire par PIN (stocké)
  String _hash(String pin, {String? salt}) {
    final s = salt ?? _salt;
    var digest = sha256.convert(utf8.encode(pin + s)).toString();
    for (int i = 1; i < 1500; i++) {
      digest = sha256.convert(utf8.encode(digest + s)).toString();
    }
    return digest;
  }

  bool verifyPin(String pin) {
    if (!hasPin || _pinHash == null) return false;
    if (_pinHash!.contains('\$')) {
      final parts = _pinHash!.split('\$');
      return _hash(pin, salt: parts[0]) == parts[1];
    }
    return _hash(pin) == _pinHash;
  }

  Future<void> setPin(String pin) async {
    final salt = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(8, '0') +
        (pin.hashCode.toRadixString(16).padLeft(8, '0'));
    final hash = _hash(pin, salt: salt);
    _pinHash = '$salt\$$hash';
    await _secureStorage.write(key: 'lock_pin_hash', value: _pinHash!);
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    unlocked.value = true; // Déverrouillé pour la session en cours
    await _secureStorage.write(key: 'lock_enabled', value: value.toString());
  }

  Future<void> setBiometric(bool value) async {
    biometric.value = value;
    await _secureStorage.write(key: 'lock_biometric', value: value.toString());
  }

  Future<bool> authenticateBiometric() async {
    final local = LocalAuthentication();
    try {
      await _checkBiometricAvailability();
      return await local.authenticate(
        localizedReason: 'Déverrouillez ChatMe pour accéder à vos discussions',
        biometricOnly: false,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      if (kDebugMode) print('Biometric auth error: $e');
      return false;
    }
  }
}
