import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_copy_button.dart';
import '../../providers/app_state.dart';
import '../../widgets/tatvik_loader.dart';
import '../../models/repository.dart';
import '../mentor/mentor_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/liquid_glass_button.dart';
import '../../services/github_events_service.dart';
import '../reviewer/reviewer_screen.dart';
import '../intelligence/developer_growth_screen.dart';
import '../intelligence/codebase_qa_screen.dart';
import '../intelligence/auto_fix_screen.dart';
import '../intelligence/ui_audit_screen.dart';
import '../intelligence/voice_review_screen.dart';
import '../memory/memory_screen.dart';
import '../pulse/pulse_screen.dart';
import '../studio/studio_screen.dart';
import '../career/career_screen.dart';

class DiscoverReposScreen extends StatefulWidget {
  const DiscoverReposScreen({super.key});

  @override
  State<DiscoverReposScreen> createState() => _DiscoverReposScreenState();
}

class _DiscoverReposScreenState extends State<DiscoverReposScreen> {
  String _searchQuery = '';
  int _activeTab = 0;
  final _resumeController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _jobDescController = TextEditingController();
  final _researchUrlController = TextEditingController();
  final _researchQueryController = TextEditingController();
  int _researchSubTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.followingActivity.isEmpty) {
        appState.fetchFollowingActivity();
      }
    });
  }

  @override
  void dispose() {
    _resumeController.dispose();
    _jobTitleController.dispose();
    _jobDescController.dispose();
    _researchUrlController.dispose();
    _researchQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseRepos = appState.filteredRepositories;
    final repos = baseRepos.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    // Sub-page view for deep tabs
    if (_activeTab > 0) {
      Widget tabContent;
      String tabTitle;
      switch (_activeTab) {
        case 1:
          tabContent = _buildReposTab(context, appState, repos);
          tabTitle = 'Recommended Repos';
          break;
        case 2:
          tabContent = _buildResumeTab(context, appState);
          tabTitle = 'Tatvik Resume Reviewer';
          break;
        case 3:
          tabContent = Container();
          tabTitle = 'Removed';
          break;
        case 4:
          tabContent = _buildAwesomeListsTab(context, appState);
          tabTitle = 'Awesome Lists';
          break;
        case 5:
          tabContent = _buildResearchTab(context, appState);
          tabTitle = 'Deep Research Agent';
          break;
        case 6:
          tabContent = _buildReviewerTab(context, appState);
          tabTitle = 'Continuous Code Reviewer';
          break;
        case 7:
          tabContent = const DeveloperGrowthScreen();
          tabTitle = 'Developer Growth & Badges';
          break;
        case 8:
          tabContent = const CodebaseQAScreen();
          tabTitle = 'Codebase Q&A Search';
          break;
        case 9:
          tabContent = const AutoFixScreen();
          tabTitle = 'Auto-Fix PR Generator';
          break;
        case 10:
          tabContent = const UIAuditScreen();
          tabTitle = 'Live UI Audit';
          break;
        case 11:
          tabContent = const VoiceReviewScreen();
          tabTitle = 'Voice Code Review';
          break;
        default:
          tabContent = Container();
          tabTitle = '';
      }
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppTheme.textMain,
            ),
            onPressed: () => setState(() => _activeTab = 0),
          ),
          title: Text(
            tabTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        body: tabContent,
      );
    }

    // Main Explore tab — GitHub mobile style
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await appState.fetchGithubData(appState.githubUsername);
        },
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Large title header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 60, bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Explore',
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                        letterSpacing: -1,
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonPurple.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.search_rounded, size: 22, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            
            // Quick Nav to AI OS Pillars
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navIcon(context, Icons.auto_awesome_rounded, 'Memory', AppTheme.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryScreen()))),
                      _navIcon(context, Icons.travel_explore_rounded, 'Pulse', AppTheme.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PulseScreen()))),
                      _navIcon(context, Icons.build_circle_rounded, 'Studio', AppTheme.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioScreen()))),
                      _navIcon(context, Icons.route_rounded, 'Career', AppTheme.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerScreen()))),
                    ],
                  ),
                ),
              ),
            ),
            // Bento Grid Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double w = constraints.maxWidth;
                    final bool isDesktop = w > 900;
                    final spacing = 16.0;
                    
                    final double half = isDesktop ? (w - spacing) / 2 : (w - spacing) / 2;
                    final double third = isDesktop ? (w - spacing * 2) / 3 : w;
                    final double full = w;

                    return Column(
                      children: [
                        // Large Hero App Store Card - Continuous Code Reviewer
                        SizedBox(
                          width: full,
                          height: 200,
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = 6),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.neonPurple.withValues(alpha: 0.3),
                                    AppTheme.accent.withValues(alpha: 0.15),
                                    AppTheme.surfaceElevated.withValues(alpha: 0.6),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.neonPurple.withValues(alpha: 0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(24),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        right: -20,
                                        bottom: -20,
                                        child: Icon(Icons.shield_rounded, size: 120, color: AppTheme.neonPurple.withValues(alpha: 0.12)),
                                      ),
                                      Positioned(
                                        right: 30,
                                        top: -10,
                                        child: Icon(Icons.code_rounded, size: 80, color: AppTheme.accent.withValues(alpha: 0.08)),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [AppTheme.neonPurple, AppTheme.accent],
                                                  ),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                                                    const SizedBox(width: 4),
                                                    Text('FEATURED', style: GoogleFonts.spaceMono(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.success.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                                                ),
                                                child: Text('AI AGENT', style: GoogleFonts.spaceMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.success)),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Continuous Code Reviewer', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                              const SizedBox(height: 6),
                                              Text('Automated PR analysis & security audits in real-time.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),
                        // Half Cards - Trending & Awesome
                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: half,
                              height: 160,
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.neonGreen.withValues(alpha: 0.2),
                                        AppTheme.surfaceElevated.withValues(alpha: 0.4),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.neonGreen.withValues(alpha: 0.1),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppTheme.neonGreen.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.trending_up_rounded, size: 24, color: AppTheme.neonGreen),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Trending', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                              const SizedBox(height: 2),
                                              Text('Hot Repositories', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: half,
                              height: 160,
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = 4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.neonOrange.withValues(alpha: 0.2),
                                        AppTheme.surfaceElevated.withValues(alpha: 0.4),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.neonOrange.withValues(alpha: 0.1),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppTheme.neonOrange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.star_rounded, size: 24, color: AppTheme.neonOrange),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Awesome', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                              const SizedBox(height: 2),
                                              Text('Curated Lists', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing),
                        // Action cards - full width on mobile, thirds on desktop
                        SizedBox(
                          width: third,
                          height: 120,
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = 2),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  colors: [AppTheme.blue.withValues(alpha: 0.15), AppTheme.surfaceElevated.withValues(alpha: 0.3)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [AppTheme.blue, AppTheme.blue.withValues(alpha: 0.6)]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.description_rounded, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Resume Reviewer', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                            const SizedBox(height: 2),
                                            Text('AI Tailoring', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: third,
                          height: 120,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _activeTab = 5);
                              appState.fetchWeeklyTechDigest();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  colors: [AppTheme.peach.withValues(alpha: 0.15), AppTheme.surfaceElevated.withValues(alpha: 0.3)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [AppTheme.peach, AppTheme.peach.withValues(alpha: 0.6)]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.travel_explore_rounded, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Deep Research', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                            const SizedBox(height: 2),
                                            Text('OSINT Agent', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: third,
                          height: 120,
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  colors: [AppTheme.neonGreen.withValues(alpha: 0.15), AppTheme.surfaceElevated.withValues(alpha: 0.3)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [AppTheme.neonGreen, AppTheme.neonGreen.withValues(alpha: 0.6)]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.search_rounded, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Codebase Q&A', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                            const SizedBox(height: 2),
                                            Text('Semantic Search', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),


            // Activity Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 28,
                  bottom: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => appState.fetchFollowingActivity(),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Activity Feed
            if (appState.isLoadingFollowingActivity)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: TatvikLoader(),
                ),
              )
            else if (appState.followingActivity.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No activity yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Follow developers on GitHub to see their events here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => appState.fetchFollowingActivity(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF007AFF,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Refresh Feed',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...() {
              // Group events by day
              final List<GitHubActivityEvent> events = appState.parsedActivityEvents.isNotEmpty
                  ? appState.parsedActivityEvents
                  : appState.followingActivity
                      .map((e) => GitHubActivityEvent.fromBackendFormat(e))
                      .toList();
              final grouped = GroupedEvents.groupByDay(events);

              final List<Widget> slivers = [];
              for (final group in grouped) {
                // Day header
                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 8),
                      child: Text(
                        group.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
                // Events in this group
                slivers.add(
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final event = group.events[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: index == group.events.length - 1 ? 4 : 10,
                        ),
                        child: _buildRichActivityCard(context, event, isDark),
                      );
                    }, childCount: group.events.length),
                  ),
                );
              }
              return slivers;
            }(),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }


  Widget _buildReposTab(
    BuildContext context,
    AppState appState,
    List<dynamic> repos,
  ) {
    return Column(
      children: [
        _buildAISearchSection(context),
        const SizedBox(height: 16),
        _buildFilterChips(appState),
        const SizedBox(height: 16),
        Expanded(
          child: repos.isEmpty
              ? Center(
                  child: Text(
                    'No repositories found matching filters.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 10,
                    bottom: 120,
                  ),
                  itemCount: repos.length,
                  itemBuilder: (context, index) {
                    final repo = repos[index];
                    return _buildRepoCard(context, repo);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResumeTab(BuildContext context, AppState state) {
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_rounded,
                          color: AppTheme.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PASTE YOUR RESUME TEXT',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: state.isReviewingResume
                          ? null
                          : () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['pdf'],
                                    withData: true,
                                  );
                              if (result != null && result.files.isNotEmpty) {
                                final file = result.files.first;
                                if (file.bytes != null) {
                                  state.uploadResume(file.bytes!, file.name);
                                }
                              }
                            },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(
                        'UPLOAD PDF',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _resumeController,
                  maxLines: 8,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Paste resume text here (e.g. skills, experience, education)...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    filled: true,
                    fillColor: AppTheme.isDark
                        ? const Color(0x10FFFFFF)
                        : const Color(0x05000000),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: LiquidGlassButton(
                    onPressed: state.isReviewingResume
                        ? null
                        : () {
                            if (_resumeController.text.trim().isNotEmpty) {
                              state.reviewResume(_resumeController.text.trim());
                            }
                          },
                    borderRadius: 16,
                    color: AppTheme.accent,
                    child: state.isReviewingResume
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ANALYZE & MATCH WITH GITHUB',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.isDark
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (state.resumeAtsScore != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Analysis Output'),
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
                        'ATS ALIGNMENT SCORE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${state.resumeAtsScore}/100',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: state.resumeAtsScore! > 80
                              ? AppTheme.success
                              : state.resumeAtsScore! > 60
                              ? AppTheme.peach
                              : AppTheme.destructive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.resumeAtsScore! / 100,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        state.resumeAtsScore! > 80
                            ? AppTheme.success
                            : state.resumeAtsScore! > 60
                            ? AppTheme.peach
                            : AppTheme.destructive,
                      ),
                    ),
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  _buildBulletList(
                    'MISSING TECHNOLOGIES',
                    state.resumeMissingTech ?? [],
                    AppTheme.destructive,
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  _buildBulletList(
                    'WEAK BULLET POINTS',
                    state.resumeWeakBullets ?? [],
                    AppTheme.peach,
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  _buildBulletList(
                    'RECOMMENDED UPGRADES',
                    state.resumeProjectImprovements ?? [],
                    AppTheme.success,
                  ),
                  if (state.resumeMindsetUpgrades != null &&
                      state.resumeMindsetUpgrades!.isNotEmpty) ...[
                    const Divider(height: 32, color: Colors.white12),
                    _buildBulletList(
                      'DEVELOPER MINDSET UPGRADES',
                      state.resumeMindsetUpgrades!,
                      AppTheme.accent,
                    ),
                  ],
                  if (state.resumeSkillUpgrades != null &&
                      state.resumeSkillUpgrades!.isNotEmpty) ...[
                    const Divider(height: 32, color: Colors.white12),
                    _buildBulletList(
                      'SKILL UPGRADES (assessment: skill.sh)',
                      state.resumeSkillUpgrades!,
                      AppTheme.blue,
                    ),
                  ],
                ],
              ),
            ),
          ],
          _buildResumeTailorSection(context, state),
        ],
      ),
    );
  }

  Widget _buildResumeTailorSection(BuildContext context, AppState state) {
    if (state.lastUploadedResumeText == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionHeader(context, 'Tailor & Sync Resume'),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI TAILORING & GOOGLE DRIVE SYNC',
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
                'Provide the target job title and description to tailor your resume for this position and automatically sync it to your Google Drive.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jobTitleController,
                style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Target Job Title',
                  labelStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  hintText: 'e.g. Senior Flutter Engineer',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jobDescController,
                maxLines: 4,
                style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Job Description / Requirements',
                  labelStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  hintText:
                      'Paste target job requirements and key responsibilities here...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: state.isGeneratingResume
                      ? null
                      : () {
                          final title = _jobTitleController.text.trim();
                          final desc = _jobDescController.text.trim();
                          if (title.isNotEmpty && desc.isNotEmpty) {
                            state.generateTailoredResume(
                              resumeText: state.lastUploadedResumeText!,
                              jobTitle: title,
                              jobDescription: desc,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Please fill out both job title and description.',
                                ),
                                backgroundColor: AppTheme.destructive,
                              ),
                            );
                          }
                        },
                  icon: state.isGeneratingResume
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(
                    state.isGeneratingResume
                        ? 'TAILORING...'
                        : 'TAILOR & SYNC TO GDRIVE',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (state.generatedResumeText != null) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ATS MATCH FORECAST',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${state.generatedResumeAtsForecast}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.googleDriveSyncInfo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppTheme.success,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Successfully synced to Google Drive!',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'File: ${state.googleDriveSyncInfo!['file_name']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.open_in_new_rounded,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          onPressed: () async {
                            final link =
                                state.googleDriveSyncInfo!['web_view_link'];
                            if (link != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Simulating Google Drive open: $link',
                                  ),
                                  backgroundColor: AppTheme.accent,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'APPLIED OPTIMIZATIONS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...?state.generatedResumeOptimizations?.map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            opt,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GENERATED RESUME (MARKDOWN)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    AnimatedCopyButton(
                      text: state.generatedResumeText ?? '',
                      size: 16,
                      color: AppTheme.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      state.generatedResumeText ?? '',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletList(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'None detected! Looking great.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          )
        else
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontSize: 14)),
                  Expanded(
                    child: Text(
                      it,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }



  Widget _buildAwesomeListsTab(BuildContext context, AppState state) {
    if (state.isLoadingAwesomeLists) {
      return const TatvikLoader();
    }

    final lists = state.awesomeLists;

    return RefreshIndicator(
      onRefresh: () => state.fetchAwesomeLists(),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 120,
        ),
        itemCount: lists.isEmpty ? 1 : lists.length,
        itemBuilder: (context, index) {
          if (lists.isEmpty) {
            return GlassCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No awesome lists found. Tap to fetch.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LiquidGlassButton(
                      child: Text(
                        'Fetch Awesome Lists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => state.fetchAwesomeLists(),
                    ),
                  ],
                ),
              ),
            );
          }

          final repo = lists[index];
          final title = '${repo['owner']}/${repo['name']}';
          final desc = repo['description'] ?? 'No description';
          final stars = repo['stars'] ?? 0;
          final url = repo['url'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: AppTheme.accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMain,
                      height: 1.4,
                    ),
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.peach,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$stars',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Text(
                              'VIEW ON GITHUB',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: AppTheme.accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResearchTab(BuildContext context, AppState state) {
    final subTabs = [
      {'label': 'GitHub', 'icon': Icons.code_rounded},
      {'label': 'YouTube', 'icon': Icons.play_circle_fill_rounded},
      {'label': 'Reddit', 'icon': Icons.reddit_rounded},
      {'label': 'RSS', 'icon': Icons.rss_feed_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-tab selectors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(subTabs.length, (idx) {
                final isSelected = _researchSubTab == idx;
                final tab = subTabs[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tab['label'] as String),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _researchSubTab = idx;
                          state.researchResult = null;
                          state.researchError = null;
                          _researchUrlController.clear();
                          _researchQueryController.clear();
                        });
                      }
                    },
                    avatar: Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                    ),
                    selectedColor: AppTheme.accent,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Inputs Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      subTabs[_researchSubTab]['icon'] as IconData,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RESEARCH ${subTabs[_researchSubTab]['label']?.toString().toUpperCase()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_researchSubTab != 2) ...[
                  TextField(
                    controller: _researchUrlController,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: _researchSubTab == 0
                          ? 'GITHUB REPOSITORY URL'
                          : _researchSubTab == 1
                          ? 'YOUTUBE VIDEO URL'
                          : 'RSS FEED URL',
                      labelStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                      hintText: _researchSubTab == 0
                          ? 'e.g. https://github.com/flutter/flutter'
                          : _researchSubTab == 1
                          ? 'e.g. https://www.youtube.com/watch?v=...'
                          : 'e.g. https://news.ycombinator.com/rss',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_researchSubTab == 0 || _researchSubTab == 2) ...[
                  TextField(
                    controller: _researchQueryController,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: _researchSubTab == 0
                          ? 'SEARCH QUERY (OPTIONAL)'
                          : 'TOPIC / KEYWORDS',
                      labelStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                      hintText: _researchSubTab == 0
                          ? 'e.g. state management'
                          : 'e.g. fastml, flutter performance',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (state.researchError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.destructive.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      state.researchError!,
                      style: TextStyle(
                        color: AppTheme.destructive,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],

                if (state.isRateLimited) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.destructive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.destructive.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.destructive,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rate limit exceeded. Please wait a few minutes before trying again.',
                            style: TextStyle(
                              color: AppTheme.destructive,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isResearching
                        ? null
                        : () {
                            state.clearRateLimit();
                            final url = _researchUrlController.text.trim();
                            final query = _researchQueryController.text.trim();

                            if (_researchSubTab == 0) {
                              if (url.isEmpty && query.isEmpty) return;
                              state.fetchResearchData('github', {
                                if (url.isNotEmpty) 'url': url,
                                if (query.isNotEmpty) 'query': query,
                              });
                            } else if (_researchSubTab == 1) {
                              if (url.isEmpty) return;
                              state.fetchResearchData('youtube', {'url': url});
                            } else if (_researchSubTab == 2) {
                              if (query.isEmpty) return;
                              state.fetchResearchData('reddit', {
                                'query': query,
                              });
                            } else if (_researchSubTab == 3) {
                              if (url.isEmpty) return;
                              state.fetchResearchData('rss', {'url': url});
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: state.isResearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'START RESEARCH SCAN',
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

          if (state.researchResult != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Research Insights'),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SUMMARY & ANALYSIS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      AnimatedCopyButton(
                        text: state.researchResult!['summary'] ?? '',
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Text(
                    state.researchResult!['summary'] ?? 'No summary returned.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMain,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.forum_outlined,
                        size: 18,
                        color: AppTheme.accent,
                      ),
                      label: Text(
                        'DISCUSS WITH TATVIK',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.accent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final platform =
                            state.researchResult!['platform'] ??
                            'research sources';
                        final urlOrQuery =
                            state.researchResult!['url'] ??
                            state.researchResult!['query'] ??
                            '';
                        final summaryText =
                            state.researchResult!['summary'] ?? '';

                        state.addSystemMessageToChat(
                          'I have performed Deep Research on $platform ($urlOrQuery):\n\n'
                          '$summaryText\n\n'
                          'Let\'s discuss these findings! Ask me about specific technical details or next steps.',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MentorChatScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          _buildSectionHeader(context, 'Latest Technical Digest'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.newspaper_rounded,
                          color: AppTheme.peach,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TECH NEWS DIGEST',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (state.isLoadingTechDigest)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            state.fetchWeeklyTechDigest(force: true),
                      ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),
                if (state.weeklyTechDigest != null)
                  Text(
                    state.weeklyTechDigest!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  )
                else
                  Text(
                    'Generating latest technical digest from HackerNews RSS feed...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(title, style: Theme.of(context).textTheme.titleMedium)],
    );
  }

  Widget _buildAISearchSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.isDark ? Colors.white : AppTheme.accent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI RECO RECOMMENDER',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.isDark ? Colors.white70 : AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(color: AppTheme.textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'Search topics to get AI repository recommendations...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x0A000000),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _filterChip(state, 'All'),
          _filterChip(state, 'Beginner'),
          _filterChip(state, 'Intermediate'),
          _filterChip(state, 'Advanced'),
        ],
      ),
    );
  }

  Widget _filterChip(AppState state, String label) {
    final isSelected = state.repoFilter == label;
    final int count = label == 'All'
        ? state.allRepositories.length
        : state.allRepositories.where((r) => r.difficulty == label).length;

    return GestureDetector(
      onTap: () => state.setRepoFilter(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: AppTheme.isDark ? 0.08 : 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : AppTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected
                ? (AppTheme.isDark ? Colors.black : Colors.white)
                : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRepoCard(BuildContext context, Repository repo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _showRepoDetailDialog(context, repo),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${repo.owner} / ${repo.name}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          repo.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textMain),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text(
                        '${repo.impactScore}',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      Text(
                        'MATCH',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...repo.tags.map((tag) => _tagWidget(tag, AppTheme.accent)),
                  _tagWidget(
                    repo.difficulty,
                    repo.difficulty == 'Advanced'
                        ? AppTheme.destructive
                        : repo.difficulty == 'Intermediate'
                        ? AppTheme.peach
                        : AppTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Learning Value',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                  Text(
                    '${repo.impactScore}/100',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: repo.impactScore / 100,
                  backgroundColor: const Color(0xFF222222),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepoDetailDialog(BuildContext context, Repository repo) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.isDark
              ? const Color(0xFF1E1E24)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '${repo.owner} / ${repo.name}',
            style: TextStyle(
              color: AppTheme.textMain,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIFFICULTY: ${repo.difficulty.toUpperCase()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: repo.difficulty == 'Advanced'
                      ? AppTheme.destructive
                      : repo.difficulty == 'Intermediate'
                      ? AppTheme.peach
                      : AppTheme.success,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                repo.description,
                style: TextStyle(
                  color: AppTheme.textMain,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const Divider(height: 24, color: Colors.white12),
              Text(
                'WHY RECOMMENDED:',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                repo.whyRecommended,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricCell(
                    'Match Score',
                    '${repo.impactScore}%',
                    AppTheme.accent,
                  ),
                  _buildMetricCell(
                    'Difficulty',
                    repo.difficulty,
                    AppTheme.peach,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCell(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
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

  Widget _tagWidget(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewerTab(BuildContext context, AppState state) {
    return const ReviewerScreen();
  }

  Widget _buildRichActivityCard(
    BuildContext context,
    GitHubActivityEvent event,
    bool isDark,
  ) {
    // Determine header action text
    String actionText = 'pushed to';
    if (event.type == 'PullRequestEvent') {
      actionText = event.prAction == 'merged' ? 'merged a PR in' : 'opened a PR in';
    } else if (event.type == 'IssuesEvent') {
      actionText = 'opened an issue in';
    } else if (event.type == 'WatchEvent') {
      actionText = 'starred';
    } else if (event.type == 'CreateEvent') {
      actionText = 'created a repository';
    } else if (event.type == 'ForkEvent') {
      actionText = 'forked';
    } else if (event.type == 'ReleaseEvent') {
      actionText = 'published a release in';
    } else if (event.type == 'IssueCommentEvent') {
      actionText = 'commented on an issue in';
    }

    final String? targetUrl = _getActivityTargetUrl(event);

    return MouseRegion(
      cursor: targetUrl != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: targetUrl != null
            ? () async {
                final uri = Uri.tryParse(targetUrl);
                if (uri != null) {
                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              }
            : null,
        child: GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Actor Row (GitHub Mobile Style)
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: event.actorAvatarUrl.isNotEmpty
                        ? NetworkImage(event.actorAvatarUrl)
                        : null,
                    radius: 12,
                    backgroundColor: AppTheme.border,
                    child: event.actorAvatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: event.actorLogin,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          TextSpan(text: ' $actionText '),
                          TextSpan(
                            text: event.repoName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(event.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              
              if (event.displayTitle.isNotEmpty || event.aiSummaryBullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title / Commit Message
                      if (event.displayTitle.isNotEmpty) ...[
                        Text(
                          event.displayTitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMain,
                            height: 1.4,
                          ),
                        ),
                        if (event.aiSummaryBullets.isNotEmpty) const SizedBox(height: 12),
                      ],
                      
                      // Summary Bullets
                      if (event.aiSummaryBullets.isNotEmpty)
                        ...event.aiSummaryBullets.map((bullet) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, right: 8),
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppTheme.textSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            
                      // Diff Stats
                      if ((event.commitCount ?? 0) > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.commit_rounded, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${event.commitCount} commit${event.commitCount! > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if ((event.additions ?? 0) > 0) ...[
                              Text(
                                '+${event.additions}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if ((event.deletions ?? 0) > 0)
                              Text(
                                '-${event.deletions}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF453A),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActivityTypeBadge(event.type, isDark),
                  if (targetUrl != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View on GitHub',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: AppTheme.accent,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getActivityTargetUrl(GitHubActivityEvent event) {
    if (event.type == 'PushEvent' && event.commits.isNotEmpty) {
      final sha = event.commits.first['sha'];
      if (sha != null && sha.isNotEmpty) {
        return 'https://github.com/${event.repoName}/commit/$sha';
      }
    } else if (event.type == 'PullRequestEvent' && event.prNumber != null) {
      return 'https://github.com/${event.repoName}/pull/${event.prNumber}';
    } else if (event.type == 'IssuesEvent' && event.issueNumber != null) {
      return 'https://github.com/${event.repoName}/issues/${event.issueNumber}';
    } else if (event.type == 'IssueCommentEvent' && event.issueNumber != null) {
      return 'https://github.com/${event.repoName}/issues/${event.issueNumber}';
    }
    return 'https://github.com/${event.repoName}';
  }

  Widget _buildActivityTypeBadge(String type, bool isDark) {
    String label = 'Activity';
    IconData icon = Icons.info_outline;
    Color color = AppTheme.textSecondary;

    if (type == 'PushEvent') {
      label = 'Push';
      icon = Icons.commit_rounded;
      color = AppTheme.accent;
    } else if (type == 'PullRequestEvent') {
      label = 'PR';
      icon = Icons.merge_type_rounded;
      color = AppTheme.success;
    } else if (type == 'IssuesEvent') {
      label = 'Issue';
      icon = Icons.error_outline_rounded;
      color = const Color(0xFFFF9500);
    } else if (type == 'IssueCommentEvent') {
      label = 'Comment';
      icon = Icons.comment_rounded;
      color = const Color(0xFF34C759);
    } else if (type == 'WatchEvent') {
      label = 'Star';
      icon = Icons.star_rounded;
      color = const Color(0xFFFFCC00);
    } else if (type == 'ForkEvent') {
      label = 'Fork';
      icon = Icons.fork_right_rounded;
      color = const Color(0xFF5856D6);
    } else if (type == 'ReleaseEvent') {
      label = 'Release';
      icon = Icons.new_releases_rounded;
      color = const Color(0xFFAF52DE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
