import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_wrapper.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({required this.email, super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final auth = Get.find<AuthService>();
  int _resendCountdown = 0;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _resendCountdown--);
      }
      return _resendCountdown > 0;
    });
  }

  Future<void> _resendEmail() async {
    if (_resendCountdown > 0) return;
    
    final success = await auth.sendEmailOtp(widget.email);
    if (success) {
      _startCountdown();
      Get.snackbar('Email envoyé', 'Vérifiez votre boîte de réception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Vérifiez votre email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nous avons envoyé un lien de confirmation à',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cliquez sur le lien dans l\'email pour confirmer votre adresse.\nLe lien expire dans 24h.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Code reçu par email (6 chiffres)',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Obx(() => SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading.value
                          ? null
                          : () async {
                              final code = _codeController.text.trim();
                              if (code.length < 4) {
                                Get.snackbar('Code', 'Saisissez le code complet reçu par email');
                                return;
                              }
                              final ok = await auth.verifyEmailOtp(widget.email, code);
                              if (ok) {
                                Get.offAll(() => const AuthWrapper());
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: auth.isLoading.value
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Vérifier le code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  )),
              const SizedBox(height: 12),
              Obx(() => SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: auth.isLoading.value
                          ? null
                          : () async {
                              final confirmed = await auth.isEmailConfirmed();
                              if (confirmed) {
                                Get.offAll(() => const AuthWrapper());
                              } else {
                                Get.snackbar(
                                  'Non vérifié',
                                  'Votre email n\'est pas encore confirmé. Veuillez vérifier votre boîte mail.',
                                );
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('J\'ai cliqué sur le lien', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  )),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _resendCountdown > 0 ? null : _resendEmail,
                child: Text(
                  _resendCountdown > 0
                      ? 'Renvoyer dans ${_resendCountdown}s'
                      : 'Renvoyer l\'email',
                  style: TextStyle(
                    color: _resendCountdown > 0 ? Colors.grey : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Changer d\'email',
                  style: TextStyle(color: Colors.grey[600]),
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
