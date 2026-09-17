import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/chatme_theme.dart';
import '../services/auth_service.dart';
import '../services/contacts_service.dart';
import '../services/messaging_service.dart';
import '../models/conversation.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final Set<String> _selectedContactIds = <String>{};
  final Map<String, AddedContact> _selectedContactsMap = <String, AddedContact>{};
  String _searchQuery = '';
  File? _groupAvatarFile;
  bool _isCreating = false;
  bool _stepName = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
      if (file != null) {
        setState(() {
          _groupAvatarFile = File(file.path);
        });
      }
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Nom requis', 'Veuillez saisir un nom pour le groupe', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_selectedContactIds.isEmpty) {
      Get.snackbar('Participants requis', 'Sélectionnez au moins un participant', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isCreating = true);
    try {
      String? avatarUrl;
      if (_groupAvatarFile != null) {
        final bytes = await _groupAvatarFile!.readAsBytes();
        avatarUrl = await MessagingService.to.uploadMedia(
          _groupAvatarFile!.path,
          bytes,
          'image/jpeg',
        );
      }

      final Conversation? conv = await MessagingService.to.createGroupConversation(
        name: name,
        memberUserIds: _selectedContactIds.toList(),
        avatarUrl: avatarUrl,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      );

      if (conv != null) {
        Get.back(); // Ferme create group screen
        Get.to(() => ChatScreen(conversation: conv));
        Get.snackbar(
          'Groupe créé',
          'Le groupe "$name" a été créé avec succès',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ChatMeColors.cProfil,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          MessagingService.to.errorMessage.value.isNotEmpty
              ? MessagingService.to.errorMessage.value
              : 'Impossible de créer le groupe',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Création échouée: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stepName ? 'Détails du groupe' : 'Nouveau groupe',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              _stepName
                  ? '${_selectedContactIds.length} participant(s)'
                  : '${_selectedContactIds.length} sélectionné(s)',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (!_stepName && _selectedContactIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _stepName = true),
              child: const Text('Suivant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          if (_stepName)
            _isCreating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: _createGroup,
                    child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
        ],
      ),
      body: _stepName ? _buildStepDetails(cs) : _buildStepSelectMembers(cs),
    );
  }

  Widget _buildStepSelectMembers(ColorScheme cs) {
    final added = ContactsService.to.added;
    final currentUserId = AuthService.to.currentUser.value?.id ?? '';
    final available = added.where((c) => c.id != currentUserId).toList();
    final filtered = _searchQuery.isEmpty
        ? available
        : available.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        // Horizontal list of selected members
        if (_selectedContactIds.isNotEmpty)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _selectedContactIds.map((id) {
                final c = _selectedContactsMap[id];
                final name = c?.name ?? 'Membre';
                final initials = c?.initials ?? '?';
                final color = c != null ? Color(c.colorValue) : ChatMeColors.violet;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: color,
                            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 50,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedContactIds.remove(id);
                              _selectedContactsMap.remove(id);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un contact...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close, color: cs.onSurfaceVariant, size: 18),
                  ),
              ],
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    available.isEmpty
                        ? 'Aucun contact enregistré.\nScannez un QR code pour ajouter vos amis.'
                        : 'Aucun contact correspondant',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final isSelected = _selectedContactIds.contains(c.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(c.colorValue),
                        child: Text(
                          c.initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: ChatMeColors.violet,
                        shape: const CircleBorder(),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedContactIds.add(c.id);
                              _selectedContactsMap[c.id] = c;
                            } else {
                              _selectedContactIds.remove(c.id);
                              _selectedContactsMap.remove(c.id);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedContactIds.remove(c.id);
                            _selectedContactsMap.remove(c.id);
                          } else {
                            _selectedContactIds.add(c.id);
                            _selectedContactsMap[c.id] = c;
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStepDetails(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: ChatMeColors.violet.withValues(alpha: 0.15),
                      backgroundImage: _groupAvatarFile != null ? FileImage(_groupAvatarFile!) : null,
                      child: _groupAvatarFile == null
                          ? const Icon(Icons.groups, size: 38, color: ChatMeColors.violet)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: ChatMeColors.violet,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: 50,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Nom du groupe',
                    labelText: 'Sujet du groupe',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            minLines: 1,
            maxLength: 250,
            decoration: const InputDecoration(
              icon: Icon(Icons.description_outlined),
              hintText: 'Ajouter une description du groupe (optionnelle)',
              labelText: 'Description du groupe',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'PARTICIPANTS (${_selectedContactIds.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedContactIds.length,
            itemBuilder: (context, index) {
              final id = _selectedContactIds.elementAt(index);
              final c = _selectedContactsMap[id];
              final name = c?.name ?? 'Membre';
              final initials = c?.initials ?? '?';
              final color = c != null ? Color(c.colorValue) : ChatMeColors.violet;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedContactIds.remove(id);
                      _selectedContactsMap.remove(id);
                      if (_selectedContactIds.isEmpty) {
                        _stepName = false;
                      }
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
