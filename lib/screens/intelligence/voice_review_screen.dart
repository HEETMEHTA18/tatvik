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

class VoiceReviewScreen extends StatefulWidget {
  const VoiceReviewScreen({super.key});

  @override
  State<VoiceReviewScreen> createState() => _VoiceReviewScreenState();
}

class _VoiceReviewScreenState extends State<VoiceReviewScreen> {
  final _transcriptController = TextEditingController();
  final _repoController = TextEditingController(
    text: 'https://github.com/HEETMEHTA18/tatvik',
  );
  bool _isLoading = false;
  Map<String, dynamic>? _reviewData;
  String _errorMsg = '';

  Future<void> _runVoiceReview() async {
    final transcript = _transcriptController.text.trim();
    final repo = _repoController.text.trim();

    if (transcript.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _reviewData = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/voice-review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
        body: jsonEncode({
          'transcript': transcript,
          'repo_url': repo.isEmpty ? null : repo,
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
            _errorMsg = data['review_summary'] ?? 'Failed to run voice review.';
          });
        }
      } else {
        setState(() {
          _errorMsg = 'Failed to run voice review. Please try again.';
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
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$score',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
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
                    Icon(Icons.mic_rounded, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'VOICE CODE REVIEW',
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
                  'Talk to OpenClaw. Provide a voice transcript to trigger a contextual code review.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _transcriptController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Voice Transcript',
                    hintText:
                        'e.g. "Review the authentication logic and find security bugs"',
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: LiquidGlassButton(
                    onPressed: _isLoading ? null : _runVoiceReview,
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
                                'ANALYZING...',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.mic,
                                color: Colors.black,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'RUN VOICE REVIEW',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
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
          if (_reviewData != null) ...[
            const SizedBox(height: 24),
            Text(
              'Voice Review Scores',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 400;
                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildScoreRing('Security', _reviewData!['scores']?['security'] ?? 0, AppTheme.destructive),
                        _buildScoreRing('Performance', _reviewData!['scores']?['performance'] ?? 0, AppTheme.peach),
                        _buildScoreRing('Arch', _reviewData!['scores']?['architecture'] ?? 0, AppTheme.blue),
                        _buildScoreRing('Maint.', _reviewData!['scores']?['maintainability'] ?? 0, AppTheme.success),
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceAround,
                    children: [
                      _buildScoreRing('Security', _reviewData!['scores']?['security'] ?? 0, AppTheme.destructive),
                      _buildScoreRing('Performance', _reviewData!['scores']?['performance'] ?? 0, AppTheme.peach),
                      _buildScoreRing('Arch', _reviewData!['scores']?['architecture'] ?? 0, AppTheme.blue),
                      _buildScoreRing('Maint.', _reviewData!['scores']?['maintainability'] ?? 0, AppTheme.success),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Review Summary',
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
                _reviewData!['review_summary'] ?? '',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
