import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/prompt_item.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';

class PromptHubScreen extends StatefulWidget {
  const PromptHubScreen({super.key});

  @override
  State<PromptHubScreen> createState() => _PromptHubScreenState();
}

class _PromptHubScreenState extends State<PromptHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _playgroundController = TextEditingController();
  String _selectedWorkflow = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      state.fetchPromptHistory();
      state.fetchPromptAnalytics();
      state.fetchPromptRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter prompts locally for responsiveness
    final filteredHistory = state.promptHistory.where((p) {
      final matchesSearch = p.originalPrompt.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          p.refinedPrompt.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          p.technologies.any((t) => t.toLowerCase().contains(_searchController.text.toLowerCase()));
      final matchesWorkflow = _selectedWorkflow == 'All' || p.workflow == _selectedWorkflow;
      return matchesSearch && matchesWorkflow;
    }).toList();

    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'PROMPT INTELLIGENCE',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.cloud_sync_rounded),
              tooltip: 'Sync GitHub Prompts',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scanning GitHub repositories for .autodevs/prompts.md...'),
                    duration: Duration(seconds: 2),
                  ),
                );
                final message = await state.syncGithubPrompts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: message.contains('failed') ? AppTheme.destructive : AppTheme.success,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                state.fetchPromptHistory(query: _searchController.text);
                state.fetchPromptAnalytics();
                state.fetchPromptRecommendations();
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            // CLI banner indicator
            _buildCliStatusBanner(isDark),
            const SizedBox(height: 20),

            // Metrics Summary Section
            _buildMetricsDashboard(state, isDark),
            const SizedBox(height: 25),

            // Real-time Playground section
            _buildPlayground(state, isDark),
            const SizedBox(height: 25),

            // Skill Gaps and Recommendations Section
            _buildRecommendationsSection(state, isDark),
            const SizedBox(height: 25),

            // Search and Filters
            Text(
              'Prompt Library',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchAndFilters(state, isDark),
            const SizedBox(height: 15),

            // Prompt History List
            if (state.isLoadingPromptHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredHistory.isEmpty)
              _buildEmptyHistory(isDark)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredHistory.length,
                itemBuilder: (context, index) {
                  final prompt = filteredHistory[index];
                  return _buildPromptCard(prompt, isDark);
                },
              ),
          ],
        ),
      );
  }

  Widget _buildCliStatusBanner(bool isDark) {
    final state = Provider.of<AppState>(context, listen: false);
    return GlassCard(
      borderRadius: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCliInstructionsBottomSheet(context, state, isDark),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.terminal_rounded, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AutoDevs CLI Integration',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 16),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap to see how to connect AutoDevs CLI and sync prompts from .autodevs/prompts.md in your repositories.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsDashboard(AppState state, bool isDark) {
    return Row(
      children: [
        // Total Prompts
        Expanded(
          child: GlassCard(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Column(
                children: [
                  Text(
                    'Total Prompts',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.totalPrompts}',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CLI Synced',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Average Quality Score
        Expanded(
          child: GlassCard(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Column(
                children: [
                  Text(
                    'Quality Index',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.averagePromptScore.toStringAsFixed(1)}%',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(state.averagePromptScore.toInt()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grade: ${_getScoreGrade(state.averagePromptScore.toInt())}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayground(AppState state, bool isDark) {
    return GlassCard(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.secondaryAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Prompt Refiner & Scorer',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _playgroundController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a basic prompt to refine... (e.g., "how to write a json parser")',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 13),
                filled: true,
                fillColor: isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: state.isSubmittingPromptEvent
                    ? null
                    : () async {
                        if (_playgroundController.text.trim().isNotEmpty) {
                          FocusScope.of(context).unfocus();
                          await state.submitPromptEvent(
                            _playgroundController.text,
                            projectName: 'playground-test',
                          );
                          _playgroundController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Prompt analyzed and saved to history!')),
                            );
                          }
                        }
                      },
                child: state.isSubmittingPromptEvent
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Score & Upgrade',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection(AppState state, bool isDark) {
    if (state.isLoadingPromptRecommendations) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Recommendations',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Personalized roadmaps derived from your prompt weaknesses.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: state.promptRecommendations.length,
            itemBuilder: (context, index) {
              final rec = state.promptRecommendations[index];
              final title = rec['title'] ?? 'Prompting Best Practices';
              final desc = rec['description'] ?? '';
              final List<String> tags = List<String>.from(rec['tags'] ?? []);

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 14),
                child: GlassCard(
                  borderRadius: 16,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMain,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            desc,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: tags.map((tag) => Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(AppState state, bool isDark) {
    final workflows = ['All', 'Feature Building', 'Debugging', 'Refactoring', 'Testing', 'DevOps', 'Architecture'];
    
    return Column(
      children: [
        // Search TextField
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() {}),
          style: TextStyle(color: AppTheme.textMain),
          decoration: InputDecoration(
            hintText: 'Search prompt text, tech, or project...',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
            filled: true,
            fillColor: isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal list of workflows
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: workflows.length,
            itemBuilder: (context, index) {
              final w = workflows[index];
              final isSelected = _selectedWorkflow == w;
              return GestureDetector(
                onTap: () => setState(() => _selectedWorkflow = w),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.accent 
                        : (isDark ? const Color(0x15FFFFFF) : const Color(0x0F000000)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppTheme.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      w,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return GlassCard(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'No Prompts Found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Run commands using AutoDevs CLI or test a prompt in the Refiner above.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(PromptItem prompt, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showPromptDetailBottomSheet(prompt, isDark),
        child: GlassCard(
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Workflow badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        prompt.workflow.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    // Score Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getScoreColor(prompt.score).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded, color: _getScoreColor(prompt.score), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${prompt.score}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(prompt.score),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Original Prompt Preview
                Text(
                  prompt.originalPrompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tech Stack tags
                    Expanded(
                      child: Row(
                        children: prompt.technologies.take(2).map((tech) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tech,
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        )).toList(),
                      ),
                    ),
                    // Project info
                    if (prompt.projectName != null)
                      Row(
                        children: [
                          Icon(Icons.folder_open, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            prompt.projectName!,
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPromptDetailBottomSheet(PromptItem prompt, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xE0121214) : const Color(0xE0F8F9FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag indicator handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prompt.workflow.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              prompt.projectName != null ? 'Project: ${prompt.projectName}' : 'Playground Prompt',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ],
                        ),
                        // Score Circle
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _getScoreColor(prompt.score), width: 2),
                            color: _getScoreColor(prompt.score).withValues(alpha: 0.1),
                          ),
                          child: Center(
                            child: Text(
                              '${prompt.score}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(prompt.score),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // Original Prompt Card
                        Text(
                          'ORIGINAL PROMPT',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x0FFFFFFF) : const Color(0x09000000),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            prompt.originalPrompt,
                            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMain),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Refined Prompt Card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'UPGRADED PROMPT (AI REFINED)',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              color: AppTheme.success,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: prompt.refinedPrompt));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Upgraded prompt copied to clipboard!')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prompt.refinedPrompt,
                                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMain, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tech tags
                        Text(
                          'EXTRACTED TECHNOLOGIES',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: prompt.technologies.map((tech) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              tech,
                              style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.bold),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 40),
                      ],
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

  void _showCliInstructionsBottomSheet(BuildContext context, AppState state, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xE0121214) : const Color(0xE0F8F9FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag indicator handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AutoDevs CLI & GitHub Setup',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      children: [
                        // SECTION 1: GITHUB PROMPTS.MD
                        _buildInstructionStep(
                          stepNumber: '1',
                          title: 'Setup GitHub .autodevs/prompts.md',
                          description: 'Track coding prompts in your repositories. The app will fetch and analyze them.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '1. Create a folder named `.autodevs` in the root of your repository.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '2. Inside it, create a file named `prompts.md`.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '3. List your prompts in markdown format:',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F2F4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '- [project-name] implement email service\n'
                                  '- [refactor] optimize database queries\n'
                                  '- how to center widgets in Flutter',
                                  style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.textMain),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '4. In the DevMentor app, enter your GitHub handle in settings, then tap the Sync GitHub Prompts cloud button at the top of the Prompts tab.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION 2: CLI INTEGRATION
                        _buildInstructionStep(
                          stepNumber: '2',
                          title: 'Real-time Terminal Integration',
                          description: 'Use the AutoDevs CLI simulator to capture prompts directly from your shell/IDE.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Authentication Token:',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F2F4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        state.token ?? 'Login to view your auth token',
                                        style: GoogleFonts.firaCode(fontSize: 11, color: AppTheme.textMain),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.copy_rounded, color: AppTheme.accent),
                                    onPressed: state.token == null
                                        ? null
                                        : () {
                                            Clipboard.setData(ClipboardData(text: state.token!));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Auth token copied to clipboard!')),
                                            );
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Set environment variable in your terminal:',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F2F4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'export DEVMENTOR_TOKEN="your_copied_token"',
                                  style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.textMain),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Run the CLI script:',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F2F4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'python autodevs_cli_simulator.py "how to create centered container" devmentor-app',
                                  style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.textMain),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Prompts sent through the CLI are parsed, refined, scored by AI, and instantly updated in the Prompt Library.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildInstructionStep({
    required String stepNumber,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return AppTheme.success;
    if (score >= 70) return AppTheme.warning;
    return AppTheme.destructive;
  }

  String _getScoreGrade(int score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }
}
