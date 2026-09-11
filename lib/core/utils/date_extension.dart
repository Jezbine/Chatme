/// Extensions pour les dates
extension DateExtension on DateTime {
  /// Format jour/mois/année (jj/MM/aaaa)
  String get formattedFrench =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';

  /// Format heure:minute
  String get formattedHour =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Format complet date + heure
  String get formattedFull => '$formattedFrench à $formattedHour';

  /// Format "il y a X temps" (il y a 5 minutes, hier, 2 jours, etc.)
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inDays > 365) {
      final years = diff.inDays ~/ 365;
      return 'il y a $years an${years > 1 ? 's' : ''}';
    }
    if (diff.inDays > 30) {
      final months = diff.inDays ~/ 30;
      return 'il y a $months mois';
    }
    if (diff.inDays > 0) {
      return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    }
    if (diff.inHours > 0) {
      return 'il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    }
    if (diff.inMinutes > 0) {
      return 'il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    }
    return 'À l\'instant';
  }

  /// Vérifier si cette date est aujourd'hui
  bool get isToday {
    final now = DateTime.now();
    return now.year == year && now.month == month && now.day == day;
  }

  /// Vérifier si cette date est hier
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return yesterday.year == year &&
        yesterday.month == month &&
        yesterday.day == day;
  }

  /// Vérifier si cette date est dans le futur
  bool get isFuture => isAfter(DateTime.now());

  /// Vérifier si cette date est dans le passé
  bool get isPast => isBefore(DateTime.now());

  /// Format compact pour affichage dans les listes
  String get compact => '${_monthAbbr[month] ?? ''} $day, $year';
}

extension DateTimeExtension on Object {
  /// Vérifier si l'objet est un DateTime
  bool get isDateTime => this is DateTime;
}

/// Month abbreviation map
const Map<int, String> _monthAbbr = {
  1: 'janv.',
  2: 'févr.',
  3: 'mars',
  4: 'avr.',
  5: 'mai',
  6: 'juin',
  7: 'juil.',
  8: 'août',
  9: 'sept.',
  10: 'oct.',
  11: 'nov.',
  12: 'déc.',
};
