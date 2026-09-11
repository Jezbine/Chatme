import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chatme/core/core.dart';
import 'package:chatme/config/supabase_config.dart';
import 'package:chatme/config/firebase_config.dart';
import 'package:chatme/models/user_profile.dart';
import 'package:chatme/services/lock_service.dart';
import 'package:chatme/services/messaging_service.dart';
import 'package:chatme/services/settings_service.dart';

class AuthService extends GetxService with WidgetsBindingObserver {
  static AuthService get to => Get.find<AuthService>();

  final SupabaseClient _client = SupabaseConfig.client;

  final Rx<UserProfile?> currentUser = Rx<UserProfile?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isInitializing = true.obs;
  final RxString errorMessage = ''.obs;
  // Vérification email uniquement à la création de compte, pas à chaque ouverture
  final RxString pendingVerificationEmail = ''.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initAuthListener();
    _checkCurrentSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updatePresence(true);
      startPresenceHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      updatePresence(false);
      _presenceTimer?.cancel();
    }
  }

  Timer? _presenceTimer;

  Future<void> init() async {
    if (kDebugMode) print('[AuthService] Initializing...');
    if (kDebugMode) print('[AuthService] Supabase initialized');
    // Restaurer l'état de vérification en attente (seulement si nouveau compte non confirmé)
    try {
      final prefs = await SharedPreferences.getInstance();
      pendingVerificationEmail.value = prefs.getString('pending_verification_email') ?? '';
      if (pendingVerificationEmail.value.isNotEmpty && kDebugMode) {
        print('[AuthService] pendingVerificationEmail restauré: ${pendingVerificationEmail.value}');
      }
    } catch (_) {}
  }

  Future<void> updatePresence(bool isOnline) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    // Respect du réglage activité (Instagram-like) : si désactivé, on ne diffuse pas
    try {
      if (Get.isRegistered<SettingsService>()) {
        final show = Get.find<SettingsService>().activityStatus.value;
        if (!show && isOnline) {
          if (kDebugMode) debugPrint('[Presence] activityStatus=false -> masqué');
          return;
        }
      }
    } catch (_) {}
    try {
      await _client.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      if (kDebugMode) debugPrint('[Presence] is_online=$isOnline');
    } catch (e) {
      if (kDebugMode) debugPrint('[Presence] update failed: $e');
    }
  }

  void startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    updatePresence(true);
    // Heartbeat toutes les 30s pour garder last_seen à jour
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => updatePresence(true));
  }

  void stopPresenceHeartbeat() {
    _presenceTimer?.cancel();
    updatePresence(false);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPresenceHeartbeat();
    super.onClose();
  }

  Future<void> _setPendingVerification(String email) async {
    pendingVerificationEmail.value = email;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_verification_email', email);
    } catch (_) {}
  }

  Future<void> clearPendingVerification() async {
    pendingVerificationEmail.value = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_verification_email');
    } catch (_) {}
  }

  void _initAuthListener() {
    _client.auth.onAuthStateChange.listen((data) async {
      if (kDebugMode) {
        print(
          '[AuthService] Auth state change: ${data.event}, session: ${data.session != null}');
      }
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        if (kDebugMode) print('[AuthService] User signed in: ${session.user.id}');
        // Si l'email vient d'être confirmé, on efface la vérification en attente
        if (session.user.emailConfirmedAt != null && pendingVerificationEmail.value.isNotEmpty) {
          await clearPendingVerification();
        }
        await _fetchUserProfile(session.user.id);
        startPresenceHeartbeat();
        Get.find<MessagingService>().loadConversations();
      } else if (event == AuthChangeEvent.signedOut) {
        if (kDebugMode) print('[AuthService] User signed out');
        stopPresenceHeartbeat();
        currentUser.value = null;
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        if (kDebugMode) print('[AuthService] Token refreshed');
        // Synchroniser emailConfirmedAt après refresh (évite de rester bloqué sur vérification)
        if (session?.user.emailConfirmedAt != null && pendingVerificationEmail.value.isNotEmpty) {
          await clearPendingVerification();
        }
      } else if (event == AuthChangeEvent.userUpdated) {
        if (session?.user.emailConfirmedAt != null) {
          await clearPendingVerification();
        }
      }
    });
  }

  Future<void> _checkCurrentSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        if (kDebugMode) print('[AuthService] Existing session found for: ${session.user.id}');
        await _fetchUserProfile(session.user.id);
        startPresenceHeartbeat();
        Get.find<MessagingService>().loadConversations();
      } else {
        if (kDebugMode) print('[AuthService] No existing session - showing phone input');
      }
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR checking session: $e');
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile', jsonEncode(profile.toJson()));
      await prefs.setString('cached_profile_id', profile.id);
    } catch (_) {}
  }

  Future<UserProfile?> _loadCachedProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_profile');
      final cachedId = prefs.getString('cached_profile_id');
      if (raw == null || cachedId != userId) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchUserProfile(String userId) async {
    try {
      if (kDebugMode) print('[AuthService] Fetching profile for user: $userId');
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        if (kDebugMode) print('[AuthService] Profile not found, creating...');
        await _ensureProfileExists(userId);
        return;
      }

      if (kDebugMode) print('[AuthService] Profile fetched: $response');
      final user = _client.auth.currentUser;
      final profile = UserProfile.fromJson({
        ...response,
        'email': user?.email ?? response['email'],
        'email_confirmed_at': user?.emailConfirmedAt,
      });
      currentUser.value = profile;
      await _cacheProfile(profile);
      // Si email déjà confirmé, on efface la vérification en attente (évite boucle)
      if (user?.emailConfirmedAt != null) await clearPendingVerification();

      FirebaseConfig.syncTokenToSupabase();
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR fetching profile: $e');
      final msg = e.toString();
      final isRecursion = msg.contains('42P17') || msg.contains('infinite recursion');
      // 42P17 = RLS récursive côté Supabase (SUPABASE_BLOQUANTS_FIX.sql) -> fallback cache + message clair
      if (isRecursion) {
        // Ne pas spammer l'UI avec le dump Postgres, utiliser cache et inviter à exécuter le fix SQL
        final cached = await _loadCachedProfile(userId);
        if (cached != null) {
          currentUser.value = cached;
          if (kDebugMode) print('[AuthService] Recursion 42P17 -> cache utilisé, attente fix SQL');
          return;
        }
        // Pas de cache : créer profil minimal depuis auth (évite boucle) sans upsert qui re-déclenche RLS
        final user = _client.auth.currentUser;
        if (user != null) {
          final fallback = UserProfile(
            id: userId,
            phoneNumber: user.phone ?? '',
            email: user.email ?? '',
            displayName: user.userMetadata?['display_name'] as String? ?? 'Utilisateur',
            emailConfirmedAt: user.emailConfirmedAt != null ? DateTime.tryParse(user.emailConfirmedAt!) : null,
          );
          currentUser.value = fallback;
          await _cacheProfile(fallback);
          return;
        }
      }
      // Fallback hors-ligne: charger cache si erreur réseau
      final isNetError = msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Network');
      if (isNetError) {
        final cached = await _loadCachedProfile(userId);
        if (cached != null) {
          if (kDebugMode) print('[AuthService] Loaded cached profile offline');
          currentUser.value = cached;
          return;
        }
      }
      await _ensureProfileExists(userId);
    }
  }

  Future<void> _ensureProfileExists(String userId) async {
    try {
      if (kDebugMode) print('[AuthService] Attempting to create missing profile...');
      final user = _client.auth.currentUser;
      if (user != null) {
        final displayName = user.userMetadata?['display_name'] ?? 'Utilisateur';
        final phone = user.phone ?? '';
        final email = user.email ?? '';

        try {
          await _client.from('profiles').upsert({
            'id': userId,
            'email': email,
            'phone_number': phone,
            'display_name': displayName,
          }, onConflict: 'id');
          if (kDebugMode) print('[AuthService] Profile created via upsert');
        } catch (upsertErr) {
          if (kDebugMode) print('[AuthService] Upsert failed (maybe email column missing): $upsertErr');
          try {
            await _client.from('profiles').upsert({
              'id': userId,
              'phone_number': phone,
              'display_name': displayName,
            }, onConflict: 'id');
            if (kDebugMode) print('[AuthService] Profile created via upsert (without email)');
          } catch (upsertErr2) {
            if (kDebugMode) print('[AuthService] Upsert without email also failed: $upsertErr2');
          }
        }

        try {
          final response =
              await _client.from('profiles').select().eq('id', userId).single();
          final loadedProfile = UserProfile.fromJson({
            ...response,
            'email': user.email ?? response['email'],
            'email_confirmed_at': user.emailConfirmedAt,
          });
          currentUser.value = loadedProfile;
          await _cacheProfile(loadedProfile);
          // Email confirmé -> on efface la vérification en attente
          if (user.emailConfirmedAt != null) await clearPendingVerification();
          if (kDebugMode) print('[AuthService] Profile loaded after ensure');
        } catch (fetchErr) {
          if (kDebugMode) print('[AuthService] Fallback: creating minimal profile from auth data');
          // Préserver emailConfirmedAt même en fallback RLS (sinon bloque sur vérification)
          final emailConfirmedAt = user.emailConfirmedAt != null
              ? DateTime.tryParse(user.emailConfirmedAt!)
              : null;
          final fallbackProfile = UserProfile(
            id: userId,
            phoneNumber: phone,
            email: email,
            displayName: displayName,
            emailConfirmedAt: emailConfirmedAt,
          );
          currentUser.value = fallbackProfile;
          await _cacheProfile(fallbackProfile);
          if (emailConfirmedAt != null) await clearPendingVerification();
        }
      }
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR creating profile: $e');
      errorMessage.value = e.toString();
    }
  }

  /// **Inscription avec email & mot de passe**
  /// Fix redirection: emailRedirectTo doit pointer vers le deep link de l'app
  /// Configurer Supabase Dashboard > Auth > URL Configuration > Redirect URLs = chatme://auth/callback, io.supabase.chatme://login-callback
  Future<bool> signUpWithEmail(
      String email, String password, String displayName) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (kDebugMode) print('[AuthService] Signing up with email: $email');

      const redirectUrl = String.fromEnvironment('SUPABASE_REDIRECT_URL', defaultValue: 'io.supabase.chatme://login-callback/');
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName, 'email': email},
        emailRedirectTo: redirectUrl,
      );

      if (kDebugMode) {
        print(
          '[AuthService] SignUp response: user=${response.user?.id}, session=${response.session != null}');
      }

      if (response.user != null) {
        final user = response.user!;
        final isConfirmed = user.emailConfirmedAt != null;
        final needsVerification = response.session == null && !isConfirmed;
        final newProfile = UserProfile(
          id: user.id,
          phoneNumber: user.phone ?? '',
          email: user.email ?? email,
          displayName: displayName,
          emailConfirmedAt: user.emailConfirmedAt != null
              ? DateTime.tryParse(user.emailConfirmedAt!)
              : null,
        );
        currentUser.value = newProfile;
        await _cacheProfile(newProfile);
        // Vérification uniquement à la création si session null (= email non confirmé)
        if (needsVerification) {
          await _setPendingVerification(user.email ?? email);
          if (kDebugMode) print('[AuthService] Nouveau compte non confirmé -> pendingVerification');
        } else {
          await clearPendingVerification();
        }

        try {
          await _client.from('profiles').upsert({
            'id': user.id,
            'phone_number': user.phone ?? '',
            'display_name': displayName,
          }, onConflict: 'id');
          if (kDebugMode) print('[AuthService] Profile created after signup');
        } catch (profileErr) {
          if (kDebugMode) print('[AuthService] Profile upsert after signup failed: $profileErr');
          try {
            await _client.from('profiles').upsert({
              'id': user.id,
              'phone_number': user.phone ?? '',
              'display_name': displayName,
              'email': user.email ?? email,
            }, onConflict: 'id');
            if (kDebugMode) print('[AuthService] Profile created after signup (with email)');
          } catch (profileErr2) {
            if (kDebugMode) print('[AuthService] Profile upsert with email also failed: $profileErr2');
          }
        }

        isLoading.value = false;
        return true;
      }

      errorMessage.value = 'Erreur lors de la création du compte';
      isLoading.value = false;
      return false;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] AuthException signUp: ${e.message} | Code: ${e.code}');
      }
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR signUp: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// **Connexion avec email**
  Future<bool> signInWithEmail(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (kDebugMode) print('[AuthService] Signing in with email: $email');

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print(
          '[AuthService] SignIn response: user=${response.user?.id}, session=${response.session != null}');
      }

      if (response.user != null) {
        await _fetchUserProfile(response.user!.id);
        // Connexion réussie = email déjà confirmé, on efface toute vérification en attente
        await clearPendingVerification();
        isLoading.value = false;
        return true;
      }

      errorMessage.value = 'Email ou mot de passe incorrect';
      isLoading.value = false;
      return false;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] AuthException signIn: ${e.message} | Code: ${e.code}');
      }
      // Si l'erreur indique email non confirmé, on met en attente vérification (création uniquement)
      if (e.message.toLowerCase().contains('confirm') || e.message.toLowerCase().contains('not confirmed')) {
        await _setPendingVerification(email);
      }
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR signIn: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// **Téléphone - Envoi OTP**
  /// Fix: si Twilio non configuré dans Supabase, message clair
  Future<bool> sendOtp(String phoneNumber) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final normalizedPhone = _normalizePhone(phoneNumber);
      if (kDebugMode) print('[AuthService] Sending SMS OTP to: $normalizedPhone');

      await _client.auth.signInWithOtp(
        phone: normalizedPhone,
        shouldCreateUser: true,
      );

      if (kDebugMode) print('[AuthService] SMS OTP sent successfully');
      isLoading.value = false;
      return true;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] AuthException sending OTP: ${e.message} | Code: ${e.code}');
      }
      // Fix: message explicite si SMS provider non configuré
      if (e.message.contains('SMS') || e.message.contains('phone') || e.message.contains('unsupported phone')) {
        errorMessage.value = 'SMS non configuré côté Supabase (Twilio manquant). Configurez Auth > SMS Provider ou utilisez Email.';
      } else {
        errorMessage.value = AppExceptions.mapAuthError(e.message);
      }
      isLoading.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR sending OTP: $e');
      final msg = e.toString();
      if (msg.contains('over_email_send_rate_limit') || msg.contains('429')) {
        errorMessage.value = 'Trop de demandes email (rate limit Supabase). Attendez 5 min ou configurez un SMTP custom dans Dashboard > Auth > SMTP.';
      } else {
        errorMessage.value = msg;
      }
      isLoading.value = false;
      return false;
    }
  }

  /// **Téléphone - Vérification OTP**
  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final normalizedPhone = _normalizePhone(phoneNumber);
      if (kDebugMode) print('[AuthService] Verifying OTP for: $normalizedPhone');

      final response = await _client.auth.verifyOTP(
        phone: normalizedPhone,
        token: otp,
        type: OtpType.sms,
      );

      if (kDebugMode) {
        print(
          '[AuthService] OTP verification response: user=${response.user?.id}, session=${response.session != null}');
      }

      if (response.user != null) {
        await _fetchUserProfile(response.user!.id);
        isLoading.value = false;
        return true;
      }

      errorMessage.value = 'Code invalide';
      isLoading.value = false;
      return false;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] AuthException verifying OTP: ${e.message} | Code: ${e.code}');
      }
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR verifying OTP: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// **Déconnexion**
  Future<void> signOut() async {
    try {
      if (kDebugMode) print('[AuthService] Signing out...');
      await _client.auth.signOut();
      currentUser.value = null;
      try {
        Get.find<LockService>().markLocked();
      } catch (_) {}
      if (kDebugMode) print('[AuthService] Signed out successfully');
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR signing out: $e');
      errorMessage.value = e.toString();
    }
  }

  /// **Mise à jour profil**
  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    if (currentUser.value == null) return false;

    isLoading.value = true;

    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('profiles')
          .update(updates)
          .eq('id', currentUser.value!.id)
          .timeout(const Duration(seconds: 10));

      currentUser.value = currentUser.value!.copyWith(
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      if (avatarUrl != null) await _cacheProfile(currentUser.value!);

      isLoading.value = false;
      return true;
    } on TimeoutException {
      errorMessage.value = 'Mise à jour du profil trop lente (réseau/Supabase).';
      isLoading.value = false;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// Upload photo de profil -> Supabase Storage (chat-media) + update profiles.avatar_url
  Future<bool> updateAvatar(String localPath) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || currentUser.value == null) return false;
    isLoading.value = true;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        errorMessage.value = 'Fichier introuvable';
        isLoading.value = false;
        return false;
      }
      final bytes = await file.readAsBytes();
      final ext = localPath.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$uid/avatar_$fileName';

      // Utiliser le bucket chat-media qui existe déja avec ses policies RLS
      final bucket = 'chat-media';
      await _client.storage.from(bucket).uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
      String url;
      try {
        url = _client.storage.from(bucket).getPublicUrl(storagePath);
      } catch (_) {
        url = await _client.storage.from(bucket).createSignedUrl(storagePath, 60 * 60 * 24 * 365);
      }
      final ok = await updateProfile(avatarUrl: url);
      isLoading.value = false;
      return ok;
    } catch (e) {
      errorMessage.value = 'Photo non envoyée: $e';
      isLoading.value = false;
      return false;
    }
  }

  /// **Inscription avec OTP email**
  /// Fix: emailRedirectTo pour redirection app + gestion rate limit
  Future<bool> sendEmailOtp(String email) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (kDebugMode) print('[AuthService] Sending email OTP to: $email');

      const redirectUrl = String.fromEnvironment('SUPABASE_REDIRECT_URL', defaultValue: 'io.supabase.chatme://login-callback/');
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectUrl,
      );

      if (kDebugMode) print('[AuthService] Email OTP sent successfully');
      isLoading.value = false;
      return true;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] AuthException email OTP: ${e.message} | Code: ${e.code}');
      }
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR email OTP: $e');
      final msg = e.toString();
      if (msg.contains('over_email_send_rate_limit') || msg.contains('429')) {
        errorMessage.value = 'Limite d\'envoi email atteinte (Supabase). Configurez SMTP custom ou attendez 10 min.';
      } else {
        errorMessage.value = msg;
      }
      isLoading.value = false;
      return false;
    }
  }

  /// **Réinitialisation mot de passe**
  Future<bool> resetPassword(String email) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      const redirectUrl = String.fromEnvironment('SUPABASE_REDIRECT_URL', defaultValue: 'io.supabase.chatme://login-callback/');
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
      isLoading.value = false;
      return true;
    } on AuthException catch (e) {
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// **Vérification email OTP**
  Future<bool> verifyEmailOtp(String email, String token) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (kDebugMode) print('[AuthService] Verifying email OTP for: $email');

      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (kDebugMode) {
        print(
          '[AuthService] Email OTP verification: user=${response.user?.id}, session=${response.session != null}');
      }

      if (response.user != null && response.session != null) {
        await _fetchUserProfile(response.user!.id);
        await clearPendingVerification();
        isLoading.value = false;
        return true;
      }

      errorMessage.value = 'Lien de confirmation invalide ou expiré';
      isLoading.value = false;
      return false;
    } on AuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] AuthException verifyEmailOtp: ${e.message} | Code: ${e.code}');
      }
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
      return false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR verifyEmailOtp: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
      return false;
    }
  }

  /// **Email confirmé ?**
  Future<bool> isEmailConfirmed() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final res = await _client.auth.getUser();
      final confirmed = res.user?.emailConfirmedAt != null;
      if (confirmed) await clearPendingVerification();
      return confirmed;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR checking email confirmed: $e');
      return false;
    }
  }

  /// **Renvoi email confirmation**
  Future<void> resendConfirmationEmail(String email) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (kDebugMode) print('[AuthService] Resending confirmation email to: $email');
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (kDebugMode) print('[AuthService] Confirmation email renvoyé');
      isLoading.value = false;
    } on AuthException catch (e) {
      if (kDebugMode) print('[AuthService] AuthException resend: ${e.message}');
      errorMessage.value = AppExceptions.mapAuthError(e.message);
      isLoading.value = false;
    } catch (e) {
      if (kDebugMode) print('[AuthService] ERROR resend: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  /// **Normalisation téléphone Benin**
  /// Numéros béninois : 10 chiffres, ne commençant pas par 01
  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    if (cleaned.startsWith('00')) {
      return '+${cleaned.substring(2)}';
    }

    if (cleaned.length == 10 && !cleaned.startsWith('01')) {
      return '+229$cleaned';
    }

    if (cleaned.length == 8) {
      return '+229$cleaned';
    }

    return '+229$cleaned';
  }
}

extension AppExceptionExtension on AppException {
  String get userMessage => toString();
}
