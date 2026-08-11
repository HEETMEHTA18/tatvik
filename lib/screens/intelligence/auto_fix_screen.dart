import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_button.dart';

class AutoFixScreen extends StatefulWidget {
  const AutoFixScreen({super.key});

  @override
  State<AutoFixScreen> createState() => _AutoFixScreenState();
}

class _AutoFixScreenState extends State<AutoFixScreen> {
  final _repoController = TextEditingController(
    text: 'https://github.com/HEETMEHTA18/tatvik',
  );
  final _issuesController = TextEditingController();
  bool _isLoading = false;
  String? _successMsg;
  String? _prUrl;
  String _errorMsg = '';

  Future<void> _runAutoFix() async {
    final repo = _repoController.text.trim();
    final issuesRaw = _issuesController.text.trim();

    if (repo.isEmpty || issuesRaw.isEmpty) return;

    final issues = issuesRaw
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _successMsg = null;
      _prUrl = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/auto-fix'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
        body: jsonEncode({'repo_url': repo, 'issues': issues}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _successMsg = data['message'];
            _prUrl = data['pull_request_url'];
          });
        } else {
          setState(() {
            _errorMsg = data['message'] ?? 'Failed to create Auto-Fix PR.';
          });
        }
      } else {
        setState(() {
          _errorMsg = 'Failed to run auto-fix. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to connect: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.build_rounded, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'AUTO-FIX PR GENERATOR',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'OpenClaw AI will automatically clone your repo, attempt to fix the listed issues, and open a Pull Request.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _repoController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Repository URL',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.isDark
                        ? const Color(0x10FFFFFF)
                        : const Color(0x05000000),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _issuesController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Issues to fix (one per line)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.isDark
                        ? const Color(0x10FFFFFF)
                        : const Color(0x05000000),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: LiquidGlassButton(
                    onPressed: _isLoading ? null : _runAutoFix,
                    color: AppTheme.accent,
                    borderRadius: 12,
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'CLONING & FIXING...',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'GENERATE AUTO-FIX PR',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_errorMsg, style: const TextStyle(color: Colors.red)),
            ),
          if (_successMsg != null) ...[
            const SizedBox(height: 24),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Text(
                        'Success!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _successMsg!,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  ),
                  if (_prUrl != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'PR Link: $_prUrl',
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
