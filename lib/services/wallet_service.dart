import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:feda_flutter/feda_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatme/config/fedapay_config.dart';
import 'package:chatme/core/theme/chatme_theme.dart' show ChatMeColors;
import 'package:chatme/core/utils/format_utils.dart';
import 'package:chatme/services/auth_service.dart';

class WalletTransaction {
  final String id;
  final String label;
  final int amount; // positif = crédit, débit = négatif
  final DateTime date;
  final String? paymentStatus; // 'pending', 'completed', 'failed'

  WalletTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    this.paymentStatus,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentStatus': paymentStatus,
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        id: j['id'] as String,
        label: j['label'] as String,
        amount: j['amount'] as int,
        date: DateTime.parse(j['date'] as String),
        paymentStatus: j['paymentStatus'] as String?,
      );
}

class WalletService extends GetxService {
  static WalletService get to => Get.find<WalletService>();

  final RxInt balance = 0.obs;
  final RxList<WalletTransaction> transactions = <WalletTransaction>[].obs;
  final Rx<String> paymentStatus = 'idle'.obs; // idle, pending, success, failed

  bool _supabaseAvailable = false;
  RealtimeChannel? _balanceChannel;
  RealtimeChannel? _txChannel;

  WalletService() {
    _initFedaPay();
  }

  void _initFedaPay() {
    if (!FedaPayConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint('[Wallet] FEDA_API_KEY non défini. Recharge désactivée jusqu\'à config.');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[Wallet] FedaPay init en mode ${FedaPayConfig.isLive ? 'LIVE' : 'SANDBOX'}');
    }
    FedaFlutter.applyConfig(
      apiKey: FedaPayConfig.apiKey,
      environment: FedaPayConfig.isLive ? ApiEnvironment.live : ApiEnvironment.sandbox,
    );
  }

  Future<WalletService> init() async {
    // Essayer Supabase en priorité -> portefeuille RÉEL persistant par utilisateur
    try {
      final client = Supabase.instance.client;
      // Test si tables wallet_balances / wallet_transactions existent
      await client.from('wallet_balances').select('user_id').limit(1);
      _supabaseAvailable = true;
      if (kDebugMode) debugPrint('[Wallet] Supabase wallet disponible -> mode RÉEL');
    } catch (e) {
      _supabaseAvailable = false;
      if (kDebugMode) debugPrint('[Wallet] Supabase wallet non disponible, fallback local: $e');
    }

    if (_supabaseAvailable) {
      await _fetchFromSupabase();
      _subscribeRealtime();
      // Écouter les changements d'auth pour recharger le bon portefeuille
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          _fetchFromSupabase();
        }
      });
      // Fallback local toujours synchronisé en cache
      await _persistLocal();
      return this;
    }

    // Fallback 100% local (si Supabase non déployé) — mode banque : solde 0, pas d'argent magique
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('wallet_tx');

    if (stored == null) {
      balance.value = 0;
      transactions.value = [];
      await _persistLocal();
    } else {
      transactions.value = stored
          .map((e) => WalletTransaction.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      balance.value = prefs.getInt('wallet_balance') ?? 0;
    }
    return this;
  }

  Future<void> _fetchFromSupabase() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) debugPrint('[Wallet] _fetchFromSupabase: pas d\'utilisateur connecté');
        return;
      }
      // 1) Balance
      final balRow = await client.from('wallet_balances').select('balance_cents').eq('user_id', userId).maybeSingle();
      if (balRow != null && balRow['balance_cents'] != null) {
        balance.value = (balRow['balance_cents'] as num).toInt();
      } else {
        // Créer ligne initiale à 0 si inexistante — portefeuille réel vide
        balance.value = 0;
        try {
          await client.from('wallet_balances').upsert({
            'user_id': userId,
            'balance_cents': balance.value,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
        } catch (e) {
          if (kDebugMode) debugPrint('[Wallet] upsert balance initial échoué (RLS?): $e');
        }
      }

      // 2) Transactions récentes — RÉEL : aucune donnée factice
      final rows = await client
          .from('wallet_transactions')
          .select('id,label,amount_cents,status,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (rows.isNotEmpty) {
        transactions.value = rows.map((r) {
          return WalletTransaction(
            id: r['id'] as String,
            label: r['label'] as String? ?? 'Transaction',
            amount: (r['amount_cents'] as num).toInt(),
            date: DateTime.parse(r['created_at'] as String),
            paymentStatus: r['status'] as String?,
          );
        }).toList();
      } else {
        // Portefeuille réel vide — pas de fausses transactions
        transactions.value = [];
      }
      await _persistLocal();
      if (kDebugMode) debugPrint('[Wallet] _fetchFromSupabase: balance=${balance.value}, tx=${transactions.length}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] _fetchFromSupabase error: $e');
    }
  }

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      _balanceChannel = client
          .channel('wallet_balances_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wallet_balances',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
            callback: (payload) {
              if (payload.newRecord['balance_cents'] != null) {
                balance.value = (payload.newRecord['balance_cents'] as num).toInt();
              }
            },
          )
          .subscribe();
      _txChannel = client
          .channel('wallet_tx_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'wallet_transactions',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
            callback: (_) => _fetchFromSupabase(),
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] realtime subscribe error: $e');
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wallet_balance', balance.value);
    await prefs.setStringList(
      'wallet_tx',
      transactions.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  Future<void> _persistBalanceToSupabase() async {
    if (!_supabaseAvailable) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('wallet_balances').upsert({
        'user_id': userId,
        'balance_cents': balance.value,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] _persistBalanceToSupabase échoué (RLS non configuré? Exécutez fix_wallet_rls.sql): $e');
    }
  }

  Future<void> _insertTransactionToSupabase(WalletTransaction tx) async {
    if (!_supabaseAvailable) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('wallet_transactions').insert({
        'user_id': userId,
        'label': tx.label,
        'amount_cents': tx.amount,
        'status': tx.paymentStatus ?? 'completed',
        'created_at': tx.date.toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] _insertTransactionToSupabase échoué (RLS?): $e');
    }
  }

  /// Recharge via FedaPay — conforme docs.fedapay.com :
  /// 1) createTransaction avec customer (téléphone, nom, email)
  /// 2) Si mode mobile money (MTN / Moov) avec numéro, enclenche directPayment (USSD push)
  /// 3) Sinon ou en repli, ouvre l'URL de paiement FedaPay sécurisée
  /// 4) Vérifie et crédite le solde uniquement via verify-fedapay-transaction
  Future<bool> rechargeWithFedapay(
    int amount, {
    String? phoneNumber,
    String? mode,
  }) async {
    if (amount <= 0) return false;
    if (!FedaPayConfig.isConfigured) {
      paymentStatus.value = 'failed';
      if (kDebugMode) debugPrint('[Wallet] FEDA_API_KEY manquante -> recharge bloquée');
      try {
        if (!Get.testMode) {
          Get.snackbar('Recharge indisponible', 'FedaPay non configuré. Veuillez renseigner votre clé dans FedaPayConfig ou via --dart-define.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black, duration: const Duration(seconds: 4));
        }
      } catch (_) {}
      return false;
    }
    paymentStatus.value = 'pending';
    try {
      // Nettoyage et normalisation du numéro de téléphone
      String? cleanPhone;
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanPhone.startsWith('00229') && cleanPhone.length > 10) {
          cleanPhone = cleanPhone.substring(5);
        } else if (cleanPhone.startsWith('229') && cleanPhone.length > 8) {
          cleanPhone = cleanPhone.substring(3);
        }
      }

      String? email;
      String? firstname;
      if (Get.isRegistered<AuthService>()) {
        final u = AuthService.to.currentUser.value;
        email = (u?.email != null && u!.email!.isNotEmpty) ? u.email : null;
        firstname = (u?.displayName != null && u!.displayName!.isNotEmpty) ? u.displayName : null;
      }
      email ??= 'client@chatme.app';
      firstname ??= 'Client';

      CustomerCreate? customer;
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        customer = CustomerCreate(
          firstname: firstname,
          lastname: 'ChatMe',
          email: email,
          phoneNumber: PhoneNumber(number: cleanPhone, country: 'bj'),
        );
      }

      final effectiveMode = mode ?? 'mtn_open';

      // 1. Création de la transaction sur FedaPay
      ApiResponse<Transaction>? res;
      try {
        res = await FedaFlutter.instance.transactions.createTransaction(
          TransactionCreate(
            amount: amount,
            currency: CurrencyIso(iso: 'XOF'),
            description: 'Recharge portefeuille ChatMe',
            callbackUrl: FedaPayConfig.callbackUrl,
            customer: customer,
          ),
        );
      } catch (createErr) {
        if (kDebugMode) debugPrint('[Wallet] createTransaction avec customer a échoué: $createErr. Tentative sans customer...');
        // Si FedaPay rejette le format du numéro, on réessaie sans customer pour ne pas bloquer l'utilisateur
        res = await FedaFlutter.instance.transactions.createTransaction(
          TransactionCreate(
            amount: amount,
            currency: CurrencyIso(iso: 'XOF'),
            description: 'Recharge portefeuille ChatMe',
            callbackUrl: FedaPayConfig.callbackUrl,
          ),
        );
      }

      if (res == null || !res.isSuccessful || res.data == null) {
        throw Exception('createTransaction failed (code ${res?.statusCode})');
      }
      final txId = res.data!.id;
      String? url = res.data!.paymentUrl;
      String? token = res.data!.paymentToken;

      bool directPaymentInitiated = false;

      // 2. Si Mobile Money (MTN / Moov) avec numéro, initier le paiement direct USSD push
      if (cleanPhone != null && cleanPhone.isNotEmpty && (effectiveMode == 'mtn_open' || effectiveMode == 'moov')) {
        try {
          if (token == null || token.isEmpty) {
            if (url != null && url.contains('fedapay.com/')) {
              token = url.split('fedapay.com/').last.split('?').first;
            }
          }

          if (token != null && token.isNotEmpty) {
            if (kDebugMode) debugPrint('[Wallet] Envoi directPayment mode=$effectiveMode pour $cleanPhone');
            final directRes = await FedaFlutter.instance.transactions.directPayment(
              TransactionDirectPayment(
                currency: CurrencyIso(iso: 'XOF'),
                description: 'Recharge portefeuille ChatMe',
                amount: amount,
                token: token,
                phoneNumber: PhoneNumber(number: cleanPhone, country: 'bj'),
              ),
              mode: effectiveMode,
            );
            if (directRes.isSuccessful && directRes.data != null) {
              directPaymentInitiated = true;
              if (kDebugMode) debugPrint('[Wallet] directPayment initié avec succès: txId=${directRes.data!.id}');
            } else {
              if (kDebugMode) debugPrint('[Wallet] directPayment non concluant: statusCode=${directRes.statusCode}');
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Wallet] directPayment exception ($e), repli sur URL');
        }
      }

      // Si le paiement direct n'a pas été lancé (mode carte ou repli), ouvrir l'URL
      if (!directPaymentInitiated && url != null && url.isNotEmpty) {
        try {
          if (kDebugMode) debugPrint('[Wallet] Ouverture page web de paiement: $url');
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Wallet] launchUrl échoué: $e');
        }
      }

      // 3. Afficher le volet d'attente interactif avec auto-vérification et confirmation
      _showWaitingForPaymentSheet(
        txId.toString(),
        amount,
        phone: cleanPhone,
        mode: effectiveMode,
        directPaymentInitiated: directPaymentInitiated,
        paymentUrl: url,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] rechargeWithFedapay échec: $e');
      paymentStatus.value = 'failed';
      try {
        if (!Get.testMode) {
          Get.snackbar('Échec du paiement', 'La recharge n\'a pas pu être initiée: $e',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        }
      } catch (_) {}
      return false;
    }
  }

  /// Affiche un volet d'attente convivial avec vérification automatique toutes les 4s
  void _showWaitingForPaymentSheet(
    String txId,
    int amount, {
    String? phone,
    String? mode,
    bool directPaymentInitiated = false,
    String? paymentUrl,
  }) {
    final isChecking = false.obs;
    final isDone = false.obs;
    final attempts = 0.obs;

    String operatorName = 'Mobile Money';
    if (mode == 'mtn_open') operatorName = 'MTN Mobile Money';
    if (mode == 'moov') operatorName = 'Moov Money';
    if (mode == 'card') operatorName = 'Carte bancaire';

    // Polling automatique en arrière-plan toutes les 4s (durant 2 minutes max)
    Future<void> autoPoll() async {
      while (!isDone.value && attempts.value < 30) {
        await Future.delayed(const Duration(seconds: 4));
        if (isDone.value) break;
        attempts.value++;
        final ok = await _verifyFedapayOnServer(transactionId: txId, amount: amount);
        if (ok) {
          isDone.value = true;
          paymentStatus.value = 'success';
          await _fetchFromSupabase();
          await _persistLocal();
          if (Get.isBottomSheetOpen == true) {
            Get.back();
          }
          Get.snackbar(
            'Recharge réussie !',
            '+${_fmt(amount)} FCFA crédités sur votre portefeuille',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF1B8A5A),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          break;
        }
      }
    }

    autoPoll();

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ChatMeColors.violet.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: ChatMeColors.violet),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Recharge de ${_fmt(amount)} FCFA',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mode: $operatorName',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                if (directPaymentInitiated && phone != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone, color: Color(0xFFE5A100), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Demande envoyée au +229 $phone',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Veuillez déverrouiller votre téléphone et composer votre code secret Mobile Money pour approuver le débit.',
                          style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Finalisez votre paiement sur la page sécurisée FedaPay, puis revenez ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: isChecking.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                        label: Text(
                          isChecking.value ? 'Vérification en cours...' : 'J\'ai validé mon paiement',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ChatMeColors.violet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isChecking.value
                            ? null
                            : () async {
                                isChecking.value = true;
                                final ok = await _verifyFedapayOnServer(transactionId: txId, amount: amount);
                                isChecking.value = false;
                                if (ok) {
                                  isDone.value = true;
                                  paymentStatus.value = 'success';
                                  await _fetchFromSupabase();
                                  await _persistLocal();
                                  if (Get.isBottomSheetOpen == true) {
                                    Get.back();
                                  }
                                  Get.snackbar(
                                    'Recharge réussie !',
                                    '+${_fmt(amount)} FCFA crédités sur votre portefeuille',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: const Color(0xFF1B8A5A),
                                    colorText: Colors.white,
                                  );
                                } else {
                                  Get.snackbar(
                                    'Paiement en attente',
                                    'Le paiement n\'a pas encore été validé par l\'opérateur. Veuillez taper votre code secret sur votre téléphone et réessayer.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.white,
                                    colorText: Colors.black,
                                    duration: const Duration(seconds: 4),
                                  );
                                }
                              },
                      ),
                    )),
                if (paymentUrl != null && paymentUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_browser, size: 16, color: ChatMeColors.violet),
                    label: const Text(
                      'Page de paiement web (si pas de notification USSD)',
                      style: TextStyle(fontSize: 12, color: ChatMeColors.violet, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () async {
                      try {
                        final uri = Uri.parse(paymentUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {}
                    },
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    isDone.value = true;
                    Get.back();
                  },
                  child: const Text('Fermer cette fenêtre', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
      isDismissible: true,
      enableDrag: true,
    );
  }

  /// Appelle l'Edge Function verify-fedapay-transaction qui vérifie auprès de FedaPay et crédite atomiquement
  Future<bool> _verifyFedapayOnServer({required String transactionId, required int amount}) async {
    if (!_supabaseAvailable) return false;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      final res = await Supabase.instance.client.functions.invoke(
        'verify-fedapay-transaction',
        body: {'transaction_id': transactionId, 'user_id': userId, 'amount': amount},
      );
      if (kDebugMode) debugPrint('[Wallet] verify-fedapay response: status=${res.status} data=${res.data}');
      if (res.status == 200) {
        final data = res.data;
        if (data is Map && (data['status'] == 'completed' || data['credited'] != null)) {
          final bal = data['balance_cents'];
          if (bal is num) balance.value = bal.toInt();
          Get.snackbar('Recharge réussie', '+${_fmt(amount)} FCFA vérifié serveur',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
          return true;
        }
        if (data is Map && data['status'] == 'already_processed') return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] _verifyFedapayOnServer erreur Edge function: $e');
    }

    // Repli de secours : interrogation directe de l'API FedaPay si l'Edge Function échoue
    try {
      final int? idNum = int.tryParse(transactionId);
      if (idNum != null) {
        final txRes = await FedaFlutter.instance.transactions.getTransaction(idNum);
        if (txRes.isSuccessful && txRes.data != null) {
          final tx = txRes.data!;
          if (kDebugMode) debugPrint('[Wallet] FedaPay getTransaction status=${tx.status}');
          if (tx.status == 'approved') {
            await _completeFedapayRecharge(amount, txId: transactionId);
            return true;
          }
        }
      }
    } catch (directErr) {
      if (kDebugMode) debugPrint('[Wallet] FedaPay getTransaction direct error: $directErr');
    }

    return false;
  }

  // ignore: unused_element
  Future<void> _completeFedapayRecharge(int amount, {String? txId}) async {
    // Fallback sandbox uniquement : crédit direct via RPC (à ne pas utiliser en live)
    if (_supabaseAvailable) {
      final newBal = await _rpcDeposit(amount, 'Recharge FedaPay${txId != null ? ' #$txId' : ''}');
      if (newBal != null) {
        balance.value = newBal;
        paymentStatus.value = 'success';
        await _fetchFromSupabase();
        await _persistLocal();
        Get.snackbar('Recharge réussie (sandbox)', '+${_fmt(amount)} FCFA — Solde: ${_fmt(newBal)} FCFA',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        return;
      }
      paymentStatus.value = 'failed';
      Get.snackbar('Recharge échouée', 'Vérification serveur échouée, solde non crédité',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      return;
    }
    // Fallback local (dev hors Supabase)
    balance.value += amount;
    final tx = WalletTransaction(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Recharge',
      amount: amount,
      date: DateTime.now(),
      paymentStatus: 'completed',
    );
    transactions.insert(0, tx);
    paymentStatus.value = 'success';
    await _persistLocal();
    Get.snackbar('Recharge réussie', '+${_fmt(amount)} FCFA (local)',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
  }

  /// Recharge — mode banque : via RPC deposit si Supabase, sinon local
  Future<bool> rechargeInternal(int amount) async {
    if (amount <= 0) return false;
    if (_supabaseAvailable) {
      final newBal = await _rpcDeposit(amount, 'Recharge');
      if (newBal != null) {
        balance.value = newBal;
        await _fetchFromSupabase();
        await _persistLocal();
        return true;
      }
      return false;
    }
    balance.value += amount;
    final tx = WalletTransaction(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Recharge',
      amount: amount,
      date: DateTime.now(),
      paymentStatus: 'completed',
    );
    transactions.insert(0, tx);
    await _persistLocal();
    return true;
  }

  Future<bool> recharge(int amount) => rechargeInternal(amount);

  // Compatibilité ancienne API — maintenant async mais garde sync wrapper pour callers existants
  bool sendMoney(String contact, int amount) {
    // Ancien appel par nom seul : fallback débit simple (sans virement réel)
    // Préférer transferToUser(destUserId) pour vrai virement banque
    final ok = _debit('Envoyé à $contact', amount);
    return ok;
  }

  Future<bool> sendMoneyToUser(String destUserId, int amount) => transferToUser(destUserId, amount);

  Future<bool> payAsync(int amount, String label) async {
    if (_supabaseAvailable) {
      final newBal = await _rpcWithdraw(amount, label);
      if (newBal != null) {
        balance.value = newBal;
        await _fetchFromSupabase();
        await _persistLocal();
        return true;
      }
      return false;
    }
    return _debit(label, amount);
  }

  bool pay(int amount, String label) => _debit(label, amount);

  bool _debit(String label, int amount) {
    if (amount <= 0) return false;
    if (amount > balance.value) return false;
    balance.value -= amount;
    final tx = WalletTransaction(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      amount: -amount,
      date: DateTime.now(),
      paymentStatus: 'completed',
    );
    transactions.insert(0, tx);
    _persistLocal();
    if (_supabaseAvailable) {
      // En mode banque, on tente aussi RPC withdraw pour cohérence serveur si RLS le permet
      // mais on ne bloque pas l'UI locale ; le prochain _fetch corrigera
      _persistBalanceToSupabase();
      _insertTransactionToSupabase(tx);
    }
    return true;
  }

  /// --- BANQUE : RPC atomiques (supabase_wallet_bank.sql) ---

  Future<int?> _rpcDeposit(int amount, String label) async {
    if (!_supabaseAvailable) return null;
    try {
      final res = await Supabase.instance.client.rpc('wallet_deposit', params: {'p_amount': amount, 'p_label': label});
      if (res is int) return res;
      if (res is num) return res.toInt();
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] wallet_deposit RPC échoué: $e');
      return null;
    }
  }

  Future<int?> _rpcWithdraw(int amount, String label) async {
    if (!_supabaseAvailable) return null;
    try {
      final res = await Supabase.instance.client.rpc('wallet_withdraw', params: {'p_amount': amount, 'p_label': label});
      if (res is int) return res;
      if (res is num) return res.toInt();
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] wallet_withdraw RPC échoué: $e');
      // Propager message utilisateur si solde insuffisant
      if (e.toString().contains('Solde insuffisant')) {
        Get.snackbar('Solde insuffisant', 'Votre solde est trop bas pour cette opération',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _rpcTransfer(String destUserId, int amount) async {
    if (!_supabaseAvailable) return null;
    try {
      final res = await Supabase.instance.client.rpc('wallet_transfer', params: {'p_dest_user_id': destUserId, 'p_amount': amount});
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] wallet_transfer RPC échoué: $e');
      if (e.toString().contains('Solde insuffisant')) {
        Get.snackbar('Solde insuffisant', 'Votre solde est trop bas',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      } else if (e.toString().contains('Destinataire')) {
        Get.snackbar('Destinataire invalide', e.toString(),
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      }
      return null;
    }
  }

  /// Dépôt manuel (banque) — crédite via RPC si Supabase, sinon local
  Future<bool> deposit(int amount, {String label = 'Dépôt'}) async {
    if (amount <= 0) return false;
    if (_supabaseAvailable) {
      final newBal = await _rpcDeposit(amount, label);
      if (newBal != null) {
        balance.value = newBal;
        await _fetchFromSupabase();
        await _persistLocal();
        Get.snackbar('Dépôt réussi', '+${_fmt(amount)} FCFA — Solde: ${_fmt(newBal)} FCFA',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        return true;
      }
      return false;
    }
    // fallback local
    balance.value += amount;
    final tx = WalletTransaction(id: 't_${DateTime.now().millisecondsSinceEpoch}', label: label, amount: amount, date: DateTime.now(), paymentStatus: 'completed');
    transactions.insert(0, tx);
    await _persistLocal();
    return true;
  }

  /// Retrait — débite via RPC atomique
  Future<bool> withdraw(int amount, {String label = 'Retrait'}) async {
    if (amount <= 0) return false;
    if (amount > balance.value && !_supabaseAvailable) return false;
    if (_supabaseAvailable) {
      final newBal = await _rpcWithdraw(amount, label);
      if (newBal != null) {
        balance.value = newBal;
        await _fetchFromSupabase();
        await _persistLocal();
        Get.snackbar('Retrait réussi', '-${_fmt(amount)} FCFA — Solde: ${_fmt(newBal)} FCFA',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        return true;
      }
      return false;
    }
    return _debit(label, amount);
  }

  /// Virement vers un autre utilisateur (par user_id)
  Future<bool> transferToUser(String destUserId, int amount) async {
    if (amount <= 0) return false;
    if (destUserId.isEmpty) return false;
    if (_supabaseAvailable) {
      final res = await _rpcTransfer(destUserId, amount);
      if (res != null) {
        balance.value = (res['from_balance'] as num).toInt();
        await _fetchFromSupabase();
        await _persistLocal();
        Get.snackbar('Virement réussi', '${_fmt(amount)} FCFA envoyés',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        return true;
      }
      return false;
    }
    // fallback local : simple débit
    return _debit('Envoyé', amount);
  }

  // ignore: unused_element
  void _push(String label, int amount, {String status = 'completed'}) {
    final tx = WalletTransaction(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      amount: amount,
      date: DateTime.now(),
      paymentStatus: status,
    );
    transactions.insert(0, tx);
    _persistLocal();
    _persistBalanceToSupabase();
    _insertTransactionToSupabase(tx);
  }

  String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  String _fmt(int n) => FormatUtils.fmtFcfa(n);

  String get paymentStatusText {
    switch (paymentStatus.value) {
      case 'idle':
        return _supabaseAvailable ? 'Portefeuille réel (Supabase)' : 'Prêt à payer (local)';
      case 'pending':
        return 'En cours de paiement...';
      case 'success':
        return 'Paiement réussi';
      case 'failed':
        return 'Échec du paiement';
      default:
        return 'Statut inconnu';
    }
  }

  Color get paymentStatusColor {
    switch (paymentStatus.value) {
      case 'idle':
        return ChatMeColors.inkSoft;
      case 'pending':
        return ChatMeColors.violet;
      case 'success':
        return ChatMeColors.cProfil;
      case 'failed':
        return const Color(0xFFC4485E);
      default:
        return ChatMeColors.inkSoft;
    }
  }

  @override
  void onClose() {
    _balanceChannel?.unsubscribe();
    _txChannel?.unsubscribe();
    super.onClose();
  }
}
