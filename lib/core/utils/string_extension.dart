/// Extensions pour les chaînes de caractères
extension StringExtension on String {
  /// Mise en majuscule du premier caractère
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';

  /// Mise en majuscule de chaque mot
  String get titleCase => split(' ').map((word) => word.capitalize).join(' ');

  /// Supprimer tous les blancs
  String get removeAllWhitespace =>
      replaceAll(' ', '').replaceAll('\n', '').replaceAll('\r', '');

  /// Garder seulement les caractères alphanumériques
  String get keepAlphanumeric => replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  /// Formatage téléphone (enlevant les caractères non numérique mais gardant +)
  String get formatPhone {
    final digits = replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    return '+$digits';
  }

  /// Vérifier si la chaîne est un email valide (regex de base)
  bool get isLikelyEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,3}$').hasMatch(this);

  /// Vérifier si la chaîne est un numéro de téléphone (au moins 8 chiffres)
  bool get isLikelyPhone => replaceAll(RegExp(r'[^\d]'), '').length >= 8;

  /// Couper avec des points de suspension si trop long
  String get truncate {
    const max = 30;
    if (length > max) return '${substring(0, max - 3)}...';
    return this;
  }

  /// Convertir en initiales (ex: "Jean Pierre" -> "JP")
  String get initials {
    final parts = split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (isNotEmpty) return this[0].toUpperCase();
    return '?';
  }

  /// Sanitise pour éviter LocaleDataException / UTF-16 mal formé (emojis)
  String get sanitized {
    try {
      // Vérifie si bien formé, sinon reconstruit via runes
      final runesList = runes.toList();
      final reconstructed = String.fromCharCodes(runesList);
      // Test rapide : si addText réussit, c'est ok
      return reconstructed;
    } catch (_) {
      try {
        return String.fromCharCodes(runes.where((r) => r < 0xD800 || r > 0xDFFF));
      } catch (_) {
        return replaceAll(RegExp(r'[\uFFFD]'), '');
      }
    }
  }
}
