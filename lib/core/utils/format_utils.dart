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

  /// Sanitize pour TextSpan — remplace surrogates isolés (UTF-16 mal formé) par �
  static String sanitize(String? s) {
    if (s == null || s.isEmpty) return '';
    // Remplace high surrogate non suivi de low, et low non précédé de high
    return s.replaceAll(RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]'), '\uFFFD');
  }
}
