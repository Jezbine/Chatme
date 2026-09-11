import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../home_screen.dart';
import '../../services/auth_service.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final nameController = TextEditingController(text: auth.currentUser.value?.displayName ?? '');
    final bioController = TextEditingController(text: auth.currentUser.value?.bio ?? '');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'Complétez votre profil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ces informations seront visibles par vos contacts',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              // Section avatar simplifiée (pas de upload pour l'instant)
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    auth.currentUser.value?.initials ?? '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom d\'affichage',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio (optionnel)',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              Obx(() => SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.isLoading.value
                      ? null
                      : () async {
                          final success = await auth.updateProfile(
                            displayName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                            bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
                          );
                          if (success) {
                            Get.offAll(() => const HomeScreen());
                          } else {
                            Get.snackbar(
                              'Profil',
                              auth.errorMessage.value.isNotEmpty
                                  ? auth.errorMessage.value
                                  : 'Profil non enregistré. Vous pourrez le modifier plus tard.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange,
                              colorText: Colors.white,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: auth.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
