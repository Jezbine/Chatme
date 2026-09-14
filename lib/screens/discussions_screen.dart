import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_screen.dart';
import '../../services/messaging_service.dart';
import '../../services/auth_service.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../core/theme/chatme_theme.dart';
import '../../widgets/chat_header.dart';
import '../../widgets/chat_sheets.dart';
import '../../services/status_service.dart';
import 'status_post_screen.dart';
import 'status_viewer_screen.dart';

class DiscussionsScreen extends StatefulWidget {
  const DiscussionsScreen({super.key});

  @override
  State<DiscussionsScreen> createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxString _query = ''.obs;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messaging = Get.find<MessagingService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            ChatHeader(
              title: 'Discussions',
              actions: [
                HeaderIconButton(
                  icon: Icons.search,
                  onPressed: () {
                    // Focus la barre de recherche
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: cs.onSurfaceVariant, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => _query.value = v.toLowerCase().trim(),
                      decoration: InputDecoration(
                        hintText: 'Rechercher',
                        hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(color: cs.onSurface, fontSize: 13),
                    ),
                  ),
                  Obx(() => _query.value.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            _query.value = '';
                          },
                          child: Icon(Icons.close, color: cs.onSurfaceVariant, size: 18),
                        )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusStrip(context),
            const SizedBox(height: 4),
            Expanded(
              child: Obx(() {
                if (messaging.isLoadingConversations.value && messaging.conversations.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (messaging.conversations.isEmpty) {
                  return _buildEmptyState(context);
                }
                final query = _query.value;
                final currentUserIdLocal = Get.find<AuthService>().currentUser.value?.id ?? '';
                final filtered = query.isEmpty
                    ? messaging.conversations
                    : messaging.conversations.where((conv) {
                        final title = conv.getTitle(currentUserIdLocal).toLowerCase();
                        final last = conv.lastMessage?.displayContent.toLowerCase() ?? '';
                        return title.contains(query) || last.contains(query);
                      }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Aucun résultat pour "$query"', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => messaging.loadConversations(),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      return _buildConversationTile(context, conv);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showNewSheet(context),
        backgroundColor: cs.primary,
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildStatusStrip(BuildContext context) {
    final status = StatusService.to;
    final me = Get.find<AuthService>().currentUser.value;
    final myInitials = (me?.displayName?.isNotEmpty == true)
        ? me!.displayName!.substring(0, 1).toUpperCase()
        : 'M';

    return Obx(() {
      final myActive = status.myActive;
      final contactsActive = status.contactsActive;
      final tiles = <Widget>[
        _StatusAvatar(
          initials: myInitials,
          colorValue: ChatMeColors.violet.toARGB32(),
          viewed: myActive.isEmpty,
          label: 'Mon statut',
          onTap: () {
            if (myActive.isNotEmpty) {
              Get.to(() => StatusViewerScreen(
                    name: 'Mon statut',
                    initials: myInitials,
                    colorValue: ChatMeColors.violet.toARGB32(),
                    items: myActive,
                    isMine: true,
                  ));
            } else {
              Get.to(() => const StatusPostScreen());
            }
          },
          onAdd: () => Get.to(() => const StatusPostScreen()),
        ),
        for (final c in contactsActive)
          _StatusAvatar(
            initials: c.initials,
            colorValue: c.colorValue,
            viewed: false,
            label: c.name,
            onTap: () => Get.to(() => StatusViewerScreen(
                  name: c.name,
                  initials: c.initials,
                  colorValue: c.colorValue,
                  items: c.items.where((i) => !i.isExpired).toList(),
                  ownerId: c.id,
                )),
          ),
      ];
      return SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) => tiles[i],
        ),
      );
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Aucune conversation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Appuyez sur + pour commencer une discussion',
              style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, Conversation conv) {
    final cs = Theme.of(context).colorScheme;
    final currentUserId = Get.find<AuthService>().currentUser.value?.id ?? '';
    final other = conv.participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => conv.participants.first,
    );
    // Calcul du nombre de non-lus (WhatsApp-like)
    final unreadCount = (() {
      final ms = Get.find<MessagingService>();
      final cached = ms.messagesByConversation[conv.id];
      if (cached != null && cached.isNotEmpty) {
        return cached.where((m) => m.senderId != currentUserId && m.status != MessageStatus.read).length;
      }
      if (conv.lastMessage != null && conv.lastMessage!.senderId != currentUserId && conv.lastMessage!.status != MessageStatus.read) return 1;
      return 0;
    })();
    final isUnread = unreadCount > 0;

    return InkWell(
      onTap: () => Get.to(() => ChatScreen(conversation: conv)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Avatar : photo si disponible, sinon initiales (Meta/WeChat style avec fallback erreur)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: (other.profile?.avatarUrl != null && other.profile!.avatarUrl!.isNotEmpty)
                  ? Image.network(
                      other.profile!.avatarUrl!,
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          other.profile?.initials ?? '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        other.profile?.initials ?? '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(conv.getTitle(currentUserId),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (conv.lastMessage != null)
                        Text(conv.lastMessage!.timeAgo,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Obx(() {
                    final isTyping = Get.find<MessagingService>().typingByConversation[conv.id] == true;
                    if (isTyping) {
                      return const Text('En train d\'écrire...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.green, fontStyle: FontStyle.italic));
                    }
                    return Row(
                      children: [
                        if (conv.lastMessage != null && conv.lastMessage!.senderId == currentUserId)
                          Text('Vous: ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        Expanded(
                          child: Text(
                            conv.lastMessage?.displayContent ?? 'Démarrez la conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            if (isUnread)
              Obx(() {
                final liveCount = (() {
                  final cached = Get.find<MessagingService>().messagesByConversation[conv.id];
                  if (cached != null && cached.isNotEmpty) {
                    return cached.where((m) => m.senderId != currentUserId && m.status != MessageStatus.read).length;
                  }
                  return unreadCount;
                })();
                final display = liveCount > 99 ? '99+' : '$liveCount';
                return Container(
                  margin: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(display, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatusAvatar extends StatelessWidget {
  final String initials;
  final int colorValue;
  final bool viewed;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StatusAvatar({
    required this.initials,
    required this.colorValue,
    required this.viewed,
    required this.label,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ring = viewed ? cs.outline : Color(colorValue);
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 2.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      backgroundColor: Color(colorValue).withValues(alpha: 0.15),
                      child: Text(initials,
                          style: TextStyle(color: Color(colorValue), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              if (onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}
