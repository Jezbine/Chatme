import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/chatme_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../widgets/chat_header.dart';
import '../../widgets/chat_sheets.dart';
import '../../services/wallet_service.dart';
import '../../services/contacts_service.dart';
import '../../services/auth_service.dart';
import 'my_qr_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = WalletService.to;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const ChatHeader(title: 'Portefeuille'),
            Expanded(
              child: Obx(() {
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [ChatMeColors.violet, Color(0xFF5B52B8)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Solde disponible',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            '${FormatUtils.fmtFcfa(wallet.balance.value)} FCFA',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _QuickAction(
                            icon: Icons.arrow_upward,
                            label: 'Envoyer',
                            onTap: () => showContactsPaySheet(context),
                          ),
                          _QuickAction(
                            icon: Icons.arrow_downward,
                            label: 'Retrait',
                            onTap: () => showAmountSheet(
                              context,
                              title: 'Retrait (XOF)',
                              onConfirm: (amount) async {
                                final ok = await wallet.withdraw(amount, label: 'Retrait');
                                if (!ok) {
                                  Get.snackbar('Échec', 'Retrait impossible — solde insuffisant',
                                      snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
                                }
                              },
                            ),
                          ),
                          _QuickAction(
                            icon: Icons.qr_code_scanner,
                            label: 'Payer QR',
                            onTap: () => _showQrChoice(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.account_balance_wallet, size: 16, color: cs.primary),
                              label: Text('Dépôt', style: TextStyle(color: cs.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: cs.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => showAmountSheet(
                                context,
                                title: 'Dépôt (XOF)',
                                onConfirm: (amount) async {
                                  final ok = await wallet.deposit(amount, label: 'Dépôt');
                                  if (!ok) {
                                    Get.snackbar('Échec', 'Dépôt échoué', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, color: Colors.white, size: 16),
                              label: const Text('Recharger', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _showRechargeSheet(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text('TRANSACTIONS RÉCENTES',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant)),
                          const Spacer(),
                          Obx(() => Text('${wallet.transactions.length} • Banque',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6)))),
                        ],
                      ),
                    ),
                    if (wallet.transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.account_balance, size: 28, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            Text('Aucune transaction — portefeuille banque à 0 FCFA',
                                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Faites un dépôt ou une recharge pour commencer.',
                                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11)),
                          ],
                        ),
                      ),
                    ...wallet.transactions.map((t) => _TxItem(
                          label: t.label,
                          time: wallet.timeAgo(t.date),
                          amount:
                              '${t.amount >= 0 ? '+' : ''}${FormatUtils.fmtFcfa(t.amount)} FCFA',
                          positive: t.amount >= 0,
                        )),
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRechargeSheet(BuildContext context) async {
    final wallet = WalletService.to;

    final amountController = TextEditingController(text: '1000');
    final phoneController = TextEditingController();

    // Pré-remplir le numéro si disponible dans le profil de l'utilisateur
    if (Get.isRegistered<AuthService>()) {
      final userPhone = AuthService.to.currentUser.value?.phoneNumber;
      if (userPhone != null && userPhone.isNotEmpty) {
        String clean = userPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (clean.startsWith('229') && clean.length > 8) {
          clean = clean.substring(3);
        }
        phoneController.text = clean;
      }
    }

    final selectedMode = 'mtn_open'.obs; // 'mtn_open', 'moov', 'card'
    final isSubmitting = false.obs;
    final errorMessage = ''.obs;

    await Get.bottomSheet(
      SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Obx(() {
                final mode = selectedMode.value;
                final isMobileMoney = mode == 'mtn_open' || mode == 'moov';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barre de poignée
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // En-tête
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ChatMeColors.violet.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: ChatMeColors.violet, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recharger le portefeuille',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              Text(
                                'Paiement sécurisé FedaPay Bénin',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section Montant
                    Text(
                      'MONTANT (FCFA)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.monetization_on_outlined, color: ChatMeColors.violet),
                        suffixText: 'FCFA',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54),
                        hintText: 'Ex: 1000',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ChatMeColors.violet, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Suggestions montants rapides
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [500, 1000, 2000, 5000, 10000].map((amt) {
                        final isSelected = amountController.text == amt.toString();
                        return InkWell(
                          onTap: () {
                            amountController.text = amt.toString();
                            selectedMode.refresh();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? ChatMeColors.violet : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? ChatMeColors.violet : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              '${FormatUtils.fmtFcfa(amt)} F',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Section Moyen de paiement
                    Text(
                      'MOYEN DE PAIEMENT',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),

                    // MTN
                    _rechargePaymentTile(
                      title: 'MTN Mobile Money Bénin',
                      subtitle: 'Invite USSD directe sur votre mobile',
                      badgeText: 'Populaire',
                      badgeColor: const Color(0xFFFFCC00),
                      badgeTextColor: Colors.black,
                      isSelected: mode == 'mtn_open',
                      icon: Icons.phone_android,
                      iconColor: const Color(0xFFD49B00),
                      onTap: () => selectedMode.value = 'mtn_open',
                    ),
                    const SizedBox(height: 8),

                    // Moov
                    _rechargePaymentTile(
                      title: 'Moov Money Bénin',
                      subtitle: 'Invite USSD directe sur votre mobile',
                      isSelected: mode == 'moov',
                      icon: Icons.phone_android,
                      iconColor: const Color(0xFF008938),
                      onTap: () => selectedMode.value = 'moov',
                    ),
                    const SizedBox(height: 8),

                    // Carte Bancaire
                    _rechargePaymentTile(
                      title: 'Carte bancaire / Autre',
                      subtitle: 'Visa, Mastercard ou portail web FedaPay',
                      isSelected: mode == 'card',
                      icon: Icons.credit_card,
                      iconColor: Colors.blueAccent,
                      onTap: () => selectedMode.value = 'card',
                    ),
                    const SizedBox(height: 16),

                    // Numéro de téléphone pour Mobile Money
                    if (isMobileMoney) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NUMÉRO DU COMPTE BÉNIN',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700, letterSpacing: 0.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Bénin (+229)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.black),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            child: const Text('+229', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '97 00 00 00',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ChatMeColors.violet, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '📲 Une notification USSD sera envoyée sur ce numéro pour valider avec votre code PIN.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (errorMessage.value.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage.value,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Bouton Valider
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ChatMeColors.violet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting.value
                            ? null
                            : () async {
                                final rawAmt = amountController.text.trim();
                                final amt = int.tryParse(rawAmt);
                                if (amt == null || amt < 100) {
                                  errorMessage.value = 'Veuillez saisir un montant valide (minimum 100 FCFA)';
                                  return;
                                }

                                final phone = phoneController.text.trim();
                                if (isMobileMoney) {
                                  final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
                                  if (clean.length < 8) {
                                    errorMessage.value = 'Veuillez saisir un numéro de téléphone valide (8 chiffres min)';
                                    return;
                                  }
                                }

                                errorMessage.value = '';
                                isSubmitting.value = true;
                                Get.back();

                                await wallet.rechargeWithFedapay(
                                  amt,
                                  phoneNumber: phone,
                                  mode: mode,
                                );
                              },
                        child: isSubmitting.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.lock_outline, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Valider et Payer',
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _rechargePaymentTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? ChatMeColors.violet.withValues(alpha: 0.08) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? ChatMeColors.violet : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor ?? Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeTextColor ?? Colors.black),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? ChatMeColors.violet : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQrChoice(BuildContext context) async {
    await Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: ChatMeColors.border, borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Paiement QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ChatMeColors.ink))),
            const SizedBox(height: 8),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Choisissez une action', style: TextStyle(fontSize: 13, color: ChatMeColors.inkSoft), textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ChatMeColors.violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_upward, color: ChatMeColors.violet)),
              title: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Scanner le QR du receveur', style: TextStyle(fontSize: 12, color: ChatMeColors.inkSoft)),
              onTap: () { Get.back(); _scanForUserToPay(context); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ChatMeColors.cProfil.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code, color: ChatMeColors.cProfil)),
              title: const Text('Recevoir', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Afficher mon QR pour être payé', style: TextStyle(fontSize: 12, color: ChatMeColors.inkSoft)),
              onTap: () { Get.back(); Get.to(() => const MyQrScreen()); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      backgroundColor: ChatMeColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    );
  }

  Future<void> _scanForUserToPay(BuildContext context) async {
    final MobileScannerController controller = MobileScannerController();
    bool handled = false;
    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: ChatMeColors.border, borderRadius: BorderRadius.circular(2))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Scanner pour envoyer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ChatMeColors.ink))),
              const SizedBox(height: 8),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Scannez le QR du receveur, puis choisissez le montant', style: TextStyle(fontSize: 13, color: ChatMeColors.inkSoft), textAlign: TextAlign.center)),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: ChatMeColors.violet, width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      if (handled) return;
                      for (final barcode in capture.barcodes) {
                        if (barcode.rawValue != null) {
                          handled = true;
                          controller.dispose();
                          Get.back();
                          _processUserQrForPayment(context, barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(onPressed: () { controller.dispose(); Get.back(); }, icon: const Icon(Icons.close, color: ChatMeColors.inkSoft), label: const Text('Annuler', style: TextStyle(color: ChatMeColors.inkSoft))),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      backgroundColor: ChatMeColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    );
  }

  void _processUserQrForPayment(BuildContext context, String qrData) {
    final data = parseUserQrPayload(qrData);
    if (data == null) {
      // Fallback: essayer format paiement marchand
      _processPaymentQR(context, qrData);
      return;
    }
    final destId = data['id']!;
    final destName = data['name']!;
    final myId = AuthService.to.currentUser.value?.id;
    if (myId != null && destId == myId) {
      Get.snackbar('Erreur', 'Vous ne pouvez pas vous envoyer de l\'argent à vous-même', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      return;
    }
    // L'envoyeur choisit le montant après scan (demande utilisateur)
    showAmountSheet(
      context,
      title: 'Envoyer à $destName (XOF)',
      onConfirm: (amount) async {
        final ok = await WalletService.to.transferToUser(destId, amount);
        if (ok) {
          Get.snackbar('Envoi réussi', '${FormatUtils.fmtFcfa(amount)} FCFA envoyés à $destName', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        } else {
          Get.snackbar('Échec', 'Solde insuffisant ou destinataire invalide', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        }
      },
    );
  }

  // ignore: unused_element - conservé pour QR marchand avec montant embarqué (fallback)
  Future<void> _scanToPay(BuildContext context) async {
    final MobileScannerController controller = MobileScannerController();
    bool handled = false;

    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: ChatMeColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Scanner pour payer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ChatMeColors.ink),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Placez le QR code du marchand dans le cadre',
                  style: TextStyle(fontSize: 13, color: ChatMeColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ChatMeColors.violet, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      if (handled) return;
                      for (final barcode in capture.barcodes) {
                        if (barcode.rawValue != null) {
                          handled = true;
                          controller.dispose();
                          Get.back();
                          _processPaymentQR(context, barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  controller.dispose();
                  Get.back();
                },
                icon: const Icon(Icons.close, color: ChatMeColors.inkSoft),
                label: const Text('Annuler', style: TextStyle(color: ChatMeColors.inkSoft)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      backgroundColor: ChatMeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    );
  }

  void _processPaymentQR(BuildContext context, String qrData) {
    // Si c'est un QR utilisateur (receveur), déléguer au flux Envoyer avec choix montant
    if (qrData.startsWith('chatme:user:')) {
      _processUserQrForPayment(context, qrData);
      return;
    }
    // Expected QR format: "chatme://pay?merchant=MARCHANT_NAME&amount=1200&id=MERCHANT_ID"
    // Or simple: "merchant_name|1200|merchant_id"
    try {
      String merchantName = 'Marchand';
      int amount = 0;

      if (qrData.startsWith('chatme://pay')) {
        final uri = Uri.parse(qrData);
        merchantName = uri.queryParameters['merchant'] ?? 'Marchand';
        amount = int.tryParse(uri.queryParameters['amount'] ?? '') ?? 0;
      } else if (qrData.contains('|')) {
        // Format: name|amount|id
        final parts = qrData.split('|');
        if (parts.length >= 2) {
          merchantName = parts[0];
          amount = int.tryParse(parts[1]) ?? 0;
        }
      } else {
        Get.snackbar('QR invalide', 'Format de QR code non reconnu',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        return;
      }

      if (amount <= 0) {
        Get.snackbar('Montant invalide', 'Le QR ne contient pas de montant valide',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        return;
      }

      // Show confirmation dialog
      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirmer le paiement', style: TextStyle(color: Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marchand: $merchantName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
              const SizedBox(height: 8),
              Text('Montant: ${FormatUtils.fmtFcfa(amount)} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Annuler', style: TextStyle(color: Colors.black))),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                final wallet = WalletService.to;
                final ok = await wallet.payAsync(amount, 'Paiement QR: $merchantName');
                if (ok) {
                  Get.snackbar('Paiement réussi', '${FormatUtils.fmtFcfa(amount)} FCFA payés à $merchantName',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.white,
                      colorText: Colors.black);
                } else {
                  Get.snackbar('Solde insuffisant', 'Rechargez votre compte pour payer',
                      snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: ChatMeColors.violet),
              child: const Text('Payer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de traiter le QR: $e',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final String label;
  final String time;
  final String amount;
  final bool positive;
  const _TxItem({required this.label, required this.time, required this.amount, required this.positive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.3), width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(time, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: positive ? ChatMeColors.cProfil : const Color(0xFFC4485E),
            ),
          ),
        ],
      ),
    );
  }
}
