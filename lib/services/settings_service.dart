import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Combine les réglages typiques de WhatsApp, Instagram, WeChat et Facebook.
class SettingsService extends GetxService {
  static SettingsService get to => Get.find();

  // ---- Confidentialité & Sécurité ----
  final RxString lastSeen = 'contacts'.obs; // everyone | contacts | nobody
  final RxBool readReceipts = true.obs; // WhatsApp (accusés de lecture)
  final RxBool typingIndicator = true.obs; // WhatsApp
  final RxBool activityStatus = true.obs; // Instagram (statut en ligne)
  final RxBool twoStepVerification = false.obs; // WhatsApp
  final RxBool loginAlerts = true.obs; // Facebook
  final RxBool faceTagging = false.obs; // Facebook (reconnaissance faciale)
  final RxString momentsVisibility = 'contacts'.obs; // all | contacts | approved
  final RxBool addByQR = true.obs; // WeChat
  final RxString statusVisibility = 'contacts'.obs; // contacts | close_friends | custom

  // ---- Notifications ----
  final RxBool notifMessages = true.obs;
  final RxBool notifGroups = true.obs;
  final RxBool notifCalls = true.obs;
  final RxBool notifStory = true.obs; // Instagram
  final RxBool notifSound = true.obs;
  final RxBool notifVibrate = true.obs;
  final RxBool notifPreview = true.obs; // aperçu sur écran de verrouillage
  final RxBool notifPaused = false.obs; // Instagram (pause)

  // ---- Discussions & Appels ----
  final RxBool enterToSend = true.obs; // WhatsApp
  final RxString fontSize = 'medium'.obs; // small | medium | large
  final RxBool mediaAutoDownload = true.obs;
  final RxBool lowDataCalls = false.obs; // WhatsApp
  final RxBool callWaiting = true.obs;

  // ---- Portefeuille ----
  final RxBool paymentPassword = false.obs; // WeChat
  final RxBool fingerprintPay = false.obs; // WeChat / Meta Pay
  final RxBool txAlerts = true.obs; // alertes de transaction

  // ---- Compte & Affichage ----
  final RxString themeMode = 'system'.obs; // system | light | dark
  final RxString language = 'fr'.obs; // fr | en | fon
  final RxString region = 'BJ'.obs; // BJ | CI | SN | TG | CM | ...

  // ---- Session (style WhatsApp : reste connecté, appareils connectés) ----
  final RxBool stayConnected = true.obs; // Rester connecté (pas de déconnexion auto)
  final RxList<Map<String, String>> devices = <Map<String, String>>[
    {'name': 'Cet appareil', 'detail': 'ChatMe Mobile', 'current': 'true'},
  ].obs;

  Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    lastSeen.value = prefs.getString('s_lastSeen') ?? 'contacts';
    readReceipts.value = prefs.getBool('s_readReceipts') ?? true;
    typingIndicator.value = prefs.getBool('s_typingIndicator') ?? true;
    activityStatus.value = prefs.getBool('s_activityStatus') ?? true;
    twoStepVerification.value = prefs.getBool('s_twoStep') ?? false;
    loginAlerts.value = prefs.getBool('s_loginAlerts') ?? true;
    faceTagging.value = prefs.getBool('s_faceTagging') ?? false;
    momentsVisibility.value = prefs.getString('s_momentsVisibility') ?? 'contacts';
    addByQR.value = prefs.getBool('s_addByQR') ?? true;
    statusVisibility.value = prefs.getString('s_statusVisibility') ?? 'contacts';
    notifMessages.value = prefs.getBool('s_notifMessages') ?? true;
    notifGroups.value = prefs.getBool('s_notifGroups') ?? true;
    notifCalls.value = prefs.getBool('s_notifCalls') ?? true;
    notifStory.value = prefs.getBool('s_notifStory') ?? true;
    notifSound.value = prefs.getBool('s_notifSound') ?? true;
    notifVibrate.value = prefs.getBool('s_notifVibrate') ?? true;
    notifPreview.value = prefs.getBool('s_notifPreview') ?? true;
    notifPaused.value = prefs.getBool('s_notifPaused') ?? false;
    enterToSend.value = prefs.getBool('s_enterToSend') ?? true;
    fontSize.value = prefs.getString('s_fontSize') ?? 'medium';
    mediaAutoDownload.value = prefs.getBool('s_mediaAutoDownload') ?? true;
    lowDataCalls.value = prefs.getBool('s_lowDataCalls') ?? false;
    callWaiting.value = prefs.getBool('s_callWaiting') ?? true;
    paymentPassword.value = prefs.getBool('s_paymentPassword') ?? false;
    fingerprintPay.value = prefs.getBool('s_fingerprintPay') ?? false;
    txAlerts.value = prefs.getBool('s_txAlerts') ?? true;
    themeMode.value = prefs.getString('s_themeMode') ?? 'system';
    language.value = prefs.getString('s_language') ?? 'fr';
    region.value = prefs.getString('s_region') ?? 'BJ';
    stayConnected.value = prefs.getBool('s_stayConnected') ?? true;
    return this;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('s_lastSeen', lastSeen.value);
    await prefs.setBool('s_readReceipts', readReceipts.value);
    await prefs.setBool('s_typingIndicator', typingIndicator.value);
    await prefs.setBool('s_activityStatus', activityStatus.value);
    await prefs.setBool('s_twoStep', twoStepVerification.value);
    await prefs.setBool('s_loginAlerts', loginAlerts.value);
    await prefs.setBool('s_faceTagging', faceTagging.value);
    await prefs.setString('s_momentsVisibility', momentsVisibility.value);
    await prefs.setBool('s_addByQR', addByQR.value);
    await prefs.setString('s_statusVisibility', statusVisibility.value);
    await prefs.setBool('s_notifMessages', notifMessages.value);
    await prefs.setBool('s_notifGroups', notifGroups.value);
    await prefs.setBool('s_notifCalls', notifCalls.value);
    await prefs.setBool('s_notifStory', notifStory.value);
    await prefs.setBool('s_notifSound', notifSound.value);
    await prefs.setBool('s_notifVibrate', notifVibrate.value);
    await prefs.setBool('s_notifPreview', notifPreview.value);
    await prefs.setBool('s_notifPaused', notifPaused.value);
    await prefs.setBool('s_enterToSend', enterToSend.value);
    await prefs.setString('s_fontSize', fontSize.value);
    await prefs.setBool('s_mediaAutoDownload', mediaAutoDownload.value);
    await prefs.setBool('s_lowDataCalls', lowDataCalls.value);
    await prefs.setBool('s_callWaiting', callWaiting.value);
    await prefs.setBool('s_paymentPassword', paymentPassword.value);
    await prefs.setBool('s_fingerprintPay', fingerprintPay.value);
    await prefs.setBool('s_txAlerts', txAlerts.value);
    await prefs.setString('s_themeMode', themeMode.value);
    await prefs.setString('s_language', language.value);
    await prefs.setString('s_region', region.value);
    await prefs.setBool('s_stayConnected', stayConnected.value);
  }

  void applyTheme() {
    switch (themeMode.value) {
      case 'light':
        Get.changeThemeMode(ThemeMode.light);
        break;
      case 'dark':
        Get.changeThemeMode(ThemeMode.dark);
        break;
      default:
        Get.changeThemeMode(ThemeMode.system);
    }
  }
}
