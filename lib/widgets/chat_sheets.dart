import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/wallet_service.dart';
import 'package:chatme/services/moments_service.dart';
import 'package:chatme/services/contacts_service.dart';
import 'package:chatme/screens/scan_contact_screen.dart';
import 'package:chatme/screens/my_qr_screen.dart';
import 'package:chatme/screens/chat_screen.dart';
import 'package:chatme/services/messaging_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/models/conversation.dart';
import 'package:chatme/models/user_profile.dart';

Widget _avatar(String initials, Color color, {double size = 36, double radius = 18}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
    child: Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          fontFamily: 'Baloo 2',
        ),
      ),
    ),
  );
}

Future<void> _startChat(BuildContext context,
    {required String otherId, required String name, required int colorValue}) async {
  if (otherId.isEmpty) {
    Get.snackbar('Contact non disponible', 'Ce contact n\'est pas encore sur ChatMe. Invitez-le via QR.',
        snackPosition: SnackPosition.BOTTOM);
    return;
  }
  final me = AuthService.to.currentUser.value;
  if (me == null) {
    Get.snackbar('Erreur', 'Connectez-vous pour démarrer une discussion',
        snackPosition: SnackPosition.BOTTOM);
    return;
  }
  Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
  final convId = await MessagingService.to.createDirectConversation(otherId);
  if (Get.isDialogOpen == true) Get.back();
  if (convId == null) {
    Get.snackbar('Erreur',
        'Impossible de créer la discussion (le contact doit être un utilisateur ChatMe inscrit)',
        snackPosition: SnackPosition.BOTTOM);
    return;
  }
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
        userId: otherId,
        role: 'member',
        joinedAt: now,
        profile: UserProfile(id: otherId, phoneNumber: '', displayName: name),
      ),
    ],
  );
  MessagingService.to.loadConversations();
  Get.to(() => ChatScreen(conversation: conv));
}

void showNewSheet(BuildContext context) {
  Get.bottomSheet(
    _Sheet(
      title: 'Nouveau',
      children: [
        _ActionRow(
          icon: Icons.chat_bubble,
          iconColor: ChatMeColors.violet,
          label: 'Nouvelle discussion',
          onTap: () {
            Get.back();
            showContactsSheet(context);
          },
        ),
        _ActionRow(
          icon: Icons.camera_alt,
          iconColor: ChatMeColors.cProfil,
          label: 'Prendre une photo',
          onTap: () {
            Get.back();
            showCameraSheet(context);
          },
        ),
        _ActionRow(
          icon: Icons.group_add,
          iconColor: ChatMeColors.cAppel,
          label: 'Créer un groupe',
          onTap: () {
            Get.back();
            showContactsSheet(context);
          },
        ),
        _ActionRow(
          icon: Icons.qr_code_scanner,
          iconColor: ChatMeColors.cDocuments,
          label: 'Scanner un QR (ajouter un contact)',
          onTap: () {
            Get.back();
            Get.to(() => const ScanContactScreen());
          },
        ),
      ],
    ),
    backgroundColor: ChatMeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

void showContactsSheet(BuildContext context, {bool selectable = true}) {
  Get.bottomSheet(
    _Sheet(
      title: 'Contacts',
      maxHeight: 0.9,
      children: [
        _PermissionBanner(
          text:
              "ChatME peut lire votre carnet d'adresses pour retrouver vos amis déjà inscrits.",
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
              const SizedBox(width: 10),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('VOS CONTACTS CHATME',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatMeColors.inkSoft)),
        ),
        Obx(() {
          final added = ContactsService.to.added;
          if (added.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Text('Aucun contact ajouté. Scannez un QR pour en ajouter.',
                  style: TextStyle(fontSize: 12.5, color: ChatMeColors.inkSoft)),
            );
          }
          return Column(
            children: added
                .map((c) => _buildContactRow(c.name, c.initials, Color(c.colorValue), () {
                      Get.back();
                      _startChat(context, otherId: c.id, name: c.name, colorValue: c.colorValue);
                    }))
                .toList(),
          );
        }),
      ],
    ),
    backgroundColor: ChatMeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

void showContactsPaySheet(BuildContext context) {
  void payTo({required String id, required String name}) {
    Get.back();
    showAmountSheet(
      context,
      title: 'Envoyer à $name',
      onConfirm: (amount) async {
        // Banque : virement atomique vers user_id si disponible, sinon fallback débit simple
        bool ok = false;
        if (id.isNotEmpty && id.length > 10) {
          // id ressemble à uuid -> vrai virement banque
          ok = await WalletService.to.transferToUser(id, amount);
        } else {
          ok = WalletService.to.sendMoney(name, amount);
        }
        if (ok) {
          Get.snackbar('Envoyé', '$amount FCFA envoyés à $name',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: ChatMeColors.cProfil,
              colorText: Colors.white);
        } else {
          Get.snackbar('Échec', 'Solde insuffisant ou montant invalide',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
        }
      },
    );
  }

  Get.bottomSheet(
    _Sheet(
      title: 'Envoyer à…',
      maxHeight: 0.9,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ChatMeColors.violetPale,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: ChatMeColors.inkSoft, size: 18),
              SizedBox(width: 8),
              Text('Nom ou numéro', style: TextStyle(color: ChatMeColors.inkSoft)),
            ],
          ),
        ),
        Obx(() => Column(
              children: ContactsService.to.added
                  .map((c) => _buildContactRow(c.name, c.initials, Color(c.colorValue), () => payTo(id: c.id, name: c.name)))
                  .toList(),
            )),
      ],
    ),
    backgroundColor: ChatMeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

void showCameraSheet(BuildContext context) {
  Get.bottomSheet(
    _Sheet(
      title: 'Caméra',
      maxHeight: 0.92,
      children: [_CameraSheetBody()],
    ),
    backgroundColor: ChatMeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

void showTextPostSheet(BuildContext context) {
  final ctrl = TextEditingController();
  Get.bottomSheet(
    _Sheet(
      title: 'Nouveau moment',
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ChatMeColors.violetPale,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration.collapsed(
              hintText: 'Que voulez-vous partager ?',
              hintStyle: TextStyle(color: ChatMeColors.inkSoft),
            ),
            style: const TextStyle(fontSize: 14, color: ChatMeColors.ink),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) {
                Get.snackbar('Erreur', 'Écrivez quelque chose', snackPosition: SnackPosition.BOTTOM);
                return;
              }
              MomentsService.to.addMoment(text: text);
              Get.back();
              Get.snackbar('Moments', 'Moment publié',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: ChatMeColors.violet,
                  colorText: Colors.white);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ChatMeColors.violet),
            child: const Text('Publier', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
    backgroundColor: ChatMeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

void showAmountSheet(BuildContext context,
    {required String title, required void Function(int amount) onConfirm}) {
  final ctrl = TextEditingController();
  Get.bottomSheet(
    _Sheet(
      title: title,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ChatMeColors.violetPale,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration.collapsed(
              hintText: 'Montant en FCFA',
              hintStyle: TextStyle(color: ChatMeColors.inkSoft),
            ),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              final raw = ctrl.text.replaceAll(' ', '');
              final amount = int.tryParse(raw);
              if (amount == null || amount <= 0) {
                Get.snackbar('Erreur', 'Montant invalide', snackPosition: SnackPosition.BOTTOM);
                return;
              }
              onConfirm(amount);
              Get.back();
            },
            child: const Text('Confirmer'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
    backgroundColor: ChatMeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

Widget _buildContactRow(String name, String initials, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _avatar(initials, color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ChatMeColors.ink)),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ChatMeColors.border, width: 2),
            ),
            child: const Center(child: Icon(Icons.chevron_right, size: 14, color: ChatMeColors.violet)),
          ),
        ],
      ),
    ),
  );
}

class _CameraSheetBody extends StatefulWidget {
  @override
  State<_CameraSheetBody> createState() => _CameraSheetBodyState();
}

class _CameraSheetBodyState extends State<_CameraSheetBody> {
  final ImagePicker _picker = ImagePicker();
  File? _photo;
  bool _captured = false;
  final TextEditingController _caption = TextEditingController();
  bool _busy = false;

  Future<void> _captureCamera() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1280);
      if (file != null) {
        setState(() {
          _photo = File(file.path);
          _captured = true;
        });
      }
    } catch (e) {
      Get.snackbar('Caméra', 'Accès caméra impossible', snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280);
      if (file != null) {
        setState(() {
          _photo = File(file.path);
          _captured = true;
        });
      }
    } catch (e) {
      Get.snackbar('Galerie', 'Accès galerie impossible', snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _busy = false);
    }
  }

  void _publish() {
    MomentsService.to.addMoment(
      text: _caption.text.trim().isEmpty ? 'Nouveau moment ✨' : _caption.text.trim(),
      photoPath: _photo?.path,
    );
    Get.back();
    Get.snackbar('Moments', 'Moment publié',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ChatMeColors.violet,
        colorText: Colors.white);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_captured) {
      return Column(
        children: [
          Container(
            height: 360,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF12101F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('Aperçu caméra',
                  style: TextStyle(color: Color(0xFF8A84BD), fontSize: 13)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickGallery,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: ChatMeColors.violetPale, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: ChatMeColors.violet, size: 22),
                ),
              ),
              const SizedBox(width: 34),
              GestureDetector(
                onTap: _captureCamera,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: ChatMeColors.violet, width: 3)),
                  child: _busy ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt, color: ChatMeColors.violet, size: 28),
                ),
              ),
              const SizedBox(width: 34),
              GestureDetector(
                onTap: _pickGallery,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: ChatMeColors.violetPale, shape: BoxShape.circle),
                  child: const Icon(Icons.collections, color: ChatMeColors.violet, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      );
    }
    return Column(
      children: [
        Container(
          height: 300,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: _photo != null
                ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover)
                : null,
            color: const Color(0xFF12101F),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _caption,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Écrivez une légende…',
              hintStyle: const TextStyle(color: ChatMeColors.inkSoft),
              filled: true,
              fillColor: ChatMeColors.violetPale,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ElevatedButton(
            onPressed: _publish,
            child: const Text('Publier sur Moments'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double maxHeight;

  const _Sheet({required this.title, required this.children, this.maxHeight = 0.82});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeight),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: ChatMeColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ChatMeColors.ink,
                  fontFamily: 'Baloo 2',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(child: SingleChildScrollView(child: Column(children: children))),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ChatMeColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final String text;

  const _PermissionBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ChatMeColors.violetPale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Autoriser l\'accès',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ChatMeColors.ink),
                ),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 12.5, color: ChatMeColors.ink)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Get.snackbar('Accès contacts', 'Fonctionnalité nécessitant l\'autorisation système',
                      snackPosition: SnackPosition.BOTTOM),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: ChatMeColors.violet,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Autoriser l\'accès',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
