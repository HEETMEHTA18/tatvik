import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';

import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../mentor/task_command_screen.dart';
import '../memory/memory_screen.dart';
import '../pulse/pulse_screen.dart';
import '../studio/studio_screen.dart';
import '../career/career_screen.dart';
import '../../widgets/liquid_glass_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (appState.showLinkGitHubPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !appState.showLinkGitHubPrompt) {
          return;
        }
        appState.showLinkGitHubPrompt = false;
        _showLinkGitHubDialog(context, appState);
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchGithubData(appState.githubUsername, force: true);
          await appState.fetchActivityData(force: true);
          await appState.fetchFollowingActivity(force: true);
          // AI-heavy calls (roast, DNA, weekly report, prompt analytics, digest)
          // are NOT refreshed here to save API tokens.
          // Use their dedicated buttons to refresh individually.
        },
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        child: Stack(
          children: [
            // Background Gradient Orbs
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 120,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 800;

                  final header = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dashboard',
                            style: GoogleFonts.inter(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Stack(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _showNotificationCenter(
                                    context,
                                    appState,
                                  ),
                                  icon: Icon(
                                    appState.unreadNotificationsCount > 0
                                        ? Icons.notifications_active_rounded
                                        : Icons.notifications_none_rounded,
                                    size: 18,
                                    color: appState.unreadNotificationsCount > 0
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              if (appState.unreadNotificationsCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${appState.unreadNotificationsCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildWelcomeHeader(context, appState),
                      const SizedBox(height: 12),
                      _buildDemoDataBanner(context, appState),
                      const SizedBox(height: 12),
                    ],
                  );

                  final spacing = 24.0;
                  // Calculate widths for bento boxes
                  final double w = constraints.maxWidth;
                  double langWidth = isDesktop ? w : w;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 24),
                      _buildQuickNav(context),
                      const SizedBox(height: 24),
                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: w,
                              child: _buildScoreSection(context, appState),
                            ),
                            SizedBox(
                              width: w,
                              child: _buildActivityHeatmap(context, appState),
                            ),
                            SizedBox(
                              width: w,
                              child: _buildOpenPullRequestsSection(context, appState),
                            ),
                            SizedBox(
                              width: w,
                              child: _buildAgentDigestSection(context, appState),
                            ),
                            SizedBox(
                              width: w,
                              child: _buildWeeklyReportSection(context, appState),
                            ),
                            SizedBox(
                              width: w,
                              child: _buildDnaSection(context, appState),
                            ),
                            SizedBox(
                              width: w,
                              child: _buildRoastSection(context, appState),
                            ),
                          SizedBox(
                            width: langWidth,
                            child: GlassCard(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.code_rounded,
                                        color: AppTheme.accent,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'TOP LANGUAGES',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildLanguageBar(
                                          context,
                                          'TypeScript',
                                          0.65,
                                          AppTheme.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildLanguageBar(
                                          context,
                                          'Rust',
                                          0.20,
                                          AppTheme.peach,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildLanguageBar(
                                          context,
                                          'Python',
                                          0.15,
                                          AppTheme.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 180), // FAB space
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TaskCommandScreen()),
              );
            },
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent,
                    AppTheme.accent.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 56.0,
                  minHeight: 56.0,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context, AppState state) {
    final scoreProgress = (state.developerScore / 10.0).clamp(0.0, 1.0);

    Color scoreColor = Colors.redAccent;
    if (state.developerScore >= 8.0) {
      scoreColor = AppTheme.neonGreen;
    } else if (state.developerScore >= 6.0) {
      scoreColor = AppTheme.neonOrange;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: isMobile
              ? Column(
                  children: [
                    _buildScoreContent(state, scoreProgress, scoreColor),
                    const SizedBox(height: 24),
                    Container(height: 1, color: AppTheme.border),
                    const SizedBox(height: 24),
                    _buildStatsRow(state, true),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildScoreContent(state, scoreProgress, scoreColor),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: AppTheme.border,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    Expanded(
                      flex: 6,
                      child: _buildStatsRow(state, false),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildScoreContent(AppState state, double scoreProgress, Color scoreColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: scoreProgress,
                strokeWidth: 6,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),
            Text(
              '${state.developerScore}',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEV SCORE',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.developerScore >= 8.0
                    ? 'Elite'
                    : state.developerScore >= 6.0
                    ? 'Pro'
                    : 'Rising',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AppState state, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildBentoStat(
            null, // context not needed here since I don't use it in _buildBentoStat
            '${state.repos}',
            'Repos',
            Icons.folder_open,
            AppTheme.neonPurple,
            isMobile,
          ),
        ),
        Container(height: 40, width: 1, color: AppTheme.border),
        Expanded(
          child: _buildBentoStat(
            null,
            '${state.commits}',
            'Commits',
            Icons.history,
            AppTheme.neonGreen,
            isMobile,
          ),
        ),
        Container(height: 40, width: 1, color: AppTheme.border),
        Expanded(
          child: _buildBentoStat(
            null,
            '${state.stars}',
            'Stars',
            Icons.star_border,
            AppTheme.neonOrange,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoStat(
    BuildContext? context,
    String value,
    String label,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: isMobile ? 20 : 24, color: color),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: isMobile ? 9 : 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: AppTheme.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActivityHeatmap(BuildContext context, AppState state) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVITY',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.selectedActivityYear,
                  dropdownColor: AppTheme.isDark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.accent,
                    size: 16,
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    color: AppTheme.accent,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      state.setActivityYear(newValue);
                    }
                  },
                  items: <String>['2026', '2025', '2024', '2023']
                      .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value.toUpperCase(),
                            style: TextStyle(color: AppTheme.textMain),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          state.isLoadingActivity
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              : (() {
                  int paddingCells = 0;
                  if (state.activityData.isNotEmpty) {
                    final dateStr = state.activityData.first['date'] as String?;
                    if (dateStr != null && dateStr.isNotEmpty) {
                      try {
                        final firstDate = DateTime.parse(dateStr);
                        paddingCells = firstDate.weekday % 7;
                      } catch (_) {}
                    }
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      height: 120,
                      width:
                          ((state.activityData.length + paddingCells) / 7)
                              .ceil() *
                          16.0,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                        itemCount: state.activityData.length + paddingCells,
                        itemBuilder: (context, index) {
                          if (index < paddingCells) {
                            return const SizedBox();
                          }
                          final dayData =
                              state.activityData[index - paddingCells];
                          final int count = dayData['count'] ?? 0;
                          final String date = dayData['date'] ?? '';
                          final double opacity = count == 0
                              ? 0.1
                              : count <= 2
                              ? 0.4
                              : count <= 5
                              ? 0.7
                              : 1.0;
                          return InkWell(
                            onTap: () {
                              _showDayActivityDialog(
                                context,
                                date,
                                state.token ?? '',
                              );
                            },
                            borderRadius: BorderRadius.circular(2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(
                                  alpha: opacity,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                })(),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Less',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
              const SizedBox(width: 4),
              ...List.generate(
                5,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: (i + 1) * 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBar(
    BuildContext context,
    String lang,
    double percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMain),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: GoogleFonts.jetBrainsMono(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: const Color(0xFF222222),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoDataBanner(BuildContext context, AppState state) {
    if (state.githubUsername.toLowerCase() != 'alexjohnson') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viewing Demo Profile (@alexjohnson)',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to link your own GitHub handle and pull your actual repository insights.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showEditGitHubDialog(context, state),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'LINK',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNav(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickNavItem(context, Icons.auto_awesome_rounded, 'Memory', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()))),
          _quickNavItem(context, Icons.travel_explore_rounded, 'Pulse', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PulseScreen()))),
          _quickNavItem(context, Icons.build_circle_rounded, 'Studio', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioScreen()))),
          _quickNavItem(context, Icons.route_rounded, 'Career', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerScreen()))),
        ],
      ),
    );
  }

  Widget _quickNavItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showEditGitHubDialog(BuildContext context, AppState state) {
    final controller = TextEditingController(text: state.githubUsername);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit GitHub Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(
                    labelText: 'GitHub Username',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixText: '@ ',
                    prefixStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    LiquidGlassButton(
                      onPressed: () {
                        final newUsername = controller.text.trim();
                        if (newUsername.isNotEmpty) {
                          state.setGithubUsername(newUsername);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GitHub handle updated to @$newUsername',
                            ),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: AppTheme.accent,
                      borderRadius: 8,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, AppState state) {
    // Time-of-day greeting
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.light_mode_rounded;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay_rounded;
    }

    final firstName = state.username.split(' ').first;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent,
                  border: Border.all(
                    color: AppTheme.neonPurple.withValues(alpha: 0.5),
                    width: 2.0,
                  ),
                  image: state.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(state.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: state.avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(greetingIcon, size: 16, color: AppTheme.neonOrange),
                        const SizedBox(width: 6),
                        Text(
                          greeting,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        firstName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          letterSpacing: -0.5,
                          color: AppTheme.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: IconButton(
                  icon: Icon(
                    state.isDarkTheme
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: AppTheme.textMain,
                    size: 22,
                  ),
                  onPressed: () {
                    state.toggleTheme();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats removed from here, unified in the score card

          const SizedBox(height: 12),
          // Suggested Next Task
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.08),
                  AppTheme.neonPurple.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.gaps.isNotEmpty
                        ? '💡 Suggested: ${state.gaps.first}'
                        : '💡 Tip: Review your latest commits for code quality improvements',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDayActivityDialog(BuildContext context, String date, String token) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.isDark
              ? const Color(0xFF1E1E24)
              : Colors.white,
          title: Text(
            'Activity Info — $date',
            style: TextStyle(color: AppTheme.textMain),
          ),
          content: FutureBuilder<Map<String, dynamic>>(
            future: _fetchDayActivity(date, token),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Text(
                  'Error loading details.',
                  style: TextStyle(color: AppTheme.textSecondary),
                );
              }
              final data = snapshot.data!;
              final summary = data['summary'] ?? '';
              final List<dynamic> details = data['details'] ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (details.isEmpty)
                    Text(
                      'No repository modifications, pull requests, or issues recorded on this day.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    )
                  else
                    ...details.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.accent,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d.toString(),
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchDayActivity(
    String date,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/github/day-activity?date=$date'),
        headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'summary': 'Failed to load details.', 'details': []};
  }

  Widget _buildDnaSection(BuildContext context, AppState state) {
    if (!state.aiInsights) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Developer DNA Engine',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.peach.withValues(alpha: 0.8),
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'AI Insights Disabled',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Developer DNA analysis is currently disabled in your Settings preferences.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassButton(
                onPressed: () {
                  state.togglePreference('ai');
                },
                color: AppTheme.peach.withValues(alpha: 0.2),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(
                  'Enable AI Insights',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.peach,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoadingDna) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Developer DNA Engine',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 10,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 12,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 12,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
      );
    }

    final archetype = state.dnaArchetype ?? 'Builder';
    final score = state.dnaScore ?? 86;
    final desc =
        state.dnaDescription ??
        'You love shipping products quickly and prototyping fresh ideas.';
    final strengths =
        state.dnaStrengths ??
        ['Rapid Prototyping', 'Full Stack Development', 'MVP Building'];
    final weaknesses =
        state.dnaWeaknesses ??
        ['DevOps Pipelines', 'Automated Testing', 'Advanced System Design'];

    String emoji = '🚀';
    Color arcColor = AppTheme.accent;
    if (archetype == 'Architect') {
      emoji = '🧠';
      arcColor = AppTheme.peach;
    } else if (archetype == 'Hacker') {
      emoji = '⚡';
      arcColor = AppTheme.destructive;
    } else if (archetype == 'Explorer') {
      emoji = '🌎';
      arcColor = AppTheme.blue;
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Developer DNA Engine',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: arcColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archetype.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: arcColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alignment Score: $score%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMain,
              height: 1.4,
            ),
          ),
          const Divider(height: 32, color: Colors.white12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STRENGTHS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...strengths.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: AppTheme.success,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEAKNESSES',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.destructive,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...weaknesses.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.close_rounded,
                              color: AppTheme.destructive,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                w,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyReportSection(BuildContext context, AppState state) {
    if (!state.weeklyReport) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI Weekly Growth Report',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.accent.withValues(alpha: 0.8),
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Weekly Report Disabled',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI Weekly Progress and Growth reports are disabled in Settings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassButton(
                onPressed: () {
                  state.togglePreference('report');
                },
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(
                  'Enable Weekly Report',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoadingWeeklyReport) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Weekly Growth Report',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 150,
              height: 16,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                4,
                (index) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 10,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
      );
    }

    final explored = state.weeklyExplored ?? 3;
    final skills = state.weeklySkills ?? 2;
    final improvement = state.weeklyImprovement ?? 7;
    final chartData = state.weeklyChartData ?? [12, 19, 3, 5, 2, 3, 10];
    final maxVal = chartData.isNotEmpty
        ? chartData.reduce((curr, next) => curr > next ? curr : next)
        : 1;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Weekly Growth Report',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WEEK',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+$explored Repos • +$skills Skills',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Improved $improvement%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(chartData.length, (i) {
                final val = chartData[i];
                final double heightPct = maxVal > 0 ? (val / maxVal) : 0.0;
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 14,
                          height: 40 * heightPct + 4,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(
                              alpha: heightPct.clamp(0.2, 1.0),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i],
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          if (state.weeklyAchievements != null ||
              (state.weeklyNextSteps != null &&
                  state.weeklyNextSteps!.isNotEmpty)) ...[
            const Divider(height: 32, color: Colors.white12),
            if (state.weeklyAchievements != null) ...[
              Text(
                'WEEKLY ACHIEVEMENTS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.blue,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              MarkdownBody(
                data: state.weeklyAchievements!,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textMain,
                    height: 1.4,
                  ),
                  listBullet: TextStyle(color: AppTheme.accent),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (state.weeklyNextSteps != null &&
                state.weeklyNextSteps!.isNotEmpty) ...[
              Text(
                'NEXT ACTION STEPS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              ...state.weeklyNextSteps!.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_right_rounded,
                        color: AppTheme.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          step,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  Widget _buildLockedAiFeature(BuildContext context, AppState state, String title, IconData icon) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This AI feature is currently locked to conserve API usage.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              LiquidGlassButton(
                onPressed: () {
                  state.togglePreference('ai');
                },
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Unlock Feature',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Open Pull Requests Section
  // ─────────────────────────────────────────────────
  Widget _buildOpenPullRequestsSection(BuildContext context, AppState state) {
    if (!state.aiInsights) {
      return _buildLockedAiFeature(context, state, 'Recent Activity', Icons.call_split_rounded);
    }
    
    if (state.isLoadingOpenPullRequests && state.openPullRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }
    
    final prs = state.openPullRequests;
    if (prs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: Text(
            'No open pull requests',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.8), // Deep dark background like GitHub Mobile
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: prs.asMap().entries.map((entry) {
              final int idx = entry.key;
              final pr = entry.value;
              final bool isLast = idx == prs.length - 1;

              return InkWell(
                onTap: () async {
                  final url = Uri.parse(pr['url'].toString());
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.vertical(
                  top: idx == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PR Icon
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.call_split_rounded, size: 22, color: AppTheme.success),
                      ),
                      const SizedBox(width: 14),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Repo & Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${pr['repo']} #${pr['number']}',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  pr['time'].toString(),
                                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Title & Comments
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    pr['title'].toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textMain,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    pr['comments'].toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Activity
                            Text(
                              pr['activity'].toString(),
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 24/7 AI Research Agent — Digest Section
  // ─────────────────────────────────────────────────
  Widget _buildAgentDigestSection(BuildContext context, AppState state) {
    if (!state.aiInsights) {
      return _buildLockedAiFeature(context, state, '24/7 AI Research Agent', Icons.radar_rounded);
    }
    
    final digest = state.whatsNewDigest;
    final isDark = AppTheme.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        // Section Header
        Row(
          children: [
            // Animated pulse dot
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              onEnd: () {},
            ),
            const SizedBox(width: 8),
            Text(
              '24/7 AI RESEARCH AGENT',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => state.fetchWhatsNewDigest(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 12,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'REFRESH',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (state.isLoadingWhatsNewDigest)
          GlassCard(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Agent scanning GitHub & YouTube…',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (digest == null)
          GestureDetector(
            onTap: () => state.fetchWhatsNewDigest(),
            child: GlassCard(
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.radar_rounded,
                        color: AppTheme.accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agent Ready',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to fetch the latest GitHub & YouTube tech digest',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GlassCard(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Digest Summary
                  if ((digest['digest'] as String? ?? '').isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI SUMMARY',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x0AFFFFFF)
                            : const Color(0x08000000),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.2),
                        ),
                      ),
                      child: MarkdownBody(
                        data: digest['digest'] as String,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppTheme.textMain,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // GitHub Trending
                  if ((digest['github'] as List?)?.isNotEmpty == true) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'TRENDING ON GITHUB',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...((digest['github'] as List).take(3).map((item) {
                      final repo = item as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () async {
                          final url = Uri.tryParse(repo['url'] as String? ?? '');
                          if (url != null) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.bookmark_border_rounded, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${repo['owner']}/${repo['name']}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accent,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star_rounded, size: 12, color: AppTheme.peach),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${repo['stars'] ?? 0}',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textMain,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                repo['description'] as String? ?? 'No description provided.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    })),
                    const SizedBox(height: 16),
                  ],

                  // YouTube Trending
                  if ((digest['youtube'] as List?)?.isNotEmpty == true) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 14,
                          color: AppTheme.destructive,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TRENDING ON YOUTUBE',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...((digest['youtube'] as List).take(3).map((item) {
                      final video = item as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () async {
                          final url = Uri.tryParse(
                            video['url'] as String? ?? '',
                          );
                          if (url != null) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x0DFFFFFF)
                                : const Color(0x06000000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.border.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: AppTheme.destructive,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video['title'] as String? ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textMain,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      video['channel'] as String? ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    })),
                  ],

                  // Timestamp
                  if ((digest['timestamp'] as String?) != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Last updated: ${_formatTimestamp(digest['timestamp'] as String)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildRoastSection(BuildContext context, AppState state) {
    if (!state.aiInsights) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GitHub Profile Roast',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.peach.withValues(alpha: 0.8),
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Roast Locked',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Profile roast generation requires AI Insights to be enabled in Settings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoadingRoast) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GitHub Profile Roast',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Container(
                  width: 100,
                  height: 14,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 12,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 12,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),
            Container(
              width: 180,
              height: 12,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
      );
    }

    final roastText =
        state.profileRoast ??
        "Your GitHub profile looks like a digital graveyard of unfinished tutorials. You have repositories with no READMEs and more generic boilerplates than a WordPress agency.";
    final tips =
        state.roastTips ??
        [
          "Archive or delete repositories that are just cloned templates.",
          "Write a proper README with screenshots for your top 3 repos.",
          "Choose descriptive names instead of 'test-app' or 'demo-1'.",
        ];

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GitHub Profile Roast',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (state.isLoadingRoast)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    state.fetchProfileRoast();
                  },
                  icon: const Icon(Icons.fireplace_rounded, size: 14),
                  label: Text(
                    'ROAST ME',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.destructive,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(
                'BRUTAL REVIEW',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.destructive,
                ),
              ),
            ],
          ),
          MarkdownBody(
            data: roastText,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMain,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CLEANUP TIPS:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationCenter(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<AppState>(
          builder: (context, state, child) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border(
                      top: BorderSide(color: AppTheme.border, width: 1.5),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NOTIFICATION CENTER',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  state.markAllNotificationsAsRead();
                                },
                                child: Text(
                                  'Read All',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  state.clearNotifications();
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Clear All',
                                  style: TextStyle(
                                    color: AppTheme.destructive,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: state.notifications.isEmpty
                            ? Center(
                                child: Text(
                                  'No notifications yet.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: state.notifications.length,
                                itemBuilder: (context, index) {
                                  final notification =
                                      state.notifications[index];
                                  final isRead =
                                      notification['isRead'] ?? false;
                                  final type =
                                      notification['type'] ?? 'welcome';

                                  IconData icon = Icons.info_outline;
                                  Color color = AppTheme.accent;
                                  if (type == 'dna') {
                                    icon = Icons.psychology_rounded;
                                    color = AppTheme.success;
                                  } else if (type == 'roast') {
                                    icon = Icons.fireplace_rounded;
                                    color = AppTheme.destructive;
                                  } else if (type == 'weekly_report') {
                                    icon = Icons.trending_up_rounded;
                                    color = AppTheme.blue;
                                  } else if (type == 'opportunity') {
                                    icon = Icons.insights_rounded;
                                    color = AppTheme.peach;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: InkWell(
                                      onTap: () {
                                        state.markNotificationAsRead(
                                          notification['id'],
                                        );
                                        _showNotificationDetail(
                                          context,
                                          notification,
                                        );
                                      },
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        borderRadius: 16,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.15,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                icon,
                                                color: color,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          notification['title'] ??
                                                              '',
                                                          style: TextStyle(
                                                            fontWeight: isRead
                                                                ? FontWeight
                                                                      .normal
                                                                : FontWeight
                                                                      .bold,
                                                            color: AppTheme
                                                                .textMain,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      if (!isRead)
                                                        Container(
                                                          width: 6,
                                                          height: 6,
                                                          decoration:
                                                              const BoxDecoration(
                                                                color:
                                                                    Colors.red,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    notification['body'] ?? '',
                                                    style: TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize: 11,
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
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationDetail(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final type = notification['type'] ?? 'welcome';
    final extraData = notification['extraData'] ?? {};

    Widget detailContent;

    if (type == 'dna') {
      final archetype = extraData['archetype'] ?? 'Builder';
      final score = extraData['score'] ?? 86;
      final desc = extraData['description'] ?? '';
      final List<dynamic> strengths = extraData['strengths'] ?? [];
      final List<dynamic> weaknesses = extraData['weaknesses'] ?? [];

      detailContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ARCHETYPE: $archetype ($score% Match)',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: TextStyle(
              color: AppTheme.textMain,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const Divider(height: 24, color: Colors.white12),
          Text(
            'STRENGTHS:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 6),
          ...strengths.map(
            (s) => Text(
              '• $s',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'WEAKNESSES:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.destructive,
            ),
          ),
          const SizedBox(height: 6),
          ...weaknesses.map(
            (w) => Text(
              '• $w',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      );
    } else if (type == 'roast') {
      final roast = extraData['roast'] ?? '';
      final List<dynamic> tips = extraData['tips'] ?? [];

      detailContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔥 BRUTAL PROFILE ROAST',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.destructive,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            roast,
            style: TextStyle(
              color: AppTheme.textMain,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const Divider(height: 24, color: Colors.white12),
          Text(
            'CLEANUP CHECKLIST:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: AppTheme.accent)),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (type == 'weekly_report') {
      final explored = extraData['repositories_explored'] ?? 3;
      final skills = extraData['skills_learned'] ?? 2;
      final improvement = extraData['improvement_percentage'] ?? 7;
      final List<dynamic> chart =
          extraData['chart_data'] ?? [12, 19, 3, 5, 2, 3, 10];

      detailContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📈 GROWTH REPORT DETAILS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.blue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricCard('Repos Explored', '+$explored', AppTheme.accent),
              _buildMetricCard('Skills Learned', '+$skills', AppTheme.peach),
              _buildMetricCard(
                'Improvement',
                '+$improvement%',
                AppTheme.success,
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white12),
          Text(
            'DAILY COMMIT BREAKDOWN (MON-SUN):',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(chart.length, (i) {
              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              return Column(
                children: [
                  Text(
                    '${chart[i]}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    days[i],
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      );
    } else if (type == 'opportunity') {
      final List<dynamic> opportunities = extraData as List<dynamic>;

      detailContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 RECOMMENDED PROJECTS TO BUILD',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.peach,
            ),
          ),
          const SizedBox(height: 16),
          ...opportunities.map((opp) {
            final oTitle = opp['title'] ?? '';
            final oWhy = opp['why'] ?? '';
            final oStack = opp['tech_stack'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    oWhy,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stack: $oStack',
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.accent,
                      fontSize: 10,
                    ),
                  ),
                  const Divider(height: 16, color: Colors.white10),
                ],
              ),
            );
          }),
        ],
      );
    } else {
      detailContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification['title'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            notification['body'] ?? '',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                detailContent,
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: LiquidGlassButton(
                    onPressed: () => Navigator.pop(context),
                    color: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    borderRadius: 12,
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: col,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showLinkGitHubDialog(BuildContext context, AppState state) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link your GitHub Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tatvik uses your GitHub profile to build your developer DNA, calculate your ratings, and generate your custom career milestones.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(
                    labelText: 'GitHub Username',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixText: '@ ',
                    prefixStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'You can link your GitHub account later in Settings.',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Skip',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    LiquidGlassButton(
                      onPressed: () {
                        final username = controller.text.trim();
                        if (username.isNotEmpty) {
                          state.setGithubUsername(username);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Linking GitHub account @$username...',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: AppTheme.accent,
                      borderRadius: 8,
                      child: const Text('Link Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
