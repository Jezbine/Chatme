import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/services/service_catalog.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatMeColors.surface,
      appBar: AppBar(
        backgroundColor: ChatMeColors.surface,
        foregroundColor: ChatMeColors.ink,
        title: Text(service.label),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header avec icône + badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatMeColors.violetPale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: service.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(service.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.label,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatMeColors.ink)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Bientôt disponible',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Description détaillée
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ChatMeColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: ChatMeColors.inkSoft),
                      SizedBox(width: 6),
                      Text('Description',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatMeColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(service.description,
                      style: const TextStyle(fontSize: 13, height: 1.45, color: ChatMeColors.inkSoft)),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: ChatMeColors.divider),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.grid_view, size: 14, color: ChatMeColors.inkSoft),
                      const SizedBox(width: 6),
                      Text('${service.items.length} prestations prévues',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatMeColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Prestations',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatMeColors.ink)),
            const SizedBox(height: 8),
            ...service.items.map((item) => _ItemRow(
                  service: service,
                  item: item,
                  onTap: () {
                    Get.snackbar(
                      'Bientôt disponible',
                      '${item.title} sera bientôt disponible',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.white,
                      colorText: Colors.black,
                    );
                  },
                )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatMeColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notifications_none, size: 18, color: ChatMeColors.inkSoft),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Activez les notifications pour être informé du lancement de ce service.',
                        style: TextStyle(fontSize: 12, color: ChatMeColors.inkSoft)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Service service;
  final ServiceItem item;
  final VoidCallback onTap;

  const _ItemRow({required this.service, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: ChatMeColors.border),
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: service.color.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(service.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ChatMeColors.ink)),
                      const Text('Bientôt disponible',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.orange)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_clock, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Bientôt',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
