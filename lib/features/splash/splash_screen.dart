import 'dart:math';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _contentController;
  late final AnimationController _shimmerController;
  late final AnimationController _bubbleController;
  late final AnimationController _fadeOutController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _dotOpacity;

  final List<_BubbleData> _bubbles = [];

  @override
  void initState() {
    super.initState();

    // Suzuvchi pufakchalar ma'lumotlari
    final rng = Random(42);
    for (int i = 0; i < 12; i++) {
      _bubbles.add(_BubbleData(
        x: rng.nextDouble(),
        startY: 0.8 + rng.nextDouble() * 0.4,
        size: 8.0 + rng.nextDouble() * 40,
        speed: 0.15 + rng.nextDouble() * 0.25,
        opacity: 0.06 + rng.nextDouble() * 0.12,
        delay: rng.nextDouble() * 0.4,
      ));
    }

    // Logo animatsiyasi — scale + fade
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Logo glow animatsiyasi
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // Matn animatsiyalari — slide up + fade
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _dotOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Suzuvchi pufakchalar animatsiyasi
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // Shimmer effekt
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Fade-out animatsiyasi
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    _bubbleController.repeat();
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    _contentController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _shimmerController.repeat();

    // Splash tugashidan oldin fade-out
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    await _fadeOutController.forward();
    if (!mounted) return;

    widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _shimmerController.dispose();
    _bubbleController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeOutController,
        builder: (context, child) {
          return Opacity(
            opacity: 1.0 - _fadeOutController.value,
            child: child,
          );
        },
        child: Stack(
          children: [
            // Gradient fon
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB8AEFF),
                    Color(0xFF9685FF),
                    Color(0xFF7B68EE),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Radial gradient — chuqurlik effekti
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.3),
                    radius: 1.2,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Suzuvchi pufakchalar
            AnimatedBuilder(
              animation: _bubbleController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _BubblePainter(
                    bubbles: _bubbles,
                    progress: _bubbleController.value,
                  ),
                );
              },
            ),

            // Asosiy kontent
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo + glow
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow effekt
                        AnimatedBuilder(
                          animation: _logoController,
                          builder: (context, _) {
                            return Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(
                                      alpha: 0.25 * _glowOpacity.value,
                                    ),
                                    blurRadius: 60,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Logo container
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B68EE)
                                    .withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Ilova nomi
                  AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _titleSlide,
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: child,
                        ),
                      );
                    },
                    child: const Text(
                      "Topso'z",
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _subtitleSlide,
                        child: Opacity(
                          opacity: _subtitleOpacity.value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      "O'zbek-Ingliz-Rus lug'at",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Pastki qismdagi loading indikator
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_contentController, _shimmerController]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _dotOpacity.value,
                        child: child,
                      );
                    },
                    child: _LoadingDots(controller: _shimmerController),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Suzuvchi pufakcha ma'lumotlari
class _BubbleData {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;
  final double delay;

  const _BubbleData({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.delay,
  });
}

/// Pufakchalarni chizuvchi painter
class _BubblePainter extends CustomPainter {
  final List<_BubbleData> bubbles;
  final double progress;

  _BubblePainter({required this.bubbles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final t = (progress + bubble.delay) % 1.0;
      final y = bubble.startY - t * (bubble.startY + 0.2) * bubble.speed * 3;
      // Pufakcha ko'rinib-yo'qolishi
      final fadeIn = (t * 4).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - t) * 3).clamp(0.0, 1.0);
      final alpha = bubble.opacity * fadeIn * fadeOut;

      if (alpha <= 0) continue;

      // Gorizontal harakatlanish (sinusoidal)
      final dx = sin(t * pi * 2 + bubble.x * pi * 4) * 12;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(bubble.x * size.width + dx, y * size.height),
        bubble.size / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Uch nuqtali loading animatsiya
class _LoadingDots extends StatelessWidget {
  final AnimationController controller;

  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * _bounce(t);
            final opacity = 0.4 + 0.6 * _bounce(t);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _bounce(double t) {
    if (t < 0.5) return 4 * t * t * (3 - 4 * t);
    return 1 - 4 * (1 - t) * (1 - t) * (4 * t - 3);
  }
}
