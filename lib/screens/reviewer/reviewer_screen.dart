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

class ReviewerScreen extends StatefulWidget {
  const ReviewerScreen({super.key});

  @override
  State<ReviewerScreen> createState() => _ReviewerScreenState();
}

class _ReviewerScreenState extends State<ReviewerScreen> {
  final _pathController = TextEditingController(text: 'https://github.com/HEETMEHTA18/devmentor');
  bool _isLoading = false;
  Map<String, dynamic>? _reviewData;
  String _errorMsg = '';

  Future<void> _runReview() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _reviewData = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);
    
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/reviewer/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
        body: jsonEncode({
          'repo_url': path,
          'branch': 'main',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _reviewData = data;
          });
        } else {
          setState(() {
            _errorMsg = data['error'] ?? 'Unknown error occurred.';
          });
        }
      } else {
        setState(() {
          _errorMsg = 'Server error: ${response.statusCode}';
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

  Widget _buildScoreRing(String label, int score, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: score / 10,
                strokeWidth: 6,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$score/10',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
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
                    Icon(Icons.code_rounded, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'CONTINUOUS CODE REVIEWER',
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
                  'Provide a public GitHub repository URL to run a continuous code review using OpenClaw.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pathController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Repository URL',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
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
                    onPressed: _isLoading ? null : _runReview,
                    color: AppTheme.accent,
                    borderRadius: 12,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'RUN REVIEW',
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
              child: Text(
                _errorMsg,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_reviewData != null && _reviewData!['success'] == true) ...[
            const SizedBox(height: 24),
            Text(
              'Code Quality Scores',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildScoreRing('Security', _reviewData!['security_score'] ?? 0, AppTheme.destructive),
                  _buildScoreRing('Performance', _reviewData!['performance_score'] ?? 0, AppTheme.peach),
                  _buildScoreRing('Arch', _reviewData!['architecture_score'] ?? 0, AppTheme.blue),
                  _buildScoreRing('Maint.', _reviewData!['maintainability_score'] ?? 0, AppTheme.success),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Actionable Issues',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            if (_reviewData!['issues'] != null && (_reviewData!['issues'] as List).isNotEmpty)
              ...(_reviewData!['issues'] as List).map((issue) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.peach, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            issue.toString(),
                            style: TextStyle(
                              color: AppTheme.textMain,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })
            else
              const Text('No issues found. Great job!'),
            const SizedBox(height: 24),
            Text(
              'Overall Feedback',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                _reviewData!['summary'] ?? '',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 80),
          ]
        ],
      ),
    );
  }
}
