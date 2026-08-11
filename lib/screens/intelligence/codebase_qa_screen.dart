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

class CodebaseQAScreen extends StatefulWidget {
  const CodebaseQAScreen({super.key});

  @override
  State<CodebaseQAScreen> createState() => _CodebaseQAScreenState();
}

class _CodebaseQAScreenState extends State<CodebaseQAScreen> {
  final _questionController = TextEditingController();
  bool _isLoading = false;
  String? _answer;
  String _errorMsg = '';

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _answer = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/codebase-qa'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
        body: jsonEncode({'question': question}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _answer = data['answer'];
        });
      } else {
        setState(() {
          _errorMsg = 'Failed to get answer. Please try again.';
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
                    Icon(Icons.search_rounded, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'CODEBASE Q&A',
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
                  'Ask questions about the architecture, patterns, and logic of any repository you have onboarded.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _questionController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText:
                        'E.g., "Where is authentication handled in this repo?"',
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
                    onPressed: _isLoading ? null : _askQuestion,
                    color: AppTheme.accent,
                    borderRadius: 12,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ASK QUESTION',
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
          if (_answer != null) ...[
            const SizedBox(height: 24),
            Text(
              'Answer',
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
                _answer!,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
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
