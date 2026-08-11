import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

bool get _isWeb => kIsWeb;

class SafeOCLiquidGlassGroup extends StatelessWidget {
  final OCLiquidGlassSettings settings;
  final Widget child;

  const SafeOCLiquidGlassGroup({
    super.key,
    required this.settings,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (_isWeb) {
      return child;
    }
    return OCLiquidGlassGroup(
      settings: settings,
      child: child,
    );
  }
}

class SafeOCLiquidGlass extends StatelessWidget {
  final double borderRadius;
  final Color color;
  final double? width;
  final double? height;
  final Widget? child;

  const SafeOCLiquidGlass({
    super.key,
    this.borderRadius = 0.0,
    this.color = Colors.transparent,
    this.width,
    this.height,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (_isWeb) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: color,
        ),
        child: child,
      );
    }
    return OCLiquidGlass(
      borderRadius: borderRadius,
      color: color,
      width: width,
      height: height,
      child: child,
    );
  }
}
