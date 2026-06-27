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
      duration: const Duration(seconds: 25), // slow movement
    )..repeat(); // loop indefinitely
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

    // Light Theme Liquid Colors (Soft, vibrant pastels)
    final lightColors = [
      const Color(0xFFFFD1E1).withValues(alpha: 0.45), // Soft Pink
      const Color(0xFFC7E9FF).withValues(alpha: 0.55), // Soft Sky Blue
      const Color(0xFFE2D6FF).withValues(alpha: 0.5), // Soft Lavender
      const Color(0xFFD3F4EC).withValues(alpha: 0.4), // Soft Mint
    ];

    // Dark Theme Liquid Colors (Sleek, glowing, deep indigo, violet, and teal hues)
    final darkColors = [
      const Color(0xFF4F46E5).withValues(alpha: 0.18), // Deep Indigo
      const Color(0xFF7C3AED).withValues(alpha: 0.15), // Royal Violet
      const Color(0xFF06B6D4).withValues(alpha: 0.12), // Deep Teal
      const Color(0xFFEC4899).withValues(alpha: 0.08), // Muted Pink
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
              final val = _controller.value * 2 * math.pi;

              // Shift distances
              final dx1 = 40 * math.sin(val);
              final dy1 = 30 * math.cos(val);

              final dx2 = 50 * math.cos(val + math.pi / 2);
              final dy2 = 40 * math.sin(val + math.pi / 2);

              final dx3 = 35 * math.sin(val + math.pi);
              final dy3 = 45 * math.cos(val + math.pi);

              final dx4 = 45 * math.cos(val + 3 * math.pi / 2);
              final dy4 = 35 * math.sin(val + 3 * math.pi / 2);

              return Stack(
                children: [
                  // Orb 1 (Top Left)
                  Positioned(
                    top: -150 + dy1,
                    left: -100 + dx1,
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
                    bottom: -200 + dy2,
                    right: -100 + dx2,
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
                    top: 250 + dy3,
                    right: -150 + dx3,
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
                    bottom: 100 + dy4,
                    left: -150 + dx4,
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
                ],
              );
            },
          ),

          // 3. Blur Filter to blend the orbs smoothly
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
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
