import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import 'profile_setup_screen.dart';

class EmailVerificationCallbackScreen extends StatefulWidget {
  final String email;
  final String token;

  const EmailVerificationCallbackScreen({
    required this.email,
    required this.token,
    super.key,
  });

  @override
  State<EmailVerificationCallbackScreen> createState() => _EmailVerificationCallbackScreenState();
}

class _EmailVerificationCallbackScreenState extends State<EmailVerificationCallbackScreen> {
  final auth = Get.find<AuthService>();
  bool _verified = false;
  String _status = 'Vérification en cours...';

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    final success = await auth.verifyEmailOtp(widget.email, widget.token);
    
    if (mounted) {
      setState(() {
        _verified = success;
        _status = success ? 'Email confirmé avec succès !' : 'Échec de la vérification';
      });

      if (success) {
        // Attendre un peu puis naviguer
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          // L'AuthWrapper va rediriger vers ProfileSetupScreen ou HomeScreen
          Get.offAll(() => const ProfileSetupScreen());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _verified ? Icons.check_circle_outline : Icons.hourglass_empty,
                size: 100,
                color: _verified ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _verified ? 'Email confirmé !' : 'Vérification...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _verified ? Colors.green : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              if (!_verified) ...[
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
