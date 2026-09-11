import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/services/auth_service.dart';
import 'package:chatme/screens/home_screen.dart';
import 'package:chatme/screens/auth/phone_input_screen.dart';
import 'package:chatme/screens/auth/profile_setup_screen.dart';
import 'package:chatme/screens/auth/email_verification_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final auth = Get.find<AuthService>();

      if (auth.isInitializing.value) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (auth.currentUser.value == null) {
        return const PhoneInputScreen();
      }

      // Vérification email uniquement à la création de nouveau compte.
      // N'affiche plus le blocage systématique basé sur emailConfirmedAt (corrige le bug où l'app
      // restait sur "Vérifiez votre email" à chaque ouverture).
      // Utilise pendingVerificationEmail posé par signUpWithEmail et effacé après confirmation.
      if (auth.pendingVerificationEmail.value.isNotEmpty) {
        return EmailVerificationScreen(email: auth.pendingVerificationEmail.value);
      }

      if (auth.currentUser.value?.displayName == null ||
          auth.currentUser.value!.displayName!.isEmpty) {
        return const ProfileSetupScreen();
      }

      return const HomeScreen();
    });
  }
}
