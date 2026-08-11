import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_button.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (appState.showLinkGitHubPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !appState.showLinkGitHubPrompt) return;
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
        },
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        child: Stack(
          children: [
            Positioned(
              top: -100, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Workspace', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textMain, letterSpacing: -0.5)),
                          _NotificationBadge(appState: appState),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _WelcomeHeader(appState: appState),
                      const SizedBox(height: 24),
                      SizedBox(width: w, child: _ScoreSection(appState: appState)),
                      const SizedBox(height: 24),
                      SizedBox(width: w, child: _ActivityHeatmap(appState: appState)),
                      const SizedBox(height: 24),
                      SizedBox(width: w, child: _PullRequestsSection(appState: appState)),
                      const SizedBox(height: 24),
                      SizedBox(width: w, child: _AgentDigest(appState: appState)),
                      const SizedBox(height: 180),
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
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)],
          ),
          child: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _QuickTaskScreen())),
            elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: Container(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 20, color: Colors.white),
                    SizedBox(height: 2),
                    Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLinkGitHubDialog(BuildContext context, AppState state) {
    final controller = TextEditingController(text: state.githubUsername);
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Link GitHub', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: controller, autofocus: true, style: TextStyle(color: AppTheme.textMain), decoration: InputDecoration(
            labelText: 'GitHub Username', prefixText: '@ ',
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
          )),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            const SizedBox(width: 12),
            LiquidGlassButton(onPressed: () { final u = controller.text.trim(); if (u.isNotEmpty) state.setGithubUsername(u); Navigator.pop(ctx); },
                color: AppTheme.accent, borderRadius: 8, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: const Text('Save')),
          ]),
        ]),
      ),
    ));
  }
}

class _NotificationBadge extends StatelessWidget {
  final AppState appState;
  const _NotificationBadge({required this.appState});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showNotificationCenter(context, appState),
      child: Stack(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: AppTheme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
          child: Icon(appState.unreadNotificationsCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18,
              color: appState.unreadNotificationsCount > 0 ? AppTheme.accent : AppTheme.textSecondary)),
        if (appState.unreadNotificationsCount > 0)
          Positioned(right: 0, top: 0, child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle, border: Border.all(color: AppTheme.surface, width: 2)),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Center(child: Text('${appState.unreadNotificationsCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          )),
      ]),
    );
  }

  void _showNotificationCenter(BuildContext context, AppState state) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, barrierColor: Colors.black.withValues(alpha: 0.3), builder: (ctx) => Container(
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.border, width: 1.5))),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (state.notifications.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No notifications')))
          else
            ...state.notifications.take(10).map((n) => ListTile(
              leading: Icon(Icons.circle, size: 10, color: AppTheme.accent),
              title: Text(n['title'] ?? '', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(n['body'] ?? '', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            )),
        ]))),
      ),
    ));
  }
}

class _WelcomeHeader extends StatelessWidget {
  final AppState appState;
  const _WelcomeHeader({required this.appState});
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting; IconData greetingIcon;
    if (hour < 12) { greeting = 'Good Morning'; greetingIcon = Icons.wb_sunny_rounded; }
    else if (hour < 17) { greeting = 'Good Afternoon'; greetingIcon = Icons.light_mode_rounded; }
    else { greeting = 'Good Evening'; greetingIcon = Icons.nights_stay_rounded; }
    final firstName = appState.username.split(' ').first;
    return GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accent,
            border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.5), width: 2),
            image: appState.avatarUrl != null ? DecorationImage(image: NetworkImage(appState.avatarUrl!), fit: BoxFit.cover) : null,
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: appState.avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(greetingIcon, size: 16, color: AppTheme.neonOrange), const SizedBox(width: 6),
            Text(greeting, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(firstName, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5, color: AppTheme.textMain))),
        ])),
        Container(decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
          child: IconButton(
            icon: Icon(appState.isDarkTheme ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: AppTheme.textMain, size: 22),
            onPressed: () => appState.toggleTheme(),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.accent.withValues(alpha: 0.08), AppTheme.neonPurple.withValues(alpha: 0.06)]),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15))),
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(appState.gaps.isNotEmpty ? 'Focus: ${appState.gaps.first}' : 'Review your latest commits for quality improvements',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMain, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ]));
  }
}

class _ScoreSection extends StatelessWidget {
  final AppState appState;
  const _ScoreSection({required this.appState});
  @override
  Widget build(BuildContext context) {
    final scoreProgress = (appState.developerScore / 10.0).clamp(0.0, 1.0);
    Color scoreColor = Colors.redAccent;
    if (appState.developerScore >= 8.0) scoreColor = AppTheme.neonGreen;
    else if (appState.developerScore >= 6.0) scoreColor = AppTheme.neonOrange;
    return GlassCard(padding: const EdgeInsets.all(24), child: Row(children: [
      Expanded(flex: 4, child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 60, height: 60, child: CircularProgressIndicator(value: scoreProgress, strokeWidth: 6,
              backgroundColor: AppTheme.border, valueColor: AlwaysStoppedAnimation<Color>(scoreColor))),
          Text('${appState.developerScore}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        ]),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DEV SCORE', style: GoogleFonts.spaceMono(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(appState.developerScore >= 8.0 ? 'Elite' : appState.developerScore >= 6.0 ? 'Pro' : 'Rising',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
        ]),
      ])),
      Container(width: 1, height: 60, color: AppTheme.border, margin: const EdgeInsets.symmetric(horizontal: 24)),
      Expanded(flex: 6, child: Row(children: [
        Expanded(child: _StatItem(value: '${appState.repos}', label: 'Repos', icon: Icons.folder_open, color: AppTheme.neonPurple)),
        Container(height: 40, width: 1, color: AppTheme.border),
        Expanded(child: _StatItem(value: '${appState.commits}', label: 'Commits', icon: Icons.history, color: AppTheme.neonGreen)),
        Container(height: 40, width: 1, color: AppTheme.border),
        Expanded(child: _StatItem(value: '${appState.stars}', label: 'Stars', icon: Icons.star_border, color: AppTheme.neonOrange)),
      ])),
    ]));
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem({required this.value, required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 20, color: color),
    const SizedBox(height: 8),
    Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 4),
    Text(label, style: GoogleFonts.spaceMono(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);
}

class _ActivityHeatmap extends StatelessWidget {
  final AppState appState;
  const _ActivityHeatmap({required this.appState});
  @override
  Widget build(BuildContext context) => GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('ACTIVITY', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: appState.selectedActivityYear,
        dropdownColor: AppTheme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: AppTheme.accent, size: 16),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 10, color: AppTheme.accent),
        onChanged: (v) { if (v != null) appState.setActivityYear(v); },
        items: <String>['2026', '2025', '2024', '2023'].map((y) => DropdownMenuItem(value: y, child: Text(y, style: TextStyle(color: AppTheme.textMain)))).toList(),
      )),
    ]),
    const SizedBox(height: 20),
    appState.isLoadingActivity
        ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
        : SizedBox(height: 120, child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: appState.activityData.length,
            itemBuilder: (_, i) {
              final count = appState.activityData[i]['count'] ?? 0;
              final opacity = count == 0 ? 0.1 : count <= 2 ? 0.4 : count <= 5 ? 0.7 : 1.0;
              return Container(decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: opacity), borderRadius: BorderRadius.circular(2)));
            },
          )),
    const SizedBox(height: 16),
    Row(children: [
      Text('Less', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10)),
      const SizedBox(width: 4),
      ...List.generate(5, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 8, height: 8,
          decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: (i + 1) * 0.2), borderRadius: BorderRadius.circular(2)))),
      const SizedBox(width: 4),
      Text('More', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10)),
    ]),
  ]));
}

class _PullRequestsSection extends StatelessWidget {
  final AppState appState;
  const _PullRequestsSection({required this.appState});
  @override
  Widget build(BuildContext context) {
    final prs = appState.openPullRequests;
    return GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.call_split_rounded, color: AppTheme.success, size: 18),
        const SizedBox(width: 10),
        Text('OPEN PULL REQUESTS', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
      ]),
      const SizedBox(height: 16),
      if (prs.isEmpty)
        Text('No open pull requests', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
      else
        ...prs.take(5).map((pr) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.call_split, color: AppTheme.success, size: 14)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pr['title'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${pr['repo']} #${pr['number']}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary)),
          ])),
        ]))),
    ]));
  }
}

class _AgentDigest extends StatelessWidget {
  final AppState appState;
  const _AgentDigest({required this.appState});
  @override
  Widget build(BuildContext context) {
    final digest = appState.whatsNewDigest;
    final isDark = AppTheme.isDark;
    return GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 18),
        const SizedBox(width: 10),
        Text('AI RESEARCH DIGEST', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        const Spacer(),
        GestureDetector(onTap: () => appState.fetchWhatsNewDigest(),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, size: 12, color: AppTheme.accent),
              const SizedBox(width: 4),
              Text('REFRESH', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accent)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (digest == null)
        GestureDetector(
          onTap: () => appState.fetchWhatsNewDigest(),
          child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1))),
            child: Row(children: [
              Icon(Icons.radar_rounded, color: AppTheme.accent, size: 24),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tap to fetch latest intelligence', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
                Text('GitHub trending + tech news', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ])),
            ]),
          ),
        )
      else ...[
        if ((digest['digest'] as String? ?? '').isNotEmpty)
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isDark ? const Color(0x0AFFFFFF) : const Color(0x08000000),
            borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border.withValues(alpha: 0.2))),
            child: MarkdownBody(data: digest['digest'] as String, selectable: true,
              styleSheet: MarkdownStyleSheet(p: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMain, height: 1.5)))),
        if ((digest['github'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Text('TRENDING', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          ...(digest['github'] as List).take(3).map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF161B22) : AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['owner']}/${item['name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                Text(item['description'] ?? '', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 14, color: AppTheme.peach),
                Text('${item['stars'] ?? 0}', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              ]),
            ]),
          )),
        ],
      ],
    ]));
  }
}

class _QuickTaskScreen extends StatefulWidget {
  const _QuickTaskScreen();
  @override
  State<_QuickTaskScreen> createState() => _QuickTaskScreenState();
}

class _QuickTaskScreenState extends State<_QuickTaskScreen> {
  final _controller = TextEditingController();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Quick Task', style: GoogleFonts.inter(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        TextField(controller: _controller, maxLines: 4, style: TextStyle(color: AppTheme.textMain, fontSize: 15),
          decoration: InputDecoration(hintText: 'Ask me anything...', hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: AppTheme.surface)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: LiquidGlassButton(
          onPressed: () async {
            final query = _controller.text.trim();
            if (query.isEmpty) return;
            await state.sendMessage(query);
            if (context.mounted) Navigator.pop(context);
          },
          color: AppTheme.accent, borderRadius: 16, padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('ASK AI', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: Colors.black)),
        )),
      ])),
    );
  }
}
