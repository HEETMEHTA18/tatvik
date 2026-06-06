import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/web_helper.dart';
import '../../routes/route_paths.dart';
import '../../widgets/liquid_glass_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _handleGithubLogin() {
    setState(() => _isLoading = true);
    const clientId = 'Ov23liN1MaudLGibnAcW';
    final redirectUri = '${AppConfig.apiBaseUrl}/auth/github/callback';
    final url = 'https://github.com/login/oauth/authorize?client_id=$clientId&redirect_uri=$redirectUri&scope=read:user,repo';
    openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const SizedBox(height: 20),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 24),
              ),
              const Spacer(),
              Text(
                'Ready to grow?',
                style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.textMain, height: 1.1),
              ),
              const SizedBox(height: 16),
              Text(
                'Connect your GitHub to start your personalized journey with DevMentor.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 48),
              _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _handleGithubLogin,
                        icon: const Icon(Icons.hub_rounded),
                        label: Text('CONTINUE WITH GITHUB', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.push(RoutePaths.emailAuth),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          side: BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text('CONTINUE WITH EMAIL', style: GoogleFonts.jetBrainsMono(color: AppTheme.textMain, fontSize: 14)),
                      ),
                    ],
                  ),
              const Spacer(),
              Center(
                child: Text(
                  'By continuing, you agree to our Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
