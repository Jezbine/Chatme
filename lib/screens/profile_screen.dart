import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../models/user_profile.dart';
import '../../widgets/chat_header.dart';
import '../../widgets/chat_sheets.dart';
import '../../widgets/auth_wrapper.dart';
import 'my_qr_screen.dart';
import 'settings_screen.dart';
import 'security_policy_screen.dart';
import 'avatar_viewer_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String maskPhone(String phone) {
    final buf = StringBuffer();
    int digits = 0;
    for (int i = 0; i < phone.length; i++) {
      final c = phone[i];
      if (RegExp(r'\d').hasMatch(c)) {
        digits++;
        buf.write(digits <= 4 ? c : '•');
      } else {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Obx(() {
          final user = auth.currentUser.value;

          if (user == null) {
            return Column(
              children: [
                const ChatHeader(title: 'Profil'),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Profil indisponible', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        SizedBox(height: 8),
                        Text('Veuillez vous reconnecter', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: () => Get.offAll(() => const AuthWrapper()),
                    child: const Text('Se connecter'),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              const ChatHeader(title: 'Profil'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _buildHeader(user),
                    const SizedBox(height: 16),
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'Modifier le profil',
                      onTap: () => _showEditProfileDialog(context, user),
                    ),
                    _MenuItem(
                      icon: Icons.qr_code_2,
                      label: 'Mon QR code',
                      onTap: () => Get.to(() => const MyQrScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.contacts_outlined,
                      label: 'Contacts',
                      onTap: () => showContactsSheet(context),
                    ),
                    _MenuItem(
                      icon: Icons.camera_alt_outlined,
                      label: 'Caméra',
                      onTap: () => showCameraSheet(context),
                    ),
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Paramètres',
                      onTap: () => Get.to(() => const SettingsScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.lock_outline,
                      label: 'Confidentialité et sécurité',
                      onTap: () => Get.to(() => const SettingsScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () => Get.to(() => const SettingsScreen()),
                    ),
                    Obx(() {
                      final mode = Get.find<SettingsService>().themeMode.value;
                      final label = mode == 'system' ? 'Système' : mode == 'light' ? 'Clair' : 'Sombre';
                      return _MenuItem(
                        icon: Icons.brightness_6,
                        label: 'Apparence ($label)',
                        onTap: () => _showThemeSheet(context),
                      );
                    }),
                    _MenuItem(
                      icon: Icons.help_outline,
                      label: 'Aide et support',
                      onTap: () => Get.snackbar('Aide', 'Page d\'aide à venir'),
                    ),
                    _MenuItem(
                      icon: Icons.policy_outlined,
                      label: 'Politique de confidentialité',
                      onTap: () => Get.to(() => const SecurityPolicyScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.logout,
                      label: 'Déconnexion',
                      iconColor: Colors.red,
                      labelColor: Colors.red,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHeader(UserProfile user) {
    final cs = Theme.of(Get.context!).colorScheme;
    final hasPhoto = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => Get.to(() => AvatarViewerScreen(imageUrl: user.avatarUrl, initials: user.initials, name: user.displayName ?? user.phoneNumber)),
                child: Hero(
                  tag: 'avatar_${user.avatarUrl ?? user.initials}',
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(24),
                      image: hasPhoto ? DecorationImage(image: NetworkImage(user.avatarUrl!), fit: BoxFit.cover) : null,
                    ),
                    child: hasPhoto
                        ? null
                        : Center(
                            child: Text(
                              user.initials,
                              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickAvatar(Get.context!),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName ?? user.phoneNumber,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            maskPhone(user.phoneNumber),
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _pickAvatar(Get.context!),
            icon: const Icon(Icons.photo_camera, size: 18, color: Colors.white),
            label: Text(hasPhoto ? 'Changer la photo' : 'Ajouter une photo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: cs.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final auth = Get.find<AuthService>();
    final picker = ImagePicker();
    final cs = Theme.of(context).colorScheme;
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Wrap(
            children: [
              ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Prendre une photo'), onTap: () async {
                Get.back();
                final cam = await Permission.camera.request();
                if (!cam.isGranted) { Get.snackbar('Permission', 'Caméra refusée'); return; }
                final f = await picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 800);
                if (f != null) {
                  final ok = await auth.updateAvatar(f.path);
                  Get.snackbar(ok ? 'Photo mise à jour' : 'Erreur', ok ? 'Profil enregistré' : auth.errorMessage.value, snackPosition: SnackPosition.BOTTOM);
                }
              }),
              ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choisir dans la galerie'), onTap: () async {
                Get.back();
                final photos = await Permission.photos.request();
                if (photos.isPermanentlyDenied) { Get.snackbar('Permission', 'Autorisez les photos'); }
                final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
                if (f != null) {
                  final ok = await auth.updateAvatar(f.path);
                  Get.snackbar(ok ? 'Photo mise à jour' : 'Erreur', ok ? 'Profil enregistré' : auth.errorMessage.value, snackPosition: SnackPosition.BOTTOM);
                }
              }),
              if (auth.currentUser.value?.avatarUrl != null)
                ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)), onTap: () async {
                  Get.back();
                  await auth.updateProfile(avatarUrl: '');
                  // Force vide : update avec chaîne vide puis recharge
                  auth.currentUser.value = auth.currentUser.value!.copyWith(avatarUrl: '');
                  auth.currentUser.refresh();
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProfile user) {
    final nameController = TextEditingController(text: user.displayName ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');
    final auth = Get.find<AuthService>();

    Get.dialog(
      AlertDialog(
        title: const Text('Modifier le profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom d\'affichage'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
          Obx(() => ElevatedButton(
                onPressed: auth.isLoading.value
                    ? null
                    : () async {
                        final success = await auth.updateProfile(
                          displayName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                          bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
                        );
                        if (success) Get.back();
                      },
                child: auth.isLoading.value
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              )),
        ],
      ),
    );
  }

  void _showThemeSheet(BuildContext context) {
    final s = Get.find<SettingsService>();
    final cs = Theme.of(context).colorScheme;
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Obx(() {
          final cur = s.themeMode.value;
          Widget opt(String value, String label, IconData icon) {
            final sel = cur == value;
            return ListTile(
              leading: Icon(icon, color: sel ? cs.primary : cs.onSurfaceVariant),
              title: Text(label, style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? cs.primary : cs.onSurface)),
              trailing: sel ? Icon(Icons.check_circle, color: cs.primary) : null,
              onTap: () { s.themeMode.value = value; s.applyTheme(); s.save(); Get.back(); },
            );
          }
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: cs.outline, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Choisir le thème', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 8),
            opt('system', 'Système', Icons.brightness_auto),
            opt('light', 'Clair', Icons.wb_sunny_outlined),
            opt('dark', 'Sombre', Icons.nightlight_round),
          ]);
        }),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Get.find<AuthService>().signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outline)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor ?? cs.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
