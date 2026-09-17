import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:chatme/services/wallet_service.dart';
import 'package:chatme/core/services/notification_service.dart';
import 'package:chatme/models/conversation.dart';
import 'package:chatme/models/message.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/utils/format_utils.dart';
import 'package:chatme/core/utils/string_extension.dart';
import 'call_screen.dart';
import 'package:chatme/widgets/media_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'conversation_info_screen.dart';

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
  double _audioSpeed = 1.0; // vitesse de lecture: 1x / 1.5x / 2x
  Timer? _recordTimer;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // WhatsApp-like swipe-to-reply state
  Message? _replyingTo;

  String get currentUserId => auth.currentUser.value?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    messaging.subscribeToConversationRoom(widget.conversation.id);
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
    messaging.unsubscribeFromConversationRoom(widget.conversation.id);
    _messageController.dispose();
    _searchCtrl.dispose();
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

    final replyingMsg = _replyingTo;
    setState(() => _replyingTo = null);
    _messageController.clear();
    messaging.sendTyping(widget.conversation.id, false);
    await messaging.sendMessage(
      conversationId: widget.conversation.id,
      content: text,
      replyToId: replyingMsg?.id,
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
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard, color: Color(0xFFD32F2F)),
                ),
                title: const Text('Enveloppe Cadeau (FCFA)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Envoyer de l\'argent façon WeChat avec un vœu 🧧'),
                onTap: () {
                  Get.back();
                  _showSendRedPacketDialog();
                },
              ),
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

  void _showSendRedPacketDialog() {
    final amountCtrl = TextEditingController(text: '1000');
    final greetingCtrl = TextEditingController(text: 'Meilleurs vœux ! 🧧');
    final selectedAmount = 1000.obs;
    final isSending = false.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard, color: Color(0xFFD32F2F), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enveloppe Cadeau (FCFA)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Envoyez de l\'argent façon WeChat avec un vœu 🧧',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Solde disponible
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Solde portefeuille disponible :', style: TextStyle(fontSize: 12.5)),
                          Text(
                            '${FormatUtils.fmtFcfa(WalletService.to.balance.value)} FCFA',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: WalletService.to.balance.value > 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                const Text('Montant de l\'enveloppe (FCFA)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [500, 1000, 2000, 5000, 10000].map((amt) {
                    return Obx(() {
                      final isSel = selectedAmount.value == amt;
                      return ChoiceChip(
                        label: Text('${FormatUtils.fmtFcfa(amt)} F'),
                        selected: isSel,
                        selectedColor: const Color(0xFFD32F2F),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (sel) {
                          if (sel) {
                            selectedAmount.value = amt;
                            amountCtrl.text = amt.toString();
                          }
                        },
                      );
                    });
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Ou montant personnalisé',
                    suffixText: 'FCFA',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) selectedAmount.value = parsed;
                  },
                ),
                const SizedBox(height: 14),
                const Text('Vœu ou message personnalisé',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: greetingCtrl,
                  maxLength: 60,
                  decoration: InputDecoration(
                    hintText: 'Ex: Meilleurs vœux ! 🧧, Félicitations ! 🎉',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Obx(() => SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: isSending.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white),
                        label: Text(
                          isSending.value
                              ? 'Envoi en cours...'
                              : 'Envoyer l\'Enveloppe (${FormatUtils.fmtFcfa(selectedAmount.value)} FCFA)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isSending.value
                            ? null
                            : () async {
                                final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                                if (amt <= 0) {
                                  Get.snackbar('Montant invalide', 'Veuillez saisir un montant positif',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }
                                if (amt > WalletService.to.balance.value) {
                                  Get.snackbar(
                                    'Solde insuffisant',
                                    'Votre solde (${FormatUtils.fmtFcfa(WalletService.to.balance.value)} FCFA) est insuffisant. Veuillez recharger votre portefeuille.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.white,
                                    colorText: Colors.black,
                                  );
                                  return;
                                }

                                isSending.value = true;
                                final greeting = greetingCtrl.text.trim().isNotEmpty
                                    ? greetingCtrl.text.trim()
                                    : 'Meilleurs vœux ! 🧧';
                                final senderName = auth.currentUser.value?.displayNameOrPhone ?? 'Un contact';

                                // Débit atomique du portefeuille expéditeur
                                final debited = await WalletService.to.payAsync(
                                  amt,
                                  'Enveloppe Cadeau ChatMe: $greeting',
                                );

                                if (!debited) {
                                  isSending.value = false;
                                  Get.snackbar('Erreur', 'Impossible de débiter le portefeuille',
                                      snackPosition: SnackPosition.BOTTOM);
                                  return;
                                }

                                final packetPayload = jsonEncode({
                                  'id': 'gift_${DateTime.now().millisecondsSinceEpoch}',
                                  'amount': amt,
                                  'greeting': greeting,
                                  'sender_id': currentUserId,
                                  'sender_name': senderName,
                                  'claimed_by': <String>[],
                                });

                                await messaging.sendMessage(
                                  conversationId: widget.conversation.id,
                                  content: '[CHATME_GIFT]:$packetPayload',
                                  type: MessageType.text,
                                );

                                isSending.value = false;
                                Get.back();
                                HapticFeedback.lightImpact();
                                _scrollToBottom();
                                Get.snackbar(
                                  'Enveloppe envoyée ! 🧧',
                                  '${FormatUtils.fmtFcfa(amt)} FCFA envoyés dans la discussion.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFFD32F2F),
                                  colorText: Colors.white,
                                );
                              },
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildRedPacketCard(BuildContext context, Message msg, bool isMine) {
    Map<String, dynamic>? giftData;
    try {
      final raw = msg.content!.substring('[CHATME_GIFT]:'.length);
      giftData = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}

    final amount = (giftData?['amount'] as num?)?.toInt() ?? 0;
    final greeting = giftData?['greeting'] as String? ?? 'Meilleurs vœux ! 🧧';
    final claimedBy = List<String>.from(giftData?['claimed_by'] ?? []);
    final hasClaimed = claimedBy.contains(currentUserId);
    final isSender = msg.senderId == currentUserId;

    return GestureDetector(
      onTap: () => _handleRedPacketTap(msg, giftData, isSender, hasClaimed, amount, greeting),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasClaimed || (isSender && claimedBy.isNotEmpty)
                ? [const Color(0xFFE57373), const Color(0xFFC62828)]
                : [const Color(0xFFE53935), const Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9A825),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFEE58), width: 2),
                    ),
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${FormatUtils.fmtFcfa(amount)} FCFA',
                          style: const TextStyle(
                            color: Color(0xFFFFE082),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (hasClaimed) ...[
                    const Icon(Icons.check_circle_outline, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    const Text('Enveloppe reçue ✓',
                        style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
                  ] else if (isSender) ...[
                    const Icon(Icons.send_outlined, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      claimedBy.isNotEmpty ? 'Ouverte (${claimedBy.length})' : 'En attente',
                      style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ] else ...[
                    const Icon(Icons.touch_app, size: 12, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 4),
                    const Text('Toucher pour ouvrir 🎁',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFFD54F))),
                  ],
                  const Spacer(),
                  const Text('ChatMe 🧧',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRedPacketTap(
    Message msg,
    Map<String, dynamic>? data,
    bool isSender,
    bool hasClaimed,
    int amount,
    String greeting,
  ) {
    if (data == null) return;
    HapticFeedback.selectionClick();

    if (isSender) {
      final claimedBy = List<String>.from(data['claimed_by'] ?? []);
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enveloppe Cadeau Envoyée 🧧',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${FormatUtils.fmtFcfa(amount)} FCFA',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '« $greeting »',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                claimedBy.isNotEmpty
                    ? '✓ Cette enveloppe a été ouverte.'
                    : '⏳ En attente d\'ouverture par le destinataire.',
                style: TextStyle(
                  fontSize: 13,
                  color: claimedBy.isNotEmpty ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (hasClaimed) {
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF388E3C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enveloppe déjà récupérée !',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '+${FormatUtils.fmtFcfa(amount)} FCFA',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF388E3C)),
              ),
              const SizedBox(height: 8),
              Text(
                'Cette somme a déjà été créditée sur votre portefeuille ChatMe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Recipient not yet claimed -> WeChat Festive Dialog
    _showWeChatOpenDialog(msg, data, amount, greeting);
  }

  void _showWeChatOpenDialog(
    Message msg,
    Map<String, dynamic> data,
    int amount,
    String greeting,
  ) {
    final senderName = (data['sender_name'] as String?) ?? (msg.sender?.displayNameOrPhone ?? 'Un contact');
    final isOpening = false.obs;
    final isOpened = false.obs;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Obx(() {
          if (isOpened.value) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Félicitations ! 🎉',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${FormatUtils.fmtFcfa(amount)} FCFA',
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La somme a été créditée directement sur votre Portefeuille ChatMe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD54F),
                        foregroundColor: const Color(0xFFB71C1C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('Super, merci !', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 24, bottom: 16, left: 20, right: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.elliptical(180, 40)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFFFD54F),
                        child: Text(
                          senderName.isNotEmpty ? senderName.initials : '🎁',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFB71C1C)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enveloppe de $senderName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '« $greeting »',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFE082), fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: isOpening.value
                      ? null
                      : () async {
                          isOpening.value = true;
                          HapticFeedback.heavyImpact();

                          // Crédit portefeuille destinataire
                          await WalletService.to.deposit(
                            amount,
                            label: 'Enveloppe Cadeau de $senderName',
                          );

                          // Mise à jour de la liste claimed_by
                          final claimedList = List<String>.from(data['claimed_by'] ?? []);
                          if (!claimedList.contains(currentUserId)) {
                            claimedList.add(currentUserId);
                          }
                          data['claimed_by'] = claimedList;
                          final updatedContent = '[CHATME_GIFT]:${jsonEncode(data)}';

                          await messaging.editMessage(
                            conversationId: widget.conversation.id,
                            messageId: msg.id,
                            newContent: updatedContent,
                          );

                          isOpening.value = false;
                          isOpened.value = true;
                        },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFEE58), Color(0xFFFDD835), Color(0xFFF57F17)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isOpening.value
                          ? const CircularProgressIndicator(color: Color(0xFFB71C1C), strokeWidth: 3)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '開',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF8D1414),
                                  ),
                                ),
                                Text(
                                  'OUVRIR',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF8D1414),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ChatMe Pay • Lucky Money',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }),
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
      await _audioPlayer.setPlaybackRate(_audioSpeed);
      setState(() {
        _isPlaying = true;
        _playingMessageId = msg.id;
      });
    } catch (e) {
      Get.snackbar('Erreur', 'Lecture impossible', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _setAudioSpeed(double speed) async {
    setState(() => _audioSpeed = speed);
    if (_isPlaying) {
      await _audioPlayer.setPlaybackRate(speed);
    }
  }

  bool _canEdit(Message msg) =>
      msg.senderId == currentUserId &&
      msg.type == MessageType.text &&
      DateTime.now().difference(msg.createdAt).inMinutes <= 15;

  void _showMessageOptions(Message msg) {
    HapticFeedback.mediumImpact();
    final cs = Theme.of(context).colorScheme;
    final quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '👏'];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre de réactions rapides style WhatsApp / Instagram
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: quickEmojis.map((emoji) {
                      final iReacted = msg.reactions?[emoji]?.contains(currentUserId) ?? false;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Get.back();
                          messaging.toggleReaction(
                            conversationId: widget.conversation.id,
                            messageId: msg.id,
                            emoji: emoji,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iReacted ? cs.primary.withValues(alpha: 0.2) : Colors.transparent,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Répondre'),
                onTap: () {
                  Get.back();
                  HapticFeedback.lightImpact();
                  setState(() => _replyingTo = msg);
                  _focusNode.requestFocus();
                },
              ),
              if (msg.content != null && msg.content!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Copier'),
                  onTap: () {
                    Get.back();
                    Clipboard.setData(ClipboardData(text: msg.content!));
                    Get.snackbar('Copié', 'Message copié dans le presse-papiers',
                        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                  },
                ),
              if (_canEdit(msg))
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Modifier'),
                  onTap: () {
                    Get.back();
                    _editMessageDialog(msg);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer pour moi'),
                onTap: () async {
                  Get.back();
                  await messaging.deleteMessageForMe(widget.conversation.id, msg.id);
                  Get.snackbar('Supprimé', 'Message supprimé pour vous',
                      snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                },
              ),
              if (msg.senderId == currentUserId)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('Supprimer pour tout le monde', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Get.back();
                    messaging.deleteMessageForEveryone(widget.conversation.id, msg.id);
                  },
                ),
            ],
          ),
        ),
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
      appBar: _isSearching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchCtrl.clear();
                }),
              ),
              title: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Rechercher dans la discussion...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              actions: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }),
                  ),
              ],
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : AppBar(
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.to(() => ConversationInfoScreen(conversation: widget.conversation)),
                child: Row(
                  children: [
                    Hero(
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
                          child: widget.conversation.isGroup
                              ? const Icon(Icons.groups, size: 20, color: Colors.white)
                              : Text(
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
                              return const _TypingDotsIndicator(color: Colors.greenAccent);
                            }
                            if (widget.conversation.isGroup) {
                              return Text(
                                '${widget.conversation.participants.length} participants',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              );
                            }
                            if (otherParticipant.profile?.isOnline == true) {
                              return const Text('En ligne',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.green));
                            }
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Text(
                              'Dernière vue: ${_formatLastSeen(otherParticipant.profile?.lastSeen)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w700),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _isSearching = true),
                ),
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
                      Get.to(() => ConversationInfoScreen(conversation: widget.conversation));
                    } else if (v == 'rechercher') {
                      setState(() => _isSearching = true);
                    } else if (v == 'effacer') {
                      final ok = await Get.dialog<bool>(AlertDialog(
                        title: const Text('Effacer la discussion'),
                        content: const Text('Supprimer tous les messages pour vous ? (comme WhatsApp) — local uniquement'),
                        actions: [
                          TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
                          TextButton(onPressed: () => Get.back(result: true), child: const Text('Effacer', style: TextStyle(color: Colors.red))),
                        ],
                      ));
                      if (ok == true) {
                        await messaging.clearConversationForMe(widget.conversation.id);
                        Get.snackbar('Discussion effacée', 'Messages supprimés pour vous', snackPosition: SnackPosition.BOTTOM);
                      }
                    } else if (v == 'bloquer') {
                      final otherId = otherParticipant.userId;
                      final isBlocked = await messaging.isBlocked(otherId);
                      if (isBlocked) {
                        final ok = await Get.dialog<bool>(AlertDialog(
                          title: const Text('Débloquer ?'),
                          content: Text('Débloquer ${widget.conversation.getTitle(currentUserId)} ?'),
                          actions: [
                            TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Get.back(result: true), child: const Text('Débloquer')),
                          ],
                        ));
                        if (ok == true) {
                          await messaging.unblockUser(otherId);
                          Get.snackbar('Débloqué', 'Utilisateur débloqué', snackPosition: SnackPosition.BOTTOM);
                        }
                      } else {
                        final ok = await Get.dialog<bool>(AlertDialog(
                          title: const Text('Bloquer ce contact ?'),
                          content: const Text('Vous ne recevrez plus ses messages (comme WhatsApp/WeChat).'),
                          actions: [
                            TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
                            TextButton(onPressed: () => Get.back(result: true), child: const Text('Bloquer', style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if (ok == true) {
                          await messaging.blockUser(otherId);
                          Get.snackbar('Bloqué', 'Utilisateur bloqué', snackPosition: SnackPosition.BOTTOM);
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'profil',
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 10),
                        Text(widget.conversation.isGroup ? 'Infos du groupe' : 'Infos du contact'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'rechercher',
                      child: Row(children: [Icon(Icons.search, size: 18), SizedBox(width: 10), Text('Rechercher')]),
                    ),
                    const PopupMenuItem(
                      value: 'effacer',
                      child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text('Effacer discussion', style: TextStyle(color: Colors.red))]),
                    ),
                    if (!widget.conversation.isGroup)
                      const PopupMenuItem(
                        value: 'bloquer',
                        child: Row(children: [Icon(Icons.block, size: 18), SizedBox(width: 10), Text('Bloquer / Débloquer')]),
                      ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final allMessages = messaging.getMessages(widget.conversation.id);
              // Auto-mark comme lu dès que les messages sont visibles
              if (allMessages.isNotEmpty) {
                final last = allMessages.last;
                if (last.senderId != currentUserId && last.status != MessageStatus.read) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleMessagesAsRead());
                }
              }

              if (allMessages.isEmpty && messaging.isLoadingConversations.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = _searchQuery.isEmpty
                  ? allMessages
                  : allMessages.where((m) => (m.content ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();

              if (messages.isEmpty) {
                if (_searchQuery.isNotEmpty) {
                  return Center(
                    child: Text(
                      'Aucun message ne correspond à "$_searchQuery"',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }
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

  void _scrollToMessage(String messageId) {
    final messages = messaging.getMessages(widget.conversation.id);
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1 && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final target = (idx / messages.length) * maxScroll;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildMessageBubble(BuildContext context, Message msg, bool isMine) {
    final cs = Theme.of(context).colorScheme;

    if (msg.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              FormatUtils.sanitize(msg.content ?? ''),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
    }

    final isGroup = widget.conversation.isGroup;
    final showSenderName = isGroup && !isMine;
    final bubble = Theme.of(context).extension<ChatMeBubbleTheme>()!;

    // Résolution du message parent pour citation
    Message? parentMsg = msg.replyTo;
    if (parentMsg == null && msg.replyToId != null) {
      parentMsg = messaging.getMessages(widget.conversation.id).firstWhereOrNull((m) => m.id == msg.replyToId);
    }

    return Dismissible(
      key: Key('msg_${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        setState(() => _replyingTo = msg);
        _focusNode.requestFocus();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.reply, color: cs.primary, size: 20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                backgroundImage: (msg.sender?.avatarUrl != null && msg.sender!.avatarUrl!.isNotEmpty)
                    ? NetworkImage(msg.sender!.avatarUrl!)
                    : null,
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
                        style: const TextStyle(fontSize: 11, color: ChatMeColors.violet, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Builder(builder: (context) {
                    final isGift = msg.content != null && msg.content!.startsWith('[CHATME_GIFT]:');
                    return Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      padding: isGift ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isGift ? Colors.transparent : (isMine ? bubble.sent : bubble.received),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMine ? 16 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 16),
                        ),
                      ),
                      child: GestureDetector(
                      onLongPress: () => _showMessageOptions(msg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (parentMsg != null)
                            GestureDetector(
                              onTap: () => _scrollToMessage(parentMsg!.id),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isMine ? Colors.black : cs.primary).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: isMine ? Colors.white : cs.primary,
                                      width: 3.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      parentMsg.senderId == currentUserId
                                          ? 'Vous'
                                          : (parentMsg.sender?.displayNameOrPhone ?? 'Contact'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMine ? Colors.white : cs.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      parentMsg.displayContent,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isMine ? Colors.white70 : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          _buildMessageContent(context, msg, isMine),
                        ],
                      ),
                    ),
                  );
                }),
                  if (msg.reactions != null && msg.reactions!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        left: isMine ? 0 : 4,
                        right: isMine ? 4 : 0,
                        top: 2,
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: msg.reactions!.entries.map((entry) {
                          final emoji = entry.key;
                          final userList = entry.value;
                          final iReacted = userList.contains(currentUserId);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              messaging.toggleReaction(
                                conversationId: widget.conversation.id,
                                messageId: msg.id,
                                emoji: emoji,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: iReacted
                                    ? cs.primary.withValues(alpha: 0.18)
                                    : cs.surfaceContainerHighest.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: iReacted ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 11)),
                                  if (userList.length > 1) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '${userList.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: iReacted ? cs.primary : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
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
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Message msg, bool isMine) {
    final cs = Theme.of(context).colorScheme;
    final bubble = Theme.of(context).extension<ChatMeBubbleTheme>()!;
    final textColor = isMine ? bubble.sentText : bubble.receivedText;

    if (msg.content != null && msg.content!.startsWith('[CHATME_GIFT]:')) {
      return _buildRedPacketCard(context, msg, isMine);
    }

    switch (msg.type) {
      case MessageType.image:
        return msg.mediaUrl != null
            ? GestureDetector(
                onTap: () {
                  if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
                    ImageViewerScreen.show(
                      context,
                      imageUrl: msg.mediaUrl!,
                      title: msg.sender?.displayNameOrPhone ?? 'Photo',
                      subtitle: msg.timeAgo,
                    );
                  }
                },
                child: Column(
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
                ),
              )
            : const Text('Image non disponible');

      case MessageType.audio:
        final playing = _playingMessageId == msg.id && _isPlaying;
        // Waveform: barres pseudo-aléatoires seeded par l'id du message
        final seed = msg.id.hashCode.abs();
        final rng = Random(seed);
        final barCount = 28;
        final barHeights = List.generate(barCount, (_) => 4.0 + rng.nextDouble() * 18.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _togglePlay(msg),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton play/stop
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: isMine ? 0.25 : 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 24,
                        color: isMine ? cs.onPrimary : cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Waveform visuelle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 28,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(barCount, (i) {
                              final barColor = playing
                                  ? (isMine ? cs.onPrimary : cs.primary)
                                  : (isMine
                                      ? cs.onPrimary.withValues(alpha: 0.55)
                                      : cs.onSurfaceVariant.withValues(alpha: 0.7));
                              return AnimatedContainer(
                                duration: playing
                                    ? Duration(milliseconds: 200 + (i * 30) % 300)
                                    : Duration.zero,
                                curve: Curves.easeInOut,
                                width: 2.5,
                                height: playing
                                    ? 4.0 + rng.nextDouble() * 18.0
                                    : barHeights[i],
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          playing ? 'Lecture en cours...' : 'Message vocal',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMine
                                ? cs.onPrimary.withValues(alpha: 0.75)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Boutons de vitesse 1x / 1.5x / 2x
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [1.0, 1.5, 2.0].map((speed) {
                  final isSelected = _audioSpeed == speed;
                  return GestureDetector(
                    onTap: () => _setAudioSpeed(speed),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isMine ? cs.onPrimary.withValues(alpha: 0.25) : cs.primary.withValues(alpha: 0.15))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? (isMine ? cs.onPrimary.withValues(alpha: 0.5) : cs.primary.withValues(alpha: 0.4))
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        speed == 1.0 ? '1×' : speed == 1.5 ? '1.5×' : '2×',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isMine
                              ? cs.onPrimary.withValues(alpha: isSelected ? 1.0 : 0.6)
                              : (isSelected ? cs.primary : cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );

      case MessageType.video:
        return GestureDetector(
          onTap: () {
            if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
              VideoViewerScreen.show(
                context,
                videoUrl: msg.mediaUrl!,
                title: msg.content != null && msg.content!.isNotEmpty ? msg.content! : 'Vidéo',
              );
            }
          },
          child: Column(
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
                    ),
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
          ),
        );

      case MessageType.file:
        return GestureDetector(
          onTap: () async {
            if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
              final uri = Uri.tryParse(msg.mediaUrl!);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                Get.snackbar('Fichier', 'Impossible d\'ouvrir le fichier', snackPosition: SnackPosition.BOTTOM);
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, size: 32, color: isMine ? cs.onPrimary : cs.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FormatUtils.sanitize(msg.content) != '' ? FormatUtils.sanitize(msg.content) : 'Fichier',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                  if (msg.mediaSizeBytes != null)
                    Text(_formatFileSize(msg.mediaSizeBytes!), style: TextStyle(fontSize: 11, color: isMine ? cs.onPrimary.withValues(alpha: 0.7) : cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
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
    final isGroupAdmin = widget.conversation.participants.any((p) => p.userId == currentUserId && p.role == 'admin') ||
        widget.conversation.createdBy == currentUserId;
    if (widget.conversation.isGroup && widget.conversation.onlyAdminsCanSend && !isGroupAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        child: const Text(
          'Seuls les administrateurs peuvent envoyer des messages.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
              border: Border(
                left: BorderSide(color: cs.primary, width: 4),
                top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _replyingTo!.senderId == currentUserId
                            ? 'Réponse à vous-même'
                            : 'Réponse à ${_replyingTo!.sender?.displayNameOrPhone ?? 'ce message'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyingTo!.displayContent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyingTo = null),
                ),
              ],
            ),
          ),
        Container(
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
    ),
  ],
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

/// Indicateur "est en train d'écrire..." animé — 3 points rebondissants style WhatsApp.
class _TypingDotsIndicator extends StatefulWidget {
  final Color color;
  const _TypingDotsIndicator({this.color = Colors.green});

  @override
  State<_TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..repeat(reverse: true, period: const Duration(milliseconds: 800));
    });
    _animations = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: -5).animate(
        CurvedAnimation(
          parent: _controllers[i],
          curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
        ),
      );
    });
    // Décalage entre chaque point
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controllers[1].forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controllers[2].forward();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'est en train d\'écrire',
          style: TextStyle(
            fontSize: 11,
            color: widget.color,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 3),
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
