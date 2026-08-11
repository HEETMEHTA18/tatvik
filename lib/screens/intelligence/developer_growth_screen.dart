import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';

class DeveloperGrowthScreen extends StatefulWidget {
  const DeveloperGrowthScreen({super.key});

  @override
  State<DeveloperGrowthScreen> createState() => _DeveloperGrowthScreenState();
}

class _DeveloperGrowthScreenState extends State<DeveloperGrowthScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _growthData;
  Map<String, dynamic>? _badgeData;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final growthRes = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/growth-report'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
      );

      final badgeRes = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/badges'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${appState.token}',
        },
      );

      if (growthRes.statusCode == 200 && badgeRes.statusCode == 200) {
        setState(() {
          _growthData = jsonDecode(growthRes.body);
          _badgeData = jsonDecode(badgeRes.body);
        });
      } else {
        setState(() {
          _errorMsg = 'Failed to load data. Please try again.';
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Text(_errorMsg, style: const TextStyle(color: Colors.red)),
      );
    }

    final growth = _growthData!;
    final badges = _badgeData!;
    final scores = growth['average_scores'] ?? {};
    final earnedBadges =
        (badges['badges'] as List?)
            ?.where((b) => b['earned'] == true)
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Growth Report',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppTheme.textMain,
                ),
              ),
              Text(
                growth['period'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'Average Code Review Scores',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildScoreRing('Security', scores['security'] ?? 0, AppTheme.destructive),
                      _buildScoreRing('Performance', scores['performance'] ?? 0, AppTheme.peach),
                      _buildScoreRing('Arch', scores['architecture'] ?? 0, AppTheme.blue),
                      _buildScoreRing('Maint.', scores['maintainability'] ?? 0, AppTheme.success),
                    ],
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    _buildScoreRing('Security', scores['security'] ?? 0, AppTheme.destructive),
                    _buildScoreRing('Performance', scores['performance'] ?? 0, AppTheme.peach),
                    _buildScoreRing('Arch', scores['architecture'] ?? 0, AppTheme.blue),
                    _buildScoreRing('Maint.', scores['maintainability'] ?? 0, AppTheme.success),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Developer Skill Badges',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 12),
          if (earnedBadges.isEmpty)
            const GlassCard(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No badges earned yet. Complete more code reviews!',
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: earnedBadges.map((badge) {
                return GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        badge['icon'] ?? '',
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge['name'] ?? '',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textMain,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),
          Text(
            'Recommendations & Improvements',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendations:',
                  style: TextStyle(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if ((growth['recommendations'] as List).isNotEmpty)
                  ...(growth['recommendations'] as List).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $r',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'Keep up the good work!',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),

                const SizedBox(height: 16),
                Text(
                  'Recurring Mistakes to Avoid:',
                  style: TextStyle(
                    color: AppTheme.peach,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if ((growth['recurring_mistakes'] as List).isNotEmpty)
                  ...(growth['recurring_mistakes'] as List).map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $m',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'No recurring mistakes found!',
                    style: TextStyle(color: AppTheme.success, fontSize: 13),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
