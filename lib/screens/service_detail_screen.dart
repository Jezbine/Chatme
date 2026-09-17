import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/services/service_catalog.dart';
import 'package:chatme/services/wallet_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/core/utils/format_utils.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({super.key, required this.service});

  bool get _isServiceActive =>
      service.id == 'boutique' || service.id == 'factures' || service.id == 'taxi';

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
            // Header avec icône + statut
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isServiceActive
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isServiceActive ? 'Mini-Programme Actif' : 'Bientôt disponible',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isServiceActive ? Colors.green : Colors.orange,
                            ),
                          ),
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
                      SizedBox(width: 6),
                      Text('${service.items.length} prestations configurées',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatMeColors.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Prestations disponibles',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatMeColors.ink)),
            const SizedBox(height: 10),
            ...service.items.map((item) {
              final isItemInteractive = _isServiceActive;
              return _ItemRow(
                service: service,
                item: item,
                isInteractive: isItemInteractive,
                onTap: () => _handleItemTap(context, service, item),
              );
            }),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatMeColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Paiements directs et sécurisés via votre portefeuille ChatMe Wallet (FCFA).',
                      style: TextStyle(fontSize: 12, color: ChatMeColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleItemTap(BuildContext context, Service service, ServiceItem item) {
    if (service.id == 'boutique') {
      _showMobileRechargeDialog(context, item);
    } else if (service.id == 'factures') {
      final title = item.title.toLowerCase();
      if (title.contains('électricité') || title.contains('sbee')) {
        _showSbeeDialog(context, item);
      } else if (title.contains('eau') || title.contains('soneb')) {
        _showSonebDialog(context, item);
      } else {
        _showInternetDialog(context, item);
      }
    } else if (service.id == 'taxi') {
      _showTaxiDialog(context, item);
    } else {
      _showHumanizedPreorderSheet(context, service, item);
    }
  }

  void _showHumanizedPreorderSheet(BuildContext context, Service service, ServiceItem item) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: service.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(service.icon, color: service.color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ChatMeColors.ink),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B8A5A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, size: 14, color: Color(0xFF1B8A5A)),
                    SizedBox(width: 4),
                    Text('Service officiel en cours d\'intégration',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B8A5A))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ce service partenaire (${service.label}) est actuellement en phase de raccordement technique avec les prestataires au Bénin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: ChatMeColors.violet, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Être notifié en priorité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Recevez un message dès l\'activation pour les premiers utilisateurs.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('Retour'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatMeColors.violet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Get.back();
                        Get.snackbar(
                          'C\'est noté ! 🎉',
                          'Vous serez parmi les premiers prévenus sur ChatMe dès le lancement de ${item.title}.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: const Color(0xFF1B8A5A),
                          colorText: Colors.white,
                          duration: const Duration(seconds: 3),
                        );
                      },
                      child: const Text('M\'inscrire', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 1. MINI-PROGRAMME RECHARGE MOBILE GSM (MTN, Moov, Celtiis)
  // ---------------------------------------------------------------------------
  void _showMobileRechargeDialog(BuildContext context, ServiceItem item) {
    final operators = [
      {'name': 'MTN Bénin', 'code': 'mtn', 'color': const Color(0xFFFDB913), 'textColor': Colors.black},
      {'name': 'Moov Bénin', 'code': 'moov', 'color': const Color(0xFF005DAA), 'textColor': Colors.white},
      {'name': 'Celtiis Bénin', 'code': 'celtiis', 'color': const Color(0xFF6A1B9A), 'textColor': Colors.white},
    ];
    final selectedOp = 0.obs;
    final phoneCtrl = TextEditingController(
      text: AuthService.to.currentUser.value?.phoneNumber ?? '',
    );
    final selectedAmt = 1000.obs;
    final isProcessing = false.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005DAA).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_android, color: Color(0xFF005DAA)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recharge Mobile GSM Bénin',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('MTN, Moov & Celtiis', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('1. Choisissez votre opérateur',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Obx(() => Row(
                      children: List.generate(operators.length, (i) {
                        final op = operators[i];
                        final isSel = selectedOp.value == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => selectedOp.value = i,
                            child: Container(
                              margin: EdgeInsets.only(right: i < operators.length - 1 ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: op['color'] as Color,
                                borderRadius: BorderRadius.circular(12),
                                border: isSel ? Border.all(color: Colors.black, width: 2.5) : null,
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                            color: (op['color'] as Color).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3))
                                      ]
                                    : null,
                              ),
                              child: Text(
                                op['name'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: op['textColor'] as Color,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    )),
                const SizedBox(height: 16),
                const Text('2. Numéro de téléphone bénéficiaire',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text('🇧🇯 +229', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    hintText: '01 97 00 00 00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('3. Montant de la recharge',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [500, 1000, 2000, 5000, 10000].map((amt) {
                    return Obx(() {
                      final isSel = selectedAmt.value == amt;
                      return ChoiceChip(
                        label: Text('${FormatUtils.fmtFcfa(amt)} FCFA'),
                        selected: isSel,
                        selectedColor: ChatMeColors.violet,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) selectedAmt.value = amt;
                        },
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Solde portefeuille
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Solde portefeuille ChatMe :', style: TextStyle(fontSize: 12)),
                          Text(
                            '${FormatUtils.fmtFcfa(WalletService.to.balance.value)} FCFA',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: WalletService.to.balance.value >= selectedAmt.value ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: isProcessing.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.flash_on, color: Colors.white),
                        label: Text(
                          isProcessing.value
                              ? 'Traitement en cours...'
                              : 'Recharger ${FormatUtils.fmtFcfa(selectedAmt.value)} FCFA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ChatMeColors.violet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isProcessing.value
                            ? null
                            : () async {
                                final phone = phoneCtrl.text.trim();
                                if (phone.isEmpty) {
                                  Get.snackbar('Numéro requis', 'Veuillez saisir le numéro de téléphone',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }
                                final amt = selectedAmt.value;
                                if (amt > WalletService.to.balance.value) {
                                  Get.snackbar('Solde insuffisant',
                                      'Veuillez recharger votre portefeuille pour effectuer cette opération',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }
                                isProcessing.value = true;
                                final opName = operators[selectedOp.value]['name'] as String;

                                final ok = await WalletService.to.payAsync(
                                  amt,
                                  'Recharge GSM $opName ($phone)',
                                );
                                isProcessing.value = false;

                                if (ok) {
                                  Get.back();
                                  HapticFeedback.heavyImpact();
                                  _showOfficialReceiptDialog(
                                    serviceTitle: 'Recharge Mobile GSM',
                                    provider: opName,
                                    amount: amt,
                                    refCode: 'REC-${Random().nextInt(900000) + 100000}',
                                    extraRows: [
                                      {'label': 'Bénéficiaire', 'value': '+229 $phone'},
                                      {'label': 'Opérateur', 'value': opName},
                                      {'label': 'Statut', 'value': 'Validé avec succès'},
                                    ],
                                  );
                                } else {
                                  Get.snackbar('Erreur', 'Paiement non autorisé',
                                      snackPosition: SnackPosition.BOTTOM);
                                }
                              },
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MINI-PROGRAMME ÉLECTRICITÉ SBEE
  // ---------------------------------------------------------------------------
  void _showSbeeDialog(BuildContext context, ServiceItem item) {
    final meterCtrl = TextEditingController(text: '14209481729');
    final selectedAmt = 5000.obs;
    final isPrepaid = true.obs;
    final isProcessing = false.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57C00).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt, color: Color(0xFFF57C00)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Électricité SBEE Bénin',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Recharge compteur & factures',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Type de compteur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Obx(() => Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('⚡ Compteur Prépayé (Code)'),
                            selected: isPrepaid.value,
                            selectedColor: const Color(0xFFF57C00),
                            labelStyle: TextStyle(
                              color: isPrepaid.value ? Colors.white : Colors.black87,
                              fontWeight: isPrepaid.value ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            onSelected: (v) => isPrepaid.value = true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('🧾 Conventionnel'),
                            selected: !isPrepaid.value,
                            selectedColor: const Color(0xFFF57C00),
                            labelStyle: TextStyle(
                              color: !isPrepaid.value ? Colors.white : Colors.black87,
                              fontWeight: !isPrepaid.value ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            onSelected: (v) => isPrepaid.value = false,
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: 16),
                const Text('Numéro de compteur / Police',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: meterCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers),
                    hintText: 'Ex: 14209481729',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Montant de la recharge',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [2000, 5000, 10000, 20000].map((amt) {
                    return Obx(() {
                      final isSel = selectedAmt.value == amt;
                      return ChoiceChip(
                        label: Text('${FormatUtils.fmtFcfa(amt)} FCFA'),
                        selected: isSel,
                        selectedColor: const Color(0xFFF57C00),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) selectedAmt.value = amt;
                        },
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // Estimation kWh
                Obx(() {
                  final kwh = (selectedAmt.value / 122).toStringAsFixed(1);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF57C00).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Énergie estimée :', style: TextStyle(fontSize: 12.5)),
                        Text('~$kwh kWh',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF57C00))),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: isProcessing.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.payment, color: Colors.white),
                        label: Text(
                          isProcessing.value
                              ? 'Génération du code...'
                              : 'Payer ${FormatUtils.fmtFcfa(selectedAmt.value)} FCFA',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF57C00),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isProcessing.value
                            ? null
                            : () async {
                                final meter = meterCtrl.text.trim();
                                if (meter.isEmpty) {
                                  Get.snackbar('Compteur requis', 'Veuillez saisir votre numéro de compteur',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }
                                final amt = selectedAmt.value;
                                if (amt > WalletService.to.balance.value) {
                                  Get.snackbar('Solde insuffisant', 'Rechargez votre portefeuille pour valider',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }

                                isProcessing.value = true;
                                final ok = await WalletService.to.payAsync(
                                  amt,
                                  'SBEE Électricité Compteur $meter',
                                );
                                isProcessing.value = false;

                                if (ok) {
                                  Get.back();
                                  HapticFeedback.heavyImpact();
                                  final r = Random();
                                  final token20 =
                                      '${r.nextInt(9000) + 1000} - ${r.nextInt(9000) + 1000} - ${r.nextInt(9000) + 1000} - ${r.nextInt(9000) + 1000} - ${r.nextInt(9000) + 1000}';
                                  final kwh = (amt / 122).toStringAsFixed(1);

                                  _showOfficialReceiptDialog(
                                    serviceTitle: 'Recharge SBEE Prépayé',
                                    provider: 'SBEE Bénin',
                                    amount: amt,
                                    refCode: 'SBEE-${r.nextInt(900000) + 100000}',
                                    tokenCode: token20,
                                    extraRows: [
                                      {'label': 'Numéro Compteur', 'value': meter},
                                      {'label': 'Énergie Créditée', 'value': '$kwh kWh'},
                                      {'label': 'Statut', 'value': 'Payé & Délivré'},
                                    ],
                                  );
                                }
                              },
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MINI-PROGRAMME EAU SONEB
  // ---------------------------------------------------------------------------
  void _showSonebDialog(BuildContext context, ServiceItem item) {
    final policeCtrl = TextEditingController(text: 'SON-784201');
    final amtCtrl = TextEditingController(text: '3500');
    final isProcessing = false.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.water_drop, color: Color(0xFF0288D1)),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Eau SONEB Bénin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Paiement de facture d\'eau', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Numéro de Police / Facture', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: policeCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.receipt),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Montant de la facture (FCFA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                  suffixText: 'FCFA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Obx(() => SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0288D1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isProcessing.value
                          ? null
                          : () async {
                              final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
                              if (amt <= 0) return;
                              if (amt > WalletService.to.balance.value) {
                                Get.snackbar('Solde insuffisant', 'Rechargez votre portefeuille',
                                    snackPosition: SnackPosition.BOTTOM);
                                return;
                              }
                              isProcessing.value = true;
                              final ok = await WalletService.to.payAsync(amt, 'Facture SONEB ${policeCtrl.text}');
                              isProcessing.value = false;

                              if (ok) {
                                Get.back();
                                HapticFeedback.heavyImpact();
                                _showOfficialReceiptDialog(
                                  serviceTitle: 'Facture Eau SONEB',
                                  provider: 'SONEB Bénin',
                                  amount: amt,
                                  refCode: 'SON-${Random().nextInt(900000) + 100000}',
                                  extraRows: [
                                    {'label': 'Police', 'value': policeCtrl.text},
                                    {'label': 'Quittance', 'value': 'Réglée intégralement'},
                                  ],
                                );
                              }
                            },
                      child: Text(isProcessing.value ? 'Règlement...' : 'Payer la facture',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. MINI-PROGRAMME INTERNET FIBRE
  // ---------------------------------------------------------------------------
  void _showInternetDialog(BuildContext context, ServiceItem item) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi, size: 40, color: ChatMeColors.violet),
              const SizedBox(height: 10),
              const Text('Internet Haut Débit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Abonnement CanalBox, Moov Fibre & Celtiis Fibre disponible.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. MINI-PROGRAMME VTC & TAXI COTONOU
  // ---------------------------------------------------------------------------
  void _showTaxiDialog(BuildContext context, ServiceItem item) {
    final fromCtrl = TextEditingController(text: 'Haie Vive, Cotonou');
    final toCtrl = TextEditingController(text: 'Aéroport International de Cotonou');
    final selectedCategory = 1.obs; // 0 = Zem, 1 = Taxi Standard, 2 = VIP
    final fares = [500, 2000, 4500];
    final isBooking = false.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57F17).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_taxi, color: Color(0xFFF57F17)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Course Taxi & VTC Cotonou',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Déplacement sécurisé en temps réel',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fromCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.my_location, color: Colors.green),
                    labelText: 'Point de départ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: toCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on, color: Colors.red),
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Type de véhicule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Obx(() => Row(
                      children: [
                        _taxiOption(0, '🛵 Moto Zem', '500 F', selectedCategory),
                        const SizedBox(width: 8),
                        _taxiOption(1, '🚗 Taxi Confort', '2 000 F', selectedCategory),
                        const SizedBox(width: 8),
                        _taxiOption(2, '🚘 VIP Climatise', '4 500 F', selectedCategory),
                      ],
                    )),
                const SizedBox(height: 20),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF57F17),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isBooking.value
                            ? null
                            : () async {
                                final fare = fares[selectedCategory.value];
                                if (fare > WalletService.to.balance.value) {
                                  Get.snackbar('Solde insuffisant', 'Rechargez votre portefeuille pour commander',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }
                                isBooking.value = true;
                                final ok = await WalletService.to.payAsync(
                                  fare,
                                  'Course VTC: ${fromCtrl.text} -> ${toCtrl.text}',
                                );
                                isBooking.value = false;

                                if (ok) {
                                  Get.back();
                                  HapticFeedback.heavyImpact();
                                  _showOfficialReceiptDialog(
                                    serviceTitle: 'Réservation VTC Cotonou',
                                    provider: 'ChatMe Mobility',
                                    amount: fare,
                                    refCode: 'VTC-${Random().nextInt(900000) + 100000}',
                                    extraRows: [
                                      {'label': 'Départ', 'value': fromCtrl.text},
                                      {'label': 'Destination', 'value': toCtrl.text},
                                      {'label': 'Chauffeur assigné', 'value': 'Koffi A. (Toyota AB-492-RB)'},
                                      {'label': 'Arrivée estimée', 'value': 'Dans 4 minutes'},
                                    ],
                                  );
                                }
                              },
                        child: Text(
                          isBooking.value
                              ? 'Recherche d\'un chauffeur...'
                              : 'Réserver & Payer (${FormatUtils.fmtFcfa(fares[selectedCategory.value])} FCFA)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _taxiOption(int index, String label, String price, RxInt selected) {
    final isSel = selected.value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => selected.value = index,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFF57F17).withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? const Color(0xFFF57F17) : Colors.grey.shade300,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(price,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSel ? const Color(0xFFF57F17) : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. MODAL REÇU NUMÉRIQUE OFFICIEL AVEC CODE COPIABLE
  // ---------------------------------------------------------------------------
  void _showOfficialReceiptDialog({
    required String serviceTitle,
    required String provider,
    required int amount,
    required String refCode,
    String? tokenCode,
    required List<Map<String, String>> extraRows,
  }) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B8A5A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              const Text('Reçu Numérique Officiel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(serviceTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ChatMeColors.ink)),
              const SizedBox(height: 8),
              Text(
                '${FormatUtils.fmtFcfa(amount)} FCFA',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1B8A5A)),
              ),
              const SizedBox(height: 14),
              if (tokenCode != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF57C00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('CODE DE RECHARGE (20 CHIFFRES)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF57C00))),
                      const SizedBox(height: 6),
                      SelectableText(
                        tokenCode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 14, color: Color(0xFFF57C00)),
                        label: const Text('Copier le code',
                            style: TextStyle(fontSize: 12, color: Color(0xFFF57C00), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tokenCode));
                          Get.snackbar('Copié', 'Code de recharge copié dans le presse-papiers',
                              snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _receiptRow('Référence', refCode),
                    _receiptRow('Date & Heure', DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.now())),
                    _receiptRow('Fournisseur', provider),
                    ...extraRows.map((r) => _receiptRow(r['label']!, r['value']!)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ChatMeColors.violet,
                        side: const BorderSide(color: ChatMeColors.violet),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.now());
                        final details = extraRows.map((r) => '• ${r['label']}: ${r['value']}').join('\n');
                        final tokenText = tokenCode != null ? '\n🔑 CODE TOKEN: $tokenCode\n' : '';
                        final receiptText = '''
==============================
🧾 REÇU OFFICIEL CHATME BÉNIN
==============================
Service: $serviceTitle
Montant: ${FormatUtils.fmtFcfa(amount)} FCFA
Fournisseur: $provider
Réf: $refCode
Date: $dateStr$tokenText
Détails:
$details
------------------------------
Certifié conforme par ChatMe SuperApp
==============================''';
                        Clipboard.setData(ClipboardData(text: receiptText));
                        Get.snackbar(
                          'Reçu officiel copié',
                          'Le reçu complet a été copié. Vous pouvez le coller dans une discussion ou par SMS.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: ChatMeColors.violet,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 4),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ChatMeColors.violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Service service;
  final ServiceItem item;
  final bool isInteractive;
  final VoidCallback onTap;

  const _ItemRow({
    required this.service,
    required this.item,
    required this.isInteractive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  color: service.color.withValues(alpha: isInteractive ? 1.0 : 0.75),
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
                    Text(
                      isInteractive ? 'Appuyez pour configurer & payer' : 'Bientôt disponible',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isInteractive ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInteractive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isInteractive ? Icons.play_arrow : Icons.lock_clock,
                      size: 13,
                      color: isInteractive ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isInteractive ? 'Ouvrir' : 'Bientôt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isInteractive ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
