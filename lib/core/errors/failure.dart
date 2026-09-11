/// Base failure class for all errors in the app
abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  String get userMessage => message;
}

/// Échec côté serveur (erreurs API, RLS, etc.)
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Erreur serveur'])
      : super(message: message);
}

/// Échec d'authentification (mauvais identifiants, session expirée, etc.)
class AuthFailure extends Failure {
  const AuthFailure([String message = 'Erreur d\'authentification'])
      : super(message: message);
}

/// Échec de validation des données (inputs invalides)
class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Données invalides'])
      : super(message: message);
}

/// Échec de cache ou de stockage (données obsolètes, conflit)
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Données obsolètes'])
      : super(message: message);
}

/// Échec de réseau (pas d'internet, timeout, etc.)
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Pas de connexion internet'])
      : super(message: message);
}

/// Échec spécifique à Supabase
class SupabaseFailure extends Failure {
  final dynamic error;
  SupabaseFailure(this.error, [String message = 'Erreur serveur'])
      : super(message: message);

  @override
  String get userMessage =>
      error is String ? error : 'Erreur serveur (code: ${error?.code})';
}
