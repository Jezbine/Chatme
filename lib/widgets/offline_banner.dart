import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/core/services/connectivity_service.dart';
import 'package:chatme/core/services/offline_service.dart';
import 'package:chatme/services/messaging_service.dart';

/// Bannière affichée en haut quand l'app est hors-ligne.
/// Montre le nombre de messages en file d'attente et un bouton "Réessayer".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Si ConnectivityService non initialisé, ne rien afficher
    if (!Get.isRegistered<ConnectivityService>()) return const SizedBox.shrink();

    final conn = Get.find<ConnectivityService>();
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      final isOffline = conn.isOffline.value;
      if (!isOffline) return const SizedBox.shrink();

      final pendingCount = Get.isRegistered<OfflineService>()
          ? Get.find<OfflineService>().getPendingQueue().length
          : 0;

      // Essayez aussi via MessagingService pending
      int displayPending = pendingCount;

      return Material(
        color: cs.error,
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Hors ligne — Mode hors connexion actif',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      if (displayPending > 0)
                        Text(
                          '$displayPending message${displayPending > 1 ? 's' : ''} en attente d\'envoi',
                          style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 11),
                        )
                      else
                        Text(
                          'Vos conversations en cache restent disponibles',
                          style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final ok = await conn.checkNow();
                    if (ok && Get.isRegistered<MessagingService>()) {
                      Get.find<MessagingService>().loadConversations();
                      Get.find<MessagingService>().flushPendingQueue();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Réessayer', style: TextStyle(color: cs.error, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Version compacte pour les écrans avec AppBar (sans SafeArea top)
class OfflineBannerCompact extends StatelessWidget {
  const OfflineBannerCompact({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectivityService>()) return const SizedBox.shrink();
    final conn = Get.find<ConnectivityService>();
    return Obx(() {
      if (!conn.isOffline.value) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.error.withOpacity(0.95),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text('Hors ligne — données en cache', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    });
  }
}
