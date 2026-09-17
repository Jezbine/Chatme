import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/services/lock_service.dart';

class AppLockScreen extends StatefulWidget {
  final String mode; // 'unlock' | 'set'
  final VoidCallback? onSuccess;
  final void Function(String pin)? onPinSet;

  const AppLockScreen({
    super.key,
    this.mode = 'unlock',
    this.onSuccess,
    this.onPinSet,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LockService lock = LockService.to;
  String _pin = '';
  String _confirm = '';
  bool _setting = false; // phase confirmation lors de la création
  String _error = '';
  bool _checking = false;
  int _failCount = 0;
  DateTime? _lockedUntil;
  Timer? _cooldownTimer;

  bool get _locked =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  int get _remainingSeconds =>
      _lockedUntil != null ? _lockedUntil!.difference(DateTime.now()).inSeconds : 0;

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lockedUntil == null || !_lockedUntil!.isAfter(DateTime.now())) {
        t.cancel();
        if (mounted) {
          setState(() {
            _lockedUntil = null;
            _failCount = 0;
            _error = '';
          });
        }
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Auto-prompt biométrie si activée (comme WhatsApp)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.mode == 'unlock' && lock.biometric.value && lock.biometricAvailable.value && !_locked) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) await _useBiometric();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _onKey(String k) async {
    setState(() => _error = '');
    if (k == 'del') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 6) return;
    setState(() => _pin += k);

    if (widget.mode == 'set') {
      if (_pin.length == 4 && !_setting) {
        // passe à la confirmation
        await Future.delayed(const Duration(milliseconds: 120));
        setState(() {
          _confirm = _pin;
          _pin = '';
          _setting = true;
        });
      } else if (_setting && _pin.length == 4) {
        if (_pin == _confirm) {
          await lock.setPin(_pin);
          widget.onPinSet?.call(_pin);
          widget.onSuccess?.call();
        } else {
          setState(() {
            _error = 'Les codes ne correspondent pas';
            _pin = '';
            _confirm = '';
            _setting = false;
          });
        }
      }
      return;
    }

    // mode unlock
    if (_pin.length == 4) {
      setState(() => _checking = true);
      await Future.delayed(const Duration(milliseconds: 150));
      if (lock.verifyPin(_pin)) {
        lock.markUnlocked();
        widget.onSuccess?.call();
      } else {
        _failCount++;
        if (_failCount >= 5) {
          _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
          _startCooldown();
          setState(() {
            _error = 'Trop de tentatives. Réessayez dans 30 s';
            _pin = '';
            _checking = false;
          });
        } else {
          setState(() {
            _error = 'Code incorrect (${5 - _failCount} tentative(s) restante(s))';
            _pin = '';
            _checking = false;
          });
        }
      }
    }
  }

  Future<void> _useBiometric() async {
    final ok = await lock.authenticateBiometric();
    if (ok) {
      lock.markUnlocked();
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == 'set'
        ? (_setting ? 'Confirmez le code' : 'Choisissez un code')
        : 'ChatMe est verrouillé';
    final subtitle = widget.mode == 'set'
        ? 'Code confidentiel à 4 chiffres'
        : 'Déverrouillez pour accéder à vos conversations';

    final canGoBack = widget.mode == 'set' || (Navigator.canPop(context) && !lock.isLocked);

    return Scaffold(
      backgroundColor: ChatMeColors.violet,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  if (canGoBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.chat, size: 48, color: ChatMeColors.violet),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            // Pastilles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final active = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
                  ),
                );
              }),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('$_error${_locked ? ' ($_remainingSeconds s)' : ''}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              )
            else if (widget.mode == 'unlock' && !_locked)
              Obx(() => lock.biometric.value && lock.biometricAvailable.value
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: TextButton.icon(
                        onPressed: _useBiometric,
                        icon: const Icon(Icons.fingerprint, color: Colors.white),
                        label: const Text('Déverrouiller avec biométrie',
                            style: TextStyle(color: Colors.white)),
                      ),
                    )
                  : const SizedBox.shrink()),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'face', '0', 'del',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        childAspectRatio: 1.5,
        children: keys.map((k) {
          if (k == 'del') {
            return IconButton(
              onPressed: () => _onKey('del'),
              icon: const Icon(Icons.backspace_outlined, color: Colors.white),
            );
          }
          if (k == 'face') {
            return Obx(() => IconButton(
                  onPressed: widget.mode == 'unlock' && !_locked && lock.biometric.value && lock.biometricAvailable.value
                      ? _useBiometric
                      : null,
                  icon: Icon(Icons.fingerprint, color: widget.mode == 'unlock' && lock.biometric.value && lock.biometricAvailable.value ? Colors.white : Colors.white24),
                ));
          }
          return InkWell(
            onTap: (_checking || _locked) ? null : () => _onKey(k),
            child: Center(
              child: Text(
                k,
                style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
