import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/web_helper.dart';
import '../../routes/route_paths.dart';
import '../../widgets/liquid_glass_background.dart';
import '../../widgets/liquid_glass_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGithubLogin() async {
    setState(() => _isLoading = true);

    // Always fetch the OAuth config from the backend so the client_id and
    // redirect_uri match what GitHub has registered (no secrets in the app).
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/auth/github/oauth-config'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('oauth-config failed: ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final clientId = data['client_id'] as String? ?? '';
      final redirectUri = data['redirect_uri'] as String? ?? '';
      final scope = data['scope'] as String? ?? 'read:user,repo';
      if (clientId.isEmpty || redirectUri.isEmpty) {
        throw Exception('OAuth not configured on server');
      }
      final url =
          'https://github.com/login/oauth/authorize?client_id=$clientId'
          '&redirect_uri=${Uri.encodeQueryComponent(redirectUri)}'
          '&scope=${Uri.encodeQueryComponent(scope)}';
      openUrl(url);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GitHub login unavailable: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accent,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ready to grow?',
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect your GitHub to start your personalized journey with Tatvik.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                        ),
                      )
                    : Column(
                        children: [
                          LiquidGlassButton.icon(
                            onPressed: _handleGithubLogin,
                            icon: const Icon(Icons.hub_rounded),
                            label: Text(
                              'CONTINUE WITH GITHUB',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            width: double.infinity,
                            height: 60,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => context.push(RoutePaths.emailAuth),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              side: BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text(
                              'CONTINUE WITH EMAIL',
                              style: GoogleFonts.jetBrainsMono(
                                color: AppTheme.textMain,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                const Spacer(),
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 10),
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
