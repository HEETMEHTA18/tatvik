import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../memory/memory_screen.dart';
import '../studio/studio_screen.dart';
import '../career/career_screen.dart';

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});
  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  final Set<String> _categories = {'All'};

  @override
  void initState() {
    super.initState();
    _fetchPulse();
  }

  Future<void> _fetchPulse() async {
    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    try {
      final categoryParam = _selectedCategory == 'All' ? '' : _selectedCategory;
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/research/pulse?category=$categoryParam&limit=50'),
        headers: {'Authorization': 'Bearer ${state.token ?? ''}'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _items = data['items'] ?? [];
          for (final item in _items) {
            final cat = item['category'];
            if (cat != null && cat.toString().isNotEmpty) _categories.add(cat.toString());
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchPulse,
        color: AppTheme.accent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text('Pulse', style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textMain, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Tech intelligence from across the ecosystem',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 20),
                    _buildPageNav(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (_categories.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: _categories.map((cat) {
                      final selected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            _fetchPulse();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.accent : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
                            ),
                            child: Text(cat,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10, fontWeight: FontWeight.bold,
                                  color: selected ? Colors.black : AppTheme.textSecondary,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.travel_explore_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No pulse items yet', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text('The scanner will fetch items periodically.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _items[index];
                      return _buildPulseCard(context, item);
                    },
                    childCount: _items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNav(BuildContext context) {
    final pages = [
      ('Memory', Icons.memory_rounded, false, const MemoryScreen()),
      ('Pulse', Icons.travel_explore_rounded, true, const PulseScreen()),
      ('Studio', Icons.build_circle_rounded, false, const StudioScreen()),
      ('Career', Icons.route_rounded, false, const CareerScreen()),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: pages.map((p) {
        final (label, icon, active, page) = p;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: active ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: active ? Border.all(color: AppTheme.accent.withValues(alpha: 0.3)) : Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: active ? AppTheme.accent : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? AppTheme.accent : AppTheme.textSecondary)),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildPulseCard(BuildContext context, dynamic item) {
    final title = item['title'] ?? 'Untitled';
    final summary = item['summary'] ?? '';
    final source = item['source'] ?? 'unknown';
    final url = item['url'] ?? '';
    final category = item['category'] ?? '';
    final techs = item['related_technologies'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: InkWell(
          onTap: url.toString().isNotEmpty ? () => launchUrl(Uri.parse(url.toString()), mode: LaunchMode.externalApplication) : null,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _categoryColor(category).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(category.toString().toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: _categoryColor(category))),
                  ),
                  const SizedBox(width: 8),
                  Text(source.toString().toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(title.toString(), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
              if (summary.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(summary.toString(), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (techs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: techs.take(4).map<Widget>((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
                    ),
                    child: Text(t.toString(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                  )).toList(),
                ),
              ],
              if (url.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'github': return AppTheme.neonGreen;
      case 'news': return AppTheme.accent;
      case 'security': return AppTheme.destructive;
      case 'ai': case 'ml': return AppTheme.neonPurple;
      case 'tutorial': return AppTheme.peach;
      case 'release': return AppTheme.blue;
      default: return AppTheme.textSecondary;
    }
  }
}
