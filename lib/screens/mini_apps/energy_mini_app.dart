import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/utils/format_utils.dart';
import 'package:chatme/services/wallet_service.dart';
import 'mini_app_frame.dart';

/// Mini-Application Énergie & Eau Bénin (SBEE & SONEB).
/// Permet la recharge de compteur prépayé avec simulateur kWh, génération de token 20 chiffres
/// et paiement des quittances d'eau SONEB.
class EnergyMiniApp extends StatefulWidget {
  final String initialTab; // 'SBEE' ou 'SONEB'
  const EnergyMiniApp({super.key, this.initialTab = 'SBEE'});

  @override
  State<EnergyMiniApp> createState() => _EnergyMiniAppState();
}

class _EnergyMiniAppState extends State<EnergyMiniApp> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _meterController = TextEditingController(text: '14285930214');
  final TextEditingController _amountController = TextEditingController(text: '5000');
  final TextEditingController _sonebPoliceController = TextEditingController(text: '08429153');
  bool _isProcessing = false;

  // Simulateur de kWh : 1 kWh = environ 110 FCFA (tranche conventionnelle SBEE)
  double get _estimatedKwh {
    final amt = int.tryParse(_amountController.text) ?? 0;
    if (amt <= 0) return 0.0;
    return (amt / 108.5);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'SONEB' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _meterController.dispose();
    _amountController.dispose();
    _sonebPoliceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniAppFrame(
      title: 'Énergie & Services Publics 🇧🇯',
      subtitle: 'SBEE Électricité & SONEB Eau',
      brandColor: const Color(0xFFF57C00),
      body: Column(
        children: [
          // En-tête des onglets SBEE / SONEB
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ChatMeColors.ink,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFF57C00),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.flash_on, color: Color(0xFFF57C00)), text: 'SBEE (Électricité)'),
                Tab(icon: Icon(Icons.water_drop, color: Color(0xFF0288D1)), text: 'SONEB (Eau)'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSbeeTab(),
                _buildSonebTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSbeeTab() {
    final amounts = [2000, 5000, 10000, 15000, 25000];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'info compteur
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('COMPTEUR PRÉPAYÉ SBEE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Text('Actif', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _meterController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                decoration: const InputDecoration(
                  labelText: 'Numéro de compteur',
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.speed, color: Colors.white70),
                ),
              ),
              const Divider(color: Colors.white24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Titulaire : AKPOVO Marcellin', style: TextStyle(color: Colors.white, fontSize: 11)),
                  Text('Cotonou - Littoral', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Simulateur intelligent kWh
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                child: const Icon(Icons.calculate_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimation de consommation :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.brown)),
                    const SizedBox(height: 2),
                    Text(
                      '~ ${_estimatedKwh.toStringAsFixed(1)} kWh d\'énergie',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.brown),
                    ),
                    Text('Basé sur le tarif basse tension conventionnel SBEE', style: TextStyle(fontSize: 10, color: Colors.brown.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text('Sélectionnez ou saisissez un montant :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),

        // Paliers rapides
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: amounts.map((amt) {
              final isSel = _amountController.text == amt.toString();
              return GestureDetector(
                onTap: () => setState(() => _amountController.text = amt.toString()),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFF57C00) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? const Color(0xFFF57C00) : Colors.grey.shade300),
                  ),
                  child: Text(
                    '${FormatUtils.fmtFcfa(amt)} F',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Montant de recharge (FCFA)',
            prefixIcon: const Icon(Icons.payments_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isProcessing ? const SizedBox() : const Icon(Icons.flash_on),
            label: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Payer & Obtenir le Code (20 chiffres)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _isProcessing ? null : _purchaseSbeeToken,
          ),
        ),
      ],
    );
  }

  Widget _buildSonebTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0277BD), Color(0xFF01579B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('QUITTANCE D\'EAU SONEB', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _sonebPoliceController,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Numéro de police abonné',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.water, color: Colors.white70),
                ),
              ),
              const Divider(color: Colors.white24),
              const Text('Abonné : SOSSOU Jean-Baptiste • Lot 428 Cadjehoun', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Facture en cours (Mois précédent)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Échéance : 28 du mois', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Volume consommé :', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Text('18 m³ (18 000 Litres)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Montant net à payer :', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Text('6 450 FCFA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0277BD))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0277BD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.payment),
            label: const Text('Régler la facture (6 450 FCFA)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _paySonebBill,
          ),
        ),
      ],
    );
  }

  Future<void> _purchaseSbeeToken() async {
    final amt = int.tryParse(_amountController.text) ?? 0;
    if (amt <= 0) {
      Get.snackbar('Montant invalide', 'Veuillez renseigner un montant valide.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final wallet = Get.find<WalletService>();
    if (wallet.balance.value < amt) {
      Get.snackbar('Solde insuffisant', 'Veuillez recharger votre portefeuille ChatMe.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final ok = await wallet.payAsync(amt, 'Recharge SBEE Compteur ${_meterController.text}');
      if (ok) {
        HapticFeedback.heavyImpact();
        // Génération d'un token prépayé réaliste (20 chiffres espacés par 4)
        final rng = Random();
        final p1 = (1000 + rng.nextInt(9000)).toString();
        final p2 = (1000 + rng.nextInt(9000)).toString();
        final p3 = (1000 + rng.nextInt(9000)).toString();
        final p4 = (1000 + rng.nextInt(9000)).toString();
        final p5 = (1000 + rng.nextInt(9000)).toString();
        final token = '$p1-$p2-$p3-$p4-$p5';
        final ref = 'SBEE-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

        _showSbeeReceiptDialog(amt, token, ref);
      } else {
        Get.snackbar('Erreur', 'Impossible de valider le paiement.', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _paySonebBill() async {
    const amt = 6450;
    final wallet = Get.find<WalletService>();
    if (wallet.balance.value < amt) {
      Get.snackbar('Solde insuffisant', 'Veuillez recharger votre portefeuille.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final ok = await wallet.payAsync(amt, 'Paiement facture SONEB Police ${_sonebPoliceController.text}');
    if (ok) {
      Get.dialog(
        AlertDialog(
          title: const Text('Facture SONEB Réglée !'),
          content: Text('La quittance pour la police ${_sonebPoliceController.text} a été émise avec succès. Montant: 6 450 FCFA.'),
          actions: [TextButton(onPressed: () => Get.back(), child: const Text('Fermer'))],
        ),
      );
    }
  }

  void _showSbeeReceiptDialog(int amount, String token, String ref) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              const Text('RECHARGE SBEE CONFIRMÉE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('${FormatUtils.fmtFcfa(amount)} FCFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF2E7D32))),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  children: [
                    const Text('TAPEZ CE CODE SUR VOTRE COMPTEUR :', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                    const SizedBox(height: 6),
                    SelectableText(
                      token,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copier le code 20 chiffres', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token.replaceAll('-', '')));
                        Get.snackbar('Copié', 'Code compteur copié sans tirets', snackPosition: SnackPosition.BOTTOM);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Compteur : ${_meterController.text} • Réf: $ref', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Partager'),
                      onPressed: () {
                        final text = '⚡ Reçu SBEE ChatMe: Code Token : $token pour le compteur ${_meterController.text}. Montant: ${FormatUtils.fmtFcfa(amount)} FCFA.';
                        Clipboard.setData(ClipboardData(text: text));
                        Get.snackbar('Copié', 'Texte de reçu copié pour partage', snackPosition: SnackPosition.BOTTOM);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ChatMeColors.violet, foregroundColor: Colors.white),
                      onPressed: () => Get.back(),
                      child: const Text('Terminer'),
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
}
