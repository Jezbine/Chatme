import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'otp_verification_screen.dart';
import 'email_auth_screen.dart';
import '../../services/auth_service.dart';

class PhoneInputScreen extends StatelessWidget {
  const PhoneInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'ChatMe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous pour continuer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),

                // Email Auth (Recommandé pour dev/test)
                _buildAuthOption(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Continuer avec email',
                  subtitle: 'Recommandé pour test (pas de config SMS)',
                  color: Colors.blue,
                  onTap: () => Get.to(() => const EmailAuthScreen()),
                ),

                const SizedBox(height: 16),

                // Phone Auth
                _buildAuthOption(
                  context,
                  icon: Icons.phone_outlined,
                  title: 'Continuer avec téléphone',
                  subtitle: 'Nécessite configuration SMS (Twilio)',
                  color: Colors.green,
                  onTap: () => _showPhoneInputDialog(context, auth, phoneController, formKey),
                ),

                const SizedBox(height: 24),
                Obx(() {
                  if (auth.errorMessage.isNotEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        auth.errorMessage.value,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPhoneInputDialog(
    BuildContext context,
    AuthService auth,
    TextEditingController controller,
    GlobalKey<FormState> formKey,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion par téléphone'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro (+229)',
                  hintText: 'XX XX XX XX XX',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Entrez votre numéro';
                  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length < 10) return '10 chiffres requis';
                  if (digits.startsWith('01')) return 'Numéro invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading.value
                          ? null
                          : () async {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(ctx);
                                final success = await auth.sendOtp(controller.text.trim());
                                if (success && context.mounted) {
                                  Get.to(() => OtpVerificationScreen(phoneNumber: controller.text.trim()));
                                }
                              }
                            },
                      child: auth.isLoading.value
                          ? const CircularProgressIndicator()
                          : const Text('Envoyer le code'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ],
      ),
    );
  }
}
