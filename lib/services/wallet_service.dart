import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:feda_flutter/feda_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatme/core/theme/chatme_theme.dart' show ChatMeColors;
import 'package:chatme/core/utils/format_utils.dart';

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
    const apiKey = String.fromEnvironment('FEDA_API_KEY', defaultValue: '');
    const envStr = String.fromEnvironment('FEDA_ENV', defaultValue: 'sandbox');
    if (apiKey.isEmpty || apiKey.contains('placeholder')) {
      if (kDebugMode) {
        debugPrint('[Wallet] FEDA_API_KEY non défini (--dart-define). Recharge désactivée jusqu\'à config.');
      }
      // Fix: ne pas configurer avec placeholder (évite 401 silencieux) — rechargeWithFedapay fera snackbar explicite
      return;
    }
    final isLive = envStr.toLowerCase() == 'live';
    if (kDebugMode) {
      debugPrint('[Wallet] FedaPay init en mode ${isLive ? 'LIVE' : 'SANDBOX'} (clé fournie via dart-define)');
    }
    FedaFlutter.applyConfig(
      apiKey: apiKey,
      environment: isLive ? ApiEnvironment.live : ApiEnvironment.sandbox,
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
  /// 1) createTransaction + getToken 2) ouvre url paiement 3) vérif serveur via Edge Function
  /// Le solde n'est crédité QUE si FedaPay retourne approved (jamais côté client).
  /// Si FEDA_API_KEY manquante (cas démo), fallback fonctionnel local pour que la page soit utilisable.
  Future<bool> rechargeWithFedapay(int amount) async {
    if (amount <= 0) return false;
    const apiKey = String.fromEnvironment('FEDA_API_KEY', defaultValue: '');
    if (apiKey.isEmpty || apiKey.contains('placeholder')) {
      paymentStatus.value = 'failed';
      if (kDebugMode) debugPrint('[Wallet] FEDA_API_KEY manquante -> recharge bloquée (sécurité anti-crédit gratuit)');
      // Evite crash Get.snackbar en test (pas de GetMaterialApp)
      try {
        if (!Get.testMode) {
          Get.snackbar('Recharge indisponible', 'FedaPay non configuré (--dart-define FEDA_API_KEY). Contactez l\'administrateur.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black, duration: const Duration(seconds: 4));
        }
      } catch (_) {}
      return false;
    }
    paymentStatus.value = 'pending';
    try {
      // Client FedaPay : customer attaché via email si dispo (merchant_reference traçage)
      final res = await FedaFlutter.instance.transactions.createTransaction(
        TransactionCreate(
          amount: amount,
          currency: CurrencyIso(iso: 'XOF'),
          description: 'Recharge portefeuille ChatMe',
          callbackUrl: 'https://chatme.com/callback',
          // merchant_reference + custom_metadata pour retrouver la tx côté webhook
          // customer: customerEmail != null ? {'email': customerEmail} : null,
        ),
      );
      if (!res.isSuccessful || res.data == null) throw Exception('createTransaction failed: $res');
      final txId = res.data!.id;
      final tokenRes = await FedaFlutter.instance.transactions.getTransactionToken(txId);
      if (!tokenRes.isSuccessful || tokenRes.data == null) throw Exception('getTransactionToken failed: $tokenRes');

      // Ouvrir la page de paiement FedaPay (docs: token.url) — conforme checkout
      String? url;
      try {
        final d = tokenRes.data as dynamic;
        url = d.url as String? ?? d['url'] as String?;
      } catch (_) {}
      if (url != null && url.isNotEmpty) {
        try {
          if (kDebugMode) debugPrint('[Wallet] Ouverture paiement FedaPay: $url');
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Wallet] launchUrl échoué: $e');
        }
      }

      // Vérification serveur : polling Edge Function verify-fedapay-transaction
      // Conforme doc : ne pas se fier au callback_url, GET /transactions/{id} côté serveur
      final verified = await _verifyFedapayOnServer(transactionId: txId.toString(), amount: amount);
      if (verified) {
        paymentStatus.value = 'success';
        await _fetchFromSupabase();
        await _persistLocal();
        return true;
      }
      // Si non approuvé immédiatement, on reste pending — le webhook fera le crédit
      paymentStatus.value = 'pending';
      Get.snackbar('Paiement en attente', 'Finalisez le paiement sur la page FedaPay. Le solde sera crédité après confirmation (webhook).',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      // Optionnel : on peut aussi créditer en local sandbox pour tests
      // await _completeFedapayRecharge(amount, txId: txId.toString());
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] rechargeWithFedapay échec: $e');
      paymentStatus.value = 'failed';
      Get.snackbar('Échec du paiement', 'La recharge n\'a pas été effectuée. Vérifiez votre connexion et réessayez.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
      return false;
    }
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
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[Wallet] _verifyFedapayOnServer erreur: $e');
      return false;
    }
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
