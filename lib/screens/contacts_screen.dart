import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/chatme_theme.dart';
import '../core/utils/format_utils.dart';
import '../core/utils/string_extension.dart';
import '../services/contacts_service.dart';
import '../services/messaging_service.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../models/conversation.dart';
import '../models/user_profile.dart';
import '../widgets/chat_sheets.dart';
import 'chat_screen.dart';
import 'call_screen.dart';
import 'my_qr_screen.dart';
import 'scan_contact_screen.dart';
import 'contact_requests_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsService _contactsService = ContactsService.to;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSyncing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncDeviceContacts() async {
    setState(() => _isSyncing = true);
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Synchronisation du carnet d\'adresses...', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Recherche de vos amis sur ChatME', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      final matched = await _contactsService.importDeviceContacts();
      if (Get.isDialogOpen == true) Get.back();

      if (matched.isNotEmpty) {
        Get.snackbar(
          'Répertoire synchronisé',
          '${matched.length} nouveau(x) ami(s) trouvé(s) sur ChatME !',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ChatMeColors.cProfil,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Synchronisation terminée',
          'Tous vos contacts existants sont déjà à jour.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      Get.snackbar('Erreur', 'Impossible de synchroniser: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddByPhoneDialog() {
    final phoneCtrl = TextEditingController();
    Map<String, dynamic>? foundProfile;
    bool isSearchingUser = false;

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Ajouter un contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saisissez le numéro de téléphone béninois (10 chiffres) de votre ami.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '01 97 00 00 00',
                    prefixText: '+229 ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    if (foundProfile != null) {
                      setDialogState(() => foundProfile = null);
                    }
                  },
                ),
                const SizedBox(height: 14),
                if (isSearchingUser)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (foundProfile != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ChatMeColors.violetPale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: ChatMeColors.violet,
                          backgroundImage: foundProfile!['avatar_url'] != null
                              ? NetworkImage(foundProfile!['avatar_url'])
                              : null,
                          child: foundProfile!['avatar_url'] == null
                              ? Text(
                                  (foundProfile!['display_name'] as String? ?? '?').initials,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                foundProfile!['display_name'] ?? 'Utilisateur ChatME',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                foundProfile!['phone_number'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
              if (foundProfile == null)
                ElevatedButton(
                  onPressed: () async {
                    final raw = phoneCtrl.text.trim();
                    if (raw.isEmpty) return;
                    setDialogState(() => isSearchingUser = true);
                    final res = await _contactsService.searchUserByPhone(raw);
                    setDialogState(() {
                      isSearchingUser = false;
                      foundProfile = res;
                    });
                    if (res == null) {
                      Get.snackbar(
                        'Utilisateur non trouvé',
                        'Aucun compte ChatME n\'est associé à ce numéro.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                  child: const Text('Vérifier'),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    final uid = foundProfile!['id'] as String;
                    final name = (foundProfile!['display_name'] as String?) ?? 'Ami';
                    final phone = foundProfile!['phone_number'] as String?;
                    final avatar = foundProfile!['avatar_url'] as String?;

                    _contactsService.addFromScan(uid, name, phoneNumber: phone, avatarUrl: avatar);
                    Get.back();
                    Get.snackbar(
                      'Contact ajouté',
                      '$name a été ajouté à vos contacts.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: ChatMeColors.cProfil,
                      colorText: Colors.white,
                    );
                  },
                  child: const Text('Ajouter aux contacts'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showContactOptionsSheet(AddedContact contact) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contact header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(contact.colorValue),
                    backgroundImage: contact.avatarUrl != null ? NetworkImage(contact.avatarUrl!) : null,
                    child: contact.avatarUrl == null
                        ? Text(
                            contact.initials,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty)
                          Text(
                            FormatUtils.formatBeninPhone(contact.phoneNumber!),
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAction(
                    icon: Icons.chat_bubble_outline,
                    label: 'Message',
                    color: ChatMeColors.violet,
                    onTap: () {
                      Get.back();
                      _startDirectChat(contact);
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.phone_outlined,
                    label: 'Appel',
                    color: ChatMeColors.cAppel,
                    onTap: () {
                      Get.back();
                      Get.to(() => CallScreen(
                            conversationId: 'direct_${contact.id}',
                            otherUserId: contact.id,
                            name: contact.name,
                            initials: contact.initials,
                            isVideo: false,
                            photoUrl: contact.avatarUrl,
                          ));
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.videocam_outlined,
                    label: 'Vidéo',
                    color: ChatMeColors.violet,
                    onTap: () {
                      Get.back();
                      Get.to(() => CallScreen(
                            conversationId: 'direct_${contact.id}',
                            otherUserId: contact.id,
                            name: contact.name,
                            initials: contact.initials,
                            isVideo: true,
                            photoUrl: contact.avatarUrl,
                          ));
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payer',
                    color: ChatMeColors.cPortefeuille,
                    onTap: () {
                      Get.back();
                      showAmountSheet(
                        context,
                        title: 'Envoyer à ${contact.name}',
                        onConfirm: (amount) async {
                          final ok = await WalletService.to.transferToUser(contact.id, amount);
                          if (ok) {
                            Get.snackbar('Transfert réussi', '$amount FCFA envoyés à ${contact.name}',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: ChatMeColors.cProfil,
                                colorText: Colors.white);
                          } else {
                            Get.snackbar('Échec', 'Solde insuffisant ou erreur', snackPosition: SnackPosition.BOTTOM);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer de mes contacts', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Get.back();
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Supprimer ce contact ?'),
                      content: Text('Voulez-vous retirer "${contact.name}" de votre liste de contacts ?'),
                      actions: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
                        TextButton(
                          onPressed: () async {
                            Get.back();
                            await _contactsService.deleteContact(contact.id);
                            Get.snackbar('Supprimé', '${contact.name} a été retiré de vos contacts',
                                snackPosition: SnackPosition.BOTTOM);
                          },
                          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _startDirectChat(AddedContact contact) async {
    final me = AuthService.to.currentUser.value;
    if (me == null) return;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    final convId = await MessagingService.to.createDirectConversation(contact.id);
    if (Get.isDialogOpen == true) Get.back();

    if (convId != null) {
      final now = DateTime.now();
      final conv = Conversation(
        id: convId,
        type: ConversationType.direct,
        createdBy: me.id,
        createdAt: now,
        updatedAt: now,
        participants: [
          ConversationParticipant(conversationId: convId, userId: me.id, role: 'member', joinedAt: now),
          ConversationParticipant(
            conversationId: convId,
            userId: contact.id,
            role: 'member',
            joinedAt: now,
            profile: UserProfile(
              id: contact.id,
              phoneNumber: contact.phoneNumber ?? '',
              displayName: contact.name,
              avatarUrl: contact.avatarUrl,
            ),
          ),
        ],
      );
      MessagingService.to.loadConversations();
      Get.to(() => ChatScreen(conversation: conv));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                decoration: const InputDecoration(
                  hintText: 'Rechercher un contact...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
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
            )
          : AppBar(
              title: Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${_contactsService.added.length} contact(s)',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  )),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: _showAddByPhoneDialog,
                ),
              ],
            ),
      body: Obx(() {
        final allContacts = _contactsService.added;
        final incoming = _contactsService.incomingRequests;

        final filtered = _searchQuery.isEmpty
            ? allContacts.toList()
            : allContacts.where((c) {
                final matchName = c.name.toLowerCase().contains(_searchQuery);
                final matchPhone = c.phoneNumber?.contains(_searchQuery) ?? false;
                return matchName || matchPhone;
              }).toList();

        // Trie alphabétique
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return ListView(
          children: [
            // Quick Action Buttons Strip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.to(() => const MyQrScreen()),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('Mon QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ChatMeColors.violet,
                        side: BorderSide(color: ChatMeColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Get.to(() => const ScanContactScreen()),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scanner'),
                      style: ElevatedButton.styleFrom(backgroundColor: ChatMeColors.violet),
                    ),
                  ),
                ],
              ),
            ),

            // Import Device Contacts Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: ChatMeColors.cAppel,
                    radius: 18,
                    child: Icon(Icons.contacts, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Importer le répertoire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Trouver vos contacts téléphoniques sur ChatME', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isSyncing ? null : _syncDeviceContacts,
                    child: const Text('Synchroniser', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Incoming Contact Requests Banner
            if (incoming.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  onTap: () => Get.to(() => const ContactRequestsScreen()),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: ChatMeColors.cProfil.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ChatMeColors.cProfil.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Badge(
                          label: Text('${incoming.length}'),
                          child: const Icon(Icons.notifications_active, color: ChatMeColors.cProfil),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${incoming.length} demande(s) de contact en attente',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: ChatMeColors.cProfil, fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: ChatMeColors.cProfil),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'VOS CONTACTS (${filtered.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Contact List or Empty
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_search, size: 54, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Aucun contact correspondant à "$_searchQuery"'
                            : 'Aucun contact enregistré.\nScannez un QR ou synchronisez votre répertoire pour ajouter vos amis.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((contact) {
                return ListTile(
                  onTap: () => _showContactOptionsSheet(contact),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(contact.colorValue),
                    backgroundImage: contact.avatarUrl != null ? NetworkImage(contact.avatarUrl!) : null,
                    child: contact.avatarUrl == null
                        ? Text(
                            contact.initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty
                      ? Text(
                          FormatUtils.formatBeninPhone(contact.phoneNumber!),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        )
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: ChatMeColors.violet, size: 20),
                    onPressed: () => _startDirectChat(contact),
                  ),
                );
              }),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddByPhoneDialog,
        backgroundColor: ChatMeColors.violet,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
