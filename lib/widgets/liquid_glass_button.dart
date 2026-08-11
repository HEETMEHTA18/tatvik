import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import '../core/theme/app_theme.dart';
import 'web_safe_liquid_glass.dart';

class LiquidGlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final double? width;
  final double? height;

  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.borderRadius = 32,
    this.color,
    this.width,
    this.height,
  });

  factory LiquidGlassButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
    double borderRadius = 32,
    Color? color,
    double? width,
    double? height,
  }) {
    return LiquidGlassButton(
      key: key,
      onPressed: onPressed,
      padding: padding,
      borderRadius: borderRadius,
      color: color,
      width: width,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [icon, const SizedBox(width: 8), label],
      ),
    );
  }

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    // Setup base color
    final Color buttonBaseColor =
        widget.color ??
        (isDark
            ? AppTheme.accent.withValues(alpha: 0.15)
            : AppTheme.accent.withValues(alpha: 0.25));

    Widget content = Padding(padding: widget.padding, child: widget.child);

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(child: content),
      );
    }

    // Build the visual container with layered Apple Liquid Glass styles
    final glassContainer = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isMobileBrowser ? 12.0 : 20.0,
          sigmaY: isMobileBrowser ? 12.0 : 20.0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered
                ? buttonBaseColor.withValues(
                    alpha: (buttonBaseColor.a + 0.08).clamp(0.0, 1.0),
                  )
                : buttonBaseColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.40),
              width: 0.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Specular reflection gloss gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.15 : 0.40),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                ),
              ),
              // Apple/Xcode physical glossy top border lip highlight
              Positioned(
                top: 0.5,
                left: widget.borderRadius / 2,
                right: widget.borderRadius / 2,
                height: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: isDark ? 0.35 : 0.70),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: MouseRegion(
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Opacity(
              opacity: widget.onPressed == null ? 0.5 : 1.0,
              child: SafeOCLiquidGlassGroup(
                settings: const OCLiquidGlassSettings(
                  refractStrength: -0.06,
                  blurRadiusPx: 3.0,
                  specStrength: 30.0,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glass shader layer - decorative only, doesn't intercept taps
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SafeOCLiquidGlass(
                          borderRadius: widget.borderRadius,
                          color: Colors.transparent,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    glassContainer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
