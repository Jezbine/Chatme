import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatme/services/messaging_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/core/services/notification_service.dart';
import 'package:chatme/models/conversation.dart';
import 'package:chatme/models/message.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/utils/format_utils.dart';
import 'call_screen.dart';
import 'avatar_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({required this.conversation, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final messaging = Get.find<MessagingService>();
  final auth = Get.find<AuthService>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  String? _recordedPath;
  bool _isPlaying = false;
  String? _playingMessageId;
  Timer? _recordTimer;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ImagePicker _imagePicker = ImagePicker();

  String get currentUserId => auth.currentUser.value?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
        _isPlaying = false;
        _playingMessageId = null;
      });
      }
    });
    _loadMessages();
    _scrollController.addListener(_onScroll);
    // Notifier qu'on est dans cette conversation (évite notif redondante)
    try {
      Get.find<NotificationService>().setCurrentConversation(widget.conversation.id);
      Get.find<NotificationService>().cancelForConversation(widget.conversation.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    try {
      Get.find<NotificationService>().setCurrentConversation(null);
    } catch (_) {}
    messaging.clearMessages(widget.conversation.id);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markVisibleMessagesAsRead();
    }
  }

  Future<void> _loadMessages() async {
    await messaging.loadMessages(widget.conversation.id);
    _scrollToBottom();
  }

  void _onScroll() {
    // Fix pagination: charger plus anciens quand on scroll vers le haut (proche du top)
    if (_scrollController.position.pixels <= 200 && !_isLoadingMore && _hasMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    final messages = messaging.getMessages(widget.conversation.id);
    if (messages.isEmpty) return;
    final oldestId = messages.first.id;
    setState(() => _isLoadingMore = true);
    final beforeCount = messages.length;
    await messaging.loadMessages(widget.conversation.id, beforeMessageId: oldestId);
    final afterCount = messaging.getMessages(widget.conversation.id).length;
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        if (afterCount == beforeCount) _hasMore = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markVisibleMessagesAsRead() {
    final messages = messaging.getMessages(widget.conversation.id);
    if (messages.isNotEmpty) {
      final lastMsg = messages.last;
      if (lastMsg.senderId != currentUserId && lastMsg.status != MessageStatus.read) {
        messaging.markAsRead(widget.conversation.id, lastMsg.id);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    messaging.sendTyping(widget.conversation.id, false);
    await messaging.sendMessage(
      conversationId: widget.conversation.id,
      content: text,
    );
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      // Fix perf: demande explicite permission_handler avant hasPermission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        Get.snackbar('Micro', 'Permission micro refusée', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (!await _recorder.hasPermission()) {
        Get.snackbar('Micro', 'Permission d\'enregistrement requise', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordedPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: _recordedPath!);
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      Get.snackbar('Erreur', 'Enregistrement impossible: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    setState(() => _isRecording = false);
    path ??= _recordedPath;
    if (path == null) return;
    final seconds = _recordDuration.inSeconds;
    _recordDuration = Duration.zero;
    await _sendVoiceLocally(path, seconds);
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (_recordedPath != null) {
      final f = File(_recordedPath!);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _isRecording = false;
      _recordedPath = null;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _sendVoiceLocally(String path, int seconds) async {
    if (currentUserId.isEmpty) {
      Get.snackbar('Connexion', 'Connectez-vous pour envoyer un message vocal', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final msg = Message(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: currentUserId,
      type: MessageType.audio,
      content: 'Message vocal',
      mediaUrl: path,
      mediaMimeType: 'audio/m4a',
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    messaging.addLocalMessage(widget.conversation.id, msg);
    _scrollToBottom();
    messaging.sendVoiceMessage(conversationId: widget.conversation.id, path: path, durationSeconds: seconds);
  }

  // Fix photo/pièce jointe : Meta (WhatsApp) compresse + upload + bulle image ; WeChat similar
  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          Get.snackbar('Permission', 'Autorisez la caméra pour prendre une photo',
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
      } else {
        try { await Permission.photos.request(); } catch (_) {}
      }
      final XFile? file = await _imagePicker.pickImage(source: source, imageQuality: 80, maxWidth: 1280);
      if (file == null) return;
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      final url = await messaging.uploadMedia(file.path, bytes, mime);
      if (Get.isDialogOpen == true) Get.back();
      if (url == null) {
        Get.snackbar('Erreur', messaging.errorMessage.value.isNotEmpty ? messaging.errorMessage.value : 'Upload échoué', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      await messaging.sendMessage(
        conversationId: widget.conversation.id,
        content: file.name,
        type: MessageType.image,
        mediaUrl: url,
        mediaMimeType: mime,
        mediaSizeBytes: bytes.length,
      );
      _scrollToBottom();
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      Get.snackbar('Erreur', 'Photo impossible: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _pickAndSendFile() async {
    _showAttachmentSheet();
  }

  Future<void> _pickAndSendVideo() async {
    try {
      try { await Permission.photos.request(); } catch (_) {}
      final XFile? file = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      final bytes = await File(file.path).readAsBytes();
      final mime = 'video/mp4';
      final url = await messaging.uploadMedia(file.path, bytes, mime);
      if (Get.isDialogOpen == true) Get.back();
      if (url == null) {
        Get.snackbar('Erreur', messaging.errorMessage.value.isNotEmpty ? messaging.errorMessage.value : 'Upload vidéo échoué', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      await messaging.sendMessage(
        conversationId: widget.conversation.id,
        content: file.name,
        type: MessageType.video,
        mediaUrl: url,
        mediaMimeType: mime,
        mediaSizeBytes: bytes.length,
      );
      _scrollToBottom();
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      Get.snackbar('Erreur', 'Vidéo impossible: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _pickAndSendGenericFile() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final f = files.first;
      Uint8List bytes;
      if (f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      } else {
        bytes = Uint8List(0);
      }
      if (bytes.isEmpty) {
        Get.snackbar('Erreur', 'Fichier illisible', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      final mime = f.extension != null ? 'application/${f.extension}' : 'application/octet-stream';
      final path = f.path ?? f.name;
      final url = await messaging.uploadMedia(path, bytes, mime);
      if (Get.isDialogOpen == true) Get.back();
      if (url == null) {
        Get.snackbar('Erreur', messaging.errorMessage.value.isNotEmpty ? messaging.errorMessage.value : 'Upload fichier échoué', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      await messaging.sendMessage(
        conversationId: widget.conversation.id,
        content: f.name,
        type: MessageType.file,
        mediaUrl: url,
        mediaMimeType: mime,
        mediaSizeBytes: bytes.length,
      );
      _scrollToBottom();
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      Get.snackbar('Erreur', 'Fichier impossible: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showAttachmentSheet() {
    Get.bottomSheet(
      Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Get.back();
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir dans la galerie'),
                onTap: () {
                  Get.back();
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Vidéo (galerie)'),
                onTap: () {
                  Get.back();
                  _pickAndSendVideo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Fichier'),
                onTap: () {
                  Get.back();
                  _pickAndSendGenericFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlay(Message msg) async {
    final url = msg.mediaUrl;
    if (url == null) return;
    if (_playingMessageId == msg.id && _isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingMessageId = null;
      });
      return;
    }
    try {
      await _audioPlayer.stop();
      if (url.startsWith('http')) {
        await _audioPlayer.play(UrlSource(url));
      } else {
        await _audioPlayer.play(DeviceFileSource(url));
      }
      setState(() {
        _isPlaying = true;
        _playingMessageId = msg.id;
      });
    } catch (e) {
      Get.snackbar('Erreur', 'Lecture impossible', snackPosition: SnackPosition.BOTTOM);
    }
  }

  bool _canEdit(Message msg) =>
      msg.senderId == currentUserId &&
      msg.type == MessageType.text &&
      DateTime.now().difference(msg.createdAt).inMinutes <= 15;

  void _showMessageOptions(Message msg) {
    final options = <Widget>[];
    if (_canEdit(msg)) {
      options.add(ListTile(
        leading: const Icon(Icons.edit_outlined),
        title: const Text('Modifier'),
        onTap: () {
          Get.back();
          _editMessageDialog(msg);
        },
      ));
    }
    options.add(ListTile(
      leading: const Icon(Icons.delete_outline),
      title: const Text('Supprimer pour moi'),
      onTap: () async {
        Get.back();
        await messaging.deleteMessageForMe(widget.conversation.id, msg.id);
        Get.snackbar('Supprimé', 'Message supprimé pour vous (comme WhatsApp)', snackPosition: SnackPosition.BOTTOM);
      },
    ));
    if (msg.senderId == currentUserId) {
      options.add(ListTile(
        leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
        title: const Text('Supprimer pour tout le monde',
            style: TextStyle(color: Colors.red)),
        onTap: () {
          Get.back();
          messaging.deleteMessageForEveryone(widget.conversation.id, msg.id);
        },
      ));
    }
    Get.bottomSheet(
      Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: options)),
      ),
    );
  }

  void _editMessageDialog(Message msg) {
    final ctrl = TextEditingController(text: msg.content ?? '');
    Get.dialog(
      AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                messaging.editMessage(
                  conversationId: widget.conversation.id,
                  messageId: msg.id,
                  newContent: text,
                );
              }
              Get.back();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherParticipant = widget.conversation.participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => widget.conversation.participants.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                final url = widget.conversation.getAvatarUrl(currentUserId);
                Get.to(() => AvatarViewerScreen(
                      imageUrl: url,
                      initials: otherParticipant.profile?.initials ?? '?',
                      name: widget.conversation.getTitle(currentUserId),
                    ));
              },
              child: Hero(
                tag: 'avatar_${widget.conversation.getAvatarUrl(currentUserId) ?? otherParticipant.profile?.initials}',
                child: Builder(builder: (ctx) {
                  final avatarUrl = widget.conversation.getAvatarUrl(currentUserId);
                  if (avatarUrl != null && avatarUrl.isNotEmpty) {
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: NetworkImage(avatarUrl),
                      onBackgroundImageError: (_, __) {},
                      child: null,
                    );
                  }
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      otherParticipant.profile?.initials ?? '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.getTitle(currentUserId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Obx(() {
                    final isTyping = messaging.typingByConversation[widget.conversation.id] == true;
                    if (isTyping) {
                      return const Text('En train d\'écrire...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic));
                    }
                    if (!widget.conversation.isGroup && otherParticipant.profile?.isOnline == true) {
                      return const Text('En ligne',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.green));
                    }
                    if (!widget.conversation.isGroup) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'Dernière vue: ${_formatLastSeen(otherParticipant.profile?.lastSeen)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => Get.to(() => CallScreen(
                  conversationId: widget.conversation.id,
                  otherUserId: otherParticipant.userId,
                  name: widget.conversation.getTitle(currentUserId),
                  initials: otherParticipant.profile?.initials ?? '?',
                  isVideo: false,
                  photoUrl: widget.conversation.getAvatarUrl(currentUserId),
                )),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => Get.to(() => CallScreen(
                  conversationId: widget.conversation.id,
                  otherUserId: otherParticipant.userId,
                  name: widget.conversation.getTitle(currentUserId),
                  initials: otherParticipant.profile?.initials ?? '?',
                  isVideo: true,
                  photoUrl: widget.conversation.getAvatarUrl(currentUserId),
                )),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'profil') {
                final url = widget.conversation.getAvatarUrl(currentUserId);
                Get.to(() => AvatarViewerScreen(imageUrl: url, initials: otherParticipant.profile?.initials ?? '?', name: widget.conversation.getTitle(currentUserId)));
              } else if (v == 'effacer') {
                final ok = await Get.dialog<bool>(AlertDialog(title: const Text('Effacer la discussion'), content: const Text('Supprimer tous les messages pour vous ? (comme WhatsApp) — local uniquement'), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')), TextButton(onPressed: () => Get.back(result: true), child: const Text('Effacer', style: TextStyle(color: Colors.red)))]));
                if (ok == true) {
                  await messaging.clearConversationForMe(widget.conversation.id);
                  Get.snackbar('Discussion effacée', 'Messages supprimés pour vous (comme WhatsApp/WeChat)', snackPosition: SnackPosition.BOTTOM);
                }
              } else if (v == 'bloquer') {
                final otherId = otherParticipant.userId;
                final isBlocked = await messaging.isBlocked(otherId);
                if (isBlocked) {
                  final ok = await Get.dialog<bool>(AlertDialog(title: const Text('Débloquer ?'), content: Text('Débloquer ${widget.conversation.getTitle(currentUserId)} ?'), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')), TextButton(onPressed: () => Get.back(result: true), child: const Text('Débloquer'))]));
                  if (ok == true) {
                    await messaging.unblockUser(otherId);
                    Get.snackbar('Débloqué', 'Utilisateur débloqué', snackPosition: SnackPosition.BOTTOM);
                  }
                } else {
                  final ok = await Get.dialog<bool>(AlertDialog(title: const Text('Bloquer ce contact ?'), content: const Text('Vous ne recevrez plus ses messages (comme WhatsApp/WeChat).'), actions: [TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')), TextButton(onPressed: () => Get.back(result: true), child: const Text('Bloquer', style: TextStyle(color: Colors.red)))]));
                  if (ok == true) {
                    await messaging.blockUser(otherId);
                    Get.snackbar('Bloqué', 'Utilisateur bloqué', snackPosition: SnackPosition.BOTTOM);
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profil', child: Row(children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 10), Text('Voir profil')])),
              PopupMenuItem(value: 'effacer', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text('Effacer discussion', style: TextStyle(color: Colors.red))])),
              PopupMenuItem(value: 'bloquer', child: Row(children: [Icon(Icons.block, size: 18), SizedBox(width: 10), Text('Bloquer / Débloquer')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final messages = messaging.getMessages(widget.conversation.id);
              // Auto-mark comme lu dès que les messages sont visibles
              if (messages.isNotEmpty) {
                final last = messages.last;
                if (last.senderId != currentUserId && last.status != MessageStatus.read) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleMessagesAsRead());
                }
              }

              if (messages.isEmpty && messaging.isLoadingConversations.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (messages.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMine = msg.senderId == currentUserId;
                  final showTime = index == 0 ||
                      messages[index - 1].createdAt.difference(msg.createdAt).inMinutes > 5;

                  return Column(
                    children: [
                      if (showTime) _buildTimeSeparator(msg.createdAt),
                      _buildMessageBubble(context, msg, isMine),
                    ],
                  );
                },
              );
            }),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Aucun message',
            style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Dites bonjour !',
            style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeparator(DateTime date) {
    final now = DateTime.now();
    String label;
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      label = 'Aujourd\'hui';
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      label = 'Hier';
    } else {
      label = DateFormat('d MMMM yyyy', 'fr').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message msg, bool isMine) {
    final isGroup = widget.conversation.isGroup;
    final showSenderName = isGroup && !isMine;
    final cs = Theme.of(context).colorScheme;
    final bubble = Theme.of(context).extension<ChatMeBubbleTheme>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              backgroundImage: (msg.sender?.avatarUrl != null && msg.sender!.avatarUrl!.isNotEmpty) ? NetworkImage(msg.sender!.avatarUrl!) : null,
              onBackgroundImageError: (_, __) {},
              child: (msg.sender?.avatarUrl == null || msg.sender!.avatarUrl!.isEmpty)
                  ? Text(
                      msg.sender?.initials ?? '?',
                      style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderName)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(
                      msg.sender?.displayNameOrPhone ?? 'Inconnu',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? bubble.sent : bubble.received,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: GestureDetector(
                    onLongPress: () => _showMessageOptions(msg),
                    child: _buildMessageContent(context, msg, isMine),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: isMine ? 0 : 12, right: isMine ? 0 : 12, top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${msg.timeAgo}${msg.isEdited ? ' (modifié)' : ''}',
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.status == MessageStatus.read ? Icons.done_all : Icons.done,
                          size: 14,
                          color: msg.status == MessageStatus.read ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text(
                auth.currentUser.value?.initials ?? '?',
                style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Message msg, bool isMine) {
    final cs = Theme.of(context).colorScheme;
    final bubble = Theme.of(context).extension<ChatMeBubbleTheme>()!;
    final textColor = isMine ? bubble.sentText : bubble.receivedText;

    switch (msg.type) {
      case MessageType.image:
        return msg.mediaUrl != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: msg.mediaUrl!.startsWith('http')
                        ? Image.network(
                            msg.mediaUrl!,
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : Container(
                                    width: 200,
                                    height: 150,
                                    color: cs.surfaceContainerHighest,
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                            errorBuilder: (_, __, ___) => Container(
                              width: 200,
                              height: 150,
                              color: cs.surfaceContainerHighest,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: cs.onSurfaceVariant, size: 32),
                                  const SizedBox(height: 6),
                                  Text('Image non disponible', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          )
                        : Image.file(
                            File(msg.mediaUrl!),
                            width: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 200,
                              height: 150,
                              color: cs.surfaceContainerHighest,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: cs.onSurfaceVariant, size: 32),
                                  const SizedBox(height: 6),
                                  Text('Image non disponible', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                  ),
                  if (msg.content != null && msg.content!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(FormatUtils.sanitize(msg.content), style: TextStyle(color: textColor)),
                    ),
                ],
              )
            : const Text('Image non disponible');

      case MessageType.audio:
        final playing = _playingMessageId == msg.id && _isPlaying;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                playing ? Icons.stop_circle : Icons.play_circle_outline,
                size: 32,
                color: cs.primary,
              ),
              onPressed: () => _togglePlay(msg),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Text('Message vocal', style: TextStyle(color: textColor)),
          ],
        );

      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 150,
                    color: cs.surfaceContainerHighest,
                    child: msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty
                        ? (msg.mediaUrl!.startsWith('http')
                            ? Image.network(msg.mediaUrl!, width: 200, height: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.videocam, size: 48, color: Colors.grey))
                            : const Icon(Icons.videocam, size: 48, color: Colors.grey))
                        : const Icon(Icons.videocam, size: 48, color: Colors.grey),
                  ),
                  const Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
                ],
              ),
            ),
            if (msg.content != null && msg.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(FormatUtils.sanitize(msg.content), style: TextStyle(color: textColor)),
              ),
            if (msg.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Vidéo • ${_formatFileSize(msg.mediaSizeBytes ?? 0)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
          ],
        );

      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 32, color: isMine ? cs.onPrimary : cs.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(FormatUtils.sanitize(msg.content) != '' ? FormatUtils.sanitize(msg.content) : 'Fichier', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                if (msg.mediaSizeBytes != null)
                  Text(_formatFileSize(msg.mediaSizeBytes!), style: TextStyle(fontSize: 11, color: isMine ? cs.onPrimary.withValues(alpha: 0.7) : cs.onSurfaceVariant)),
              ],
            ),
          ],
        );

      default:
        return Text(
          FormatUtils.sanitize(msg.content),
          style: TextStyle(color: textColor, fontSize: _msgFontSize(), height: 1.35, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        );
    }
  }

  Widget _buildInputBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.red),
            const SizedBox(width: 10),
            Text(_formatDuration(_recordDuration),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Text('Enregistrement...'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _cancelRecording,
            ),
            IconButton(
              icon: Icon(Icons.send, color: cs.primary),
              onPressed: _stopAndSend,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.mic_none, color: cs.primary),
            onPressed: _startRecording,
          ),
          IconButton(
            icon: Icon(Icons.attach_file, color: cs.primary),
            onPressed: _pickAndSendFile,
          ),
          IconButton(
            icon: Icon(Icons.camera_alt_outlined, color: cs.primary),
            onPressed: () => _pickAndSendImage(ImageSource.camera),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onChanged: (v) => messaging.sendTyping(widget.conversation.id, v.trim().isNotEmpty),
              onSubmitted: (_) {
                messaging.sendTyping(widget.conversation.id, false);
                _sendMessage();
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) => FormatUtils.formatDuration(d);

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'inconnu';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return DateFormat('d MMM', 'fr').format(lastSeen);
  }

  double _msgFontSize() => 15;

  String _formatFileSize(int bytes) => FormatUtils.formatFileSize(bytes);
}
