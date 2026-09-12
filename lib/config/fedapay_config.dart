/// Configuration centralisée FedaPay pour ChatMe.
/// Permet de basculer facilement entre Sandbox et Live.
class FedaPayConfig {
  /// Clé API FedaPay (sk_live_... pour transactions directes SDK)
  /// Peut être surchargée au build via: --dart-define=FEDA_API_KEY=sk_live_...
  static const String apiKey = String.fromEnvironment(
    'FEDA_API_KEY',
    defaultValue: 'sk_live_3S9-sh1MNdfKW0699mhdoVqq',
  );

  /// Environnement : 'live' pour les vrais paiements, 'sandbox' pour les tests
  /// Surchargeable via: --dart-define=FEDA_ENV=live
  static const String environment = String.fromEnvironment(
    'FEDA_ENV',
    defaultValue: 'live',
  );

  /// Indique si FedaPay est configuré en mode production (argent réel)
  static bool get isLive => environment.toLowerCase() == 'live';

  /// Indique si une clé valide est renseignée
  static bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.contains('placeholder');

  /// URL de callback après paiement
  static const String callbackUrl = 'https://chatme.com/callback';
}
