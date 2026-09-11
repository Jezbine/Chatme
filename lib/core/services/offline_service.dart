import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de cache hors-ligne générique.
/// - Utilise Hive pour données structurées (conversations, messages, pending queue)
/// - Fallback SharedPreferences pour petites données (compatibilité existante)
/// Initialisé au démarrage, avant les autres services.
class OfflineService extends GetxService {
  static OfflineService get to => Get.find<OfflineService>();

  static const String _boxConversations = 'offline_conversations';
  static const String _boxMessages = 'offline_messages'; // key: conversationId -> List<Message json>
  static const String _boxPending = 'offline_pending'; // file d'attente messages à envoyer

  Box? _convBox;
  Box? _msgBox;
  Box? _pendingBox;

  final RxBool isReady = false.obs;

  Future<OfflineService> init() async {
    try {
      await Hive.initFlutter();
      _convBox = await Hive.openBox(_boxConversations);
      _msgBox = await Hive.openBox(_boxMessages);
      _pendingBox = await Hive.openBox(_boxPending);
      isReady.value = true;
      if (kDebugMode) debugPrint('[Offline] Hive ready: conv=${_convBox!.length} msgKeys=${_msgBox!.keys.length} pending=${_pendingBox!.length}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Offline] Hive init error (fallback SharedPrefs): $e');
      isReady.value = false;
    }
    return this;
  }

  // ============ Conversations ============
  Future<void> cacheConversations(List<Map<String, dynamic>> jsonList) async {
    try {
      if (_convBox != null) {
        await _convBox!.put('list', jsonEncode(jsonList));
        await _convBox!.put('cached_at', DateTime.now().toIso8601String());
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_conversations', jsonEncode(jsonList));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Offline] cacheConversations error: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedConversations() {
    try {
      String? raw;
      if (_convBox != null) {
        raw = _convBox!.get('list') as String?;
      }
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('[Offline] getCachedConversations error: $e');
      return null;
    }
  }

  // ============ Messages par conversation ============
  Future<void> cacheMessages(String conversationId, List<Map<String, dynamic>> jsonList) async {
    try {
      if (_msgBox != null) {
        await _msgBox!.put(conversationId, jsonEncode(jsonList));
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_msgs_$conversationId', jsonEncode(jsonList));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Offline] cacheMessages error: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedMessages(String conversationId) {
    try {
      String? raw;
      if (_msgBox != null) {
        raw = _msgBox!.get(conversationId) as String?;
      } else {
        // fallback sync pas possible, on retourne null (appelant fera await prefs)
        return null;
      }
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('[Offline] getCachedMessages error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getCachedMessagesAsync(String conversationId) async {
    final sync = getCachedMessages(conversationId);
    if (sync != null) return sync;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_msgs_$conversationId');
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  // ============ Pending queue (messages à envoyer quand online) ============
  Future<void> enqueuePending(Map<String, dynamic> payload) async {
    try {
      final list = getPendingQueue();
      list.add(payload);
      if (_pendingBox != null) {
        await _pendingBox!.put('queue', jsonEncode(list));
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_pending_queue', jsonEncode(list));
      }
      if (kDebugMode) debugPrint('[Offline] enqueue pending: ${payload['content']} queue=${list.length}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Offline] enqueuePending error: $e');
    }
  }

  List<Map<String, dynamic>> getPendingQueue() {
    try {
      String? raw;
      if (_pendingBox != null) {
        raw = _pendingBox!.get('queue') as String?;
      }
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> removePendingAt(int index) async {
    final list = getPendingQueue();
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (_pendingBox != null) {
      await _pendingBox!.put('queue', jsonEncode(list));
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_pending_queue', jsonEncode(list));
    }
  }

  Future<void> clearPending() async {
    if (_pendingBox != null) {
      await _pendingBox!.put('queue', jsonEncode([]));
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_pending_queue', jsonEncode([]));
    }
  }

  // ============ Utilitaires ============
  Future<void> clearAll() async {
    await _convBox?.clear();
    await _msgBox?.clear();
    await _pendingBox?.clear();
    final prefs = await SharedPreferences.getInstance();
    // ne supprime pas les autres prefs (moments, contacts) – seulement offline keys
    await prefs.remove('offline_conversations');
  }

  String? get cachedAt {
    try {
      return _convBox?.get('cached_at') as String?;
    } catch (_) {
      return null;
    }
  }
}
