import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../mentor/mentor_chat_screen.dart';

/// Dedicated Chat tab — shows conversation list + new chat launcher.
/// Designed after Apple Messages / Cursor AI style.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _showConversation = false;

  @override
  void dispose() {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setChatOpen(false);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final sessions = appState.getChatSessions();

    // If user tapped a conversation, show the full mentor chat inline
    if (_showConversation) {
      return Column(
        children: [
          // Custom back bar
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.accent),
                    onPressed: () {
                      setState(() => _showConversation = false);
                      appState.setChatOpen(false);
                    },
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accent, AppTheme.neonPurple],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tatvik AI',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        'Online • Repository-Aware',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add_comment_rounded, size: 20, color: AppTheme.textSecondary),
                    onPressed: () {
                      appState.startNewChat();
                    },
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          const Expanded(child: MentorChatScreen(embedded: true)),
        ],
      );
    }

    // Conversation list view
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 60, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chat',
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                      letterSpacing: -1,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          appState.startNewChat();
                          setState(() => _showConversation = true);
                          appState.setChatOpen(true);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(Icons.edit_rounded, size: 20, color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // AI Assistant Hero Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _showConversation = true);
                  appState.setChatOpen(true);
                },
                child: GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.accent, AppTheme.neonPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Tatvik AI Mentor',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.success.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code review, architecture advice, resume help, and more.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Section: Recent Conversations
          if (sessions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Conversations',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (sessions.length > 3)
                      GestureDetector(
                        onTap: () {
                          // Could show all conversations
                        },
                        child: Text(
                          'See All',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final session = sessions[index];
                  final title = session['title'] as String? ?? 'New Chat';
                  final startedAt = session['startedAt'] as String?;
                  final messages = session['messages'] as List<dynamic>? ?? [];

                  String timeDisplay = '';
                  if (startedAt != null) {
                    try {
                      final date = DateTime.parse(startedAt);
                      final diff = DateTime.now().difference(date);
                      if (diff.inMinutes < 60) {
                        timeDisplay = '${diff.inMinutes}m ago';
                      } else if (diff.inHours < 24) {
                        timeDisplay = '${diff.inHours}h ago';
                      } else if (diff.inDays < 7) {
                        timeDisplay = '${diff.inDays}d ago';
                      } else {
                        timeDisplay = '${date.day}/${date.month}';
                      }
                    } catch (_) {}
                  }

                  String lastMessage = '';
                  if (messages.isNotEmpty) {
                    final last = messages.last;
                    lastMessage = (last['content'] as String? ?? '').replaceAll('\n', ' ');
                    if (lastMessage.length > 80) {
                      lastMessage = '${lastMessage.substring(0, 80)}...';
                    }
                  }

                  // Choose icon based on content
                  IconData sessionIcon = Icons.chat_bubble_outline_rounded;
                  Color iconColor = AppTheme.accent;
                  if (title.toLowerCase().contains('resume')) {
                    sessionIcon = Icons.description_outlined;
                    iconColor = AppTheme.blue;
                  } else if (title.toLowerCase().contains('voice') || title.toLowerCase().contains('🎙')) {
                    sessionIcon = Icons.mic_rounded;
                    iconColor = AppTheme.peach;
                  } else if (title.toLowerCase().contains('code') || title.toLowerCase().contains('debug')) {
                    sessionIcon = Icons.code_rounded;
                    iconColor = AppTheme.neonGreen;
                  } else if (title.toLowerCase().contains('review') || title.toLowerCase().contains('pr')) {
                    sessionIcon = Icons.rate_review_outlined;
                    iconColor = AppTheme.neonPurple;
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: index == 0 ? 0 : 0,
                      bottom: index == sessions.length - 1 ? 120 : 8,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        appState.loadChatSession(session['id'] as String);
                        setState(() => _showConversation = true);
                        appState.setChatOpen(true);
                      },
                      onLongPress: () {
                        _showSessionOptions(context, appState, session['id'] as String, title);
                      },
                      child: GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: iconColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Icon(sessionIcon, size: 20, color: iconColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textMain,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (timeDisplay.isNotEmpty)
                                        Text(
                                          timeDisplay,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (lastMessage.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: sessions.length,
              ),
            ),
          ] else ...[
            // Empty state
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accent.withValues(alpha: 0.15),
                              AppTheme.neonPurple.withValues(alpha: 0.15),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.forum_rounded,
                          size: 36,
                          color: AppTheme.accent.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No conversations yet',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation with your AI mentor.\nAsk about code, architecture, or career advice.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          appState.startNewChat();
                          setState(() => _showConversation = true);
                          appState.setChatOpen(true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.accent, AppTheme.neonPurple],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Start Chat',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showSessionOptions(BuildContext context, AppState appState, String sessionId, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppTheme.destructive),
              title: Text(
                'Delete Conversation',
                style: TextStyle(color: AppTheme.destructive),
              ),
              onTap: () {
                Navigator.pop(context);
                appState.deleteChatSession(sessionId);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ],
        ),
      ),
    );
  }
}
