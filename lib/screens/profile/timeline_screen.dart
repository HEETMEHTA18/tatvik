import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  bool _isLoading = true;
  List<dynamic> _timeline = [];

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  Future<void> _fetchTimeline() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.token == null || appState.token!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/timeline/?limit=50'),
        headers: {'Authorization': 'Bearer ${appState.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _timeline = data['timeline'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'prompt':
        return Icons.auto_awesome;
      case 'coding_session':
        return Icons.code;
      case 'repository':
        return Icons.book_outlined;
      case 'memory_graph':
        return Icons.memory;
      default:
        return Icons.history;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'prompt':
        return AppTheme.accent;
      case 'coding_session':
        return AppTheme.peach;
      case 'repository':
        return AppTheme.blue;
      case 'memory_graph':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 8) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Color _getColorForRepo(String repoName) {
    final colors = [
      AppTheme.accent,
      AppTheme.peach,
      AppTheme.success,
      const Color(0xFFFACC15), // Yellow
      const Color(0xFF818CF8), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
    ];
    int hash = repoName.codeUnits.fold(0, (prev, curr) => prev + curr);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDark ? const Color(0xFF141414) : const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: Text('Developer Timeline', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textMain),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timeline.isEmpty
              ? Center(
                  child: Text(
                    'No timeline events found.\nStart chatting or coding to build your history!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _timeline.length,
                  itemBuilder: (context, index) {
                    final item = _timeline[index];
                    final type = item['type'] ?? 'unknown';
                    final dateStr = item['timestamp'] ?? '';
                    
                    String displayDate = '';
                    if (dateStr.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(dateStr).toLocal();
                        displayDate = _formatTimeAgo(dt);
                      } catch (_) {
                        displayDate = dateStr;
                      }
                    }

                    // Dynamic colors & styling
                    String title = item['title'] ?? 'Event';
                    String description = item['description'] ?? '';
                    Color itemColor = _getColorForType(type);
                    
                    if (type == 'repository') {
                      // Extract repo name to colorize beautifully
                      String repoName = description.replaceFirst('Synced repository ', '');
                      itemColor = _getColorForRepo(repoName);
                      title = repoName.split('/').last; // Just the project name
                      description = 'Repository Synced • ${item['language'] ?? 'Code'}';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: itemColor.withValues(alpha: 0.3), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: itemColor.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                ),
                                child: Icon(
                                  _getIconForType(type),
                                  color: itemColor,
                                  size: 20,
                                ),
                              ),
                              if (index != _timeline.length - 1)
                                Container(
                                  width: 2,
                                  height: 60,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [itemColor.withValues(alpha: 0.5), AppTheme.border],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              color: AppTheme.textMain,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.bgSecondary.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            displayDate,
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (type == 'prompt' && item['technologies'] != null && (item['technologies'] as List).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: (item['technologies'] as List).take(3).map((tech) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: itemColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: itemColor.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                tech.toString(),
                                                style: TextStyle(color: itemColor, fontSize: 11, fontWeight: FontWeight.w500),
                                              ),
                                            );
                                          }).toList(),
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
    );
  }
}
