import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../providers/app_state.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  int _activeTab = 0;
  String _selectedBattleRole = 'Senior Backend Engineer';
  final _copilotRepoController = TextEditingController();
  final _copilotTitleController = TextEditingController();
  final _copilotDescController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _copilotRepoController.text = 'flutter/flutter';
    _copilotTitleController.text = 'Navigator pop memory leak';
    _copilotDescController.text = 'The navigator stack leaks routes when popped repeatedly.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      state.fetchRoadmap();
    });
  }

  @override
  void dispose() {
    _copilotRepoController.dispose();
    _copilotTitleController.dispose();
    _copilotDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    Widget tabContent;
    switch (_activeTab) {
      case 0:
        tabContent = _buildCareerTab(context, appState);
        break;
      case 1:
        tabContent = _buildLearningPathTab(context, appState);
        break;
      case 2:
        tabContent = _buildBattleTab(context, appState);
        break;
      case 3:
        tabContent = _buildCopilotTab(context, appState);
        break;
      default:
        tabContent = Container();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _activeTab == 0
              ? 'Career Roadmap'
              : _activeTab == 1
                  ? 'Learning Paths'
                  : _activeTab == 2
                      ? 'Developer Battle'
                      : 'Open Source Copilot',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: _activeTab == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.psychology_outlined),
                  tooltip: 'Regenerate AI Roadmap',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating custom AI career roadmap based on your profile...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    await appState.regenerateRoadmap();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('AI Career Roadmap updated successfully!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          Positioned(
            top: 400,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            children: [
              _buildTabBar(),
              Expanded(child: tabContent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['CAREER', 'PATHS', 'BATTLE', 'COPILOT'];
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(tabs.length, (index) {
            final isSelected = _activeTab == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.accent.withValues(alpha: 0.85) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? (AppTheme.isDark ? Colors.black : Colors.white) 
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCareerTab(BuildContext context, AppState appState) {
    if (appState.isLoadingRoadmap) {
      return _buildRoadmapSkeleton(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildProgressHero(context, appState),
          const SizedBox(height: 40),
          if (appState.milestones.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.route_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No milestones generated yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the brain icon in the top right to generate your AI roadmap.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appState.milestones.length,
              itemBuilder: (context, index) {
                final m = appState.milestones[index];
                
                final isCompleted = m.isCompleted;
                int activeIndex = appState.milestones.indexWhere((element) => !element.isCompleted);
                if (activeIndex == -1) activeIndex = 0;
                final isActive = index == activeIndex;

                final Color milestoneColor = isCompleted 
                    ? AppTheme.success 
                    : (isActive ? AppTheme.accent : AppTheme.textSecondary);
                    
                final String milestoneStatus = isCompleted 
                    ? 'Completed' 
                    : (isActive ? 'In Progress' : 'Planned');

                return _buildMilestone(
                  context,
                  index,
                  m.title,
                  m.description,
                  milestoneStatus,
                  milestoneColor,
                  isCompleted,
                  [],
                  null,
                  appState,
                  m.recommendations,
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProgressHero(BuildContext context, AppState state) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PATHWAY', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 10)),
                    const SizedBox(height: 8),
                    Text(
                      state.roadmapTitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    state.milestones.isEmpty ? '0%' : '${(state.roadmapProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text('COMPLETE', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: state.milestones.isEmpty ? 0.0 : state.roadmapProgress,
              backgroundColor: const Color(0xFF222222),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestone(
    BuildContext context,
    int index,
    String title,
    String description,
    String status,
    Color color,
    bool isDone,
    List<String> tasks,
    String? currentProject,
    AppState state,
    List<String> recommendations,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: () => state.toggleMilestone(index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 20, color: Colors.black)
                      : Icon(
                          status == 'In Progress' ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: AppTheme.border,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 32),
              child: GestureDetector(
                onTap: () => state.toggleMilestone(index),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                                title,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                            size: 14,
                            color: isDone ? AppTheme.success : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDone ? AppTheme.success : AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                        ),
                      ],
                      if (recommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'SMART RECOMMENDATIONS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: recommendations.map((rec) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 10, color: AppTheme.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    rec,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapSkeleton(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Progress Hero Skeleton
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 160,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 60,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Milestones List Skeleton
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 32),
                        child: GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 180 + (index * 15.0),
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 80,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPathTab(BuildContext context, AppState state) {
    if (state.isLoadingLearningPaths) {
      return const Center(child: CircularProgressIndicator());
    }

    final title = state.learningPathTitle ?? 'Advanced Web Architect';
    final List<dynamic> steps = state.learningPathSteps ?? [
      {
        "step_num": 1,
        "repo_name": "nestjs/nest",
        "description": "Learn modern backend architectures and decorators.",
        "task": "Inspect how Dependency Injection is implemented in the NestJS core package.",
        "is_completed": true
      },
      {
        "step_num": 2,
        "repo_name": "typeorm/typeorm",
        "description": "Understand database connections and active-record patterns.",
        "task": "Review query builder creation inside src/query-builder/QueryBuilder.ts.",
        "is_completed": false
      },
      {
        "step_num": 3,
        "repo_name": "fastify/fastify",
        "description": "High performance request lifecycle and schema validation.",
        "task": "Check how fastify hook pipeline is implemented.",
        "is_completed": false
      },
      {
        "step_num": 4,
        "repo_name": "moby/moby",
        "description": "Deep dive containerization principles.",
        "task": "Read Docker execution runtime interfaces.",
        "is_completed": false
      },
      {
        "step_num": 5,
        "repo_name": "hashicorp/terraform",
        "description": "Automated deployments and state engines.",
        "task": "Examine terraform provider lifecycle code.",
        "is_completed": false
      }
    ];

    int completedCount = steps.where((s) => s['is_completed'] == true).length;
    double progress = steps.isNotEmpty ? completedCount / steps.length : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEARNING PATH',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accent),
                    ),
                    Text('COMPLETE', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final stepNum = step['step_num'] ?? (index + 1);
            final repoName = step['repo_name'] ?? 'owner/repo';
            final desc = step['description'] ?? '';
            final task = step['task'] ?? '';
            final isCompleted = step['is_completed'] ?? false;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCompleted ? AppTheme.accent : Colors.white10,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? AppTheme.accent : AppTheme.border,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(Icons.check, color: AppTheme.isDark ? Colors.black : Colors.white, size: 20)
                              : Text(
                                  '$stepNum',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      if (index < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isCompleted ? AppTheme.accent : Colors.white12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repoName,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? AppTheme.accent : AppTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const Divider(height: 24, color: Colors.white12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.assignment_turned_in_outlined, color: AppTheme.peach, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Task: $task',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMain,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBattleTab(BuildContext context, AppState state) {
    final targets = ['Senior Backend Engineer', 'Senior Flutter Engineer', 'Senior DevOps Engineer', 'System Architect'];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
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
                    Icon(Icons.sports_martial_arts_rounded, color: AppTheme.destructive, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'DEVELOPER BATTLE MODE',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Compare your profile strengths, languages and commits against standard profiles to detect missing capabilities.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBattleRole,
                  dropdownColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'SELECT TARGET ROLE',
                    labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBattleRole = val;
                      });
                    }
                  },
                  items: targets.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: TextStyle(color: AppTheme.textMain)),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isBattling
                        ? null
                        : () {
                            state.battleTarget(_selectedBattleRole);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.destructive,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: state.isBattling
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'INITIATE BATTLE MATCHUP',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (state.battleMatchScore != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Matchup Results'),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PROFILE STACK MATCH',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${state.battleMatchScore}%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.destructive,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  _battleMetricProgress('Code Quality', (state.battleCodeQuality ?? 75) / 100, AppTheme.success),
                  const SizedBox(height: 16),
                  _battleMetricProgress('Scale / Load Handling', (state.battleScale ?? 45) / 100, AppTheme.peach),
                  const SizedBox(height: 16),
                  _battleMetricProgress('System Architecture', (state.battleArchitecture ?? 58) / 100, AppTheme.accent),
                  const Divider(height: 32, color: Colors.white12),
                  Text(
                    'CRITICAL SKILLS YOU LACK:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.destructive,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(state.battleMissingSkills ?? []).map((skill) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline, color: AppTheme.destructive, size: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _battleMetricProgress(String name, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: TextStyle(fontSize: 12, color: AppTheme.textMain, fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildCopilotTab(BuildContext context, AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
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
                    Icon(Icons.assistant_rounded, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'OPEN SOURCE COPILOT',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _copilotRepoController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'REPOSITORY',
                    labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                    hintText: 'e.g. flutter/flutter',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _copilotTitleController,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'ISSUE TITLE',
                    labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                    hintText: 'e.g. Memory leak on Navigator pop',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _copilotDescController,
                  maxLines: 3,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'ISSUE DESCRIPTION',
                    labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                    hintText: 'Describe details of the issue to solve...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isCopilotRunning
                        ? null
                        : () {
                            if (_copilotRepoController.text.trim().isNotEmpty &&
                                _copilotTitleController.text.trim().isNotEmpty) {
                              state.runCopilot(
                                _copilotTitleController.text.trim(),
                                _copilotDescController.text.trim(),
                                _copilotRepoController.text.trim(),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: state.isCopilotRunning
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'ANALYZE & BLUEPRINT FIX',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.isDark ? Colors.black : Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (state.copilotIssueExplanation != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Copilot Blueprint'),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ISSUE BREAKDOWN',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(state.copilotIssueExplanation!, style: TextStyle(fontSize: 12, color: AppTheme.textMain, height: 1.3)),
                  const Divider(height: 24, color: Colors.white12),
                  Text(
                    'CODEBASE CONTEXT',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.peach),
                  ),
                  const SizedBox(height: 8),
                  Text(state.copilotCodebaseExplanation!, style: TextStyle(fontSize: 12, color: AppTheme.textMain, height: 1.3)),
                  const Divider(height: 24, color: Colors.white12),
                  Text(
                    'FILES TO FOCUS ON',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.destructive),
                  ),
                  const SizedBox(height: 8),
                  ...(state.copilotFilesToEdit ?? []).map((file) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, color: AppTheme.destructive, size: 14),
                        const SizedBox(width: 8),
                        Text(file, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )),
                  const Divider(height: 24, color: Colors.white12),
                  Text(
                    'AI GENERATED IMPLEMENTATION PLAN',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                  ),
                  const SizedBox(height: 12),
                  ...(state.copilotImplementationPlan ?? []).map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded, color: AppTheme.success, size: 10),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
