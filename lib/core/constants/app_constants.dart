/// Application-wide constants for ChatMe
class AppConstants {
  // Application info
  static const String appName = 'ChatMe';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  // URLs et configurations Supabase — S1/S2 fix: via dart-define, jamais hardcodé seul
  // Source unique: SupabaseConfig (voir lib/config/supabase_config.dart)
  // Gardé ici pour compatibilité mais déprécié — préférer SupabaseConfig.url / publishableKey
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zunviylosliunknpneph.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_mG2qOXX7Dzi4ZCxfDNZs3w_VUuqYiJt',
  );
  // S2 fix: service_role JAMAIS côté client — supprimé. Utiliser Edge Functions côté serveur.

  // Clés Firebase
  static const String firebaseProjectId = 'chatme-benin';

  // Keys pour userMetadata Supabase
  static const String displayNameKey = 'display_name';
  static const String fullNameKey = 'full_name';
  static const String phoneKey = 'phone_number';
  static const String avatarUrlKey = 'avatar_url';
  static const String bioKey = 'bio';

  // Messages d'erreur utilisateur
  static const String errorNetwork = 'Pas de connexion internet';
  static const String errorServer = 'Erreur serveur, réessayez plus tard';
  static const String errorAuth = 'Erreur d\'authentification';
  static const String errorValidation = 'Données invalides';
  static const String successAction = 'Action effectuée avec succès';

  // Messages par défaut
  static const String defaultDisplayName = 'Utilisateur';
  static const String defaultBio = '';
  static const String initialsDefault = '?';

  // Configurations
  static const int minPasswordLength = 6;
  static const int minPhoneLength = 10;
  static const String phoneCountryCode = '+229';

  // Types de message
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeAudio = 'audio';
  static const String messageTypeVideo = 'video';
  static const String messageTypeFile = 'file';
  static const String messageTypeSystem = 'system';

  // Types de conversation
  static const String conversationTypeDirect = 'direct';
  static const String conversationTypeGroup = 'group';

  // États
  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusRead = 'read';
}
