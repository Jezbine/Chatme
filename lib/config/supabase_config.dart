import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // S1 fix: plus de clé hardcodée seule — valeur par défaut gardée pour compat
  // mais surcharge via --dart-define=SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY
  // (ou SUPABASE_ANON_KEY). Voir .env.example
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zunviylosliunknpneph.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_mG2qOXX7Dzi4ZCxfDNZs3w_VUuqYiJt',
  );
  // Alias pour compatibilité avec anciens scripts --dart-define=SUPABASE_ANON_KEY
  static const String _anonKeyAlt = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get _effectiveKey =>
      publishableKey.isNotEmpty && !publishableKey.contains('placeholder')
          ? publishableKey
          : (_anonKeyAlt.isNotEmpty ? _anonKeyAlt : publishableKey);

  static Future<void> init() async {
    if (kDebugMode) {
      final usingDefault = url.contains('zunviylosliunknpneph');
      if (usingDefault) {
        debugPrint('[Supabase] Utilisation URL/key par défaut (dev). '
            'En prod, lancez avec --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...');
      }
    }
    await Supabase.initialize(
      url: url,
      publishableKey: _effectiveKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
