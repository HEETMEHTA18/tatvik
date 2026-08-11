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

class UIAuditScreen extends StatefulWidget {
  const UIAuditScreen({super.key});

  @override
  State<UIAuditScreen> createState() => _UIAuditScreenState();
}

class _UIAuditScreenState extends State<UIAuditScreen> {
  final _urlController = TextEditingController(text: 'https://heetmehta.me');
  final _focusController = TextEditingController(
    text: 'accessibility, responsiveness, UX',
  );
  bool _isLoading = false;
  Map<String, dynamic>? _auditData;
  String _errorMsg = '';

  Future<void> _runAudit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final focusAreas = _focusController.text
        .split(',')
        .map((e) => e.trim())
        .toList();

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _auditData = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/ui-audit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
        body: jsonEncode({'target_url': url, 'focus_areas': focusAreas}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _auditData = data;
          });
        } else {
          setState(() {
            _errorMsg = data['audit_report'] ?? 'Failed to run UI Audit.';
          });
        }
      } else {
        setState(() {
          _errorMsg = 'Failed to run UI audit. Please try again.';
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
                    Icon(Icons.desktop_mac_rounded, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE UI AUDIT',
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
                  'OpenClaw uses a browser plugin to navigate a live URL, take screenshots, and generate a UI report.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Target URL',
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
                  controller: _focusController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Focus Areas (comma separated)',
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
                    onPressed: _isLoading ? null : _runAudit,
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
                                'BROWSING & AUDITING...',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'RUN UI AUDIT',
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
          if (_auditData != null) ...[
            const SizedBox(height: 24),
            Text(
              'Audit Report',
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
                _auditData!['audit_report'] ?? '',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if ((_auditData!['issues_found'] as List?)?.isNotEmpty ??
                false) ...[
              Text(
                'Issues Found',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 12),
              ...(_auditData!['issues_found'] as List).map((issue) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.peach,
                          size: 20,
                        ),
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
              }),
            ],
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
