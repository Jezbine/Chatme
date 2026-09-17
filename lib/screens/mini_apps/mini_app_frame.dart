import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Cadre WeChat-style pour les Mini-Applications autonomes dans ChatMe.
/// Comprend la capsule d'actions rapides (Menu '•••' et Fermer '✕'),
/// le titre de la mini-app et l'intégration pleine page.
class MiniAppFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color brandColor;
  final Color? backgroundColor;
  final Widget body;
  final List<Widget>? quickActions;

  const MiniAppFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.brandColor,
    this.backgroundColor,
    required this.body,
    this.quickActions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: brandColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Capsule de contrôle style WeChat Mini-Program
          Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  onTap: () => _showMiniAppMenu(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.more_horiz, size: 18),
                  ),
                ),
                Container(
                  width: 0.8,
                  height: 14,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                InkWell(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                  onTap: () => Get.back(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  void _showMiniAppMenu(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: brandColor,
                  radius: 16,
                  child: const Icon(Icons.apps, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Text('Mini-Programme ChatMe Officiel', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager ce mini-programme'),
              onTap: () {
                Get.back();
                Get.snackbar('Partage', 'Lien du mini-programme prêt à être partagé', snackPosition: SnackPosition.BOTTOM);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Redémarrer le mini-programme'),
              onTap: () {
                Get.back();
                Get.back();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('À propos & Certification'),
              subtitle: const Text('Vérifié par ChatMe SuperApp Bénin'),
              onTap: () {
                Get.back();
                Get.snackbar('Certification', 'Ce service est validé et conforme aux normes béninoises', snackPosition: SnackPosition.BOTTOM);
              },
            ),
          ],
        ),
      ),
    );
  }
}
