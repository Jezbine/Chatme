import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chatme/config/supabase_config.dart';

/// Statuts éphémères (Stories 24h) — migré Supabase (P1.3) sur modèle MomentsService.
/// Tente Supabase (table public.statuses) en premier, fallback SharedPreferences si non déployé.

class StatusItem {
  final String id;
  final String type; // 'text' | 'image'
  final String? text;
  final String? mediaPath;
  final int durationMinutes;
  final DateTime createdAt;
  final DateTime expiresAt;

  StatusItem({
    required this.id,
    required this.type,
    this.text,
    this.mediaPath,
    required this.durationMinutes,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'text': text,
        'mediaPath': mediaPath,
        'durationMinutes': durationMinutes,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory StatusItem.fromJson(Map<String, dynamic> j) => StatusItem(
        id: j['id'] as String,
        type: j['type'] as String,
        text: j['text'] as String?,
        mediaPath: j['mediaPath'] as String?,
        durationMinutes: j['durationMinutes'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}

class ContactStatus {
  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final List<StatusItem> items;

  ContactStatus({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.items,
  });

  bool get hasActive => items.any((i) => !i.isExpired);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'colorValue': colorValue,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory ContactStatus.fromJson(Map<String, dynamic> j) => ContactStatus(
        id: j['id'] as String,
        name: j['name'] as String,
        initials: j['initials'] as String,
        colorValue: j['colorValue'] as int,
        items: (j['items'] as List? ?? [])
            .map((i) => StatusItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

class StatusService extends GetxService {
  static StatusService get to => Get.find<StatusService>();

  final RxList<StatusItem> myStatuses = <StatusItem>[].obs;
  final RxList<ContactStatus> contacts = <ContactStatus>[].obs;
  bool _supabaseAvailable = false;
  RealtimeChannel? _statusChannel; // ignore: unused_field - utilisé via _statusChannel?.unsubscribe() dans onClose

  Future<StatusService> init() async {
    // P1.3 : tente Supabase d'abord (identique à MomentsService)
    try {
      final client = SupabaseConfig.client;
      if (client.auth.currentUser != null) {
        await client.from('statuses').select('id').limit(1);
        _supabaseAvailable = true;
        await _fetchFromSupabase();
        _statusChannel = client.channel('statuses').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'statuses', callback: (_) => _fetchFromSupabase()).subscribe();
        client.auth.onAuthStateChange.listen((d) { if (d.session != null) _fetchFromSupabase(); });
        startAutoCleanup();
        if (kDebugMode) debugPrint('[Status] Supabase statuses disponible -> mode réel');
        return this;
      }
    } catch (e) {
      _supabaseAvailable = false;
      if (kDebugMode) debugPrint('[Status] Supabase non disponible, fallback local: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    final rawMine = prefs.getStringList('status_mine');
    final rawContacts = prefs.getStringList('status_contacts');

    if (rawMine == null && rawContacts == null) {
      myStatuses.value = [];
      contacts.value = [];
      await _persist();
    } else {
      myStatuses.value = (rawMine ?? [])
          .map((e) => StatusItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      contacts.value = (rawContacts ?? [])
          .map((e) => ContactStatus.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    }
    return this;
  }

  Future<void> _fetchFromSupabase() async {
    try {
      final client = SupabaseConfig.client;
      final rows = await client.from('statuses').select('id,user_id,type,text,media_path,duration_minutes,created_at,expires_at,profiles!statuses_user_id_fkey(display_name)').order('created_at', ascending: false).limit(100);
      final uid = client.auth.currentUser?.id;
      final mine = <StatusItem>[];
      final others = <String, ContactStatus>{};
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final expires = DateTime.parse(m['expires_at'] as String);
        if (expires.isBefore(DateTime.now())) continue;
        final item = StatusItem(
          id: m['id'] as String,
          type: m['type'] as String,
          text: m['text'] as String?,
          mediaPath: m['media_path'] as String?,
          durationMinutes: m['duration_minutes'] as int,
          createdAt: DateTime.parse(m['created_at'] as String),
          expiresAt: expires,
        );
        if (m['user_id'] == uid) {
          mine.add(item);
        } else {
          final cid = m['user_id'] as String;
          final display = (m['profiles']?['display_name'] as String?) ?? 'Contact';
          final initials = display.isNotEmpty ? display.substring(0, display.length >= 2 ? 2 : 1).toUpperCase() : '?';
          others.putIfAbsent(cid, () => ContactStatus(id: cid, name: display, initials: initials, colorValue: 0xFF3C3489, items: []));
          others[cid]!.items.add(item);
        }
      }
      myStatuses.value = mine;
      contacts.value = others.values.where((c) => c.hasActive).toList();
      await _persist();
    } catch (e) {
      if (kDebugMode) debugPrint('[Status] _fetchFromSupabase error: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'status_mine',
      myStatuses.map((s) => jsonEncode(s.toJson())).toList(),
    );
    await prefs.setStringList(
      'status_contacts',
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  List<StatusItem> get myActive =>
      myStatuses.where((s) => !s.isExpired).toList();

  List<ContactStatus> get contactsActive =>
      contacts.where((c) => c.hasActive).toList();

  Future<String?> _uploadStatusMedia(String localPath) async {
    try {
      final client = SupabaseConfig.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return null;
      final file = File(localPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final ext = localPath.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
      final mime = isVideo ? 'video/$ext' : (ext == 'png' ? 'image/png' : 'image/jpeg');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'statuses/$uid/$fileName';
      // Essayer bucket status-media puis chat-media
      String bucket = 'status-media';
      try {
        await client.storage.from(bucket).uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
      } catch (e) {
        if (e.toString().contains('Bucket not found')) {
          bucket = 'chat-media';
          await client.storage.from(bucket).uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
        } else {
          rethrow;
        }
      }
      // URL publique si possible, sinon signée 30 jours
      try {
        return client.storage.from(bucket).getPublicUrl(storagePath);
      } catch (_) {
        return await client.storage.from(bucket).createSignedUrl(storagePath, 60 * 60 * 24 * 30);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Status] _uploadStatusMedia error: $e');
      return null;
    }
  }

  Future<void> addMyStatus({required String type, String? text, String? mediaPath, required int durationMinutes}) async {
    String? remoteMediaPath = mediaPath;
    // Si chemin local, uploader vers Storage pour que les autres voient le contenu
    if (mediaPath != null && mediaPath.isNotEmpty && !mediaPath.startsWith('http')) {
      final uploaded = await _uploadStatusMedia(mediaPath);
      if (uploaded != null) remoteMediaPath = uploaded;
    }
    if (_supabaseAvailable) {
      try {
        final client = SupabaseConfig.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          final now = DateTime.now();
          final row = await client.from('statuses').insert({
            'user_id': uid,
            'type': type,
            'text': text,
            'media_path': remoteMediaPath,
            'duration_minutes': durationMinutes,
            'expires_at': now.add(Duration(minutes: durationMinutes)).toIso8601String(),
          }).select().single();
          myStatuses.insert(0, StatusItem(id: row['id'] as String, type: type, text: text, mediaPath: remoteMediaPath, durationMinutes: durationMinutes, createdAt: DateTime.parse(row['created_at'] as String), expiresAt: DateTime.parse(row['expires_at'] as String)));
          await _persist();
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Status] addMyStatus Supabase error: $e');
      }
    }
    final now = DateTime.now();
    myStatuses.insert(
      0,
      StatusItem(
        id: 's_mine_${now.millisecondsSinceEpoch}',
        type: type,
        text: text,
        mediaPath: remoteMediaPath,
        durationMinutes: durationMinutes,
        createdAt: now,
        expiresAt: now.add(Duration(minutes: durationMinutes)),
      ),
    );
    await _persist();
  }

  /// Édition d'un statut personnel tant que < 15 min se sont écoulées.
  bool canEditMyStatus(StatusItem item) =>
      !item.isExpired && DateTime.now().difference(item.createdAt).inMinutes <= 15;

  void editMyStatus(String id, {String? text, int? durationMinutes}) {
    final idx = myStatuses.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final s = myStatuses[idx];
    if (!canEditMyStatus(s)) return;
    final minutes = durationMinutes ?? s.durationMinutes;
    myStatuses[idx] = StatusItem(
      id: s.id,
      type: s.type,
      text: text ?? s.text,
      mediaPath: s.mediaPath,
      durationMinutes: minutes,
      createdAt: s.createdAt,
      expiresAt: s.createdAt.add(Duration(minutes: minutes)),
    );
    _persist();
  }

  /// Suppression sans délai (pour moi).
  Future<void> deleteMyStatus(String id) async {
    if (_supabaseAvailable) {
      try {
        await SupabaseConfig.client.from('statuses').delete().eq('id', id);
      } catch (e) {
        if (kDebugMode) debugPrint('[Status] deleteMyStatus Supabase error: $e');
      }
    }
    myStatuses.removeWhere((s) => s.id == id);
    await _persist();
  }

  /// Suppression d'un statut de contact (pour tout le monde, côté local).
  void deleteContactStatus(String contactId, String statusId) {
    final idx = contacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    contacts[idx].items.removeWhere((i) => i.id == statusId);
    if (!contacts[idx].hasActive) contacts.removeAt(idx);
    _persist();
  }

  Future<void> _deleteExpiredFromSupabase() async {
    if (!_supabaseAvailable) return;
    try {
      final client = SupabaseConfig.client;
      final nowIso = DateTime.now().toIso8601String();
      // Supprime mes statuts expirés côté DB (RLS: user_id = auth.uid())
      await client.from('statuses').delete().lt('expires_at', nowIso).eq('user_id', client.auth.currentUser!.id);
      if (kDebugMode) debugPrint('[Status] expired supprimés de la BD');
    } catch (e) {
      if (kDebugMode) debugPrint('[Status] _deleteExpiredFromSupabase error: $e');
    }
  }

  void removeExpired() {
    final hadExpired = myStatuses.any((s) => s.isExpired) || contacts.any((c) => c.items.any((i) => i.isExpired));
    myStatuses.removeWhere((s) => s.isExpired);
    for (final c in contacts) {
      c.items.removeWhere((i) => i.isExpired);
    }
    contacts.removeWhere((c) => !c.hasActive);
    _persist();
    if (hadExpired) _deleteExpiredFromSupabase();
  }

  void startAutoCleanup() {
    // Nettoyage toutes les 60s
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 60));
      if (Get.isRegistered<StatusService>()) {
        removeExpired();
        return true;
      }
      return false;
    });
  }

  @override
  void onClose() {
    _statusChannel?.unsubscribe();
    super.onClose();
  }
}
