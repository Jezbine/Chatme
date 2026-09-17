/// Validateurs réutilisables à travers l'application
class AppValidators {
  /// Validation pour numéro téléphone Bénin (+229)
  /// Plan national de numérotation à 10 chiffres (préfixe 01 pour les mobiles : MTN, Moov, Celtiis)
  static String? validateBeninPhone(String? value) {
    if (value == null || value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');

    String local = digits;
    if (local.startsWith('00229')) {
      local = local.substring(5);
    } else if (local.startsWith('229')) {
      local = local.substring(3);
    }

    // Format officiel 10 chiffres (commence par 01 pour mobile ou 02 pour fixe)
    if (local.length == 10) {
      if (!local.startsWith('01') && !local.startsWith('02')) {
        return 'Un numéro mobile béninois à 10 chiffres commence par 01';
      }
      return null;
    }

    // Ancien format 8 chiffres (accepté et normalisé automatiquement avec 01)
    if (local.length == 8) {
      return null;
    }

    return '10 chiffres requis (ex: 01 97 00 00 00)';
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
