import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/settings_service.dart';
import 'package:chatme/services/lock_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/screens/app_lock_screen.dart';
import 'package:chatme/screens/security_policy_screen.dart';
import 'package:chatme/screens/auth/phone_input_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.to;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        title: const Text('Paramètres'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _Section(
              title: 'Confidentialité & Sécurité',
              icon: Icons.lock_outline,
              children: [
                _Choice(
                  title: 'Dernière vue et en ligne',
                  subtitle: 'Qui peut voir votre activité',
                  value: s.lastSeen.value,
                  options: const {'everyone': 'Tout le monde', 'contacts': 'Mes contacts', 'nobody': 'Personne'},
                  onChanged: (v) { s.lastSeen.value = v; s.save(); },
                ),
                _Toggle('Accusés de lecture (blue ticks)', '', s.readReceipts),
                _Toggle('Indicateur de saisie', '', s.typingIndicator),
                _Toggle('Statut d\'activité', '', s.activityStatus),
                const _TwoStepVerificationTile(),
                _Toggle('Alertes de connexion', '', s.loginAlerts),
                _Toggle('Reconnaissance faciale (tags)', '', s.faceTagging),
                _Choice(
                  title: 'Visibilité des Moments',
                  subtitle: '',
                  value: s.momentsVisibility.value,
                  options: const {'all': 'Tous', 'contacts': 'Mes contacts', 'approved': 'Contacts approuvés'},
                  onChanged: (v) { s.momentsVisibility.value = v; s.save(); },
                ),
                _Toggle('Ajout par QR', '', s.addByQR),
                _Choice(
                  title: 'Visibilité des statuts',
                  subtitle: '',
                  value: s.statusVisibility.value,
                  options: const {'contacts': 'Mes contacts', 'close_friends': 'Amis proches', 'custom': 'Personnalisé'},
                  onChanged: (v) { s.statusVisibility.value = v; s.save(); },
                ),
                Builder(builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                    return Obx(() => SwitchListTile(
                      title: Text('Verrouiller l\'application',
                          style: TextStyle(fontSize: 14, color: cs.onSurface)),
                      subtitle: Text('Code confidentiel au démarrage et en arrière-plan',
                          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                      value: LockService.to.enabled.value,
                      activeThumbColor: cs.primary,
                      onChanged: (v) async {
                        final lock = LockService.to;
                        if (v && !lock.hasPin) {
                          await Get.to(() => AppLockScreen(
                                mode: 'set',
                                onSuccess: () => Get.back(),
                              ));
                          if (lock.hasPin) {
                            await lock.setEnabled(true);
                            Get.snackbar('Sécurité', 'Verrouillage de l\'application activé',
                                snackPosition: SnackPosition.BOTTOM);
                          }
                        } else {
                          await lock.setEnabled(v);
                          Get.snackbar(
                            'Sécurité',
                            v ? 'Verrouillage de l\'application activé' : 'Verrouillage de l\'application désactivé',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      },
                    ));
                  },
                ),
                Builder(builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Obx(() {
                    final lock = LockService.to;
                    final canUseBiometric = lock.biometricAvailable.value && lock.enabled.value && lock.hasPin;
                    final subtitleText = !lock.hasPin
                        ? 'Définissez d\'abord un code de déverrouillage'
                        : !lock.biometricAvailable.value
                            ? 'Non disponible ou non configuré sur cet appareil'
                            : !lock.enabled.value
                                ? 'Activez d\'abord le verrouillage de l\'application'
                                : 'Empreinte digitale ou reconnaissance faciale';

                    return Column(
                      children: [
                        SwitchListTile(
                          title: Text('Déverrouillage biométrique',
                              style: TextStyle(fontSize: 14, color: cs.onSurface)),
                          subtitle: Text(subtitleText,
                              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                          value: lock.biometric.value && lock.enabled.value,
                          activeThumbColor: cs.primary,
                          onChanged: canUseBiometric
                              ? (v) async {
                                  if (v) {
                                    final ok = await lock.authenticateBiometric();
                                    if (ok) {
                                      await lock.setBiometric(true);
                                      Get.snackbar('Biométrie', 'Déverrouillage biométrique activé',
                                          snackPosition: SnackPosition.BOTTOM);
                                    } else {
                                      Get.snackbar('Biométrie', 'Authentification annulée ou empreinte non reconnue',
                                          snackPosition: SnackPosition.BOTTOM);
                                    }
                                  } else {
                                    await lock.setBiometric(false);
                                    Get.snackbar('Biométrie', 'Déverrouillage biométrique désactivé',
                                        snackPosition: SnackPosition.BOTTOM);
                                  }
                                }
                              : null,
                        ),
                        if (lock.biometric.value && lock.enabled.value)
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: ChatMeColors.cReactions),
                            title: const Text('Supprimer l\'empreinte',
                                style: TextStyle(fontSize: 14, color: ChatMeColors.cReactions)),
                            subtitle: Text('Retire l\'enregistrement biométrique',
                                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                            onTap: () async {
                              final confirm = await Get.dialog<bool>(
                                AlertDialog(
                                  title: const Text('Supprimer l\'empreinte ?'),
                                  content: const Text('Cela désactivera le déverrouillage biométrique. Vous pourrez le réactiver plus tard.'),
                                  actions: [
                                    TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
                                    TextButton(
                                      onPressed: () => Get.back(result: true),
                                      child: const Text('Supprimer', style: TextStyle(color: ChatMeColors.cReactions)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await lock.setBiometric(false);
                                Get.snackbar('Supprimé', 'Empreinte biométrique retirée', snackPosition: SnackPosition.BOTTOM);
                              }
                            },
                          ),
                      ],
                    );
                  });
                }),
                Builder(builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Obx(() {
                    final lock = LockService.to;
                    return Column(children: [
                      ListTile(
                        leading: Icon(Icons.pin_outlined, color: cs.primary),
                        title: Text('Code de déverrouillage',
                            style: TextStyle(fontSize: 14, color: cs.onSurface)),
                        subtitle: Text(
                          lock.hasPin ? 'Modifier le code secret à 4 chiffres' : 'Définir un code secret à 4 chiffres',
                          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                        onTap: () => Get.to(() => AppLockScreen(
                              mode: 'set',
                              onSuccess: () {
                                Get.back();
                                Get.snackbar('Code secret', 'Code de déverrouillage enregistré avec succès',
                                    snackPosition: SnackPosition.BOTTOM);
                              },
                            )),
                      ),
                      ListTile(
                        leading: Icon(Icons.policy_outlined, color: cs.primary),
                        title: Text('Politique de confidentialité',
                            style: TextStyle(fontSize: 14, color: cs.onSurface)),
                        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                        onTap: () => Get.to(() => const SecurityPolicyScreen()),
                      ),
                    ]);
                  });
                }),
              ],
            ),
            _Section(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              children: [
                _Toggle('Messages', '', s.notifMessages),
                _Toggle('Groupes', '', s.notifGroups),
                _Toggle('Appels', '', s.notifCalls),
                _Toggle('Réponses aux statuts', '', s.notifStory),
                _Toggle('Son', '', s.notifSound),
                _Toggle('Vibration', '', s.notifVibrate),
                _Toggle('Aperçu sur écran verrouillé', '', s.notifPreview),
                _Toggle('Pause des notifications', '', s.notifPaused),
              ],
            ),
            _Section(
              title: 'Discussions & Appels',
              icon: Icons.chat_bubble_outline,
              children: [
                _Toggle('Entrée pour envoyer', '', s.enterToSend),
                _Choice(
                  title: 'Taille du texte',
                  subtitle: '',
                  value: s.fontSize.value,
                  options: const {'small': 'Petit', 'medium': 'Moyen', 'large': 'Grand'},
                  onChanged: (v) { s.fontSize.value = v; s.save(); },
                ),
                _Toggle('Téléchargement auto des médias', '', s.mediaAutoDownload),
                _Toggle('Données réduites (appels)', '', s.lowDataCalls),
                _Toggle('Attente d\'appel', '', s.callWaiting),
              ],
            ),
            _Section(
              title: 'Portefeuille & Paiements',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                _Toggle('Code de paiement', '', s.paymentPassword),
                _Toggle('Paiement par empreinte', '', s.fingerprintPay),
                _Toggle('Alertes de transaction', '', s.txAlerts),
              ],
            ),
            _Section(
              title: 'Compte & Affichage',
              icon: Icons.tune,
              children: [
                const _ThemeSelector(),
                _Choice(
                  title: 'Langue',
                  subtitle: '',
                  value: s.language.value,
                  options: const {'fr': 'Français', 'en': 'English', 'fon': 'Fon'},
                  onChanged: (v) { s.language.value = v; s.save(); },
                ),
                _Choice(
                  title: 'Pays / Région',
                  subtitle: '',
                  value: s.region.value,
                  options: const {
                    'BJ': 'Bénin',
                    'CI': "Côte d'Ivoire",
                    'SN': 'Sénégal',
                    'TG': 'Togo',
                    'CM': 'Cameroun',
                  },
                  onChanged: (v) { s.region.value = v; s.save(); },
                ),
              ],
            ),
            _Section(
              title: 'Session & Appareils connectés',
              icon: Icons.devices_outlined,
              children: [
                _Toggle('Rester connecté', 'WhatsApp : la session est maintenue', s.stayConnected),
                const _DeviceList(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(Get.context!),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Se déconnecter de cet appareil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ChatMeColors.cReactions,
                        side: const BorderSide(color: ChatMeColors.cReactions),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'ChatMe - Super-app de messagerie et services.',
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: cs.outline),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(icon, color: cs.primary),
          title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: cs.onSurface)),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          children: children,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final RxBool rx;
  const _Toggle(this.title, this.subtitle, this.rx);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() => SwitchListTile(
          title: Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface)),
          subtitle: subtitle.isNotEmpty
              ? Text(subtitle, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant))
              : null,
          value: rx.value,
          activeThumbColor: cs.primary,
          onChanged: (v) { rx.value = v; SettingsService.to.save(); },
        ));
  }
}

class _TwoStepVerificationTile extends StatelessWidget {
  const _TwoStepVerificationTile();

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.to;
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      final isEnabled = s.twoStepVerification.value;

      return Column(
        children: [
          SwitchListTile(
            title: Text(
              'Vérification en deux étapes',
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
            subtitle: Text(
              isEnabled
                  ? 'Activée — Un code PIN à 6 chiffres protège votre compte'
                  : 'Désactivée — Exiger un code PIN lors de la reconnexion',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
            value: isEnabled,
            activeThumbColor: cs.primary,
            onChanged: (val) => _handleToggle(context, s, val),
          ),
          if (isEnabled)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              leading: Icon(Icons.password, size: 20, color: cs.primary),
              title: Text(
                'Modifier le code PIN (6 chiffres)',
                style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w600),
              ),
              trailing: Icon(Icons.chevron_right, size: 20, color: cs.primary),
              onTap: () => _showChangePinDialog(context, s),
            ),
        ],
      );
    });
  }

  void _handleToggle(BuildContext context, SettingsService s, bool enable) {
    if (enable) {
      _showEnablePinDialog(context, s);
    } else {
      _showDisablePinDialog(context, s);
    }
  }

  void _showEnablePinDialog(BuildContext context, SettingsService s) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Activer la vérification 2FA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Définissez un code PIN à 6 chiffres pour sécuriser votre compte.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Code PIN (6 chiffres)',
                      hintText: '••••••',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le code PIN',
                      hintText: '••••••',
                      prefixIcon: const Icon(Icons.lock_reset),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: ChatMeColors.cReactions, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();

                  if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
                    setState(() {
                      errorText = 'Le code PIN doit comporter exactement 6 chiffres.';
                    });
                    return;
                  }
                  if (pin != confirm) {
                    setState(() {
                      errorText = 'Les deux codes PIN ne correspondent pas.';
                    });
                    return;
                  }

                  await s.setTwoStepPin(pin);
                  Get.back();
                  Get.snackbar(
                    'Sécurité',
                    'Vérification en deux étapes activée avec succès',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withValues(alpha: 0.85),
                    colorText: Colors.white,
                  );
                },
                child: const Text('Activer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDisablePinDialog(BuildContext context, SettingsService s) {
    final pinController = TextEditingController();
    String? errorText;

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Désactiver la vérification 2FA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrez votre code PIN actuel pour désactiver la vérification en deux étapes.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Code PIN actuel',
                      hintText: '••••••',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: ChatMeColors.cReactions, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatMeColors.cReactions,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final valid = await s.verifyTwoStepPin(pin);
                  if (!valid) {
                    setState(() {
                      errorText = 'Code PIN incorrect.';
                    });
                    return;
                  }

                  await s.disableTwoStep();
                  Get.back();
                  Get.snackbar(
                    'Sécurité',
                    'Vérification en deux étapes désactivée',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: const Text('Désactiver'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, SettingsService s) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Changer le code PIN 2FA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: currentController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Ancien code PIN (6 chiffres)',
                      hintText: '••••••',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Nouveau code PIN (6 chiffres)',
                      hintText: '••••••',
                      prefixIcon: const Icon(Icons.key),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le nouveau code',
                      hintText: '••••••',
                      prefixIcon: const Icon(Icons.lock_reset),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: ChatMeColors.cReactions, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final cur = currentController.text.trim();
                  final newPin = newController.text.trim();
                  final confirm = confirmController.text.trim();

                  final validCur = await s.verifyTwoStepPin(cur);
                  if (!validCur) {
                    setState(() {
                      errorText = 'L\'ancien code PIN est incorrect.';
                    });
                    return;
                  }
                  if (!RegExp(r'^\d{6}$').hasMatch(newPin)) {
                    setState(() {
                      errorText = 'Le nouveau PIN doit comporter 6 chiffres.';
                    });
                    return;
                  }
                  if (newPin != confirm) {
                    setState(() {
                      errorText = 'Les nouveaux codes PIN ne correspondent pas.';
                    });
                    return;
                  }

                  await s.setTwoStepPin(newPin);
                  Get.back();
                  Get.snackbar(
                    'Sécurité',
                    'Code PIN 2FA modifié avec succès',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withValues(alpha: 0.85),
                    colorText: Colors.white,
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _Choice({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant))
          : null,
      trailing: PopupMenuButton<String>(
        initialValue: value,
        onSelected: onChanged,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(options[value] ?? value, style: TextStyle(fontSize: 12.5, color: cs.primary)),
              Icon(Icons.arrow_drop_down, color: cs.primary),
            ],
          ),
        ),
        itemBuilder: (_) => options.entries
            .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
      ),
    );
  }
}

/// Sélecteur 3 options Système / Clair / Sombre avec aperçu miniature — Spec §7
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.to;
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final current = s.themeMode.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_6, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Thème', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const Spacer(),
                Text(current == 'system' ? 'Système' : current == 'light' ? 'Clair' : 'Sombre',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ThemePreviewCard(
                  label: 'Système',
                  icon: Icons.brightness_auto,
                  selected: current == 'system',
                  onTap: () { s.themeMode.value = 'system'; s.applyTheme(); s.save(); },
                  // Aperçu mixte
                  bg: cs.surface,
                  surface: cs.surfaceContainerHighest,
                  primary: cs.primary,
                ),
                const SizedBox(width: 10),
                _ThemePreviewCard(
                  label: 'Clair',
                  icon: Icons.wb_sunny_outlined,
                  selected: current == 'light',
                  onTap: () { s.themeMode.value = 'light'; s.applyTheme(); s.save(); },
                  bg: ChatMeColors.bg,
                  surface: ChatMeColors.surface,
                  primary: ChatMeColors.violet,
                ),
                const SizedBox(width: 10),
                _ThemePreviewCard(
                  label: 'Sombre',
                  icon: Icons.nightlight_round,
                  selected: current == 'dark',
                  onTap: () { s.themeMode.value = 'dark'; s.applyTheme(); s.save(); },
                  bg: ChatMeColors.darkBg,
                  surface: ChatMeColors.darkSurface,
                  primary: ChatMeColors.darkPrimary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Transition douce : AnimatedSwitcher sur le label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                current == 'system'
                    ? 'Suit les réglages du téléphone'
                    : current == 'light'
                        ? 'Thème clair activé'
                        : 'Thème sombre activé',
                key: ValueKey(current),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color bg;
  final Color surface;
  final Color primary;
  const _ThemePreviewCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.bg,
    required this.surface,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: 0.10) : cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? cs.primary : cs.outline, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              // Mini aperçu : fond + carte + bulle
              Container(
                width: 56,
                height: 36,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: surface.computeLuminance() > 0.5 ? Colors.black12 : Colors.white12),
                ),
                child: Stack(
                  children: [
                    Positioned(left: 4, top: 4, right: 18, child: Container(height: 6, decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(3)))),
                    Positioned(right: 4, top: 12, left: 18, child: Container(height: 6, decoration: BoxDecoration(color: primary.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(3)))),
                    Positioned(right: 4, bottom: 4, child: Icon(icon, size: 10, color: primary)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? cs.primary : cs.onSurface)),
              if (selected) Icon(Icons.check_circle, size: 14, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = SettingsService.to;
    return Obx(() => Column(
          children: s.devices
              .map((d) => ListTile(
                    leading: Icon(Icons.smartphone, color: cs.primary),
                    title: Text(d['name'] ?? '', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                    subtitle: Text(d['detail'] ?? '', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                    trailing: d['current'] == 'true'
                        ? Text('Actif', style: TextStyle(fontSize: 12, color: cs.primary))
                        : TextButton(
                            onPressed: () {
                              s.devices.remove(d);
                              Get.snackbar('Session', 'Appareil déconnecté', snackPosition: SnackPosition.BOTTOM);
                            },
                            child: const Text('Déconnecter'),
                          ),
                  ))
              .toList(),
        ));
  }
}

Future<void> _confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Se déconnecter ?'),
      content: const Text('Vous serez déconnecté de cet appareil. Vos conversations resteront disponibles après reconnexion.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Se déconnecter', style: TextStyle(color: ChatMeColors.cReactions)),
        ),
      ],
    ),
  );
  if (ok == true) {
    await Get.find<AuthService>().signOut();
    Get.offAll(() => const PhoneInputScreen());
  }
}
