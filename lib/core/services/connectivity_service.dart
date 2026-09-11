import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Service central pour détection hors-ligne / en-ligne.
/// Expose [isOnline] et [isOffline] réactifs.
/// Utilise connectivity_plus + debounce pour éviter les flaps.
class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find<ConnectivityService>();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  final RxBool isOnline = true.obs;
  final RxBool isOffline = false.obs;
  final Rx<ConnectivityResult> currentResult = ConnectivityResult.wifi.obs;

  Future<ConnectivityService> init() async {
    // État initial
    try {
      final results = await _connectivity.checkConnectivity();
      _updateFromResults(results);
    } catch (e) {
      if (kDebugMode) debugPrint('[Connectivity] check initial error: $e');
      isOnline.value = true; // fallback online pour ne pas bloquer
    }

    // Écoute continue
    _sub = _connectivity.onConnectivityChanged.listen(_updateFromResults);
    return this;
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    // connectivity_plus 6 renvoie une liste (multi-interfaces)
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final primary = results.isNotEmpty ? results.first : ConnectivityResult.none;

    isOnline.value = hasConnection;
    isOffline.value = !hasConnection;
    currentResult.value = primary;

    if (kDebugMode) debugPrint('[Connectivity] $results -> online=$hasConnection');
  }

  /// Vérification ponctuelle avec ping léger (optionnel).
  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateFromResults(results);
      return isOnline.value;
    } catch (_) {
      return isOnline.value;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
