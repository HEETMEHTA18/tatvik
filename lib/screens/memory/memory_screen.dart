import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_button.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  Map<String, dynamic>? _growthReport;
  Map<String, dynamic>? _badges;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    final token = state.token ?? '';
    final headers = {'Authorization': 'Bearer $token'};

    try {
      final growthRes = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/growth-report'),
        headers: headers,
      );
      final badgesRes = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/badges'),
        headers: headers,
      );

      setState(() {
        if (growthRes.statusCode == 200) _growthReport = jsonDecode(growthRes.body);
        if (badgesRes.statusCode == 200) _badges = jsonDecode(badgesRes.body);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: AppTheme.accent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('Memory', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textMain, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('Your knowledge graph, skills, and growth', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _buildBadgesSection(context),
                const SizedBox(height: 24),
                _buildGrowthSection(context),
                const SizedBox(height: 24),
                _buildCodebaseQASection(context),
                const SizedBox(height: 24),
                _buildSkillTimeline(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    final badges = _badges;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 10),
              Text('SKILL BADGES', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          if (badges == null)
            Text('Connect GitHub and complete reviews to earn badges.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
          else ...[
            if (badges['strongest_skill'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.accent.withValues(alpha: 0.1), AppTheme.neonPurple.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.emoji_events_rounded, color: AppTheme.accent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STRONGEST SKILL', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(badges['strongest_skill'] ?? '', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (badges['badges'] is List && (badges['badges'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('BADGES', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: (badges['badges'] as List).map((b) {
                  final name = b is Map ? (b['name'] ?? b.toString()) : b.toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.neonPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.3)),
                    ),
                    child: Text(name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.neonPurple)),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGrowthSection(BuildContext context) {
    final report = _growthReport;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppTheme.neonGreen, size: 18),
              const SizedBox(width: 10),
              Text('WEEKLY GROWTH', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          if (report == null)
            Text('Growth data will appear after AI reviews.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
          else ...[
            if (report['period'] != null)
              Text(report['period'], style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold)),
            if (report['skills_improved'] is List && (report['skills_improved'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('SKILLS IMPROVED', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.neonGreen, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(report['skills_improved'] as List).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.neonGreen),
                    const SizedBox(width: 8),
                    Text(s.toString(), style: TextStyle(fontSize: 13, color: AppTheme.textMain)),
                  ],
                ),
              )),
            ],
            if (report['recommendations'] is List && (report['recommendations'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('RECOMMENDATIONS', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.peach, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(report['recommendations'] as List).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.peach),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.toString(), style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                  ],
                ),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCodebaseQASection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 10),
              Text('CODEBASE MEMORY', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ask questions about your indexed repositories.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => _showCodebaseQA(context),
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('ASK YOUR CODEBASE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillTimeline(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: AppTheme.neonPurple, size: 18),
              const SizedBox(width: 10),
              Text('DEVELOPER TIMELINE', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('View your full developer journey with Cognee checkpoints.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const _TimelineScreen()));
              },
              color: AppTheme.neonPurple.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('VIEW TIMELINE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.neonPurple)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCodebaseQA(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Ask your Codebase', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller, autofocus: true, maxLines: 3,
                    style: TextStyle(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      hintText: 'e.g. How is auth implemented?',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: AppTheme.background,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: LiquidGlassButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _answerCodebaseQA(context, controller.text.trim());
                      },
                      color: AppTheme.accent, borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('ASK', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _answerCodebaseQA(BuildContext context, String query) {
    if (query.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchCodebaseAnswer(query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                }
                final answer = snapshot.data?['answer'] ?? 'No answer available.';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Answer', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Text(answer.toString(), style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Close', style: TextStyle(color: AppTheme.accent)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchCodebaseAnswer(String query) async {
    final state = Provider.of<AppState>(context, listen: false);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/codebase-qa'),
        headers: {
          'Authorization': 'Bearer ${state.token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'query': query}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {'answer': 'Failed to get answer. Make sure repositories are indexed.'};
  }
}

class _TimelineScreen extends StatelessWidget {
  const _TimelineScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Developer Timeline', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppTheme.textMain),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline_rounded, color: AppTheme.neonPurple, size: 18),
                      const SizedBox(width: 10),
                      Text('COGNEE CHECKPOINTS', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Your developer journey checkpoints will appear here as Cognee indexes your repositories.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 24),
                  Center(
                    child: Icon(Icons.hourglass_empty_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
