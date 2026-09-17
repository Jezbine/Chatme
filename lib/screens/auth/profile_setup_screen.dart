import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/utils/format_utils.dart';
import '../home_screen.dart';
import '../../services/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final AuthService _auth = Get.find<AuthService>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  File? _selectedAvatar;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _auth.currentUser.value?.displayName ?? '');
    _bioCtrl = TextEditingController(text: _auth.currentUser.value?.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarSheet() async {
    final cs = Theme.of(context).colorScheme;
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Photo de profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: cs.primary),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Get.back();
                  try {
                    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1024);
                    if (f != null) setState(() => _selectedAvatar = File(f.path));
                  } catch (e) {
                    Get.snackbar('Caméra', 'Accès caméra impossible: $e', snackPosition: SnackPosition.BOTTOM);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: cs.primary),
                title: const Text('Choisir dans la galerie'),
                onTap: () async {
                  Get.back();
                  try {
                    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
                    if (f != null) setState(() => _selectedAvatar = File(f.path));
                  } catch (e) {
                    Get.snackbar('Galerie', 'Accès galerie impossible: $e', snackPosition: SnackPosition.BOTTOM);
                  }
                },
              ),
              if (_selectedAvatar != null || (_auth.currentUser.value?.avatarUrl != null && _auth.currentUser.value!.avatarUrl!.isNotEmpty))
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Get.back();
                    setState(() => _selectedAvatar = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = _auth.currentUser.value;
    final phone = user?.phoneNumber ?? '';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Complétez votre profil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ces informations permettent à vos amis de vous reconnaître sur ChatME.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              // Avatar avec bouton d'ajout photo
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.primary, width: 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _selectedAvatar != null
                          ? Image.file(_selectedAvatar!, fit: BoxFit.cover)
                          : (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                              ? Image.network(user.avatarUrl!, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    user?.initials ?? '?',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAvatarSheet,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Identifiant vérifié
              if (phone.isNotEmpty || email.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: ChatMeColors.cProfil.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, color: ChatMeColors.cProfil, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          phone.isNotEmpty ? FormatUtils.formatBeninPhone(phone) : email,
                          style: const TextStyle(
                            color: ChatMeColors.cProfil,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              // Nom d'affichage
              TextField(
                controller: _nameCtrl,
                maxLength: 35,
                decoration: InputDecoration(
                  labelText: 'Nom d\'affichage *',
                  hintText: 'Ex: Kofi Mensah',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
              ),

              const SizedBox(height: 12),

              // Bio
              TextField(
                controller: _bioCtrl,
                maxLength: 140,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio / Statut (optionnel)',
                  hintText: 'Ex: Disponible sur ChatME 🇧🇯',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
              ),

              const SizedBox(height: 24),

              Obx(() => SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _auth.isLoading.value
                      ? null
                      : () async {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) {
                            Get.snackbar('Nom requis', 'Veuillez renseigner votre nom d\'affichage',
                                snackPosition: SnackPosition.BOTTOM);
                            return;
                          }

                          if (_selectedAvatar != null) {
                            await _auth.updateAvatar(_selectedAvatar!.path);
                          }

                          final success = await _auth.updateProfile(
                            displayName: name,
                            bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
                          );

                          if (success) {
                            Get.offAll(() => const HomeScreen());
                          } else {
                            Get.snackbar(
                              'Profil',
                              _auth.errorMessage.value.isNotEmpty
                                  ? _auth.errorMessage.value
                                  : 'Profil non enregistré. Vous pourrez le modifier plus tard.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _auth.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
