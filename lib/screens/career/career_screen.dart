import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_button.dart';
import '../roadmap/roadmap_screen.dart';
import '../profile/profile_screen.dart';

import '../repositories/discover_repos_screen.dart';

class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text('Career', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textMain, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Your growth path, skills, and opportunities',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            _buildProfileCard(context, appState),
            const SizedBox(height: 24),
            _buildRoadmapSection(context, appState),
            const SizedBox(height: 24),
            _buildBattleSection(context, appState),
            const SizedBox(height: 24),
            _buildExploreSection(context),
            const SizedBox(height: 24),
            _buildResumeSection(context),
            const SizedBox(height: 24),
            _buildSettingsSection(context, appState),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AppState state) {
    String initials = 'AJ';
    try {
      final parts = state.username.split(' ');
      if (parts.length >= 2) {
        initials = parts[0].substring(0, 1) + parts[1].substring(0, 1);
      } else if (state.username.isNotEmpty) {
        initials = state.username.substring(0, 2).toUpperCase();
      }
    } catch (_) {}

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accent, borderRadius: BorderRadius.circular(16),
              image: state.avatarUrl != null
                  ? DecorationImage(image: NetworkImage(state.avatarUrl!), fit: BoxFit.cover) : null,
            ),
            child: state.avatarUrl == null
                ? Center(child: Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(state.username, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('PRO', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text('@${state.githubUsername.toLowerCase()}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('${state.repos} repos · ${state.commits} commits · ${state.stars} stars',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapSection(BuildContext context, AppState state) {
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
                child: Icon(Icons.route_rounded, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text('ROADMAP', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text(state.roadmapTitle.isNotEmpty ? state.roadmapTitle : 'Your personalized career roadmap',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
          if (state.milestones.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.roadmapProgress,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(state.roadmapProgress * 100).toInt()}% complete · ${state.milestones.length} milestones',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
              color: AppTheme.accent,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('OPEN ROADMAP', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleSection(BuildContext context, AppState state) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.destructive.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.sports_martial_arts_rounded, color: AppTheme.destructive, size: 20),
              ),
              const SizedBox(width: 12),
              Text('SKILL BATTLE', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Compare your profile against target roles to find skill gaps.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (state.battleMatchScore != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Match: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Text('${state.battleMatchScore}%', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.destructive)),
              ],
            ),
            if (state.battleMissingSkills != null && state.battleMissingSkills!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('GAPS TO FILL:', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.destructive, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...state.battleMissingSkills!.take(3).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline, size: 12, color: AppTheme.destructive),
                    const SizedBox(width: 6),
                    Text(s, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              )),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoadmapScreen())),
              color: AppTheme.destructive.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('START BATTLE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.destructive)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreSection(BuildContext context) {
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
                child: Icon(Icons.explore_rounded, color: AppTheme.neonGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Text('LEARN', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Discover curated open-source repositories and learning paths.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverReposScreen())),
              color: AppTheme.neonGreen.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('EXPLORE PROJECTS', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.neonGreen)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.peach.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.description_rounded, color: AppTheme.peach, size: 20),
              ),
              const SizedBox(width: 12),
              Text('RESUME', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Get AI-powered ATS scoring, missing tech detection, and weak bullet analysis.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const _ResumeReviewerScreen()));
              },
              color: AppTheme.peach.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('REVIEW RESUME', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.peach)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, AppState state) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.textSecondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.settings_rounded, color: AppTheme.textSecondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('SETTINGS', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              color: AppTheme.textSecondary.withValues(alpha: 0.15),
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('OPEN SETTINGS', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeReviewerScreen extends StatefulWidget {
  const _ResumeReviewerScreen();
  @override
  State<_ResumeReviewerScreen> createState() => _ResumeReviewerScreenState();
}

class _ResumeReviewerScreenState extends State<_ResumeReviewerScreen> {
  Map<String, dynamic>? _result;
  bool _loading = false;
  PlatformFile? _selectedFile;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _selectedFile = result.files.first;
      _loading = true;
    });

    final state = Provider.of<AppState>(context, listen: false);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/intelligence/resume-review'),
      );
      request.headers['Authorization'] = 'Bearer ${state.token ?? ''}';
      request.files.add(http.MultipartFile.fromBytes(
        'file', result.files.first.bytes!,
        filename: result.files.first.name,
      ));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        setState(() => _result = jsonDecode(response.body));
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Resume Reviewer', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
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
                      Icon(Icons.description_rounded, color: AppTheme.peach, size: 18),
                      const SizedBox(width: 10),
                      Text('ATS SCORING', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Upload your resume for AI-powered ATS scoring, missing tech detection, and weak bullet analysis.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 24),
                  if (_loading)
                    const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                  else if (_result != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_result!['ats_score'] != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppTheme.accent.withValues(alpha: 0.1), AppTheme.neonPurple.withValues(alpha: 0.05)]),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Text('ATS Score: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                Text('${_result!['ats_score']}%', style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                              ],
                            ),
                          ),
                        if (_result!['missing_tech'] is List && (_result!['missing_tech'] as List).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('MISSING TECHNOLOGIES', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.destructive, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...(_result!['missing_tech'] as List).map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Icon(Icons.warning_rounded, size: 14, color: AppTheme.destructive),
                              const SizedBox(width: 8),
                              Text(t.toString(), style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ]),
                          )),
                        ],
                        if (_result!['weak_bullets'] is List && (_result!['weak_bullets'] as List).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('WEAK BULLETS', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.peach, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...(_result!['weak_bullets'] as List).map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.peach),
                              const SizedBox(width: 8),
                              Expanded(child: Text(b.toString(), style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                            ]),
                          )),
                        ],
                        const SizedBox(height: 20),
                        LiquidGlassButton(
                          onPressed: () => setState(() => _result = null),
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('UPLOAD ANOTHER', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accent)),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: _pickAndUpload,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.upload_file_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(_selectedFile?.name ?? 'Upload resume (PDF/DOCX)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
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
