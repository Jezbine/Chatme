import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/utils/format_utils.dart';
import 'package:chatme/services/wallet_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/services/contacts_service.dart';
import 'mini_app_frame.dart';

/// Mini-Application Télécom & Data Bénin (MTN, Moov Africa, Celtiis).
/// Offre une expérience autonome d'achat de crédit, forfaits data et forfaits mixtes.
class TelecomMiniApp extends StatefulWidget {
  const TelecomMiniApp({super.key});

  @override
  State<TelecomMiniApp> createState() => _TelecomMiniAppState();
}

class _TelecomMiniAppState extends State<TelecomMiniApp> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedOperator = 'MTN'; // 'MTN', 'MOOV', 'CELTIIS'
  int _selectedAmount = 1000;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customAmountController = TextEditingController();
  bool _isRecharging = false;

  final Map<String, Map<String, dynamic>> _operators = {
    'MTN': {
      'name': 'MTN Bénin',
      'color': const Color(0xFFFFCC00),
      'textColor': Colors.black87,
      'prefix': '+229 01',
      'tagline': 'Everywhere you go • Y\'ello',
      'icon': Icons.cell_tower,
      'dataOffers': [
        {'title': 'Maxi Jour 1 Go', 'validity': '24h', 'price': 500, 'volume': '1 Go'},
        {'title': 'Maxi Semaine 3 Go', 'validity': '7 jours', 'price': 1500, 'volume': '3 Go'},
        {'title': 'Giga Mois 10 Go', 'validity': '30 jours', 'price': 5000, 'volume': '10 Go'},
        {'title': 'Giga Mois 25 Go', 'validity': '30 jours', 'price': 10000, 'volume': '25 Go'},
        {'title': 'Nuit Illimitée', 'validity': '00h - 06h', 'price': 300, 'volume': 'Illimité'},
      ],
      'mixOffers': [
        {'title': 'Y\'ello Mix Mini', 'desc': '50min d\'appels + 500 Mo', 'price': 1000},
        {'title': 'Y\'ello Mix Pro', 'desc': '180min d\'appels + 3 Go', 'price': 3000},
        {'title': 'Y\'ello VIP', 'desc': 'Appels illimités + 15 Go', 'price': 10000},
      ],
    },
    'MOOV': {
      'name': 'Moov Africa',
      'color': const Color(0xFF005BAA),
      'textColor': Colors.white,
      'prefix': '+229 02',
      'tagline': 'Un monde nouveau vous appelle',
      'icon': Icons.wifi_tethering,
      'dataOffers': [
        {'title': 'Moov Flex 1.2 Go', 'validity': '24h', 'price': 500, 'volume': '1.2 Go'},
        {'title': 'Choco Hebdo 4 Go', 'validity': '7 jours', 'price': 1800, 'volume': '4 Go'},
        {'title': 'Moov Mensuel 12 Go', 'validity': '30 jours', 'price': 5000, 'volume': '12 Go'},
        {'title': 'Moov Giga 30 Go', 'validity': '30 jours', 'price': 10000, 'volume': '30 Go'},
      ],
      'mixOffers': [
        {'title': 'Choco Mixte', 'desc': '45min tous réseaux + 1 Go', 'price': 1000},
        {'title': 'Izi Pack', 'desc': '120min + 4 Go', 'price': 3500},
      ],
    },
    'CELTIIS': {
      'name': 'Celtiis Bénin',
      'color': const Color(0xFF5E2750),
      'textColor': Colors.white,
      'prefix': '+229 03',
      'tagline': 'Le réseau 100% national • SBIN',
      'icon': Icons.bolt,
      'dataOffers': [
        {'title': 'Gbékoun 1.5 Go', 'validity': '24h', 'price': 500, 'volume': '1.5 Go'},
        {'title': 'Alafia Semaine 5 Go', 'validity': '7 jours', 'price': 2000, 'volume': '5 Go'},
        {'title': 'Alafia Mois 15 Go', 'validity': '30 jours', 'price': 5000, 'volume': '15 Go'},
        {'title': 'Giga Celtiis 40 Go', 'validity': '30 jours', 'price': 10000, 'volume': '40 Go'},
      ],
      'mixOffers': [
        {'title': 'Mixte Celtiis Découverte', 'desc': '60min + 1.5 Go', 'price': 1000},
        {'title': 'Mixte Celtiis Sérénité', 'desc': '200min + 6 Go', 'price': 4000},
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Pré-remplir avec le numéro de l'utilisateur connecté s'il existe
    final user = Get.find<AuthService>().currentUser.value;
    if (user != null && user.phoneNumber.isNotEmpty) {
      _phoneController.text = user.phoneNumber;
    } else {
      _phoneController.text = '+229 01 97 00 00 00';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final op = _operators[_selectedOperator]!;
    final Color opColor = op['color'] as Color;

    return MiniAppFrame(
      title: 'Télécom & Data Bénin',
      subtitle: op['name'] as String,
      brandColor: opColor,
      body: Column(
        children: [
          // 1. Sélecteur visuel d'opérateur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor,
            child: Row(
              children: _operators.keys.map((key) {
                final isSelected = _selectedOperator == key;
                final opData = _operators[key]!;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedOperator = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? opData['color'] as Color : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (opData['color'] as Color).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opData['icon'] as IconData,
                            size: 20,
                            color: isSelected ? opData['textColor'] as Color : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            key,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? opData['textColor'] as Color : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 2. Champ numéro de téléphone avec raccourci répertoire
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Numéro à recharger',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.contacts, color: ChatMeColors.violet, size: 20),
                    tooltip: 'Choisir un contact',
                    onPressed: _pickContact,
                  ),
                ],
              ),
            ),
          ),

          // 3. Onglets : Crédit / Data / Mixtes
          TabBar(
            controller: _tabController,
            labelColor: ChatMeColors.ink,
            unselectedLabelColor: Colors.grey,
            indicatorColor: opColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Crédit d\'appel'),
              Tab(text: 'Forfaits Data'),
              Tab(text: 'Packs Mixtes'),
            ],
          ),

          // 4. Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreditTab(opColor),
                _buildDataTab(op, opColor),
                _buildMixTab(op, opColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditTab(Color opColor) {
    final amounts = [500, 1000, 2000, 5000, 10000];
    final wallet = Get.find<WalletService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Sélectionnez un montant :',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: amounts.map((amt) {
            final isSelected = _selectedAmount == amt;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAmount = amt;
                  _customAmountController.clear();
                });
              },
              child: Container(
                width: (MediaQuery.of(context).size.width - 52) / 3,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? opColor.withValues(alpha: 0.15) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? opColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${FormatUtils.fmtFcfa(amt)} F',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black87 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amt >= 5000 ? '+10% Bonus' : 'Standard',
                      style: TextStyle(
                        fontSize: 9,
                        color: amt >= 5000 ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        // Montant personnalisé
        TextField(
          controller: _customAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Ou entrez un montant libre (FCFA)',
            prefixIcon: const Icon(Icons.edit),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null && parsed > 0) {
              setState(() => _selectedAmount = parsed);
            }
          },
        ),
        const SizedBox(height: 24),
        // Info solde portefeuille
        Obx(() {
          final bal = wallet.balance.value;
          final enough = bal >= _selectedAmount;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enough ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: enough ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  enough ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                  color: enough ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Solde ChatMe : ${FormatUtils.fmtFcfa(bal)} FCFA',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: enough ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ChatMeColors.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: _isRecharging ? null : () => _executePurchase('Recharge Crédit', _selectedAmount),
            child: _isRecharging
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'Recharger ${_phoneController.text} (${FormatUtils.fmtFcfa(_selectedAmount)} F)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTab(Map<String, dynamic> op, Color opColor) {
    final List offers = op['dataOffers'] as List;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final offer = offers[i] as Map<String, dynamic>;
        final price = offer['price'] as int;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: opColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    offer['volume'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Validité : ${offer['validity']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatMeColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _isRecharging ? null : () => _executePurchase('Forfait Data ${offer['title']}', price),
                child: Text('${FormatUtils.fmtFcfa(price)} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMixTab(Map<String, dynamic> op, Color opColor) {
    final List offers = op['mixOffers'] as List;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final offer = offers[i] as Map<String, dynamic>;
        final price = offer['price'] as int;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: opColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.all_inclusive, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(offer['desc'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatMeColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _isRecharging ? null : () => _executePurchase(offer['title'] as String, price),
                child: Text('${FormatUtils.fmtFcfa(price)} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickContact() {
    final contacts = ContactsService.to.added;
    if (contacts.isEmpty) {
      Get.snackbar('Répertoire', 'Aucun contact enregistré dans ChatMe pour le moment.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    Get.bottomSheet(
      Container(
        height: 350,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Choisir un contact à recharger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, i) {
                  final c = contacts[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(c.colorValue),
                      child: Text(c.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.phoneNumber ?? 'Numéro masqué'),
                    onTap: () {
                      if (c.phoneNumber != null && c.phoneNumber!.isNotEmpty) {
                        setState(() => _phoneController.text = c.phoneNumber!);
                      }
                      Get.back();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executePurchase(String itemTitle, int amount) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      Get.snackbar('Numéro requis', 'Veuillez renseigner le numéro à recharger.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final wallet = Get.find<WalletService>();
    if (wallet.balance.value < amount) {
      Get.snackbar(
        'Solde insuffisant',
        'Votre portefeuille ChatMe a besoin d\'être rechargé pour effectuer cet achat.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isRecharging = true);
    try {
      final success = await wallet.payAsync(amount, '$_selectedOperator - $itemTitle ($phone)');
      if (success) {
        HapticFeedback.heavyImpact();
        final ref = 'TEL-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
        _showSuccessReceipt(itemTitle, amount, phone, ref);
      } else {
        Get.snackbar('Échec', 'Impossible de valider la transaction.', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isRecharging = false);
    }
  }

  void _showSuccessReceipt(String title, int amount, String phone, String ref) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.now());
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: Color(0xFF1B8A5A), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              const Text('Recharge Effectuée avec Succès !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Opérateur : $_selectedOperator Bénin', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              Text('${FormatUtils.fmtFcfa(amount)} FCFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Color(0xFF1B8A5A))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _receiptRow('Détail', title),
                    _receiptRow('Numéro crédité', phone),
                    _receiptRow('Référence', ref),
                    _receiptRow('Date', dateStr),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Partager'),
                      onPressed: () {
                        final text = '🧾 Reçu ChatMe: Recharge $title de ${FormatUtils.fmtFcfa(amount)} F sur $phone. Réf: $ref - Certifié par ChatMe Bénin.';
                        Clipboard.setData(ClipboardData(text: text));
                        Get.snackbar('Copié', 'Reçu officiel copié pour partage SMS/WhatsApp', snackPosition: SnackPosition.BOTTOM);
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

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}
