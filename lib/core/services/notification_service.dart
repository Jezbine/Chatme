import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:chatme/services/messaging_service.dart';
import 'package:chatme/services/settings_service.dart';
import 'package:chatme/models/conversation.dart';
import 'package:chatme/screens/chat_screen.dart';

/// Service de notifications locales pour ChatMe.
/// - Canal Android "chatme_messages" (importance high, son activé)
/// - Affichage automatique sur nouveau message Realtime si l'app n'est pas dans la conversation
/// - Tap → ouvre la conversation
class NotificationService extends GetxService {
  static NotificationService get to => Get.find<NotificationService>();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Conversation actuellement ouverte (pour ne pas notifier dedans)
  final RxString currentOpenConversationId = ''.obs;

  Future<NotificationService> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    // Canal Android
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'chatme_messages',
        'Messages ChatMe',
        description: 'Notifications des nouveaux messages',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification'),
        playSound: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Permission Android 13+ et iOS
    await _requestPermission();

    _ready = true;
    if (kDebugMode) debugPrint('[Notification] prêt');
    return this;
  }

  Future<void> _requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
      // iOS déjà géré par DarwinInitializationSettings + Firebase
    } catch (e) {
      if (kDebugMode) debugPrint('[Notification] permission error: $e');
    }
  }

  void setCurrentConversation(String? convId) {
    currentOpenConversationId.value = convId ?? '';
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.isEmpty) return;
    try {
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          final messaging = Get.find<MessagingService>();
          final conv = messaging.conversations.firstWhereOrNull((c) => c.id == payload);
          if (conv != null) {
            _onTapDirect(conv);
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  // Lazy import pour éviter dépendance circulaire
  void _onTapDirect(Conversation conv) {
    try {
      Get.to(() => ChatScreen(conversation: conv));
    } catch (_) {}
  }

  Future<void> showMessageNotification({
    required String conversationId,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    if (currentOpenConversationId.value == conversationId) return;
    try {
      if (Get.isRegistered<SettingsService>()) {
        final s = Get.find<SettingsService>();
        if (!s.notifMessages.value || s.notifPaused.value) return;
      }
    } catch (_) {}

    const androidDetails = AndroidNotificationDetails(
      'chatme_messages',
      'Messages ChatMe',
      channelDescription: 'Notifications des nouveaux messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      id: conversationId.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: conversationId,
    );
    if (kDebugMode) debugPrint('[Notification] affichée $title -> $conversationId');
  }

  Future<void> cancelForConversation(String convId) async {
    await _plugin.cancel(id: convId.hashCode);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
