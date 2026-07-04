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
import '../prompts/prompt_hub_screen.dart';
import '../mentor/task_command_screen.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  List<dynamic> _tools = [];
  bool _loadingTools = true;

  @override
  void initState() {
    super.initState();
    _fetchTools();
  }

  Future<void> _fetchTools() async {
    final state = Provider.of<AppState>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/v1/openclaw/tools'),
        headers: {'Authorization': 'Bearer ${state.token ?? ''}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _tools = data['data'] ?? [];
          _loadingTools = false;
        });
      } else {
        setState(() => _loadingTools = false);
      }
    } catch (_) {
      setState(() => _loadingTools = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchTools,
        color: AppTheme.accent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('Studio', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textMain, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text('Build agents, manage prompts, and automate workflows',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              _buildAgentSection(context),
              const SizedBox(height: 24),
              _buildOpenClawSection(context),
              const SizedBox(height: 24),
              _buildPromptHubSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.smart_toy_rounded, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text('AI AGENTS', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Tatvik has 11 specialized agents: Scout, Scholar, Mentor, Reviewer, Architect, Guardian, Memory, Navigator, Career, Trend, and more.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _agentChip('Scout', Icons.explore_rounded, AppTheme.accent),
              _agentChip('Scholar', Icons.menu_book_rounded, AppTheme.neonPurple),
              _agentChip('Mentor', Icons.psychology_rounded, AppTheme.neonGreen),
              _agentChip('Reviewer', Icons.rate_review_rounded, AppTheme.peach),
              _agentChip('Architect', Icons.account_tree_rounded, AppTheme.blue),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskCommandScreen())),
              color: AppTheme.accent,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('TATVIK PLANNER', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agentChip(String name, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildOpenClawSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.neonPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.bolt_rounded, color: AppTheme.neonPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text('OPENCLAW AUTOMATION', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingTools)
            const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
          else if (_tools.isEmpty)
            Text('No tools available.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
          else ...[
            Text('${_tools.length} tools available', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ..._tools.take(6).map((tool) {
              final name = tool['name'] ?? tool['id'] ?? 'Tool';
              final desc = tool['description'] ?? '';
              final category = tool['category'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _toolColor(category).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.build_rounded, color: _toolColor(category), size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.toString(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                          if (desc.toString().isNotEmpty)
                            Text(desc.toString(), style: TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Color _toolColor(String category) {
    switch (category.toLowerCase()) {
      case 'github': return AppTheme.neonGreen;
      case 'slack': case 'communication': return AppTheme.peach;
      case 'deploy': case 'infra': return AppTheme.blue;
      case 'ai': return AppTheme.neonPurple;
      default: return AppTheme.accent;
    }
  }

  Widget _buildPromptHubSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.neonGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.psychology_rounded, color: AppTheme.neonGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Text('PROMPT HUB', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Browse, manage, and sync AI prompts from your repositories.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PromptHubScreen())),
              color: AppTheme.neonGreen.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('OPEN PROMPT HUB', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.neonGreen)),
            ),
          ),
        ],
      ),
    );
  }
}
