import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/route_paths.dart';

enum ShapeType { circleOutline, circleSolid, diamond, cross, wavyLine }

class FloatingShape {
  final ShapeType type;
  final Alignment baseAlignment;
  final double size;
  final double phaseOffset;
  final double speed;
  final double driftRadius;

  FloatingShape({
    required this.type,
    required this.baseAlignment,
    required this.size,
    required this.phaseOffset,
    this.speed = 1.0,
    this.driftRadius = 15.0,
  });
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _continuousController;
  late AnimationController _rippleController;
  late AnimationController _interactionController;
  late AnimationController _shimmerController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  Offset? _tapPosition;

  final List<FloatingShape> _floatingShapes = [
    FloatingShape(
      type: ShapeType.circleOutline,
      baseAlignment: const Alignment(-0.7, -0.5),
      size: 30,
      phaseOffset: 0.0,
      speed: 1.1,
      driftRadius: 12,
    ),
    FloatingShape(
      type: ShapeType.circleSolid,
      baseAlignment: const Alignment(-0.25, -0.65),
      size: 10,
      phaseOffset: 1.5,
      speed: 0.9,
      driftRadius: 8,
    ),
    FloatingShape(
      type: ShapeType.diamond,
      baseAlignment: const Alignment(0.65, -0.45),
      size: 16,
      phaseOffset: 3.1,
      speed: 1.3,
      driftRadius: 15,
    ),
    FloatingShape(
      type: ShapeType.wavyLine,
      baseAlignment: const Alignment(0.8, -0.15),
      size: 32,
      phaseOffset: 4.2,
      speed: 0.8,
      driftRadius: 10,
    ),
    FloatingShape(
      type: ShapeType.cross,
      baseAlignment: const Alignment(-0.6, 0.45),
      size: 18,
      phaseOffset: 2.0,
      speed: 1.2,
      driftRadius: 14,
    ),
    FloatingShape(
      type: ShapeType.circleOutline,
      baseAlignment: const Alignment(0.7, 0.55),
      size: 24,
      phaseOffset: 5.5,
      speed: 1.0,
      driftRadius: 11,
    ),
    FloatingShape(
      type: ShapeType.diamond,
      baseAlignment: const Alignment(-0.3, 0.7),
      size: 14,
      phaseOffset: 0.8,
      speed: 1.4,
      driftRadius: 13,
    ),
    FloatingShape(
      type: ShapeType.circleSolid,
      baseAlignment: const Alignment(0.25, 0.6),
      size: 8,
      phaseOffset: 2.7,
      speed: 0.95,
      driftRadius: 9,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _continuousController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _interactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _navigateToApp();
  }

  @override
  void dispose() {
    _continuousController.dispose();
    _rippleController.dispose();
    _interactionController.dispose();
    _shimmerController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _navigateToApp() async {
    await Future.delayed(const Duration(milliseconds: 4000));
    if (!mounted) return;
    context.go(RoutePaths.app);
  }

  void _handleTap(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _rippleController.forward(from: 0.0);
    _interactionController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? const Color(0xFF09090B) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: baseBg,
      body: GestureDetector(
        onTapDown: _handleTap,
        child: Stack(
          children: [
            // 1. Custom Geometry Background (Full screen)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _continuousController,
                  _rippleController,
                  _interactionController,
                ]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: SplashGeometryPainter(
                      animationValue: _continuousController.value,
                      tapPosition: _tapPosition,
                      interactionValue: _interactionController.value,
                      rippleProgress: _rippleController.value,
                      isDark: isDark,
                      accentColor: AppTheme.accent,
                      secondaryAccentColor: AppTheme.secondaryAccent,
                      peachColor: AppTheme.peach,
                      blueColor: AppTheme.blue,
                      borderColor: AppTheme.border,
                      floatingShapes: _floatingShapes,
                    ),
                  );
                },
              ),
            ),

            // 2. Central Glassmorphic Card containing the Gujarati text "તાત્ત્વિક"
            Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.25 : 0.45),
                        border: Border.all(
                          color: (isDark ? Colors.white : AppTheme.accent).withValues(alpha: isDark ? 0.15 : 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Shimmer reflection shine
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: AnimatedBuilder(
                                animation: _shimmerController,
                                builder: (context, child) {
                                  final double progress = _shimmerController.value;
                                  final double alignmentX = -2.5 + (progress * 5.0);
                                  return FractionallySizedBox(
                                    widthFactor: 0.4,
                                    alignment: Alignment(alignmentX, 0.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(alpha: 0.0),
                                            Colors.white.withValues(alpha: isDark ? 0.08 : 0.2),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // Text content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _glowAnimation,
                                  builder: (context, child) {
                                    return Text(
                                      'તાત્ત્વિક',
                                      style: GoogleFonts.notoSansGujarati(
                                        textStyle: TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textMain,
                                          letterSpacing: 2,
                                          shadows: [
                                            Shadow(
                                              color: (isDark ? AppTheme.secondaryAccent : AppTheme.accent)
                                                  .withValues(alpha: 0.3 + 0.45 * _glowAnimation.value),
                                              blurRadius: 8 + 14 * _glowAnimation.value,
                                              offset: const Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'TATVIK',
                                  style: GoogleFonts.jetBrainsMono(
                                    textStyle: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                      letterSpacing: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashGeometryPainter extends CustomPainter {
  final double animationValue;
  final Offset? tapPosition;
  final double interactionValue;
  final double rippleProgress;
  final bool isDark;
  final Color accentColor;
  final Color secondaryAccentColor;
  final Color peachColor;
  final Color blueColor;
  final Color borderColor;
  final List<FloatingShape> floatingShapes;

  SplashGeometryPainter({
    required this.animationValue,
    required this.tapPosition,
    required this.interactionValue,
    required this.rippleProgress,
    required this.isDark,
    required this.accentColor,
    required this.secondaryAccentColor,
    required this.peachColor,
    required this.blueColor,
    required this.borderColor,
    required this.floatingShapes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw Large Corner Gradient Circles (themed like the user's reference image)
    // Pulse scale factor (between 0.95 and 1.05)
    final pulse = 1.0 + 0.05 * math.sin(animationValue * 2 * math.pi * 2);

    // Top-Right Orb
    final trCenter = Offset(size.width, 0);
    final trRadius = size.width * 0.45 * pulse;
    final trGradientColors = isDark
        ? [secondaryAccentColor.withValues(alpha: 0.25), secondaryAccentColor.withValues(alpha: 0.0)]
        : [peachColor.withValues(alpha: 0.85), peachColor.withValues(alpha: 0.0)];

    final trPaint = Paint()
      ..shader = RadialGradient(colors: trGradientColors).createShader(
        Rect.fromCircle(center: trCenter, radius: trRadius),
      );
    canvas.drawCircle(trCenter, trRadius, trPaint);

    // Bottom-Left Orb
    final blCenter = Offset(0, size.height);
    final blRadius = size.width * 0.45 * pulse;
    final blGradientColors = isDark
        ? [accentColor.withValues(alpha: 0.25), accentColor.withValues(alpha: 0.0)]
        : [peachColor.withValues(alpha: 0.85), peachColor.withValues(alpha: 0.0)];

    final blPaint = Paint()
      ..shader = RadialGradient(colors: blGradientColors).createShader(
        Rect.fromCircle(center: blCenter, radius: blRadius),
      );
    canvas.drawCircle(blCenter, blRadius, blPaint);

    // 2. Draw Concentric Arcs / Rings (rotating slowly)
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = isDark ? accentColor.withValues(alpha: 0.3) : blueColor.withValues(alpha: 0.5);

    // Top-Right arcs rotating clockwise
    final trAngle = animationValue * 2 * math.pi * 0.05; // very slow rotation
    canvas.save();
    canvas.translate(trCenter.dx, trCenter.dy);
    canvas.rotate(trAngle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: size.width * 0.52),
      math.pi / 2,
      math.pi / 3,
      false,
      outlinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: size.width * 0.58),
      math.pi * 0.6,
      math.pi / 4,
      false,
      outlinePaint..strokeWidth = 1.0,
    );
    canvas.restore();

    // Bottom-Left arcs rotating counter-clockwise
    final blAngle = -animationValue * 2 * math.pi * 0.05;
    canvas.save();
    canvas.translate(blCenter.dx, blCenter.dy);
    canvas.rotate(blAngle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: size.width * 0.52),
      1.5 * math.pi,
      math.pi / 3,
      false,
      outlinePaint..strokeWidth = 1.5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: size.width * 0.6),
      1.6 * math.pi,
      math.pi / 5,
      false,
      outlinePaint..strokeWidth = 1.0,
    );
    canvas.restore();

    // 3. Draw Orbit Path & Node around the center
    final orbitRadius = size.width * 0.35;
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? Colors.white : accentColor).withValues(alpha: 0.15);

    // Draw dashed circle for the orbit path
    final int dashCount = 60;
    final double dashAngle = 2 * math.pi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: orbitRadius),
        i * dashAngle,
        dashAngle,
        false,
        orbitPaint,
      );
    }

    // Draw the Orbiting glowing Node (unique replacement for a loader)
    final nodeAngle = animationValue * 2 * math.pi;
    final nodeOffset = Offset(
      center.dx + orbitRadius * math.cos(nodeAngle),
      center.dy + orbitRadius * math.sin(nodeAngle),
    );

    // Node glowing paint
    final nodePaint = Paint()
      ..color = isDark ? secondaryAccentColor : accentColor;
    
    // Draw outer glow
    canvas.drawCircle(
      nodeOffset,
      8.0,
      Paint()
        ..color = (isDark ? secondaryAccentColor : accentColor).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );
    // Draw solid inner core
    canvas.drawCircle(nodeOffset, 4.0, nodePaint);

    // 4. Draw Floating Shapes (with custom drift & interactive force field)
    for (final shape in floatingShapes) {
      // Get base offset from fractional alignment
      final baseOffset = shape.baseAlignment.resolve(TextDirection.ltr).withinRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

      // Apply bobbing animation
      final bobAngle = animationValue * 2 * math.pi * shape.speed + shape.phaseOffset;
      final bobX = math.cos(bobAngle) * (shape.driftRadius / 2);
      final bobY = math.sin(bobAngle) * shape.driftRadius;
      
      Offset currentPos = baseOffset + Offset(bobX, bobY);

      // Apply tap force field displacement
      if (tapPosition != null && interactionValue > 0.0) {
        final toShape = currentPos - tapPosition!;
        final distance = toShape.distance;
        const maxDist = 220.0;
        if (distance < maxDist) {
          final forceFactor = math.sin(interactionValue * math.pi);
          final pushDist = (1.0 - (distance / maxDist)) * 50.0 * forceFactor;
          if (distance > 0) {
            currentPos += (toShape / distance) * pushDist;
          }
        }
      }

      // Draw the shape based on its type
      final shapePaint = Paint()
        ..color = (isDark ? secondaryAccentColor : accentColor).withValues(alpha: 0.65)
        ..strokeWidth = 1.5;

      switch (shape.type) {
        case ShapeType.circleOutline:
          shapePaint.style = PaintingStyle.stroke;
          canvas.drawCircle(currentPos, shape.size / 2, shapePaint);
          break;
        case ShapeType.circleSolid:
          shapePaint.style = PaintingStyle.fill;
          canvas.drawCircle(currentPos, shape.size / 2, shapePaint);
          break;
        case ShapeType.diamond:
          shapePaint.style = PaintingStyle.stroke;
          final path = Path()
            ..moveTo(currentPos.dx, currentPos.dy - shape.size / 2)
            ..lineTo(currentPos.dx + shape.size / 2, currentPos.dy)
            ..lineTo(currentPos.dx, currentPos.dy + shape.size / 2)
            ..lineTo(currentPos.dx - shape.size / 2, currentPos.dy)
            ..close();
          canvas.drawPath(path, shapePaint);
          break;
        case ShapeType.cross:
          shapePaint.style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(currentPos.dx - shape.size / 2, currentPos.dy),
            Offset(currentPos.dx + shape.size / 2, currentPos.dy),
            shapePaint,
          );
          canvas.drawLine(
            Offset(currentPos.dx, currentPos.dy - shape.size / 2),
            Offset(currentPos.dx, currentPos.dy + shape.size / 2),
            shapePaint,
          );
          break;
        case ShapeType.wavyLine:
          shapePaint.style = PaintingStyle.stroke;
          final path = Path();
          final startX = currentPos.dx - shape.size / 2;
          path.moveTo(startX, currentPos.dy);
          for (double x = 0; x <= shape.size; x += 2) {
            final yOffset = math.sin((x / shape.size) * 2 * math.pi * 1.2) * 3.5;
            path.lineTo(startX + x, currentPos.dy + yOffset);
          }
          canvas.drawPath(path, shapePaint);
          break;
      }
    }

    // 5. Draw Interactive Tap Ripple Effect
    if (tapPosition != null && rippleProgress > 0.0 && rippleProgress < 1.0) {
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = (isDark ? secondaryAccentColor : accentColor).withValues(alpha: 1.0 - rippleProgress);
      canvas.drawCircle(tapPosition!, rippleProgress * 180.0, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SplashGeometryPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.tapPosition != tapPosition ||
        oldDelegate.interactionValue != interactionValue ||
        oldDelegate.rippleProgress != rippleProgress;
  }
}
