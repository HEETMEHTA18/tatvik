import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final double blur;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 32, // Rounder forms for Liquid Glass
    this.padding,
    this.blur = 30, // Increased blur for better liquid glass effect
    this.opacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final double activeBlur = isMobileBrowser ? 16.0 : blur;

    final Color glassColor = isDark
        ? Colors.white.withValues(alpha: isMobileBrowser ? 0.05 : 0.08)
        : Colors.white.withValues(alpha: isMobileBrowser ? 0.35 : 0.45);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: OCLiquidGlassGroup(
          settings: OCLiquidGlassSettings(
            refractStrength: -0.05,
            blurRadiusPx: activeBlur > 0 ? activeBlur : 2.0,
            specStrength: 25.0,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: OCLiquidGlass(
                  borderRadius: borderRadius,
                  color: glassColor,
                  child: const SizedBox.expand(),
                ),
              ),
              Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
