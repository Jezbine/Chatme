import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/services/contacts_service.dart';
import 'package:chatme/screens/scan_contact_screen.dart';
import 'package:chatme/screens/auth/phone_input_screen.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAll(() => const PhoneInputScreen());
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = user.displayName ?? user.phoneNumber;
    final id = user.id;
    final payload = buildUserQrPayload(id, name);

    return Scaffold(
      backgroundColor: ChatMeColors.surface,
      appBar: AppBar(
        backgroundColor: ChatMeColors.surface,
        foregroundColor: ChatMeColors.ink,
        title: const Text("Mon QR"),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: ChatMeColors.violet,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: ChatMeColors.ink)),
              const SizedBox(height: 4),
              Text(user.phoneNumber,
                  style: const TextStyle(fontSize: 12.5, color: ChatMeColors.inkSoft)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: payload,
                  size: 220,
                  backgroundColor: Colors.white,
                  dataModuleStyle: const QrDataModuleStyle(
                    color: ChatMeColors.ink,
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                  eyeStyle: const QrEyeStyle(
                    color: ChatMeColors.ink,
                    eyeShape: QrEyeShape.square,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Faites scanner ce code par un ami pour qu'il vous ajoute en contact.",
                style: TextStyle(fontSize: 13.5, color: ChatMeColors.inkSoft),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Get.to(() => const ScanContactScreen()),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scanner un contact"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatMeColors.violet,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
