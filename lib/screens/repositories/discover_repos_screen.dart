import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_copy_button.dart';
import '../../providers/app_state.dart';
import '../../models/repository.dart';
import '../mentor/mentor_chat_screen.dart';

class DiscoverReposScreen extends StatefulWidget {
  const DiscoverReposScreen({super.key});

  @override
  State<DiscoverReposScreen> createState() => _DiscoverReposScreenState();
}

class _DiscoverReposScreenState extends State<DiscoverReposScreen> {
  String _searchQuery = '';
  int _activeTab = 0;
  final _resumeController = TextEditingController();
  final _projectController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _jobDescController = TextEditingController();
  final _researchUrlController = TextEditingController();
  final _researchQueryController = TextEditingController();
  int _researchSubTab = 0;

  @override
  void dispose() {
    _resumeController.dispose();
    _projectController.dispose();
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
          tabTitle = 'AI Resume Reviewer';
          break;
        case 3:
          tabContent = _buildProjectTab(context, appState);
          tabTitle = 'AI Project Evaluator';
          break;
        case 4:
          tabContent = _buildOpportunitiesTab(context, appState);
          tabTitle = 'Opportunity Scanner';
          break;
        case 5:
          tabContent = _buildResearchTab(context, appState);
          tabTitle = 'Deep Research Agent';
          break;
        default:
          tabContent = Container();
          tabTitle = '';
      }
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textMain),
            onPressed: () => setState(() => _activeTab = 0),
          ),
          title: Text(tabTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
        ),
        body: tabContent,
      );
    }

    // Main Explore tab — GitHub mobile style
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Large title header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Explore',
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Discover Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
              child: Text(
                'Discover',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ),

          // Discover Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                borderRadius: 16,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildDiscoverRow(
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF34C759),
                      label: 'Trending Repositories',
                      onTap: () => setState(() => _activeTab = 1),
                      showDivider: true,
                    ),
                    _buildDiscoverRow(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      iconColor: const Color(0xFFFF9500),
                      label: 'Awesome Lists',
                      onTap: () => setState(() => _activeTab = 4),
                      showDivider: true,
                    ),
                    _buildDiscoverRow(
                      icon: Icons.description_rounded,
                      iconColor: const Color(0xFF5856D6),
                      label: 'AI Resume Reviewer',
                      onTap: () => setState(() => _activeTab = 2),
                      showDivider: true,
                    ),
                    _buildDiscoverRow(
                      icon: Icons.workspace_premium_rounded,
                      iconColor: const Color(0xFFFF2D55),
                      label: 'AI Project Evaluator',
                      onTap: () => setState(() => _activeTab = 3),
                      showDivider: true,
                    ),
                    _buildDiscoverRow(
                      icon: Icons.travel_explore_rounded,
                      iconColor: const Color(0xFF0A84FF),
                      label: 'Deep Research Agent',
                      onTap: () {
                        setState(() => _activeTab = 5);
                        appState.fetchWeeklyTechDigest();
                      },
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Activity Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 12),
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
                child: Center(child: CircularProgressIndicator()),
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
                      Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'No activity yet',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Follow developers on GitHub to see their events here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => appState.fetchFollowingActivity(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Refresh Feed',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF007AFF)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = appState.followingActivity[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 16, right: 16,
                      top: index == 0 ? 0 : 0,
                      bottom: index == appState.followingActivity.length - 1 ? 120 : 12,
                    ),
                    child: _buildActivityCard(context, event, isDark),
                  );
                },
                childCount: appState.followingActivity.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildDiscoverRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Container(height: 0.5, color: AppTheme.border.withValues(alpha: 0.3)),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, Map<String, dynamic> event, bool isDark) {
    final actor = event['actor'] ?? {};
    final repo = event['repo'] ?? {};
    final type = event['type'] ?? 'PushEvent';
    final action = event['action'] ?? '';
    final title = event['title'] ?? 'Activity';
    final body = event['body'] ?? '';
    final createdAtStr = event['created_at'] ?? '';

    DateTime? date;
    if (createdAtStr.isNotEmpty) {
      date = DateTime.tryParse(createdAtStr);
    }
    final now = DateTime.now();
    String timeAgo = '';
    if (date != null) {
      final diff = now.difference(date);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h';
      } else {
        timeAgo = '${diff.inDays}d';
      }
    }

    // Event type styling
    IconData eventIcon = Icons.commit_rounded;
    String typeLabel = 'pushed to';
    Color badgeColor = const Color(0xFF8957E5);
    String badgeLabel = 'Push';

    if (type == 'PullRequestEvent') {
      if (action == 'merged') {
        typeLabel = 'merged a PR in';
        eventIcon = Icons.merge_rounded;
        badgeColor = const Color(0xFF8957E5);
        badgeLabel = 'Merged';
      } else {
        typeLabel = 'opened a PR in';
        eventIcon = Icons.call_merge_rounded;
        badgeColor = const Color(0xFF3FB950);
        badgeLabel = 'Open';
      }
    } else if (type == 'ReleaseEvent') {
      typeLabel = 'published a release for';
      eventIcon = Icons.new_releases_rounded;
      badgeColor = const Color(0xFFFF9500);
      badgeLabel = 'Release';
    } else if (type == 'WatchEvent') {
      typeLabel = 'starred';
      eventIcon = Icons.star_rounded;
      badgeColor = const Color(0xFFE3B341);
      badgeLabel = 'Star';
    }

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actor row
          Row(
            children: [
              CircleAvatar(
                backgroundImage: actor['avatar_url'] != null
                    ? NetworkImage(actor['avatar_url'])
                    : null,
                radius: 16,
                backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                child: actor['avatar_url'] == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain),
                    children: [
                      TextSpan(
                        text: actor['login'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' $typeLabel '),
                      TextSpan(
                        text: repo['name'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.accent),
                      ),
                    ],
                  ),
                ),
              ),
              if (timeAgo.isNotEmpty)
                Text(timeAgo, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),

          // PR/Release card body
          if (title.isNotEmpty && title != 'Activity') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Repo name
                  Text(
                    repo['name'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                  ),
                  // Badge row
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(eventIcon, size: 12, color: badgeColor),
                            const SizedBox(width: 4),
                            Text(
                              badgeLabel,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Summary body
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Summary',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Read more  ›',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accent),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }




  Widget _buildReposTab(BuildContext context, AppState appState, List<dynamic> repos) {
    return Column(
      children: [
        _buildAISearchSection(context),
        const SizedBox(height: 16),
        _buildFilterChips(appState),
        const SizedBox(height: 16),
        Expanded(
          child: repos.isEmpty
            ? Center(child: Text('No repositories found matching filters.', style: Theme.of(context).textTheme.bodyMedium))
            : ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
                itemCount: repos.length,
                itemBuilder: (context, index) {
                  final repo = repos[index];
                  return _buildRepoCard(
                    context,
                    repo,
                  );
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
                        Icon(Icons.description_rounded, color: AppTheme.accent, size: 20),
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
                              final result = await FilePicker.platform.pickFiles(
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
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
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
                    hintText: 'Paste resume text here (e.g. skills, experience, education)...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isReviewingResume
                        ? null
                        : () {
                            if (_resumeController.text.trim().isNotEmpty) {
                              state.reviewResume(_resumeController.text.trim());
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: state.isReviewingResume
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'ANALYZE & MATCH WITH GITHUB',
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
                  _buildBulletList('MISSING TECHNOLOGIES', state.resumeMissingTech ?? [], AppTheme.destructive),
                  const Divider(height: 32, color: Colors.white12),
                  _buildBulletList('WEAK BULLET POINTS', state.resumeWeakBullets ?? [], AppTheme.peach),
                  const Divider(height: 32, color: Colors.white12),
                  _buildBulletList('RECOMMENDED UPGRADES', state.resumeProjectImprovements ?? [], AppTheme.success),
                  if (state.resumeMindsetUpgrades != null && state.resumeMindsetUpgrades!.isNotEmpty) ...[
                    const Divider(height: 32, color: Colors.white12),
                    _buildBulletList('DEVELOPER MINDSET UPGRADES', state.resumeMindsetUpgrades!, AppTheme.accent),
                  ],
                  if (state.resumeSkillUpgrades != null && state.resumeSkillUpgrades!.isNotEmpty) ...[
                    const Divider(height: 32, color: Colors.white12),
                    _buildBulletList('SKILL UPGRADES (assessment: skill.sh)', state.resumeSkillUpgrades!, AppTheme.blue),
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
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 20),
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
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jobTitleController,
                style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Target Job Title',
                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  hintText: 'e.g. Senior Flutter Engineer',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jobDescController,
                maxLines: 4,
                style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Job Description / Requirements',
                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  hintText: 'Paste target job requirements and key responsibilities here...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
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
                                content: const Text('Please fill out both job title and description.'),
                                backgroundColor: AppTheme.destructive,
                              ),
                            );
                          }
                        },
                  icon: state.isGeneratingResume
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(
                    state.isGeneratingResume ? 'TAILORING...' : 'TAILOR & SYNC TO GDRIVE',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 20),
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
                          icon: Icon(Icons.open_in_new_rounded, color: AppTheme.accent, size: 18),
                          onPressed: () async {
                            final link = state.googleDriveSyncInfo!['web_view_link'];
                            if (link != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Simulating Google Drive open: $link'),
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
                ...?state.generatedResumeOptimizations?.map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              opt,
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMain),
                            ),
                          ),
                        ],
                      ),
                    )),
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
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMain),
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
          Text('None detected! Looking great.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
        else
          ...items.map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color, fontSize: 14)),
                Expanded(
                  child: Text(
                    it,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildProjectTab(BuildContext context, AppState state) {
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
                    Icon(Icons.workspace_premium_rounded, color: AppTheme.peach, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'EVALUATE PROJECT IDEA',
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
                  controller: _projectController,
                  maxLines: 2,
                  style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter project name (e.g. Expense Tracker)...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    filled: true,
                    fillColor: AppTheme.isDark ? const Color(0x10FFFFFF) : const Color(0x05000000),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state.isEvaluatingProject
                        ? null
                        : () {
                            if (_projectController.text.trim().isNotEmpty) {
                              state.evaluateProject(_projectController.text.trim());
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.peach,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: state.isEvaluatingProject
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'GET VALUE SCORE & PATH',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.isDark ? Colors.black : Colors.white,
                            ),
                          ),
                  ),
                ),
                if (state.isRateLimited) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.destructive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.destructive.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.destructive, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rate limit exceeded. Please wait a few minutes before trying again.',
                            style: TextStyle(color: AppTheme.destructive, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (state.evaluatedProjectScore != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Evaluation Insights'),
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
                        'RESUME VALUE SCORE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${state.evaluatedProjectScore}/10',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: state.evaluatedProjectScore! >= 7 
                              ? AppTheme.success 
                              : state.evaluatedProjectScore! >= 5 
                                  ? AppTheme.peach 
                                  : AppTheme.destructive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.evaluatedProjectExplanation ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMain,
                      height: 1.4,
                    ),
                  ),
                  const Divider(height: 32, color: Colors.white12),
                  Text(
                    '4-STEP PREMIUM UPGRADE PATH',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(state.evaluatedProjectUpgradePath ?? []).map((step) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.upgrade_rounded, color: AppTheme.accent, size: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.3,
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

  Widget _buildOpportunitiesTab(BuildContext context, AppState state) {
    if (state.isLoadingOpportunities) {
      return const Center(child: CircularProgressIndicator());
    }

    final opps = state.techOpportunities ?? [];

    return RefreshIndicator(
      onRefresh: () => state.fetchOpportunities(),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
        itemCount: opps.isEmpty ? 1 : opps.length,
        itemBuilder: (context, index) {
          if (opps.isEmpty) {
            return GlassCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No opportunities scanned yet. Try pulling to refresh.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            );
          }

          final opp = opps[index];
          final title = opp['title'] ?? 'Dynamic Project Idea';
          final why = opp['why'] ?? 'Trending in tech industry circles.';
          final stack = opp['tech_stack'] ?? 'Flutter, FastAPI, Postgres';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
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
                        child: Icon(Icons.trending_up_rounded, color: AppTheme.accent, size: 18),
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
                    'WHY BUILD THIS:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    why,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMain,
                      height: 1.4,
                    ),
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    children: [
                      Text(
                        'RECOMMENDED STACK: ',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          stack,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: AppTheme.textSecondary,
                          ),
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
                    Icon(subTabs[_researchSubTab]['icon'] as IconData, color: AppTheme.accent, size: 20),
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
                      labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                      hintText: _researchSubTab == 0
                          ? 'e.g. https://github.com/flutter/flutter'
                          : _researchSubTab == 1
                              ? 'e.g. https://www.youtube.com/watch?v=...'
                              : 'e.g. https://news.ycombinator.com/rss',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_researchSubTab == 0 || _researchSubTab == 2) ...[
                  TextField(
                    controller: _researchQueryController,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: _researchSubTab == 0 ? 'SEARCH QUERY (OPTIONAL)' : 'TOPIC / KEYWORDS',
                      labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                      hintText: _researchSubTab == 0 ? 'e.g. state management' : 'e.g. fastml, flutter performance',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (state.researchError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.destructive.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      state.researchError!,
                      style: TextStyle(color: AppTheme.destructive, fontSize: 12),
                    ),
                  ),
                ],

                if (state.isRateLimited) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.destructive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.destructive.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.destructive, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rate limit exceeded. Please wait a few minutes before trying again.',
                            style: TextStyle(color: AppTheme.destructive, fontSize: 12, fontWeight: FontWeight.w600),
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
                              state.fetchResearchData('reddit', {'query': query});
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
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
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
                      AnimatedCopyButton(text: state.researchResult!['summary'] ?? ''),
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
                      icon: Icon(Icons.forum_outlined, size: 18, color: AppTheme.accent),
                      label: Text(
                        'DISCUSS WITH AI MENTOR',
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final platform = state.researchResult!['platform'] ?? 'research sources';
                        final urlOrQuery = state.researchResult!['url'] ?? state.researchResult!['query'] ?? '';
                        final summaryText = state.researchResult!['summary'] ?? '';
                        
                        state.addSystemMessageToChat(
                          'I have performed Deep Research on $platform ($urlOrQuery):\n\n'
                          '$summaryText\n\n'
                          'Let\'s discuss these findings! Ask me about specific technical details or next steps.'
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
                        Icon(Icons.newspaper_rounded, color: AppTheme.peach, size: 16),
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
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => state.fetchWeeklyTechDigest(force: true),
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
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
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
                Icon(Icons.auto_awesome_rounded, color: AppTheme.isDark ? Colors.white : AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'AI RECO RECOMMENDER', 
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.isDark ? Colors.white70 : AppTheme.accent, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  )
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
                hintText: 'Search topics to get AI repository recommendations...',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            color: isSelected ? (AppTheme.isDark ? Colors.black : Colors.white) : AppTheme.textSecondary,
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
                        Text('${repo.owner} / ${repo.name}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(repo.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMain)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text('${repo.impactScore}', style: Theme.of(context).textTheme.displayMedium),
                      Text('MATCH', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textSecondary)),
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
                  _tagWidget(repo.difficulty, repo.difficulty == 'Advanced' ? AppTheme.destructive : repo.difficulty == 'Intermediate' ? AppTheme.peach : AppTheme.success),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Learning Value', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
                  Text('${repo.impactScore}/100', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMain)),
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
          backgroundColor: AppTheme.isDark ? const Color(0xFF1E1E24) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${repo.owner} / ${repo.name}', style: TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DIFFICULTY: ${repo.difficulty.toUpperCase()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: repo.difficulty == 'Advanced' ? AppTheme.destructive : repo.difficulty == 'Intermediate' ? AppTheme.peach : AppTheme.success,
                ),
              ),
              const SizedBox(height: 12),
              Text(repo.description, style: TextStyle(color: AppTheme.textMain, fontSize: 13, height: 1.4)),
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
              Text(repo.whyRecommended, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricCell('Match Score', '${repo.impactScore}%', AppTheme.accent),
                  _buildMetricCell('Difficulty', repo.difficulty, AppTheme.peach),
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
          Text(val, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: col)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
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
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}
