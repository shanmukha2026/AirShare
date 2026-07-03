// lib/views/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'radar_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _fadeController;
  late AnimationController _scanController;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _fadeOut = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _fadeController.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const RadarScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fadeController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1218),
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, _) {
          return Opacity(
            opacity: (1.0 - _fadeOut.value).clamp(0.0, 1.0),
            child: Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated radar icon
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: AnimatedBuilder(
                        animation: _ringController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _SplashRadarPainter(
                              _ringController.value,
                              _scanController.value,
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App name
                    const Text(
                      "AirShare",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    const Text(
                      "Instant. Wireless. Free.",
                      style: TextStyle(
                        color: Colors.cyan,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Byline
                    const Text(
                      "Built by Pardhu",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading dots
                    _LoadingDots(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplashRadarPainter extends CustomPainter {
  final double ringProgress;
  final double scanAngle;

  _SplashRadarPainter(this.ringProgress, this.scanAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Background circle
    canvas.drawCircle(
      center,
      maxRadius,
      Paint()..color = const Color(0xFF0D1B26),
    );

    // Static rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        maxRadius * i / 3,
        Paint()
          ..color = Colors.cyan.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Animated pulse ring
    final pulseRadius = maxRadius * ringProgress;
    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = Colors.cyan.withOpacity((1 - ringProgress) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Sweep gradient
    final sweepAngle = scanAngle * 2 * pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 1.2,
        endAngle: sweepAngle,
        colors: [Colors.transparent, Colors.cyan.withOpacity(0.45)],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Scan line
    canvas.drawLine(
      center,
      Offset(
        center.dx + maxRadius * cos(sweepAngle),
        center.dy + maxRadius * sin(sweepAngle),
      ),
      Paint()
        ..color = Colors.cyan.withOpacity(0.9)
        ..strokeWidth = 1.5,
    );

    // Center dot
    canvas.drawCircle(
      center,
      5,
      Paint()..color = Colors.cyan,
    );
  }

  @override
  bool shouldRepaint(_SplashRadarPainter old) => true;
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final value = (((_ctrl.value - delay) % 1.0 + 1.0) % 1.0);
            final opacity = (sin(value * pi)).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.cyan,
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
}
