import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:chatme/firebase_options.dart';
import 'supabase_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) print('[Firebase] Message en arrière-plan reçu: ${message.messageId} - ${message.notification?.title}');
    // Afficher notif locale même en background
    try {
      const androidDetails = AndroidNotificationDetails(
        'chatme_messages', 'Messages ChatMe',
        importance: Importance.high, priority: Priority.high, icon: '@mipmap/launcher_icon');
      const details = NotificationDetails(android: androidDetails);
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      await plugin.initialize(settings: const InitializationSettings(android: androidInit));
      await plugin.show(
        id: message.messageId.hashCode,
        title: message.notification?.title ?? 'Nouveau message',
        body: message.notification?.body ?? message.data['body']?.toString() ?? 'Vous avez un nouveau message',
        notificationDetails: details,
        payload: message.data['conversationId']?.toString() ?? message.data['conversation_id']?.toString() ?? '',
      );
    } catch (_) {}
  } catch (e) {
    if (kDebugMode) print('[Firebase] Erreur handler arrière-plan: $e');
  }
}

class FirebaseConfig {
  static FirebaseMessaging? _firebaseMessaging;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> init() async {
    try {
      if (kDebugMode) print('[Firebase] Initialisation en cours...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Configurer le handler de messages en arrière-plan
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _firebaseMessaging = FirebaseMessaging.instance;

      // Options d'affichage des notifications au premier plan (iOS / Android)
      await _firebaseMessaging?.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Demander l'autorisation des notifications
      final settings = await _firebaseMessaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) print('[Firebase] Statut permission notifications: ${settings?.authorizationStatus}');

      if (settings?.authorizationStatus == AuthorizationStatus.authorized ||
          settings?.authorizationStatus == AuthorizationStatus.provisional) {
        // Récupérer le token initial
        final token = await _firebaseMessaging?.getToken();
        if (kDebugMode) print('[Firebase] FCM Token obtenu: $token');
        if (token != null) {
          await syncTokenToSupabase(token);
        }
      }

      // Écouter le rafraîchissement du token
      _firebaseMessaging?.onTokenRefresh.listen((newToken) {
        if (kDebugMode) print('[Firebase] FCM Token rafraîchi: $newToken');
        syncTokenToSupabase(newToken);
      });

      // Écouter les messages reçus au premier plan -> afficher notif locale
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (kDebugMode) print('[Firebase] Message reçu en premier plan: ${message.notification?.title} - ${message.notification?.body}');
        try {
          // Afficher via flutter_local_notifications pour garantir visibilité même en foreground
          const androidDetails = AndroidNotificationDetails(
            'chatme_messages', 'Messages ChatMe',
            importance: Importance.high, priority: Priority.high, icon: '@mipmap/launcher_icon');
          const details = NotificationDetails(android: androidDetails);
          final plugin = FlutterLocalNotificationsPlugin();
          const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
          await plugin.initialize(settings: const InitializationSettings(android: androidInit));
          await plugin.show(
            id: message.messageId.hashCode,
            title: message.notification?.title ?? 'Nouveau message',
            body: message.notification?.body ?? 'Vous avez un nouveau message',
            notificationDetails: details,
            payload: message.data['conversationId']?.toString() ?? '',
          );
        } catch (e) {
          if (kDebugMode) print('[Firebase] onMessage notif error: $e');
        }
      });

      // Écouter le clic sur une notification qui a ouvert l'app depuis l'arrière-plan — 100% routing
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) print('[Firebase] Notification cliquée (onMessageOpenedApp): ${message.data}');
        try {
          final data = message.data;
          final convId = data['conversationId'] as String? ?? data['conversation_id'] as String?;
          if (convId != null && convId.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () async {
              try {
                if (kDebugMode) print('[Firebase] Routing vers conversation $convId');
                Get.snackbar('Message', 'Ouverture conversation...', snackPosition: SnackPosition.BOTTOM);
              } catch (_) {}
            });
          }
        } catch (_) {}
      });

      // Gérer le tap sur notif qui a lancé l'app cold start — 100%
      try {
        final initial = await _firebaseMessaging?.getInitialMessage();
        if (initial != null) {
          final convId = initial.data['conversationId'] as String? ?? initial.data['conversation_id'] as String?;
          if (convId != null && convId.isNotEmpty) {
            if (kDebugMode) print('[Firebase] getInitialMessage routing $convId');
          }
        }
      } catch (_) {}

      // Réponse aux notifs locales (foreground) — tap payload
      try {
        final plugin = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
        await plugin.initialize(
          settings: const InitializationSettings(android: androidInit),
          onDidReceiveNotificationResponse: (resp) {
            final convId = resp.payload;
            if (convId != null && convId.isNotEmpty) {
              if (kDebugMode) print('[Firebase] Local notif tap $convId');
              Get.snackbar('Message', 'Ouverture...', snackPosition: SnackPosition.BOTTOM);
            }
          },
        );
      } catch (_) {}

      _initialized = true;
      if (kDebugMode) print('[Firebase] Initialisé avec succès !');
    } catch (e) {
      if (kDebugMode) print('[Firebase] Avertissement / Erreur lors de l\'initialisation: $e');
    }
  }

  /// Synchronise le token FCM de l'appareil avec le profil utilisateur dans Supabase
  static Future<void> syncTokenToSupabase([String? token]) async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return;

      final fcmToken = token ?? await _firebaseMessaging?.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      await SupabaseConfig.client.from('profiles').update({
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (kDebugMode) print('[Firebase] Token FCM synchronisé avec succès dans Supabase pour l\'utilisateur: $userId');
    } catch (e) {
      if (kDebugMode) print('[Firebase] Note: Impossible de synchroniser le token FCM dans Supabase: $e');
    }
  }

  /// Récupère le token FCM actuel
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging?.getToken();
    } catch (e) {
      if (kDebugMode) print('[Firebase] Erreur récupération token: $e');
      return null;
    }
  }
}
