import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'moving_ascii_background.dart';

class LiquidGlassBackground extends StatefulWidget {
  final Widget child;
  final double transitionProgress;

  const LiquidGlassBackground({
    super.key,
    required this.child,
    this.transitionProgress = 0.0,
  });

  @override
  State<LiquidGlassBackground> createState() => _LiquidGlassBackgroundState();
}

class _LiquidGlassBackgroundState extends State<LiquidGlassBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    // Light Theme Liquid Colors (iOS-inspired vibrant pastels with depth)
    final lightColors = [
      const Color(0xFFFF9EBB).withValues(alpha: 0.40), // Vibrant Pink
      const Color(0xFF8ECAE6).withValues(alpha: 0.50), // Ocean Blue
      const Color(0xFFD4B8FF).withValues(alpha: 0.45), // Soft Violet
      const Color(0xFF9BD9C7).withValues(alpha: 0.35), // Seafoam Mint
    ];

    // Dark Theme Liquid Colors (Glowing neon-like with deep liquid depth)
    final darkColors = [
      const Color(0xFF6366F1).withValues(alpha: 0.20), // Bright Indigo
      const Color(0xFFA855F7).withValues(alpha: 0.16), // Electric Violet
      const Color(0xFF22D3EE).withValues(alpha: 0.14), // Cyan Teal
      const Color(0xFFF472B6).withValues(alpha: 0.10), // Neon Pink
    ];

    final colors = isDark ? darkColors : lightColors;
    final baseBg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);

    if (isMobileBrowser) {
      final baseBg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);
      final colors = isDark ? darkColors : lightColors;

      return Scaffold(
        backgroundColor: baseBg,
        body: Stack(
          children: [
            // 1. Base background
            Positioned.fill(child: Container(color: baseBg)),

            // 2. Static Liquid Orbs/Blobs (no ticking animations, painted once for zero GPU load)
            // Orb 1 (Top Left)
            Positioned(
              top: -150,
              left: -100,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [colors[0], colors[0].withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),

            // Orb 2 (Bottom Right)
            Positioned(
              bottom: -200,
              right: -100,
              child: Container(
                width: 550,
                height: 550,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [colors[1], colors[1].withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),

            // Orb 3 (Center Right)
            Positioned(
              top: 250,
              right: -150,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [colors[2], colors[2].withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),

            // Orb 4 (Bottom Left/Center)
            Positioned(
              bottom: 100,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [colors[3], colors[3].withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),

            // 3. Static blur filter to blend colors beautifully
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: Container(color: Colors.transparent),
              ),
            ),

            // 3.5. Moving ASCII Background (which remains static on mobile browser)
            Positioned.fill(child: MovingAsciiBackground(isDark: isDark)),

            // 3b. Transition Glass Layer (visible when swiping/transitioning)
            if (widget.transitionProgress > 0.01)
              Positioned.fill(
                child: Opacity(
                  opacity: widget.transitionProgress.clamp(0.0, 1.0),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(
                      alpha: widget.transitionProgress * 0.2,
                    ),
                  ),
                ),
              ),

            // 4. Content Screen
            Positioned.fill(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: baseBg,
      body: Stack(
        children: [
          // 1a. Base Solid Color
          Positioned.fill(child: Container(color: baseBg)),

          // 2. Liquid Animated Orbs/Blobs
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value * 2 * math.pi;

              // Organic liquid motion using multiple sine waves at different frequencies
              // Creates a more natural, flowing movement like liquid
              final dx1 = 40 * math.sin(t * 0.7) + 15 * math.cos(t * 1.3);
              final dy1 = 30 * math.cos(t * 0.8) + 10 * math.sin(t * 1.1);

              final dx2 = 50 * math.cos(t * 0.6 + math.pi / 3) + 20 * math.sin(t * 1.4);
              final dy2 = 40 * math.sin(t * 0.9 + math.pi / 2) + 12 * math.cos(t * 1.2);

              final dx3 = 35 * math.sin(t * 0.5 + math.pi) + 18 * math.cos(t * 1.5);
              final dy3 = 45 * math.cos(t * 0.7 + math.pi) + 14 * math.sin(t * 1.1);

              final dx4 = 45 * math.cos(t * 0.8 + 3 * math.pi / 2) + 22 * math.sin(t * 1.3);
              final dy4 = 35 * math.sin(t * 0.6 + 3 * math.pi / 2) + 16 * math.cos(t * 1.2);

              return Stack(
                children: [
                  // Orb 1 (Top Left) - larger with slower, sweeping motion
                  Positioned(
                    top: -150 + dy1,
                    left: -100 + dx1,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [colors[0], colors[0].withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),

                  // Orb 2 (Bottom Right)
                  Positioned(
                    bottom: -200 + dy2,
                    right: -100 + dx2,
                    child: Container(
                      width: 600,
                      height: 600,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [colors[1], colors[1].withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),

                  // Orb 3 (Center Right)
                  Positioned(
                    top: 250 + dy3,
                    right: -150 + dx3,
                    child: Container(
                      width: 480,
                      height: 480,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [colors[2], colors[2].withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),

                  // Orb 4 (Bottom Left/Center)
                  Positioned(
                    bottom: 100 + dy4,
                    left: -150 + dx4,
                    child: Container(
                      width: 450,
                      height: 450,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [colors[3], colors[3].withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Blur Filter to blend the orbs smoothly into liquid
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 3.5. Moving ASCII Background
          Positioned.fill(child: MovingAsciiBackground(isDark: isDark)),

          // 3b. Transition Glass Layer (visible when swiping/transitioning)
          if (widget.transitionProgress > 0.01)
            Positioned.fill(
              child: Opacity(
                opacity: widget.transitionProgress.clamp(0.0, 1.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.transitionProgress * 25.0,
                    sigmaY: widget.transitionProgress * 25.0,
                  ),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(
                      alpha: widget.transitionProgress * 0.15,
                    ),
                  ),
                ),
              ),
            ),

          // 4. Content Screen
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}
