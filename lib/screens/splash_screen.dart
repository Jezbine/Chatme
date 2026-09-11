import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chatme/screens/root_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;

  // Logo animations
  late Animation<double> _rotation;
  late Animation<double> _scale;
  late Animation<Offset> _slide;
  late Animation<double> _fadeLogo;
  late Animation<double> _pulse;

  // Text animations
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Rotation: 0 -> 1 tour complet avec ease
    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
      ),
    );

    // Scale: 0.5 -> 1.0 avec rebond
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    // Translation verticale du logo: -80 -> 0
    _slide = Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _fadeLogo = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Titre: translation + fade décalés
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.65, curve: Curves.easeIn),
      ),
    );

    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeIn),
      ),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    // Pulse subtil après l'entrée
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Navigation après 2.8s (laisse voir l'animation complète)
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) Get.offAll(const RootGate());
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              cs.primary.withValues(alpha: 0.85),
              const Color(0xFF2C2566),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO avec translation + rotation + scale + fade + pulse
              SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fadeLogo,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_mainController, _pulseController]),
                    builder: (context, child) {
                      final rot = _rotation.value * 2 * 3.1415926535;
                      final sc = _scale.value * (_mainController.isCompleted ? _pulse.value : 1.0);
                      return Transform.translate(
                        // micro translation horizontale pendulaire pendant rotation
                        offset: Offset(0, 0), // gardé pour extension future
                        child: Transform.rotate(
                          angle: rot,
                          child: Transform.scale(
                            scale: sc,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SvgPicture.asset(
                          'assets/icons/app_icon.svg',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          placeholderBuilder: (_) => Container(
                            color: Colors.white,
                            child: const Icon(Icons.chat_bubble_rounded, size: 54, color: Color(0xFF3C3489)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // TITRE avec translation + fade
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: const Text(
                    'ChatMe',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SlideTransition(
                position: _subtitleSlide,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: Column(
                    children: [
                      Text(
                        'Messagerie • Appels • Portefeuille',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Indicateur de chargement animé
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
