import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../widgets/auth_wrapper.dart';
import '../../services/auth_service.dart';
import '../../core/utils/app_validators.dart';
import 'email_verification_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'Connexion' : 'Créer un compte',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Entrez vos identifiants pour accéder à ChatMe'
                      : 'Remplissez le formulaire pour commencer',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nom d\'affichage',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => AppValidators.validateEmail(v?.trim()) ??
                      (v == null || v.trim().isEmpty ? 'Email requis' : null),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Mot de passe requis';
                    if (!_isLogin && v.length < 6) return 'Min 6 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _sendResetEmail(auth),
                      child: Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                Obx(() => SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading.value
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;

                                bool success;
                                if (_isLogin) {
                                  success = await auth.signInWithEmail(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                  );
                                } else {
                                  success = await auth.signUpWithEmail(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                    _nameController.text.trim(),
                                  );
                                }

                                if (success) {
                                  Get.offAll(() => const AuthWrapper());
                                } else {
                                  final err = auth.errorMessage.value.toLowerCase();
                                  if (err.contains('confirm')) {
                                    Get.offAll(() => EmailVerificationScreen(email: _emailController.text.trim()));
                                  } else if (err.contains('rate') || err.contains('trop de tentatives') || err.contains('trop de demandes')) {
                                    Get.snackbar('Limite atteinte', auth.errorMessage.value,
                                        duration: const Duration(seconds: 30),
                                        snackPosition: SnackPosition.BOTTOM);
                                  } else if (err.contains('déjà') || err.contains('already') || err.contains('associé')) {
                                    setState(() => _isLogin = true);
                                    Get.snackbar('Compte existant', 'Connectez-vous avec votre mot de passe',
                                        snackPosition: SnackPosition.BOTTOM);
                                  } else {
                                    Get.snackbar('Erreur', auth.errorMessage.value,
                                        snackPosition: SnackPosition.BOTTOM);
                                  }
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
                            : Text(
                                _isLogin ? 'Se connecter' : 'Créer mon compte',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    )),

                const SizedBox(height: 16),

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

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'Pas de compte ?' : 'Déjà un compte ?',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _isLogin = !_isLogin);
                        auth.errorMessage.value = '';
                      },
                      child: Text(_isLogin ? 'S\'inscrire' : 'Se connecter'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () => _sendEmailOtp(auth),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Recevoir un code par email (sans mot de passe)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendResetEmail(AuthService auth) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar('Erreur', 'Entrez votre email d\'abord');
      return;
    }
    await auth.resetPassword(email);
    Get.snackbar('Email envoyé', 'Vérifiez votre boîte de réception');
  }

  Future<void> _sendEmailOtp(AuthService auth) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar('Erreur', 'Entrez votre email d\'abord');
      return;
    }
    final success = await auth.sendEmailOtp(email);
    if (success) {
      Get.snackbar('Code envoyé', 'Vérifiez votre email pour le code à 6 chiffres');
    }
  }
}
