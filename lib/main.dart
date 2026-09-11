import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'config/supabase_config.dart';
import 'config/firebase_config.dart';
import 'core/theme/chatme_theme.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_service.dart';
import 'core/services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/messaging_service.dart';
import 'services/wallet_service.dart';
import 'services/moments_service.dart';
import 'services/contacts_service.dart';
import 'services/settings_service.dart';
import 'services/status_service.dart';
import 'services/lock_service.dart';
import 'services/call_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/phone_input_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/email_verification_callback_screen.dart';
import 'core/utils/ui_utils.dart';
import 'package:intl/date_symbol_data_local.dart';

final _appLinks = AppLinks();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix LocaleDataException: initialiser intl avant tout DateFormat
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('fr', null);
  await initializeDateFormatting('en', null);

  // 1) Config critiques en parallèle (Supabase + Firebase ne dépendent pas l'un de l'autre)
  await Future.wait([
    SupabaseConfig.init(),
    FirebaseConfig.init(),
  ]);

  // 2) DI — Offline d'abord (Hive + Connectivity avant tout accès réseau)
  Get.put(OfflineService());
  Get.put(ConnectivityService());
  Get.put(NotificationService());
  Get.put(AuthService());
  Get.put(MessagingService());
  Get.put(WalletService());
  Get.put(MomentsService());
  Get.put(ContactsService());
  Get.put(SettingsService());
  Get.put(StatusService());
  Get.put(LockService());
  Get.put(CallService());

  // 3) Inits critiques d'abord (offline + connectivity + auth + settings + notifications)
  await Get.find<OfflineService>().init();
  await Get.find<ConnectivityService>().init();
  await Get.find<NotificationService>().init();
  await Get.find<AuthService>().init();
  await Get.find<SettingsService>().init();

  await Future.wait([
    Get.find<MessagingService>().init(),
    Get.find<WalletService>().init(),
    Get.find<MomentsService>().init(),
    Get.find<ContactsService>().init(),
    Get.find<StatusService>().init(),
    Get.find<LockService>().init(),
  ]);

  // Tâche non critique reportée après le premier frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Get.find<StatusService>().removeExpired();
    _initDeepLinks();
  });

  _wireErrorPopups();

  runApp(const ChatMeApp());
}

void _wireErrorPopups() {
  void wire(RxString err) => ever(err, (String v) {
        if (v.isNotEmpty) {
          showError(v);
          err.value = '';
        }
      });
  wire(AuthService.to.errorMessage);
  wire(MessagingService.to.errorMessage);
  // Note: Wallet/Contacts/Moments/Status utilisent Get.snackbar direct + debugPrint;
  // TODO: leur ajouter RxString errorMessage pour unifier le wiring
}

void _initDeepLinks() {
  // Gérer les liens profonds en cours (ouvrir depuis une notification, etc.)
  _appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }, onError: (err) {
    if (kDebugMode) print('Deep link error: $err');
  });

  // Aussi gérer le lien initial au démarrage
  _appLinks.getInitialLink().then((Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }).catchError((err) {
    if (kDebugMode) print('Initial URI error: $err');
  });
}

void _handleDeepLink(Uri uri) {
  if (kDebugMode) print('[DeepLink] Received: $uri fragment=${uri.fragment} scheme=${uri.scheme} host=${uri.host}');

  // Fix redirection Supabase : gère 3 formats
  // 1) https://.../auth/v1/callback?token=...&type=signup&email=...
  // 2) io.supabase.chatme://login-callback/#access_token=...&refresh_token=... (fragment)
  // 3) chatme://auth/callback?code=... ou ?token_hash=...
  final isAuthCallback = uri.path.contains('/auth/v1/callback') ||
      uri.path.contains('/auth/callback') ||
      uri.host == 'login-callback' ||
      uri.fragment.contains('access_token') ||
      uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('token_hash');

  if (isAuthCallback) {
    // Cas fragment access_token (Supabase envoie en hash pour PKCE)
    if (uri.fragment.contains('access_token')) {
      final fragParams = Uri.splitQueryString(uri.fragment);
      final accessToken = fragParams['access_token'];
      final refreshToken = fragParams['refresh_token'];
      if (kDebugMode) print('[DeepLink] fragment tokens access=${accessToken != null} refresh=${refreshToken != null}');
      if (accessToken != null && refreshToken != null) {
        // Laisser Supabase récupérer la session via getSessionFromUrl est auto, mais on force refresh
        SupabaseConfig.client.auth.getSession().then((_) {
          Get.offAll(() => const HomeScreen());
        });
        return;
      }
    }
    final token = uri.queryParameters['token'] ?? uri.queryParameters['token_hash'] ?? uri.queryParameters['code'];
    final type = uri.queryParameters['type'];
    final email = uri.queryParameters['email'];

    if (kDebugMode) print('[DeepLink] Auth callback - token: ${token != null}, type: $type, email: $email');

    if (token != null) {
      // Si email présent, on passe par l'écran de vérification
      if (email != null) {
        Get.offAll(() => EmailVerificationCallbackScreen(email: email, token: token));
      } else {
        // Tentative directe verifyOtp avec token_hash (email OTP)
        Get.offAll(() => EmailVerificationCallbackScreen(email: '', token: token));
      }
    } else if (uri.queryParameters.containsKey('code')) {
      // PKCE code flow
      Get.offAll(() => const HomeScreen());
    }
  }
}

class ChatMeApp extends StatelessWidget {
  const ChatMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsService>();
    return Obx(() {
      ThemeMode themeMode;
      switch (settings.themeMode.value) {
        case 'light':
          themeMode = ThemeMode.light;
          break;
        case 'dark':
          themeMode = ThemeMode.dark;
          break;
        default:
          themeMode = ThemeMode.system;
      }

      return GetMaterialApp(
        title: 'ChatMe',
        debugShowCheckedModeBanner: false,
        theme: ChatMeTheme.light,
        darkTheme: ChatMeTheme.dark,
        themeMode: themeMode,
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SplashScreen()),
          GetPage(name: '/phone', page: () => const PhoneInputScreen()),
          GetPage(name: '/otp', page: () => OtpVerificationScreen(phoneNumber: Get.arguments)),
          GetPage(name: '/profile-setup', page: () => const ProfileSetupScreen()),
          GetPage(name: '/home', page: () => const HomeScreen()),
          GetPage(name: '/email-verify', page: () => EmailVerificationScreen(email: Get.arguments)),
        ],
        home: const SplashScreen(),
      );
    });
  }
}
