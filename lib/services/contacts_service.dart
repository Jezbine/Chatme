import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chatme/config/supabase_config.dart';

/// Audit 2.8 — Système d'ajout de contacts actuel : par QR uniquement (style WeChat).
/// Choix produit : le QR est la méthode principale (rapide, offline, sans permission READ_CONTACTS).
/// Si le besoin "import répertoire façon WhatsApp" est confirmé, ajouter le package
/// `flutter_contacts` et implémenter importDeviceContacts() ci-dessous (permission READ_CONTACTS).

class AddedContact {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final DateTime addedAt;

  AddedContact({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'colorValue': colorValue,
        'addedAt': addedAt.toIso8601String(),
      };

  factory AddedContact.fromJson(Map<String, dynamic> j) => AddedContact(
        id: j['id'] as String,
        name: j['name'] as String,
        initials: j['initials'] as String,
        colorValue: j['colorValue'] as int,
        addedAt: DateTime.parse(j['addedAt'] as String),
      );
}

class ContactRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;
  final String? fromName;
  ContactRequest({required this.id, required this.fromUserId, required this.toUserId, required this.status, required this.createdAt, this.fromName});
  factory ContactRequest.fromJson(Map<String, dynamic> j) => ContactRequest(
        id: j['id'] as String,
        fromUserId: j['from_user_id'] as String,
        toUserId: j['to_user_id'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        fromName: j['from_profile'] != null ? (j['from_profile']['display_name'] as String?) : null,
      );
}

class ContactsService extends GetxService {
  static ContactsService get to => Get.find<ContactsService>();

  static const List<int> _palette = [
    0xFF3C3489, // cDiscussion
    0xFF378ADD, // cAppel
    0xFFBA7517, // cDocuments
    0xFFD4537E, // cReactions
    0xFF639922, // cPortefeuille
    0xFF1D9E75, // cProfil
  ];

  final RxList<AddedContact> added = <AddedContact>[].obs;
  final RxList<ContactRequest> incomingRequests = <ContactRequest>[].obs;
  final RxList<ContactRequest> outgoingRequests = <ContactRequest>[].obs;
  final SupabaseClient _client = SupabaseConfig.client;
  RealtimeChannel? _reqChannel;
  bool _supabaseAvailable = false;

  Future<ContactsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('added_contacts') ?? [];
    added.value = raw
        .map((e) => AddedContact.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    // Tenter mode Supabase contact_requests si table existe
    try {
      await _client.from('contact_requests').select('id').limit(1);
      _supabaseAvailable = true;
      await _fetchRequests();
      _subscribeRequests();
      if (kDebugMode) debugPrint('[Contacts] Supabase contact_requests disponible -> validation mutuelle active');
    } catch (e) {
      _supabaseAvailable = false;
      if (kDebugMode) debugPrint('[Contacts] contact_requests non disponible, fallback local: $e');
    }
    return this;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'added_contacts',
      added.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  bool has(String id) => added.any((c) => c.id == id);

  Future<void> _fetchRequests() async {
    if (!_supabaseAvailable) return;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final inc = await _client.from('contact_requests').select('*, from_profile:profiles!contact_requests_from_user_id_fkey(display_name)').eq('to_user_id', uid).eq('status', 'pending');
      incomingRequests.value = (inc as List).map((j) => ContactRequest.fromJson(j as Map<String, dynamic>)).toList();
      final out = await _client.from('contact_requests').select('*').eq('from_user_id', uid).eq('status', 'pending');
      outgoingRequests.value = (out as List).map((j) => ContactRequest.fromJson(j as Map<String, dynamic>)).toList();
      // Synchroniser les contacts acceptés : si une demande que j'ai envoyée est acceptée,
      // ajouter automatiquement le destinataire chez moi (l'accepteur l'a déjà via addFromScan)
      await _syncAcceptedContacts(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('[Contacts] _fetchRequests error: $e');
    }
  }

  Future<void> _syncAcceptedContacts(String uid) async {
    try {
      // Demandes que j'ai envoyées et qui sont maintenant acceptées
      final acceptedOut = await _client
          .from('contact_requests')
          .select('*, to_profile:profiles!contact_requests_to_user_id_fkey(display_name)')
          .eq('from_user_id', uid)
          .eq('status', 'accepted')
          .limit(20);
      for (final row in (acceptedOut as List)) {
        final j = row as Map<String, dynamic>;
        final toId = j['to_user_id'] as String;
        if (!has(toId)) {
          final name = (j['to_profile'] != null ? (j['to_profile']['display_name'] as String?) : null) ?? 'Ami';
          addFromScan(toId, name);
          if (kDebugMode) debugPrint('[Contacts] Auto-add accepted outgoing $toId $name');
        }
      }
      // Au cas où une demande que j'ai reçue et acceptée n'aurait pas été ajoutée (crash avant _persist)
      final acceptedIn = await _client
          .from('contact_requests')
          .select('*, from_profile:profiles!contact_requests_from_user_id_fkey(display_name)')
          .eq('to_user_id', uid)
          .eq('status', 'accepted')
          .limit(20);
      for (final row in (acceptedIn as List)) {
        final j = row as Map<String, dynamic>;
        final fromId = j['from_user_id'] as String;
        if (!has(fromId)) {
          final name = (j['from_profile'] != null ? (j['from_profile']['display_name'] as String?) : null) ?? 'Ami';
          addFromScan(fromId, name);
          if (kDebugMode) debugPrint('[Contacts] Auto-add accepted incoming $fromId $name');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Contacts] _syncAcceptedContacts error: $e');
    }
  }

  void _subscribeRequests() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    _reqChannel?.unsubscribe();
    _reqChannel = _client.channel('contact_requests_$uid').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'contact_requests', callback: (_) => _fetchRequests()).subscribe();
    _client.auth.onAuthStateChange.listen((_) => _fetchRequests());
  }

  /// Placeholder pour import répertoire — à activer si `flutter_contacts` est ajouté au pubspec.
  /// Retourne [] tant que la dépendance n'est pas installée.
  Future<List<AddedContact>> importDeviceContacts() async {
    if (kDebugMode) debugPrint('[Contacts] importDeviceContacts non implémenté — ajouter flutter_contacts + permission READ_CONTACTS');
    // NOTE audit 2.8: si choix = importer répertoire, décommenter après ajout du package
    // final contacts = await FlutterContacts.getContacts(withProperties: true);
    // puis filtrer ceux avec phone/email existant dans Supabase profiles
    return [];
  }

  /// Ajoute un contact (depuis un QR scanné). Retourne false si déjà présent.
  /// Maintenant: en mode Supabase, envoie une demande en attente de validation (mutuelle).
  bool addFromScan(String id, String name) {
    if (id.isEmpty) return false;
    if (has(id)) return false;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? (parts[0][0] + parts[1][0]).toUpperCase()
        : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    final color = _palette[added.length % _palette.length];
    added.insert(
      0,
      AddedContact(
        id: id,
        name: name,
        initials: initials,
        colorValue: color,
        addedAt: DateTime.now(),
      ),
    );
    _persist();
    return true;
  }

  /// Envoie une demande d'ajout (validation mutuelle). Retourne true si envoyée.
  Future<bool> sendContactRequest(String toUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    if (toUserId.isEmpty || toUserId == uid) return false;
    if (has(toUserId)) return false; // déjà ami
    if (!_supabaseAvailable) {
      // Fallback local: ajout direct (pas de validation possible)
      return false;
    }
    try {
      // Vérifier si demande déjà pending
      final existing = await _client.from('contact_requests').select('id,status').or('and(from_user_id.eq.$uid,to_user_id.eq.$toUserId),and(from_user_id.eq.$toUserId,to_user_id.eq.$uid)').eq('status', 'pending').limit(1);
      if ((existing as List).isNotEmpty) {
        if (kDebugMode) debugPrint('[Contacts] Demande déjà en attente');
        return false;
      }
      await _client.from('contact_requests').insert({'from_user_id': uid, 'to_user_id': toUserId});
      await _fetchRequests();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Contacts] sendContactRequest error: $e');
      // Fallback: si table n'existe pas encore, ajout direct
      return false;
    }
  }

  Future<bool> acceptRequest(String requestId, String fromUserId, String fromName) async {
    if (!_supabaseAvailable) return false;
    try {
      await _client.rpc('accept_contact_request', params: {'req_id': requestId});
      // Localement ajouter le contact après acceptation
      addFromScan(fromUserId, fromName);
      await _fetchRequests();
      return true;
    } catch (e) {
      // Fallback direct update
      try {
        await _client.from('contact_requests').update({'status': 'accepted', 'responded_at': DateTime.now().toIso8601String()}).eq('id', requestId);
        addFromScan(fromUserId, fromName);
        await _fetchRequests();
        return true;
      } catch (e2) {
        if (kDebugMode) debugPrint('[Contacts] acceptRequest error: $e2');
        return false;
      }
    }
  }

  Future<bool> rejectRequest(String requestId) async {
    if (!_supabaseAvailable) return false;
    try {
      await _client.from('contact_requests').update({'status': 'rejected', 'responded_at': DateTime.now().toIso8601String()}).eq('id', requestId);
      await _fetchRequests();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Contacts] rejectRequest error: $e');
      return false;
    }
  }

  bool hasPendingOutgoing(String toUserId) => outgoingRequests.any((r) => r.toUserId == toUserId);
  bool hasPendingIncoming(String fromUserId) => incomingRequests.any((r) => r.fromUserId == fromUserId);
}

/// Construit la charge utile d'un QR "ajout de contact" (format ChatMe).
String buildUserQrPayload(String userId, String name) =>
    'chatme:user:$userId:${Uri.encodeComponent(name)}';

/// Décode une charge utile de QR ChatMe. Retourne null si invalide.
Map<String, String>? parseUserQrPayload(String raw) {
  if (!raw.startsWith('chatme:user:')) return null;
  final parts = raw.split(':');
  if (parts.length < 4) return null;
  final id = parts[2];
  // Vérif UUID basique
  final uuidOk = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id);
  if (!uuidOk) return null;
  // Join au cas où le nom encodé contenait des ':' (%3A) mal décodés ou payload legacy
  final encodedName = parts.sublist(3).join(':');
  try {
    return {
      'id': id,
      'name': Uri.decodeComponent(encodedName),
    };
  } catch (_) {
    return {'id': id, 'name': encodedName};
  }
}

/// Vérifie côté Supabase que l'utilisateur du QR existe (anti-spoof)
Future<bool> verifyQrUserExists(String userId) async {
  try {
    final row = await SupabaseConfig.client.from('profiles').select('id').eq('id', userId).maybeSingle();
    return row != null;
  } catch (_) {
    return false;
  }
}
