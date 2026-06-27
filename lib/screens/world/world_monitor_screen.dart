import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

// Conditionally import the web implementation
import 'world_monitor_unsupported.dart'
    if (dart.library.html) 'world_monitor_web.dart';

class WorldMonitorScreen extends StatelessWidget {
  const WorldMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WorldMonitorWeb();
    }

    // Fallback UI for Native Desktop/Mobile builds
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_rounded, size: 64, color: AppTheme.accent),
            const SizedBox(height: 24),
            Text(
              'World Monitor',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Global context for engineering teams: Outages, disruptions, geopolitics, and more. '
                '(Currently requires Web Environment to load Dashboard)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
