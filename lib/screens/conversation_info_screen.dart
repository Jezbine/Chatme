import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/chatme_theme.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/messaging_service.dart';
import '../services/contacts_service.dart';
import '../widgets/media_viewer.dart';
import 'avatar_viewer_screen.dart';
import 'call_screen.dart';
import 'chat_screen.dart';

class ConversationInfoScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationInfoScreen({required this.conversation, super.key});

  @override
  State<ConversationInfoScreen> createState() => _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends State<ConversationInfoScreen> {
  final messaging = MessagingService.to;
  final auth = AuthService.to;

  late Conversation _conv;
  bool _isMuted = false;
  bool _isBlocked = false;

  String get currentUserId => auth.currentUser.value?.id ?? '';
  bool get isAdmin =>
      _conv.participants.any((p) => p.userId == currentUserId && p.role == 'admin') ||
      _conv.createdBy == currentUserId;
  bool get canEditInfo => !(_conv.onlyAdminsCanEditInfo) || isAdmin;

  @override
  void initState() {
    super.initState();
    _conv = widget.conversation;
    final myParticipant = _conv.participants.firstWhereOrNull((p) => p.userId == currentUserId);
    _isMuted = myParticipant?.muted ?? false;
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    if (_conv.isDirect) {
      final other = _conv.getOtherParticipant(currentUserId);
      if (other != null) {
        final blocked = await messaging.isBlocked(other.userId);
        if (mounted) setState(() => _isBlocked = blocked);
      }
    }
  }

  Future<void> _toggleMute() async {
    final nextState = !_isMuted;
    final ok = await messaging.toggleMuteConversation(_conv.id, nextState);
    if (ok && mounted) {
      setState(() => _isMuted = nextState);
      Get.snackbar(
        'Notifications',
        nextState ? 'Conversation mise en sourdine' : 'Notifications rétablies',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _editGroupNameDialog() {
    if (!canEditInfo) {
      Get.snackbar('Accès restreint', 'Seuls les administrateurs peuvent modifier le sujet du groupe.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final ctrl = TextEditingController(text: _conv.name ?? '');
    Get.dialog(
      AlertDialog(
        title: const Text('Modifier le nom du groupe'),
        content: TextField(
          controller: ctrl,
          maxLength: 50,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom du groupe'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != _conv.name) {
                Get.back();
                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                final ok = await messaging.updateGroupInfo(conversationId: _conv.id, name: newName);
                if (Get.isDialogOpen == true) Get.back();
                if (ok && mounted) {
                  setState(() => _conv = _conv.copyWith(name: newName));
                  Get.snackbar('Succès', 'Nom du groupe mis à jour', snackPosition: SnackPosition.BOTTOM);
                }
              } else {
                Get.back();
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _editGroupDescriptionDialog() {
    if (!canEditInfo) {
      Get.snackbar('Accès restreint', 'Seuls les administrateurs peuvent modifier la description du groupe.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final ctrl = TextEditingController(text: _conv.description ?? '');
    Get.dialog(
      AlertDialog(
        title: const Text('Description du groupe'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 250,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ajoutez une description pour présenter ce groupe...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              final newDesc = ctrl.text.trim();
              Get.back();
              Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
              final ok = await messaging.updateGroupInfo(conversationId: _conv.id, description: newDesc);
              if (Get.isDialogOpen == true) Get.back();
              if (ok && mounted) {
                setState(() => _conv = _conv.copyWith(description: newDesc));
                Get.snackbar('Succès', 'Description mise à jour', snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showInviteLinkSheet() {
    final inviteLink = 'https://chatme.app/join/${_conv.id}';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inviter via un lien', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Toute personne ayant ChatME peut suivre ce lien pour rejoindre ce groupe.',
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: ChatMeColors.violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      inviteLink,
                      style: const TextStyle(fontSize: 13, color: ChatMeColors.violet, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy, color: ChatMeColors.violet),
              title: const Text('Copier le lien'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteLink));
                Get.back();
                Get.snackbar('Lien copié', 'Le lien d\'invitation a été copié dans le presse-papiers',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code, color: ChatMeColors.cDocuments),
              title: const Text('Code QR du groupe'),
              onTap: () {
                Get.back();
                _showGroupQrDialog(inviteLink);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupQrDialog(String link) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _conv.getTitle(currentUserId),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text('Scannez pour rejoindre le groupe', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: QrImageView(
                  data: link,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: ChatMeColors.violet),
                child: const Text('Fermer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupSettingsSheet() {
    bool onlySend = _conv.onlyAdminsCanSend;
    bool onlyEdit = _conv.onlyAdminsCanEditInfo;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paramètres du groupe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Modifier les infos du groupe'),
                  subtitle: Text(
                    onlyEdit ? 'Uniquement les admins' : 'Tous les participants',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: onlyEdit,
                  activeTrackColor: ChatMeColors.violet,
                  onChanged: (v) => setSheetState(() => onlyEdit = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Envoyer des messages'),
                  subtitle: Text(
                    onlySend ? 'Uniquement les admins (mode annonce)' : 'Tous les participants',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: onlySend,
                  activeTrackColor: ChatMeColors.violet,
                  onChanged: (v) => setSheetState(() => onlySend = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                      final ok = await messaging.updateGroupSettings(
                        conversationId: _conv.id,
                        onlyAdminsCanSend: onlySend,
                        onlyAdminsCanEditInfo: onlyEdit,
                      );
                      if (Get.isDialogOpen == true) Get.back();
                      if (ok && mounted) {
                        setState(() {
                          _conv = _conv.copyWith(
                            onlyAdminsCanSend: onlySend,
                            onlyAdminsCanEditInfo: onlyEdit,
                          );
                        });
                        Get.snackbar('Paramètres enregistrés', 'Les autorisations du groupe ont été mises à jour',
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: ChatMeColors.violet),
                    child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showParticipantOptionsSheet(ConversationParticipant p) {
    final isMe = p.userId == currentUserId;
    final name = isMe ? 'Vous' : (p.profile?.displayNameOrPhone ?? 'Membre');
    final isPAdmin = p.role == 'admin' || p.userId == _conv.createdBy;
    final isCreator = p.userId == _conv.createdBy;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ChatMeColors.violet,
                      backgroundImage: (p.profile?.avatarUrl != null && p.profile!.avatarUrl!.isNotEmpty)
                          ? NetworkImage(p.profile!.avatarUrl!)
                          : null,
                      child: (p.profile?.avatarUrl == null || p.profile!.avatarUrl!.isEmpty)
                          ? Text(p.profile?.initials ?? '?', style: const TextStyle(color: Colors.white))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (p.profile?.phoneNumber != null && p.profile!.phoneNumber.isNotEmpty)
                          Text(p.profile!.phoneNumber, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (!isMe)
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: ChatMeColors.violet),
                  title: Text('Envoyer un message à $name'),
                  onTap: () async {
                    Get.back();
                    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                    final directId = await messaging.createDirectConversation(p.userId);
                    if (Get.isDialogOpen == true) Get.back();
                    if (directId != null) {
                      final now = DateTime.now();
                      final directConv = Conversation(
                        id: directId,
                        type: ConversationType.direct,
                        createdBy: currentUserId,
                        createdAt: now,
                        updatedAt: now,
                        participants: [
                          ConversationParticipant(conversationId: directId, userId: currentUserId, role: 'member', joinedAt: now),
                          ConversationParticipant(
                            conversationId: directId,
                            userId: p.userId,
                            role: 'member',
                            joinedAt: now,
                            profile: p.profile ?? UserProfile(id: p.userId, phoneNumber: '', displayName: name),
                          ),
                        ],
                      );
                      Get.to(() => ChatScreen(conversation: directConv));
                    }
                  },
                ),
              if (isAdmin && !isMe) ...[
                if (!isPAdmin)
                  ListTile(
                    leading: const Icon(Icons.security, color: ChatMeColors.cProfil),
                    title: const Text('Désigner comme administrateur du groupe'),
                    onTap: () async {
                      Get.back();
                      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                      final ok = await messaging.setParticipantRole(
                        conversationId: _conv.id,
                        userId: p.userId,
                        role: 'admin',
                        memberName: name,
                      );
                      if (Get.isDialogOpen == true) Get.back();
                      if (ok) {
                        final updated = messaging.conversations.firstWhereOrNull((c) => c.id == _conv.id);
                        if (updated != null && mounted) setState(() => _conv = updated);
                        Get.snackbar('Rôle mis à jour', '$name est désormais administrateur', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                  )
                else if (!isCreator)
                  ListTile(
                    leading: const Icon(Icons.remove_moderator_outlined, color: Colors.orange),
                    title: const Text('Rétrograder comme membre'),
                    onTap: () async {
                      Get.back();
                      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                      final ok = await messaging.setParticipantRole(
                        conversationId: _conv.id,
                        userId: p.userId,
                        role: 'member',
                        memberName: name,
                      );
                      if (Get.isDialogOpen == true) Get.back();
                      if (ok) {
                        final updated = messaging.conversations.firstWhereOrNull((c) => c.id == _conv.id);
                        if (updated != null && mounted) setState(() => _conv = updated);
                        Get.snackbar('Rôle mis à jour', '$name n\'est plus administrateur', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                  ),
                if (!isCreator)
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    title: Text('Retirer $name du groupe', style: const TextStyle(color: Colors.red)),
                    onTap: () {
                      Get.back();
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Retirer le participant ?'),
                          content: Text('Voulez-vous retirer $name de ce groupe ?'),
                          actions: [
                            TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
                            TextButton(
                              onPressed: () async {
                                Get.back();
                                final ok = await messaging.removeParticipantFromGroup(_conv.id, p.userId, memberName: name);
                                if (ok) {
                                  final updated = messaging.conversations.firstWhereOrNull((c) => c.id == _conv.id);
                                  if (updated != null && mounted) setState(() => _conv = updated);
                                  Get.snackbar('Participant retiré', '$name a été retiré du groupe', snackPosition: SnackPosition.BOTTOM);
                                }
                              },
                              child: const Text('Retirer', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMembersSheet() {
    final added = ContactsService.to.added;
    final existingUids = _conv.participants.map((p) => p.userId).toSet();
    final available = added.where((c) => !existingUids.contains(c.id)).toList();

    if (available.isEmpty) {
      Get.snackbar('Information', 'Tous vos contacts enregistrés sont déjà dans ce groupe.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final selected = <String>{}.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ajouter au groupe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Obx(() => TextButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              final selList = selected.toList();
                              final names = selList.map((id) => available.firstWhereOrNull((c) => c.id == id)?.name ?? 'Membre').toList();
                              Get.back();
                              Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                              final ok = await messaging.addParticipantsToGroup(_conv.id, selList, names: names);
                              if (Get.isDialogOpen == true) Get.back();
                              if (ok) {
                                final updated = messaging.conversations.firstWhereOrNull((c) => c.id == _conv.id);
                                if (updated != null && mounted) setState(() => _conv = updated);
                                Get.snackbar('Succès', 'Participants ajoutés', snackPosition: SnackPosition.BOTTOM);
                              }
                            },
                      child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final c = available[index];
                  return Obx(() {
                    final isSel = selected.contains(c.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(c.colorValue),
                        child: Text(c.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Checkbox(
                        value: isSel,
                        activeColor: ChatMeColors.violet,
                        shape: const CircleBorder(),
                        onChanged: (val) {
                          if (val == true) {
                            selected.add(c.id);
                          } else {
                            selected.remove(c.id);
                          }
                        },
                      ),
                      onTap: () {
                        if (isSel) {
                          selected.remove(c.id);
                        } else {
                          selected.add(c.id);
                        }
                      },
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _leaveGroupConfirm() {
    Get.dialog(
      AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: Text('Voulez-vous vraiment quitter "${_conv.getTitle(currentUserId)}" ?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Get.back();
              final myName = auth.currentUser.value?.displayName ?? 'Un participant';
              final ok = await messaging.leaveGroup(_conv.id, userName: myName);
              if (ok) {
                Get.back(); // Close conversation info
                Get.back(); // Close chat screen
                Get.snackbar('Groupe', 'Vous avez quitté le groupe', snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text('Quitter', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final otherParticipant = _conv.getOtherParticipant(currentUserId);
    final avatarUrl = _conv.getAvatarUrl(currentUserId);
    final title = _conv.getTitle(currentUserId);
    final messages = messaging.getMessages(_conv.id);
    final mediaMessages = messages.where((m) => m.mediaUrl != null && m.mediaUrl!.isNotEmpty).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_conv.isGroup && canEditInfo) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _editGroupNameDialog,
                      child: const Icon(Icons.edit, size: 16, color: Colors.white70),
                    ),
                  ],
                ],
              ),
              background: GestureDetector(
                onTap: () {
                  Get.to(() => AvatarViewerScreen(
                        imageUrl: avatarUrl,
                        initials: otherParticipant?.profile?.initials ?? '?',
                        name: title,
                      ));
                },
                child: Hero(
                  tag: 'avatar_${avatarUrl ?? otherParticipant?.profile?.initials}',
                  child: Container(
                    color: cs.primaryContainer,
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => _buildAvatarFallback(cs),
                          )
                        : _buildAvatarFallback(cs),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Quick Call & Media Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Audio',
                      color: ChatMeColors.cAppel,
                      onTap: () => Get.to(() => CallScreen(
                            conversationId: _conv.id,
                            otherUserId: otherParticipant?.userId ?? '',
                            name: title,
                            initials: otherParticipant?.profile?.initials ?? '?',
                            isVideo: false,
                            photoUrl: avatarUrl,
                          )),
                    ),
                    _buildActionButton(
                      icon: Icons.videocam_outlined,
                      label: 'Vidéo',
                      color: ChatMeColors.violet,
                      onTap: () => Get.to(() => CallScreen(
                            conversationId: _conv.id,
                            otherUserId: otherParticipant?.userId ?? '',
                            name: title,
                            initials: otherParticipant?.profile?.initials ?? '?',
                            isVideo: true,
                            photoUrl: avatarUrl,
                          )),
                    ),
                    _buildActionButton(
                      icon: _isMuted ? Icons.notifications_off : Icons.notifications_none,
                      label: _isMuted ? 'Muet' : 'Silencieux',
                      color: _isMuted ? Colors.orange : cs.onSurfaceVariant,
                      onTap: _toggleMute,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),

                // Group Description Section
                if (_conv.isGroup) ...[
                  InkWell(
                    onTap: canEditInfo ? _editGroupDescriptionDialog : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.description_outlined, color: ChatMeColors.violet, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Description du groupe',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  (_conv.description != null && _conv.description!.isNotEmpty)
                                      ? _conv.description!
                                      : 'Appuyez pour ajouter une description du groupe',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (_conv.description != null && _conv.description!.isNotEmpty)
                                        ? cs.onSurface
                                        : ChatMeColors.violet,
                                    fontStyle: (_conv.description == null || _conv.description!.isEmpty)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canEditInfo) const Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],

                // Media Gallery Section
                _buildMediaSection(cs, mediaMessages),
                const Divider(height: 1),

                // Group Settings & Invite Link (WhatsApp style)
                if (_conv.isGroup) ...[
                  ListTile(
                    leading: const Icon(Icons.link, color: ChatMeColors.violet),
                    title: const Text('Inviter via un lien'),
                    subtitle: const Text('Partager le lien ou le code QR du groupe'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showInviteLinkSheet,
                  ),
                  if (isAdmin) ...[
                    ListTile(
                      leading: const Icon(Icons.settings_outlined, color: ChatMeColors.cAppel),
                      title: const Text('Paramètres du groupe'),
                      subtitle: const Text('Modifier les autorisations des participants'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showGroupSettingsSheet,
                    ),
                  ],
                  const Divider(height: 1),
                  _buildGroupParticipantsSection(cs),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text('Quitter le groupe', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: _leaveGroupConfirm,
                  ),
                ],

                // Direct Chat Options
                if (_conv.isDirect) ...[
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: Colors.orange),
                    title: const Text('Effacer la discussion'),
                    subtitle: const Text('Supprime les messages pour vous sur cet appareil'),
                    onTap: () {
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Effacer la discussion ?'),
                          content: const Text('Tous les messages de cette conversation seront effacés.'),
                          actions: [
                            TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
                            TextButton(
                              onPressed: () async {
                                Get.back();
                                await messaging.clearConversationForMe(_conv.id);
                                Get.snackbar('Discussion effacée', 'Les messages ont été effacés', snackPosition: SnackPosition.BOTTOM);
                              },
                              child: const Text('Effacer', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(_isBlocked ? Icons.lock_open : Icons.block, color: Colors.red),
                    title: Text(_isBlocked ? 'Débloquer le contact' : 'Bloquer le contact', style: const TextStyle(color: Colors.red)),
                    onTap: () async {
                      if (otherParticipant == null) return;
                      if (_isBlocked) {
                        await messaging.unblockUser(otherParticipant.userId);
                        setState(() => _isBlocked = false);
                        Get.snackbar('Contact débloqué', '${otherParticipant.profile?.displayNameOrPhone} est débloqué', snackPosition: SnackPosition.BOTTOM);
                      } else {
                        await messaging.blockUser(otherParticipant.userId);
                        setState(() => _isBlocked = true);
                        Get.snackbar('Contact bloqué', '${otherParticipant.profile?.displayNameOrPhone} est bloqué', snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                  ),
                ],

                // Security & Privacy Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ChatMeColors.violetPale.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: ChatMeColors.violet, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Les messages et appels sont chiffrés et sécurisés. Seuls les participants de cette conversation peuvent les lire ou les écouter.',
                          style: TextStyle(fontSize: 12, color: ChatMeColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(ColorScheme cs) {
    if (_conv.isGroup) {
      return Center(child: Icon(Icons.groups, size: 72, color: cs.onPrimaryContainer));
    }
    final other = _conv.getOtherParticipant(currentUserId);
    return Center(
      child: Text(
        other?.profile?.initials ?? '?',
        style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(ColorScheme cs, List<Message> mediaMessages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MÉDIAS ET FICHIERS (${mediaMessages.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (mediaMessages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Aucun média partagé dans cette discussion',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mediaMessages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final msg = mediaMessages[index];
                  if (msg.type == MessageType.image) {
                    return GestureDetector(
                      onTap: () => ImageViewerScreen.show(
                        context,
                        imageUrl: msg.mediaUrl!,
                        title: msg.sender?.displayNameOrPhone ?? 'Photo',
                        subtitle: msg.timeAgo,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          msg.mediaUrl!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        ),
                      ),
                    );
                  } else if (msg.type == MessageType.video) {
                    return GestureDetector(
                      onTap: () => VideoViewerScreen.show(
                        context,
                        videoUrl: msg.mediaUrl!,
                        title: msg.sender?.displayNameOrPhone ?? 'Vidéo',
                      ),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                        ),
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: () {
                        if (msg.mediaUrl != null) {
                          launchUrl(Uri.parse(msg.mediaUrl!), mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.insert_drive_file, color: ChatMeColors.violet, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              msg.content ?? 'Fichier',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupParticipantsSection(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_conv.participants.length} PARTICIPANTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddMembersSheet,
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _conv.participants.length,
            itemBuilder: (context, index) {
              final p = _conv.participants[index];
              final isMe = p.userId == currentUserId;
              final name = isMe ? 'Vous' : (p.profile?.displayNameOrPhone ?? 'Membre');
              final isPAdmin = p.role == 'admin' || p.userId == _conv.createdBy;

              return ListTile(
                onTap: () => _showParticipantOptionsSheet(p),
                leading: CircleAvatar(
                  backgroundColor: isMe ? ChatMeColors.violet : ChatMeColors.cAppel,
                  backgroundImage: (p.profile?.avatarUrl != null && p.profile!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(p.profile!.avatarUrl!)
                      : null,
                  child: (p.profile?.avatarUrl == null || p.profile!.avatarUrl!.isEmpty)
                      ? Text(p.profile?.initials ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(name, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w500)),
                subtitle: p.profile?.phoneNumber != null && p.profile!.phoneNumber.isNotEmpty
                    ? Text(p.profile!.phoneNumber, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ChatMeColors.violet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Admin du groupe',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ChatMeColors.violet),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
