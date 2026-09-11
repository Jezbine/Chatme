import 'dart:collection';

/// Rate limiter côté client P2.8 - anti-spam envoi messages / verify-fedapay
class RateLimiter {
  final int maxCalls;
  final Duration window;
  final Queue<DateTime> _calls = Queue<DateTime>();

  RateLimiter({this.maxCalls = 5, this.window = const Duration(seconds: 10)});

  bool tryCall() {
    final now = DateTime.now();
    while (_calls.isNotEmpty && now.difference(_calls.first) > window) {
      _calls.removeFirst();
    }
    if (_calls.length >= maxCalls) return false;
    _calls.add(now);
    return true;
  }
}
