/// Helpers de formatage centralisés — fix duplication wallet/chat
class FormatUtils {
  /// 1200000 -> "1 200 000"
  static String fmtFcfa(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Formate un numéro béninois (10 chiffres, ex: +229 01 97 00 00 00)
  static String formatBeninPhone(String raw) {
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.startsWith('+') && !digits.startsWith('229')) {
      return raw;
    }
    String local = digits;
    String prefix = '+229';
    if (digits.startsWith('229')) {
      local = digits.substring(3);
    }
    final buffer = StringBuffer();
    for (int i = 0; i < local.length; i++) {
      if (i > 0 && i % 2 == 0) buffer.write(' ');
      buffer.write(local[i]);
    }
    return '$prefix ${buffer.toString()}'.trim();
  }

  /// Sanitize pour TextSpan — remplace surrogates isolés (UTF-16 mal formé) par 
  static String sanitize(String? s) {
    if (s == null || s.isEmpty) return '';
    // Remplace high surrogate non suivi de low, et low non précédé de high
    return s.replaceAll(RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]'), '\uFFFD');
  }
}
