import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showError(String message) {
  final text = message.trim();
  if (text.isEmpty) return;
  if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
  Get.snackbar(
    'Erreur',
    text,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.redAccent,
    colorText: Colors.white,
    duration: const Duration(seconds: 5),
    margin: const EdgeInsets.all(12),
  );
}

void showSuccess(String message) {
  final text = message.trim();
  if (text.isEmpty) return;
  Get.snackbar(
    'Succès',
    text,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.green,
    colorText: Colors.white,
    duration: const Duration(seconds: 3),
    margin: const EdgeInsets.all(12),
  );
}

void showInfo(String message) {
  final text = message.trim();
  if (text.isEmpty) return;
  Get.snackbar(
    'Info',
    text,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
    margin: const EdgeInsets.all(12),
  );
}
