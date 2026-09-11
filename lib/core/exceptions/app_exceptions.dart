import 'package:chatme/core/errors/failure.dart';

/// Exceptions personnalisées pour une meilleure gestion d'erreurs
class AppException implements Exception {
  final String message;
  final int? code;
  final dynamic originalError;

  AppException(this.message, [this.code, this.originalError]);

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Exception lorsque la session expire
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(
      [this.message = 'Session expirée, reconnexion requise']);

  @override
  String toString() => 'SessionExpiredException: $message';
}

/// Exception lorsque les données sont obsolètes
class StaleDataException implements Exception {
  final String message;
  StaleDataException(
      [this.message = 'Données obsolètes, actualisation requise']);

  @override
  String toString() => 'StaleDataException: $message';
}

/// Exception de dépassement de taux (rate limit)
class RateLimitException implements Exception {
  final String message;
  final int retryAfter;
  RateLimitException({
    this.message = 'Trop de demandes, réessayez plus tard',
    this.retryAfter = 60,
  });

  @override
  String toString() =>
      'RateLimitException: $message (réessayez dans $retryAfter secondes)';
}

/// Exception de conflit de version
class VersionConflictException implements Exception {
  final String currentVersion;
  final String requiredVersion;
  VersionConflictException({
    required this.currentVersion,
    required this.requiredVersion,
  });

  @override
  String toString() =>
      'VersionConflictException: $currentVersion vs $requiredVersion';
}

/// Exception de dépendance manquante
class DependencyMissingException implements Exception {
  final String dependency;
  DependencyMissingException(this.dependency);

  @override
  String toString() => 'DependencyMissingException: $dependency manquant';
}

/// Conversion d'une Failure en AppException
extension FailureToAppException on Failure {
  AppException toAppException() {
    if (this is ServerFailure) {
      return AppException(message, 500, 'server_error');
    }
    if (this is AuthFailure) {
      return AppException(message, 401, 'auth_error');
    }
    if (this is ValidationFailure) {
      return AppException(message, 400, 'validation_error');
    }
    if (this is CacheFailure) {
      return AppException(message, 503, 'cache_error');
    }
    if (this is NetworkFailure) {
      return AppException(message, 500, 'network_error');
    }
    return AppException(message);
  }
}

/// Utilitaires pour le mappage des erreurs
class AppExceptions {
  static String mapAuthError(String error) {
    if (error.contains('email_not_confirmed')) {
      return 'Email non confirmé. Vérifiez votre boîte de réception';
    }
    if (error.contains('over_email_send_rate_limit')) {
      return 'Trop de demandes par email. Réessayez dans quelques minutes';
    }
    if (error.contains('invalid') || error.contains('Invalid')) {
      return 'Email ou mot de passe incorrect';
    }
    if (error.contains('rate limit') || error.contains('too many') || error.contains('over_')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes';
    }
    if (error.contains('expired') || error.contains('invalid token')) {
      return 'Code expiré ou invalide';
    }
    if (error.toLowerCase().contains('phone') &&
        (error.toLowerCase().contains('already') ||
            error.toLowerCase().contains('registered') ||
            error.toLowerCase().contains('exists'))) {
      return 'Ce numéro de téléphone est déjà associé à un compte';
    }
    if (error.toLowerCase().contains('already registered') ||
        error.toLowerCase().contains('already exists') ||
        error.toLowerCase().contains('already been registered') ||
        error.toLowerCase().contains('user already exists')) {
      return 'Cet email est déjà associé à un compte';
    }
    if (error.contains('weak password')) {
      return 'Mot de passe trop faible (min 6 caractères)';
    }
    if (error.contains('signup_disabled')) {
      return 'Inscription désactivée. Vérifiez Supabase Dashboard > Auth > Settings';
    }
    if (error.contains('email_address_invalid') || error.contains('invalid_email')) {
      return 'Adresse email invalide';
    }
    return 'Erreur: $error';
  }

  static String mapError(dynamic error) {
    if (error == null) return 'Une erreur est survenue';
    if (error is AppException) return error.message;
    return error.toString();
  }
}
