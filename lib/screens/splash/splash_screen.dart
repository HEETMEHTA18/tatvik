import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/route_paths.dart';
import '../../widgets/liquid_glass_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToApp();
  }

  Future<void> _navigateToApp() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    context.go(RoutePaths.app);
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minimal Logo Mark
              Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accent, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 40,
                      color: AppTheme.accent,
                    ),
                  )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack)
                  .shimmer(delay: 800.ms, duration: 1500.ms),
              const SizedBox(height: 24),
              // Wordmark
              Text(
                'TATVIK',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                  letterSpacing: 4,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 60),
              // Scanning progress bar animation
              Container(
                width: 200,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(1),
                ),
                child: Stack(
                  children: [
                    Container(
                          width: 60,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .moveX(
                          begin: -60,
                          end: 200,
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
