import 'package:flutter/foundation.dart';

/// Logger centralisé P1.10 - remplace debugPrint épars
/// En debug : print, en prod : envoi vers Sentry si configuré
class AppLogger {
  // ignore: unused_field
  static bool _sentryEnabled = false;

  static void d(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
  }

  static void i(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
    // TODO P2.9 : Sentry.captureMessage si _sentryEnabled
  }

  static void w(String tag, String msg, [Object? err]) {
    if (kDebugMode) debugPrint('[$tag] WARN $msg ${err ?? ""}');
  }

  static void e(String tag, String msg, [Object? err, StackTrace? st]) {
    debugPrint('[$tag] ERROR $msg ${err ?? ""}');
    // TODO P2.9 : Sentry.captureException(err, stackTrace: st)
  }

  static void enableSentry() => _sentryEnabled = true;
}
