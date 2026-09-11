/// Validateurs réutilisables à travers l'application
class AppValidators {
  /// Validation pour numéro téléphone Bénin (+229)
  /// Numéros béninois : 10 chiffres, ne commençant pas par 01
  static String? validateBeninPhone(String? value) {
    if (value == null || value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.startsWith('229')) {
      final local = digits.substring(3);
      if (local.length != 10) return '10 chiffres requis après +229';
      if (local.startsWith('01')) return 'Numéro invalide';
      return null;
    }

    if (digits.length == 10) {
      if (digits.startsWith('01')) return 'Numéro invalide';
      return null;
    }

    return '10 chiffres requis';
  }

  /// Validation pour adresse email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Format email invalide';
    return null;
  }

  /// Validation pour mot de passe (min 6 caractères)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis';
    if (value.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  /// Validation pour nom d'affichage (au moins 2 caractères)
  static String? validateDisplayName(String? value) {
    if (value == null || value.isEmpty) return 'Nom requis';
    if (value.trim().length < 2) {
      return 'Au moins 2 caractères';
    }
    return null;
  }

  /// Validation pour bio (optionnel, mais longueur max)
  static String? validateBio(String? value) {
    if (value != null && value.length > 500) return 'Bio trop longue (max 500 chars)';
    return null;
  }

  /// Validation générale champ requis
  static String? validateRequired(String? value, String champName) {
    if (value == null || value.trim().isEmpty) return '$champName requis';
    return null;
  }
}
