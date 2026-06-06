import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

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

    // Light Theme Liquid Colors (Soft, vibrant pastels)
    final lightColors = [
      const Color(0xFFFFD1E1).withValues(alpha: 0.45), // Soft Pink
      const Color(0xFFC7E9FF).withValues(alpha: 0.55), // Soft Sky Blue
      const Color(0xFFE2D6FF).withValues(alpha: 0.5),  // Soft Lavender
      const Color(0xFFD3F4EC).withValues(alpha: 0.4),  // Soft Mint
    ];

    // Dark Theme Liquid Colors (Sleek, dark carbon & zinc hues)
    final darkColors = [
      const Color(0xFF27272A).withValues(alpha: 0.25), // Slate Gray
      const Color(0xFF3F3F46).withValues(alpha: 0.2),  // Medium Gray
      const Color(0xFF18181B).withValues(alpha: 0.35), // Carbon
      const Color(0xFF52525B).withValues(alpha: 0.15), // Silver Gray
    ];

    final colors = isDark ? darkColors : lightColors;
    final baseBg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);

    return Scaffold(
      backgroundColor: baseBg,
      body: Stack(
        children: [
          // 1a. Base Solid Color
          Positioned.fill(
            child: Container(color: baseBg),
          ),

          // 1b. Background Image Overlay (img.png)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.15 : 0.25,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const NetworkImage('/img.png'),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      debugPrint('Background image error: $exception');
                    },
                  ),
                ),
              ),
            ),
          ),

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
                          colors: [
                            colors[0],
                            colors[0].withValues(alpha: 0.0),
                          ],
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
                          colors: [
                            colors[1],
                            colors[1].withValues(alpha: 0.0),
                          ],
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
                          colors: [
                            colors[2],
                            colors[2].withValues(alpha: 0.0),
                          ],
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
                          colors: [
                            colors[3],
                            colors[3].withValues(alpha: 0.0),
                          ],
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
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

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
                    color: (isDark ? Colors.black : Colors.white)
                        .withOpacity(widget.transitionProgress * 0.15),
                  ),
                ),
              ),
            ),

          // 4. Content Screen
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
