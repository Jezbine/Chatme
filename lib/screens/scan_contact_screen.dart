import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/contacts_service.dart';
import 'package:chatme/services/messaging_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/models/conversation.dart';
import 'package:chatme/models/user_profile.dart';
import 'package:chatme/screens/chat_screen.dart';

class ScanContactScreen extends StatefulWidget {
  const ScanContactScreen({super.key});

  @override
  State<ScanContactScreen> createState() => _ScanContactScreenState();
}

class _ScanContactScreenState extends State<ScanContactScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  Future<void> _onDetect(String raw) async {
    if (_handled) return;
    final data = parseUserQrPayload(raw);
    if (data == null) {
      Get.snackbar("QR non reconnu", "Ce code n'est pas un contact ChatMe",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    // Vérif serveur anti-spoof
    final exists = await verifyQrUserExists(data['id']!);
    if (!exists) {
      Get.snackbar("QR invalide", "Utilisateur introuvable côté serveur",
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    _handled = true;
    _controller.pause();

    final cs = ContactsService.to;
    final targetId = data['id']!;
    final targetName = data['name']!;

    // 1. Ajouter immédiatement le contact (façon WhatsApp)
    cs.addFromScan(targetId, targetName);

    // 2. Créer ou récupérer la conversation directe
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    String? convId;
    try {
      convId = await MessagingService.to.createDirectConversation(targetId);
    } catch (_) {}

    if (Get.isDialogOpen == true) {
      Get.back(); // Fermer le loader
    }

    // 3. Ouvrir directement la discussion si créée, sinon fermer le scan avec succès
    if (convId != null) {
      final myId = AuthService.to.currentUser.value?.id ?? '';
      final conv = Conversation(
        id: convId,
        type: ConversationType.direct,
        createdBy: myId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        participants: [
          ConversationParticipant(conversationId: convId, userId: myId, role: 'member', joinedAt: DateTime.now()),
          ConversationParticipant(
            conversationId: convId,
            userId: targetId,
            role: 'member',
            joinedAt: DateTime.now(),
            profile: UserProfile(id: targetId, displayName: targetName, phoneNumber: ''),
          ),
        ],
      );
      Get.off(() => ChatScreen(conversation: conv));
    } else {
      Get.back();
      Get.snackbar("Demande envoyée", "$targetName doit valider votre demande",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ChatMeColors.violet,
          colorText: Colors.white);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requestCamera();
  }

  Future<void> _requestCamera() async {
    final s = await Permission.camera.request();
    if (s.isPermanentlyDenied) {
      Get.snackbar("Caméra", "Autorisez la caméra dans les paramètres",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12101F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12101F),
        foregroundColor: Colors.white,
        title: const Text("Scanner un QR"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final b in capture.barcodes) {
                if (b.rawValue != null) _onDetect(b.rawValue!);
              }
            },
          ),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: ChatMeColors.violetLight, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              "Scannez le QR code d'un contact pour l'ajouter",
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
