/// Configuration centralisée FedaPay pour ChatMe (Mode LIVE).
/// Permet les paiements réels via FedaPay Live.
/// Surchargeable au build via: --dart-define=FEDA_API_KEY=... --dart-define=FEDA_ENV=live
class FedaPayConfig {
  /// Clé API FedaPay Live (sk_live_... ou pk_live_...).
  /// Peut être surchargée au build via: --dart-define=FEDA_API_KEY=sk_live_...
  static const String apiKey = String.fromEnvironment(
    'FEDA_API_KEY',
    defaultValue: '',
  );

  /// Environnement : 'live' par défaut (production / argent réel).
  /// Surchargeable via: --dart-define=FEDA_ENV=live
  static const String environment = String.fromEnvironment(
    'FEDA_ENV',
    defaultValue: 'live',
  );

  /// Indique si FedaPay est configuré en mode production (argent réel)
  static bool get isLive =>
      environment.toLowerCase() == 'live' ||
      apiKey.startsWith('sk_live_') ||
      apiKey.startsWith('pk_live_');

  /// Indique si une clé valide est renseignée
  static bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.contains('placeholder');

  /// URL de callback après paiement
  static const String callbackUrl = 'https://chatme.com/callback';
}
