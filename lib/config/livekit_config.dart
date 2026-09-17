/// Configuration LiveKit Cloud pour ChatMe (Appels Audio & Vidéo).
///
/// SÉCURITÉ : Aucune clé secrète dans ce fichier.
/// Les tokens JWT sont générés UNIQUEMENT par la Supabase Edge Function `create-call-token`.
/// Pour le développement local, fournir via --dart-define :
///   flutter run --dart-define=LIVEKIT_URL=wss://...
class LiveKitConfig {
  /// URL WebSocket du serveur LiveKit Cloud (pas un secret — publique)
  static const String url = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://chat-me-yqn9lr8d.livekit.cloud',
  );

  /// URI SIP pour l'interconnexion téléphonie et routage d'appels
  static const String sipUri = String.fromEnvironment(
    'LIVEKIT_SIP_URI',
    defaultValue: 'sip:1ipsdjjvj99.sip.livekit.cloud',
  );

  /// Indique si le serveur LiveKit est configuré (URL non vide)
  static bool get isConfigured => url.isNotEmpty;

  // ⚠️  SUPPRIMÉ INTENTIONNELLEMENT :
  //  - apiKey / apiSecret (ne jamais embarquer dans le client)
  //  - generateToken()    (signature HMAC côté client = risque sécurité critique)
  //
  // Les tokens sont obtenus via :
  //   Supabase.instance.client.functions.invoke('create-call-token', ...)
  // Voir call_service.dart → _fetchCallToken()
}
