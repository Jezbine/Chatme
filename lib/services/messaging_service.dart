import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/offline_service.dart';
import '../core/services/notification_service.dart';

class MessagingService extends GetxService {
  static MessagingService get to => Get.find<MessagingService>();

  final SupabaseClient _client = SupabaseConfig.client;

  final RxList<Conversation> conversations = <Conversation>[].obs;
  final RxMap<String, List<Message>> messagesByConversation = <String, List<Message>>{}.obs;
  final RxBool isLoadingConversations = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isOfflineMode = false.obs;
  // WhatsApp-like typing indicator
  final RxMap<String, bool> typingByConversation = <String, bool>{}.obs;
  final RxMap<String, String> typingUserByConversation = <String, String>{}.obs;
  // WhatsApp-like pinned conversations (max 3)
  final RxList<String> pinnedConversationIds = <String>[].obs;

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _typingChannel;
  Worker? _connectivityWorker;
  bool _pendingFlushScheduled = false;
  Timer? _typingTimer;

  bool get _isOffline {
    try {
      return ConnectivityService.to.isOffline.value;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    _listenConnectivity();
    await _loadPinnedConversations();
    await loadConversations();
    // S'assurer que les canaux realtime sont toujours actifs même si load a échoué
    _subscribeToConversations();
    _subscribeToMessages();
    _subscribeToPresence();
    _subscribeToTyping();
    // Tenter flush pending au démarrage si online
    if (!_isOffline) unawaited(flushPendingQueue());
  }

  @override
  void onClose() {
    _connectivityWorker?.dispose();
    _disposeChannels();
    super.onClose();
  }

  RealtimeChannel? _presenceChannel;

  void _disposeChannels() {
    _messagesChannel?.unsubscribe();
    _conversationsChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _messagesChannel = null;
    _conversationsChannel = null;
    _presenceChannel = null;
    _typingChannel = null;
  }

  void _subscribeToPresence() {
    _presenceChannel?.unsubscribe();
    _presenceChannel = _client
        .channel('profiles_presence')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final rec = payload.newRecord;
            final uid = rec['id'] as String?;
            if (uid == null) return;
            bool updated = false;
            for (int i = 0; i < conversations.length; i++) {
              final conv = conversations[i];
              final pIdx = conv.participants.indexWhere((p) => p.userId == uid);
              if (pIdx != -1) {
                final oldP = conv.participants[pIdx];
                final newProfile = oldP.profile?.copyWith(
                  isOnline: rec['is_online'] as bool?,
                  lastSeen: rec['last_seen'] != null ? DateTime.tryParse(rec['last_seen'].toString()) : null,
                  avatarUrl: rec['avatar_url'] as String?,
                  displayName: rec['display_name'] as String?,
                );
                if (newProfile != null) {
                  final newParticipants = List<ConversationParticipant>.from(conv.participants);
                  newParticipants[pIdx] = ConversationParticipant(
                    conversationId: oldP.conversationId,
                    userId: oldP.userId,
                    role: oldP.role,
                    joinedAt: oldP.joinedAt,
                    lastReadMessageId: oldP.lastReadMessageId,
                    muted: oldP.muted,
                    profile: newProfile,
                  );
                  conversations[i] = conv.copyWith(participants: newParticipants);
                  updated = true;
                }
              }
            }
            if (updated) conversations.refresh();
          },
        )
        .subscribe();
  }

  void _listenConnectivity() {
    try {
      final cs = ConnectivityService.to;
      _connectivityWorker = ever(cs.isOnline, (bool online) {
        isOfflineMode.value = !online;
        if (online) {
          if (kDebugMode) debugPrint('[Messaging] Back online → flushPending + reload');
          unawaited(flushPendingQueue());
          unawaited(loadConversations());
        } else {
          if (kDebugMode) debugPrint('[Messaging] Went offline');
        }
      });
      isOfflineMode.value = cs.isOffline.value;
    } catch (e) {
      if (kDebugMode) debugPrint('[Messaging] _listenConnectivity no ConnectivityService yet: $e');
    }
  }

  Future<void> _cacheConversationsRaw(List rawList) async {
    try {
      final jsonList = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await OfflineService.to.cacheConversations(jsonList);
    } catch (e) {
      if (kDebugMode) debugPrint('[Messaging] cacheConversations error: $e');
    }
  }

  Future<bool> _loadConversationsFromCache() async {
    try {
      final cached = OfflineService.to.getCachedConversations();
      if (cached == null || cached.isEmpty) return false;
      final loaded = cached.map((json) => Conversation.fromJsonWithParticipants(json)).toList();
      conversations.value = loaded;
      if (kDebugMode) debugPrint('[Messaging] Loaded ${loaded.length} convs from offline cache');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Messaging] _loadConversationsFromCache error: $e');
      return false;
    }
  }

  Future<void> _cacheMessagesRaw(String convId, List<Message> msgs) async {
    try {
      final jsonList = msgs.map((m) => m.toJson()).toList();
      await OfflineService.to.cacheMessages(convId, jsonList);
    } catch (e) {
      if (kDebugMode) debugPrint('[Messaging] cacheMessages error: $e');
    }
  }

  Future<bool> _loadMessagesFromCache(String conversationId) async {
    try {
      final cached = await OfflineService.to.getCachedMessagesAsync(conversationId);
      if (cached == null || cached.isEmpty) return false;
      final loaded = cached.map((j) => Message.fromJson(j)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      messagesByConversation[conversationId] = loaded;
      messagesByConversation.refresh();
      if (kDebugMode) debugPrint('[Messaging] Loaded ${loaded.length} msgs cache for $conversationId');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Messaging] _loadMessagesFromCache error: $e');
      return false;
    }
  }

  Future<void> loadConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Mode hors-ligne : charger directement depuis cache sans appel réseau
    if (_isOffline) {
      isOfflineMode.value = true;
      isLoadingConversations.value = true;
      final fromCache = await _loadConversationsFromCache();
      isLoadingConversations.value = false;
      if (!fromCache) {
        errorMessage.value = 'Hors ligne — aucune donnée en cache';
      } else {
        errorMessage.value = '';
      }
      return;
    }

    isLoadingConversations.value = true;

    try {
      // Fix discussions affichait le profil courant au lieu de l'interlocuteur :
      // !inner + eq('participants.user_id', userId) ne renvoyait que ta propre ligne participant
      // → on fait en 2 étapes pour récupérer TOUS les participants de chaque conversation
      final participantRows = await _client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);
      final convIds = (participantRows as List)
          .map((r) => (r as Map<String, dynamic>)['conversation_id'] as String)
          .toList();
      if (convIds.isEmpty) {
        conversations.value = [];
        isOfflineMode.value = false;
        errorMessage.value = '';
        isLoadingConversations.value = false;
        return;
      }
      final response = await _client
          .from('conversations')
          .select('''
            *,
            participants:conversation_participants(
              user_id,
              role,
              last_read_message_id,
              muted,
              profiles:profiles!conversation_participants_user_id_fkey(
                id, phone_number, display_name, avatar_url, is_online, last_seen
              )
            ),
            last_message:messages!conversation_id(
              id, content, type, media_url, sender_id, status, created_at, conversation_id
            )
          ''')
          .inFilter('id', convIds)
          .order('updated_at', ascending: false);

      final List<Conversation> loaded = [];
      for (final raw in (response as List)) {
        try {
          loaded.add(Conversation.fromJsonWithParticipants(raw as Map<String, dynamic>));
        } catch (e) {
          if (kDebugMode) debugPrint('[Messaging] skip conversation parse error $e raw=$raw');
        }
      }

      conversations.value = loaded;
      isOfflineMode.value = false;
      errorMessage.value = '';
      // Cache pour usage hors-ligne
      await _cacheConversationsRaw(response as List);
      _subscribeToConversations();
      _subscribeToMessages();
      _subscribeToPresence();
    } catch (e) {
      final msg = e.toString();
      final isRecursion = msg.contains('42P17') || msg.contains('infinite recursion');
      if (isRecursion) {
        // RLS mal configurée : basculer en cache et masquer le dump Postgres à l'utilisateur
        final fromCache = await _loadConversationsFromCache();
        if (fromCache) {
          isOfflineMode.value = true;
          errorMessage.value = '';
          if (kDebugMode) print('[Messaging] 42P17 recursion -> cache utilisé (exécutez SUPABASE_RECURSION_FIX.sql)');
        } else {
          errorMessage.value = 'Base en maintenance — exécutez supabase/SUPABASE_RECURSION_FIX.sql dans SQL Editor';
        }
        if (kDebugMode) print('Erreur loadConversations 42P17: $e');
        return;
      }
      // Si erreur réseau, tenter fallback cache
      final isNetError = msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Network') ||
          msg.contains('Timeout');
      if (isNetError) {
        final fromCache = await _loadConversationsFromCache();
        if (fromCache) {
          isOfflineMode.value = true;
          errorMessage.value = 'Hors ligne — données en cache affichées';
          if (kDebugMode) print('[Messaging] loadConversations offline fallback OK');
        } else {
          errorMessage.value = 'Erreur chargement: $e';
        }
      } else {
        errorMessage.value = 'Erreur chargement: $e';
      }
      if (kDebugMode) print('Erreur loadConversations: $e');
    } finally {
      isLoadingConversations.value = false;
    }
  }

  void _subscribeToConversations() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    _conversationsChannel?.unsubscribe();
    _conversationsChannel = _client
        .channel('conversations_changes_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            _handleConversationChange(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            // updated_at changé (nouveau message) -> refresh liste
            _handleConversationChange(payload);
          },
        )
        .subscribe();
  }

  void _subscribeToMessages() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    _messagesChannel?.unsubscribe();

    _messagesChannel = _client
        .channel('messages_changes_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final rec = payload.newRecord;
            final convId = rec['conversation_id'] as String?;
            if (convId == null) return;
            // Toujours traiter le nouveau message, même si conversation pas encore en cache
            if (conversations.any((c) => c.id == convId)) {
              _handleNewMessage(payload);
            } else {
              // Nouvelle conversation (ex: premier message) -> recharger la liste
              loadConversations().then((_) => _handleNewMessage(payload));
            }
            // Mettre en cache pour mode hors-ligne
            final msg = Message.fromJson(payload.newRecord);
            _cacheMessagesRaw(convId, messagesByConversation[convId] ?? [msg]);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _handleMessageUpdate(payload);
          },
        )
        .subscribe();
  }

  void _subscribeToTyping() {
    try {
      bool canShow = true;
      try {
        final settings = Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : null;
        canShow = settings?.typingIndicator.value ?? true;
      } catch (_) {}
      _typingChannel?.unsubscribe();
      _typingChannel = _client.channel('typing_indicator');
      _typingChannel!.onBroadcast(event: 'typing', callback: (payload, [ref]) {
        if (!canShow) return;
        final convId = payload['conversation_id'] as String?;
        final userId = payload['user_id'] as String?;
        final isTyping = payload['is_typing'] as bool? ?? false;
        final myId = _client.auth.currentUser?.id;
        if (convId == null || userId == null || userId == myId) return;
        typingByConversation[convId] = isTyping;
        if (isTyping) {
          typingUserByConversation[convId] = userId;
          Future.delayed(const Duration(seconds: 3), () {
            if (typingByConversation[convId] == true) {
              typingByConversation[convId] = false;
            }
          });
        } else {
          typingUserByConversation.remove(convId);
        }
      }).subscribe();
    } catch (e) {
      if (kDebugMode) debugPrint('[Typing] subscribe error: $e');
    }
  }

  void sendTyping(String conversationId, bool isTyping) {
    try {
      bool canSend = true;
      try {
        final settings = Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : null;
        canSend = settings?.typingIndicator.value ?? true;
      } catch (_) {}
      if (!canSend) return;
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      if (isTyping) {
        _typingTimer?.cancel();
        _typingChannel?.sendBroadcastMessage(
          event: 'typing',
          payload: {'conversation_id': conversationId, 'user_id': uid, 'is_typing': true},
        );
        _typingTimer = Timer(const Duration(seconds: 2), () {
          _typingChannel?.sendBroadcastMessage(
            event: 'typing',
            payload: {'conversation_id': conversationId, 'user_id': uid, 'is_typing': false},
          );
          typingByConversation[conversationId] = false;
        });
      } else {
        _typingTimer?.cancel();
        _typingChannel?.sendBroadcastMessage(
          event: 'typing',
          payload: {'conversation_id': conversationId, 'user_id': uid, 'is_typing': false},
        );
        typingByConversation[conversationId] = false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Typing] send error: $e');
    }
  }

  void _handleConversationChange(dynamic payload) {
    loadConversations();
  }

  void _handleNewMessage(PostgresChangePayload payload) {
    final newMessage = Message.fromJson(payload.newRecord);
    final convId = newMessage.conversationId;

    // Filtrage bloqués (Meta/WeChat : bloqué = plus de messages reçus)
    final sender = newMessage.senderId;
    // async check bloqué - on filtre sync via cache, le check async est fait via isBlocked cache
    _isBlockedSync(sender).then((blocked) {
      if (blocked) {
        if (kDebugMode) debugPrint('[Messaging] message bloqué ignoré de $sender');
        return;
      }
    });

    messagesByConversation.update(convId, (list) {
      if (!list.any((m) => m.id == newMessage.id)) {
        return [...list, newMessage]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      return list;
    }, ifAbsent: () => [newMessage]);

    _updateConversationLastMessage(convId, newMessage);

    // Auto delivered (Meta WhatsApp double coche) : si je suis destinataire, marquer delivered
    final myId = _client.auth.currentUser?.id;
    if (newMessage.senderId != myId && newMessage.status == MessageStatus.sent) {
      // fire and forget
      updateMessageStatus(newMessage.id, MessageStatus.delivered);
      // maj locale immédiate
      final list = messagesByConversation[convId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == newMessage.id);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(status: MessageStatus.delivered);
          messagesByConversation.refresh();
        }
      }
    }

    // Notification locale si message d'un autre et pas dans la conversation ouverte
    if (newMessage.senderId != myId) {
      try {
        final notif = Get.isRegistered<NotificationService>() ? Get.find<NotificationService>() : null;
        if (notif != null && notif.currentOpenConversationId.value != convId) {
          final conv = conversations.firstWhereOrNull((c) => c.id == convId);
          final title = conv?.getTitle(myId ?? '') ?? 'Nouveau message';
          final body = newMessage.displayContent;
          notif.showMessageNotification(conversationId: convId, title: title, body: body);
        }
      } catch (_) {}
    }
  }

  void _handleMessageUpdate(PostgresChangePayload payload) {
    final updatedMessage = Message.fromJson(payload.newRecord);
    final convId = updatedMessage.conversationId;

    // Même si la conversation n'est pas ouverte (pas dans messagesByConversation),
    // on met à jour la liste des conversations pour refléter le statut (lu/non lu)
    messagesByConversation.update(convId, (list) {
      final index = list.indexWhere((m) => m.id == updatedMessage.id);
      if (index != -1) {
        final newList = List<Message>.from(list);
        newList[index] = updatedMessage;
        return newList;
      }
      // Si pas en cache, on ajoute quand même pour garder la cohérence
      if (list.isEmpty) return [updatedMessage];
      return list;
    }, ifAbsent: () => [updatedMessage]);

    _updateConversationLastMessage(convId, updatedMessage);
    // Mettre à jour le cache hors-ligne
    final cached = messagesByConversation[convId];
    if (cached != null) _cacheMessagesRaw(convId, cached);
  }

  void _updateConversationLastMessage(String convId, Message message) {
    final index = conversations.indexWhere((c) => c.id == convId);
    if (index != -1) {
      conversations[index] = conversations[index].copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
      );
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      conversations.refresh();
    }
  }

  Future<void> loadMessages(String conversationId, {int limit = 50, String? beforeMessageId}) async {
    // Hors-ligne : servir cache local
    if (_isOffline) {
      final fromCache = await _loadMessagesFromCache(conversationId);
      if (!fromCache) {
        errorMessage.value = 'Hors ligne — aucun message en cache';
      }
      return;
    }
    try {
      // Fix N+1: utilise le created_at local si disponible, évite requête supplémentaire
      String? beforeCreatedAt;
      if (beforeMessageId != null) {
        final localList = messagesByConversation[conversationId];
        if (localList != null) {
          try {
            final localMsg = localList.firstWhere((m) => m.id == beforeMessageId);
            beforeCreatedAt = localMsg.createdAt.toIso8601String();
          } catch (_) {}
        }
        if (beforeCreatedAt == null) {
          try {
            final beforeMsg = await _client
                .from('messages')
                .select('created_at')
                .eq('id', beforeMessageId)
                .single();
            beforeCreatedAt = beforeMsg['created_at'] as String;
          } catch (e) {
            if (kDebugMode) print('loadMessages: beforeMessageId introuvable: $e');
          }
        }
      }

      var filter = _client
          .from('messages')
          .select('*, sender:profiles!messages_sender_id_fkey(id, display_name, avatar_url)')
          .eq('conversation_id', conversationId);

      if (beforeCreatedAt != null) {
        filter = filter.lt('created_at', beforeCreatedAt);
      }

      final response = await filter
          .order('created_at', ascending: false)
          .limit(limit);

      var loaded = (response as List)
          .map((json) => Message.fromJsonWithSender(json))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Filtre "Supprimer pour moi" persistant (WhatsApp local) + bloqués
      final deleted = await _getDeletedForMe(conversationId);
      if (deleted.isNotEmpty) {
        loaded = loaded.where((m) => !deleted.contains(m.id)).toList();
      }
      final blocked = await getBlockedUsers();
      if (blocked.isNotEmpty) {
        loaded = loaded.where((m) => !blocked.contains(m.senderId)).toList();
      }

      if (beforeMessageId != null && messagesByConversation.containsKey(conversationId)) {
        final existing = messagesByConversation[conversationId]!;
        final merged = [...loaded, ...existing]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final seen = <String>{};
        final deduped = merged.where((m) => seen.add(m.id)).toList();
        messagesByConversation[conversationId] = deduped;
      } else {
        messagesByConversation[conversationId] = loaded;
      }

      // Résolution des citations parentes (replyTo)
      final currentList = messagesByConversation[conversationId] ?? loaded;
      for (int i = 0; i < currentList.length; i++) {
        final rId = currentList[i].replyToId;
        if (rId != null && rId.isNotEmpty && currentList[i].replyTo == null) {
          final parent = currentList.firstWhereOrNull((m) => m.id == rId);
          if (parent != null) {
            currentList[i] = currentList[i].copyWith(replyTo: parent);
          }
        }
      }
      messagesByConversation[conversationId] = currentList;
      messagesByConversation.refresh();
      // Cache messages pour hors-ligne
      final allMsgs = messagesByConversation[conversationId] ?? loaded;
      await _cacheMessagesRaw(conversationId, allMsgs);
    } catch (e) {
      final isNetError = e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network');
      if (isNetError) {
        final fromCache = await _loadMessagesFromCache(conversationId);
        if (fromCache) {
          errorMessage.value = 'Hors ligne — messages en cache';
          return;
        }
      }
      errorMessage.value = 'Erreur messages: $e';
      if (kDebugMode) print('Erreur loadMessages: $e');
    }
  }

  Future<String?> createDirectConversation(String otherUserId) async {
    try {
      final response = await _client.rpc('get_or_create_direct_conversation', params: {
        'other_user_id': otherUserId,
      });
      return response as String?;
    } catch (e) {
      errorMessage.value = 'Erreur création conversation: $e';
      return null;
    }
  }

  Future<Message?> sendSystemMessage({
    required String conversationId,
    required String content,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return await sendMessage(
      conversationId: conversationId,
      content: content,
      type: MessageType.system,
    );
  }

  Future<Conversation?> createGroupConversation({
    required String name,
    required List<String> memberUserIds,
    String? avatarUrl,
    String? description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      errorMessage.value = 'Non connecté — reconnectez-vous';
      return null;
    }
    try {
      final insertPayload = <String, dynamic>{
        'type': 'group',
        'name': name.trim(),
        'avatar_url': avatarUrl,
        'created_by': userId,
      };
      if (description != null && description.trim().isNotEmpty) {
        insertPayload['description'] = description.trim();
      }

      final insertRes = await _client.from('conversations').insert(insertPayload).select().single();
      final convId = insertRes['id'] as String;

      final allUserIds = {userId, ...memberUserIds}.toList();
      final participantsData = allUserIds.map((uid) {
        return {
          'conversation_id': convId,
          'user_id': uid,
          'role': uid == userId ? 'admin' : 'member',
        };
      }).toList();

      await _client.from('conversation_participants').insert(participantsData);

      // Message système initial WhatsApp
      await sendSystemMessage(
        conversationId: convId,
        content: 'Vous avez créé le groupe « $name »',
      );

      await loadConversations();
      return conversations.firstWhereOrNull((c) => c.id == convId);
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur createGroupConversation: $e');
      errorMessage.value = 'Erreur création groupe: $e';
      return null;
    }
  }

  Future<bool> updateGroupInfo({
    required String conversationId,
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) payload['name'] = name.trim();
      if (description != null) payload['description'] = description.trim();
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

      await _client.from('conversations').update(payload).eq('id', conversationId);

      // Maj locale réactive
      final idx = conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        conversations[idx] = conversations[idx].copyWith(
          name: name ?? conversations[idx].name,
          description: description ?? conversations[idx].description,
          avatarUrl: avatarUrl ?? conversations[idx].avatarUrl,
        );
        conversations.refresh();
      }

      await sendSystemMessage(
        conversationId: conversationId,
        content: 'Les informations du groupe ont été mises à jour',
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur updateGroupInfo: $e');
      errorMessage.value = 'Erreur mise à jour groupe: $e';
      return false;
    }
  }

  Future<bool> updateGroupSettings({
    required String conversationId,
    required bool onlyAdminsCanSend,
    required bool onlyAdminsCanEditInfo,
  }) async {
    try {
      await _client.from('conversations').update({
        'only_admins_can_send': onlyAdminsCanSend,
        'only_admins_can_edit_info': onlyAdminsCanEditInfo,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);

      final idx = conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        conversations[idx] = conversations[idx].copyWith(
          onlyAdminsCanSend: onlyAdminsCanSend,
          onlyAdminsCanEditInfo: onlyAdminsCanEditInfo,
        );
        conversations.refresh();
      }

      await sendSystemMessage(
        conversationId: conversationId,
        content: 'Les autorisations du groupe ont été modifiées',
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur updateGroupSettings: $e');
      errorMessage.value = 'Erreur paramètres groupe: $e';
      return false;
    }
  }

  Future<bool> setParticipantRole({
    required String conversationId,
    required String userId,
    required String role,
    String? memberName,
  }) async {
    try {
      await _client
          .from('conversation_participants')
          .update({'role': role})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      await loadConversations();

      final label = role == 'admin'
          ? '${memberName ?? 'Ce membre'} est désormais administrateur'
          : '${memberName ?? 'Ce membre'} n\'est plus administrateur';
      await sendSystemMessage(conversationId: conversationId, content: label);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur setParticipantRole: $e');
      errorMessage.value = 'Erreur rôle participant: $e';
      return false;
    }
  }

  Future<bool> addParticipantsToGroup(String conversationId, List<String> userIds, {List<String>? names}) async {
    try {
      final participantsData = userIds.map((uid) => {
        'conversation_id': conversationId,
        'user_id': uid,
        'role': 'member',
      }).toList();
      await _client.from('conversation_participants').insert(participantsData);
      await loadConversations();

      final namesStr = (names != null && names.isNotEmpty) ? names.join(', ') : 'De nouveaux membres';
      await sendSystemMessage(
        conversationId: conversationId,
        content: '$namesStr ont été ajoutés au groupe',
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur addParticipantsToGroup: $e');
      errorMessage.value = 'Erreur ajout participant: $e';
      return false;
    }
  }

  Future<bool> removeParticipantFromGroup(String conversationId, String userId, {String? memberName}) async {
    try {
      await _client
          .from('conversation_participants')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
      await loadConversations();

      await sendSystemMessage(
        conversationId: conversationId,
        content: '${memberName ?? 'Un membre'} a été retiré du groupe',
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur removeParticipantFromGroup: $e');
      errorMessage.value = 'Erreur retrait participant: $e';
      return false;
    }
  }

  Future<bool> leaveGroup(String conversationId, {String? userName}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from('conversation_participants')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      await sendSystemMessage(
        conversationId: conversationId,
        content: '${userName ?? 'Un participant'} a quitté le groupe',
      );

      conversations.removeWhere((c) => c.id == conversationId);
      conversations.refresh();
      clearMessages(conversationId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur leaveGroup: $e');
      return false;
    }
  }

  Future<bool> toggleMuteConversation(String conversationId, bool mute) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from('conversation_participants')
          .update({'muted': mute})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
      final idx = conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        final conv = conversations[idx];
        final pIdx = conv.participants.indexWhere((p) => p.userId == userId);
        if (pIdx != -1) {
          final p = conv.participants[pIdx];
          final updatedP = ConversationParticipant(
            conversationId: p.conversationId,
            userId: p.userId,
            role: p.role,
            joinedAt: p.joinedAt,
            lastReadMessageId: p.lastReadMessageId,
            muted: mute,
            profile: p.profile,
          );
          final newParticipants = List<ConversationParticipant>.from(conv.participants);
          newParticipants[pIdx] = updatedP;
          conversations[idx] = conv.copyWith(participants: newParticipants);
          conversations.refresh();
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Erreur toggleMuteConversation: $e');
      return false;
    }
  }

  Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? mediaMimeType,
    int? mediaSizeBytes,
    String? replyToId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      errorMessage.value = 'Non connecté — reconnectez-vous';
      return null;
    }

    // === MODE HORS-LIGNE : file d'attente + message optimiste ===
    if (_isOffline) {
      final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}_${content.hashCode}';
      final localMsg = Message(
        id: tempId,
        conversationId: conversationId,
        senderId: userId,
        type: type,
        content: content,
        mediaUrl: mediaUrl,
        mediaMimeType: mediaMimeType,
        mediaSizeBytes: mediaSizeBytes,
        replyToId: replyToId,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        sender: AuthService.to.currentUser.value,
      );
      addLocalMessage(conversationId, localMsg);
      // persister cache messages
      await _cacheMessagesRaw(conversationId, messagesByConversation[conversationId] ?? [localMsg]);
      // enqueue pour envoi différé
      await OfflineService.to.enqueuePending({
        'tempId': tempId,
        'conversation_id': conversationId,
        'sender_id': userId,
        'type': type.name,
        'content': content,
        'media_url': mediaUrl,
        'media_mime_type': mediaMimeType,
        'media_size_bytes': mediaSizeBytes,
        'reply_to_id': replyToId,
        'created_at': DateTime.now().toIso8601String(),
      });
      errorMessage.value = 'Hors ligne — message en attente d\'envoi';
      if (kDebugMode) debugPrint('[Messaging] Offline queued msg $tempId');
      return localMsg;
    }

    // Optimistic UI : affiche immédiatement avant la confirmation serveur
    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}_${content.hashCode}';
    final optimisticMsg = Message(
      id: optimisticId,
      conversationId: conversationId,
      senderId: userId,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      mediaSizeBytes: mediaSizeBytes,
      replyToId: replyToId,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sender: AuthService.to.currentUser.value,
    );
    addLocalMessage(conversationId, optimisticMsg);
    await _cacheMessagesRaw(conversationId, messagesByConversation[conversationId] ?? [optimisticMsg]);

    try {
      dynamic response;
      try {
        response = await _client
            .from('messages')
            .insert({
              'conversation_id': conversationId,
              'sender_id': userId,
              'type': type.name,
              'content': content,
              'media_url': mediaUrl,
              'media_mime_type': mediaMimeType,
              'media_size_bytes': mediaSizeBytes,
              'reply_to_id': replyToId,
              'status': 'sent',
            })
            .select('*, sender:profiles!messages_sender_id_fkey(id, display_name, avatar_url)')
            .single();
      } catch (insertErr) {
        response = await _client
            .from('messages')
            .insert({
              'conversation_id': conversationId,
              'sender_id': userId,
              'type': type.name,
              'content': content,
              'media_url': mediaUrl,
              'media_mime_type': mediaMimeType,
              'media_size_bytes': mediaSizeBytes,
              'reply_to_id': replyToId,
              'status': 'sent',
            })
            .select()
            .single();
      }

      Message message;
      try {
        message = Message.fromJsonWithSender(response);
      } catch (_) {
        final profile = AuthService.to.currentUser.value;
        message = Message.fromJson(response).copyWith(
          sender: profile,
        );
      }

      // Remplace l'optimistic par le message serveur (vrai id)
      final list = messagesByConversation[conversationId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == optimisticId);
        if (idx != -1) {
          list[idx] = message;
          messagesByConversation.refresh();
        } else {
          // Fallback si déjà supprimé via realtime
          addLocalMessage(conversationId, message);
        }
      } else {
        addLocalMessage(conversationId, message);
      }
      _updateConversationLastMessage(conversationId, message);
      await _cacheMessagesRaw(conversationId, messagesByConversation[conversationId] ?? [message]);

      try {
        await _client
            .from('conversations')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', conversationId);
      } catch (_) {
        // Non critique: trigger SQL
      }

      return message;
    } catch (e) {
      final msg = e.toString();
      // Si erreur réseau, garder l'optimistic et le mettre en file d'attente
      if (msg.contains('Failed host lookup') || msg.contains('SocketException') || msg.contains('Network is unreachable') || msg.contains('TimeoutException')) {
        // L'optimistic est déjà affiché, on le met juste en queue avec son id
        await OfflineService.to.enqueuePending({
          'tempId': optimisticId,
          'conversation_id': conversationId,
          'sender_id': userId,
          'type': type.name,
          'content': content,
          'media_url': mediaUrl,
          'media_mime_type': mediaMimeType,
          'media_size_bytes': mediaSizeBytes,
          'reply_to_id': replyToId,
          'created_at': DateTime.now().toIso8601String(),
        });
        errorMessage.value = 'Hors ligne — message mis en file d\'attente';
        return optimisticMsg;
      }
      String friendly = 'Erreur envoi: $msg';
      if (msg.contains('row-level security') || msg.contains('violates row-level security')) {
        friendly = 'Envoi bloqué par la sécurité (RLS). Exécutez supabase/ALL_FIXES.sql dans Supabase SQL Editor.';
      } else if (msg.contains('Bucket not found') || msg.contains('chat-media')) {
        friendly = 'Stockage non configuré (bucket chat-media manquant). Exécutez supabase/ALL_FIXES.sql';
      } else if (msg.contains('42501') || msg.contains('permission denied')) {
        friendly = 'Permission refusée (RLS). Exécutez supabase/ALL_FIXES.sql.';
      } else if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
        friendly = 'Pas de connexion internet';
      }
      errorMessage.value = friendly;
      if (kDebugMode) print('Erreur sendMessage: $e');
      return null;
    }
  }

  /// Vide la file d'attente des messages en attente (appelé au retour online)
  Future<void> flushPendingQueue() async {
    if (_pendingFlushScheduled) return;
    _pendingFlushScheduled = true;
    try {
      final queue = OfflineService.to.getPendingQueue();
      if (queue.isEmpty) return;
      if (kDebugMode) debugPrint('[Messaging] flushPendingQueue: ${queue.length} items');
      // Itérer copie pour pouvoir remove
      for (int i = queue.length - 1; i >= 0; i--) {
        final item = queue[i];
        final convId = item['conversation_id'] as String;
        final content = item['content'] as String? ?? '';
        final typeStr = item['type'] as String? ?? 'text';
        final tempId = item['tempId'] as String? ?? '';

        try {
          final result = await _client
              .from('messages')
              .insert({
                'conversation_id': convId,
                'sender_id': item['sender_id'],
                'type': typeStr,
                'content': content,
                'media_url': item['media_url'],
                'media_mime_type': item['media_mime_type'],
                'media_size_bytes': item['media_size_bytes'],
                'reply_to_id': item['reply_to_id'],
                'status': 'sent',
              })
              .select()
              .single();

          // Remplacer le message temporaire par le vrai
          final realMsg = Message.fromJson(result);
          final list = messagesByConversation[convId];
          if (list != null) {
            final idx = list.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              list[idx] = realMsg;
              messagesByConversation.refresh();
              await _cacheMessagesRaw(convId, list);
            }
          }
          // Supprimer de la queue
          await OfflineService.to.removePendingAt(i);
          if (kDebugMode) debugPrint('[Messaging] flushed pending $tempId -> ${realMsg.id}');
        } catch (e) {
          if (kDebugMode) debugPrint('[Messaging] flush pending item failed (keep queue): $e');
          // On garde l'item pour retry plus tard si c'est réseau, sinon on supprime?
          final msg = e.toString();
          if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
            // Reste en queue, on arrête le flush
            break;
          }
          // Pour autres erreurs (RLS etc), on ne supprime pas non plus, on laisse l'utilisateur réessayer
          continue;
        }
      }
    } finally {
      _pendingFlushScheduled = false;
    }
  }

  Future<void> markAsRead(String conversationId, String messageId) async {
    bool canSendReceipt = true;
    try {
      if (Get.isRegistered<SettingsService>()) {
        canSendReceipt = Get.find<SettingsService>().readReceipts.value;
      }
    } catch (_) {}
    if (canSendReceipt) {
      try {
        try {
          await _client.rpc('mark_messages_as_read', params: {
            'p_conversation_id': conversationId,
            'p_message_id': messageId,
          });
        } catch (_) {
          await _client.rpc('mark_messages_as_read', params: {
            'conversation_id': conversationId,
            'message_id': messageId,
          });
        }
      } catch (e) {
        if (kDebugMode) print('Erreur markAsRead (ignorée): $e');
      }
    } else {
      if (kDebugMode) debugPrint('[ReadReceipt] désactivé -> pas d\'envoi serveur, marquage local seul');
    }

    try {
      final messages = messagesByConversation[conversationId];
      if (messages != null) {
        for (var msg in messages) {
          if (msg.senderId != _client.auth.currentUser?.id) {
            final idx = messages.indexOf(msg);
            if (idx != -1) {
              messages[idx] = msg.copyWith(status: MessageStatus.read);
            }
          }
          if (msg.id == messageId) break;
        }
        messagesByConversation.refresh();
      }
    } catch (e) {
      if (kDebugMode) print('Erreur markAsRead local: $e');
    }
  }

  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    try {
      await _client
          .from('messages')
          .update({'status': status.name})
          .eq('id', messageId);
    } catch (e) {
      if (kDebugMode) print('Erreur updateMessageStatus: $e');
    }
  }

  Future<String?> uploadMedia(String path, Uint8List bytes, String mimeType) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}';
      final storagePath = '$userId/$fileName';

      await _client.storage.from('chat-media').uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: mimeType, upsert: true));

      // Fix robuste : signed 1 an pour durée de vie réelle (photos chat) ; fallback public si bucket public
      // Bucket peut être public (ALL_FIXES) ou privé (BLOQUANTS) -> on tente signed longue durée
      String url;
      try {
        url = await _client.storage.from('chat-media').createSignedUrl(storagePath, 60 * 60 * 24 * 365);
      } catch (_) {
        url = _client.storage.from('chat-media').getPublicUrl(storagePath);
      }
      if (kDebugMode) debugPrint('[Messaging] uploadMedia ok $storagePath -> ${url.substring(0, 60)}...');
      return url;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Bucket not found') || msg.contains('not found')) {
        errorMessage.value = 'Bucket chat-media manquant — exécutez supabase/ALL_FIXES.sql dans SQL Editor';
      } else if (msg.contains('row-level') || msg.contains('42501')) {
        errorMessage.value = 'Permission stockage refusée (RLS). Exécutez supabase/SUPABASE_BLOQUANTS_FIX.sql';
      } else {
        errorMessage.value = 'Erreur upload: $e';
      }
      if (kDebugMode) debugPrint('Erreur uploadMedia: $e');
      return null;
    }
  }

  List<Message> getMessages(String conversationId) {
    return messagesByConversation[conversationId] ?? [];
  }

  void clearMessages(String conversationId) {
    messagesByConversation.remove(conversationId);
  }

  // WhatsApp/WeChat "Effacer discussion" : vide pour moi, persiste cache vide + filtre reload
  Future<void> clearConversationForMe(String conversationId) async {
    messagesByConversation.remove(conversationId);
    messagesByConversation.refresh();
    try {
      await OfflineService.to.cacheMessages(conversationId, []);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('deleted_for_me_$conversationId', []);
      // Marqueur pour filtrer les anciens messages au prochain load
      await prefs.setString('cleared_at_$conversationId', DateTime.now().toIso8601String());
    } catch (_) {}
    // Option serveur: ne supprime pas côté Supabase (comme WhatsApp effacer = local)
  }

  // Bloquer / Débloquer (Meta/WeChat) : liste locale + filtrage
  static const _blockedKey = 'blocked_users';

  Future<bool> isBlocked(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_blockedKey) ?? [];
      return list.contains(userId);
    } catch (_) { return false; }
  }

  Future<bool> _isBlockedSync(String userId) async => await isBlocked(userId);

  Future<void> blockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedKey) ?? [];
    if (!list.contains(userId)) {
      list.add(userId);
      await prefs.setStringList(_blockedKey, list);
    }
  }

  Future<void> unblockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedKey) ?? [];
    list.remove(userId);
    await prefs.setStringList(_blockedKey, list);
  }

  Future<List<String>> getBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_blockedKey) ?? [];
  }

  void editLocalMessage(String conversationId, String messageId, String newContent) {
    final list = messagesByConversation[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(content: newContent, isEdited: true);
    messagesByConversation.refresh();
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    editLocalMessage(conversationId, messageId, newContent);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('messages').update({'content': newContent, 'is_edited': true}).eq('id', messageId);
    } catch (e) {
      if (kDebugMode) print('Erreur editMessage: $e');
    }
  }

  // WhatsApp "Supprimer pour moi" : masque localement + persiste pour ne pas réapparaître au reload
  Future<void> deleteMessageForMe(String conversationId, String messageId) async {
    messagesByConversation.update(
      conversationId,
      (list) => list.where((m) => m.id != messageId).toList(),
    );
    messagesByConversation.refresh();
    // Persiste les ids supprimés localement (comme WhatsApp) pour filtrer au prochain loadMessages
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'deleted_for_me_$conversationId';
      final existing = prefs.getStringList(key) ?? [];
      if (!existing.contains(messageId)) {
        existing.add(messageId);
        await prefs.setStringList(key, existing);
      }
      // Maj cache offline sans le message supprimé
      final remaining = messagesByConversation[conversationId] ?? [];
      await _cacheMessagesRaw(conversationId, remaining);
    } catch (_) {}
  }

  Future<Set<String>> _getDeletedForMe(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('deleted_for_me_$conversationId') ?? <String>[];
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> deleteMessageForEveryone(String conversationId, String messageId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final list = messagesByConversation[conversationId];
    Message? msg;
    if (list != null) {
      for (final m in list) {
        if (m.id == messageId) {
          msg = m;
          break;
        }
      }
    }
    if (msg != null && msg.senderId != userId) {
      errorMessage.value = 'Vous ne pouvez supprimer que vos propres messages pour tout le monde';
      return;
    }
    deleteMessageForMe(conversationId, messageId);
    try {
      await _client.from('messages').delete().eq('id', messageId).eq('sender_id', userId);
    } catch (e) {
      if (kDebugMode) print('Erreur deleteMessage: $e');
      errorMessage.value = 'Suppression échouée: $e';
    }
  }

  void addLocalMessage(String conversationId, Message message) {
    var msgToAdd = message;
    if (msgToAdd.replyToId != null && msgToAdd.replyTo == null) {
      final list = messagesByConversation[conversationId];
      if (list != null) {
        final parent = list.firstWhereOrNull((m) => m.id == msgToAdd.replyToId);
        if (parent != null) {
          msgToAdd = msgToAdd.copyWith(replyTo: parent);
        }
      }
    }
    messagesByConversation.update(
      conversationId,
      (list) => [...list, msgToAdd]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      ifAbsent: () => [msgToAdd],
    );
    _updateConversationLastMessage(conversationId, msgToAdd);
  }

  Future<Message?> sendVoiceMessage({
    required String conversationId,
    required String path,
    required int durationSeconds,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final url = await uploadMedia(path, bytes, 'audio/m4a');
      if (url == null) return null;
      final msg = await sendMessage(
        conversationId: conversationId,
        content: 'Message vocal',
        type: MessageType.audio,
        mediaUrl: url,
        mediaMimeType: 'audio/m4a',
        mediaSizeBytes: bytes.length,
      );
      return msg;
    } catch (e) {
      errorMessage.value = 'Erreur envoi vocal: $e';
      if (kDebugMode) print('Erreur sendVoiceMessage: $e');
      return null;
    }
  }

  // ===========================================================================
  // WhatsApp Pinned Conversations (Épinglage max 3)
  // ===========================================================================
  static const String _pinnedPrefsKey = 'chatme_pinned_conversations';

  Future<void> _loadPinnedConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pinnedPrefsKey) ?? [];
      pinnedConversationIds.value = list;
    } catch (_) {}
  }

  bool isPinned(String conversationId) => pinnedConversationIds.contains(conversationId);

  Future<bool> togglePinConversation(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pinnedConversationIds.contains(conversationId)) {
        pinnedConversationIds.remove(conversationId);
        await prefs.setStringList(_pinnedPrefsKey, pinnedConversationIds.toList());
        return true;
      } else {
        if (pinnedConversationIds.length >= 3) {
          return false; // limite WhatsApp max 3
        }
        pinnedConversationIds.add(conversationId);
        await prefs.setStringList(_pinnedPrefsKey, pinnedConversationIds.toList());
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  List<Conversation> get sortedConversations {
    final list = List<Conversation>.from(conversations);
    list.sort((a, b) {
      final aPinned = isPinned(a.id);
      final bPinned = isPinned(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  // ===========================================================================
  // WhatsApp / Meta Emoji Reactions
  // ===========================================================================
  final Map<String, RealtimeChannel> _activeRoomChannels = {};

  void subscribeToConversationRoom(String conversationId) {
    if (_activeRoomChannels.containsKey(conversationId)) return;
    final chan = _client.channel('chat_realtime_$conversationId');
    chan.onBroadcast(
      event: 'reaction',
      callback: (payload) {
        final messageId = payload['message_id'] as String?;
        final reactionsMap = payload['reactions'] as Map?;
        if (messageId == null) return;

        final list = messagesByConversation[conversationId];
        if (list == null) return;
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;

        Map<String, List<String>>? parsed;
        if (reactionsMap != null) {
          parsed = reactionsMap.map((k, v) => MapEntry(
                k.toString(),
                (v as List?)?.map((e) => e.toString()).toList() ?? <String>[],
              ));
        }

        list[idx] = list[idx].copyWith(reactions: parsed);
        messagesByConversation.refresh();
      },
    ).subscribe();
    _activeRoomChannels[conversationId] = chan;
  }

  void unsubscribeFromConversationRoom(String conversationId) {
    _activeRoomChannels[conversationId]?.unsubscribe();
    _activeRoomChannels.remove(conversationId);
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final list = messagesByConversation[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final currentMsg = list[idx];
    final currentReactions = Map<String, List<String>>.from(
      currentMsg.reactions?.map((k, v) => MapEntry(k, List<String>.from(v))) ?? {},
    );

    final usersForEmoji = currentReactions[emoji] ?? <String>[];
    if (usersForEmoji.contains(userId)) {
      usersForEmoji.remove(userId);
      if (usersForEmoji.isEmpty) {
        currentReactions.remove(emoji);
      } else {
        currentReactions[emoji] = usersForEmoji;
      }
    } else {
      usersForEmoji.add(userId);
      currentReactions[emoji] = usersForEmoji;
    }

    final updated = currentMsg.copyWith(reactions: currentReactions);
    list[idx] = updated;
    messagesByConversation.refresh();

    // Cache offline
    await _cacheMessagesRaw(conversationId, list);

    // Diffusion temps réel aux autres participants
    try {
      final chan = _activeRoomChannels[conversationId] ?? _client.channel('chat_realtime_$conversationId');
      await chan.sendBroadcastMessage(
        event: 'reaction',
        payload: {
          'message_id': messageId,
          'reactions': currentReactions,
        },
      );
    } catch (_) {}
  }
}
