import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/services/lock_service.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/widgets/auth_wrapper.dart';
import 'package:chatme/screens/app_lock_screen.dart';

/// Porte de sécurité : affiche le verrouillage si activé et session ouverte.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final lock = LockService.to;
    final auth = AuthService.to;

    return Obx(() {
      final loggedIn = auth.currentUser.value != null;
      if (lock.enabled.value && lock.isLocked && loggedIn) {
        return AppLockScreen(
          mode: 'unlock',
          onSuccess: () => lock.markUnlocked(),
        );
      }
      return const AuthWrapper();
    });
  }
}
