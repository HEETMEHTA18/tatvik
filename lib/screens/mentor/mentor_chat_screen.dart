import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mentor_message.dart';
import '../../providers/app_state.dart';
import '../../widgets/liquid_glass_background.dart';
import '../../widgets/animated_copy_button.dart';
import '../../utils/speech_helper.dart';

class MentorChatScreen extends StatefulWidget {
  const MentorChatScreen({super.key});

  @override
  State<MentorChatScreen> createState() => _MentorChatScreenState();
}

class _MentorChatScreenState extends State<MentorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.escape) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
          return true;
        }
      }

      if (!_focusNode.hasFocus) {
        final character = event.character;
        if (character != null && character.isNotEmpty) {
          _focusNode.requestFocus();
          final text = _controller.text + character;
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          return true;
        }
      }
    }
    return false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final messages = appState.chatMessages;

    return LiquidGlassBackground(
      child: GestureDetector(
        onTap: () {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textMain),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'AI Mentor',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              if (appState.lastUploadedResumeText != null && appState.lastUploadedResumeText!.isNotEmpty)
                _buildResumeStatusBar(appState),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is ScrollStartNotification) {
                      if (_focusNode.hasFocus) {
                        _focusNode.unfocus();
                      }
                    }
                    return false;
                  },
                  child: messages.isEmpty
                      ? _buildEmptyState(appState)
                      : ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: _buildMessageRow(msg, appState),
                              ),
                            );
                          },
                        ),
                ),
              ),
              _buildInputArea(appState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeStatusBar(AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: state.isGoogleDriveConnected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isGoogleDriveConnected
              ? AppTheme.accent.withValues(alpha: 0.2)
              : Colors.amber.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                color: state.isGoogleDriveConnected ? AppTheme.accent : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.lastUploadedResumeFileName ?? 'Active Resume PDF',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.isGoogleDriveConnected
                          ? 'Connected to Google Drive (${state.googleDriveEmail ?? ''})'
                          : 'Google Drive disconnected (saves locally)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTailorDialog(state),
              icon: const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(
                'Tailor & Sync',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTailorDialog(AppState state) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xCC0D0E15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppTheme.border),
            ),
            title: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppTheme.accent),
                const SizedBox(width: 12),
                Text(
                  'Tailor Resume',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Provide the job details to automatically tailor your resume and sync the output to Google Drive.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: titleController,
                      style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Job Title',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.accent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please enter job title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Job Description',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        alignLabelWithHint: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.accent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Please enter job description' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    state.generateAndSyncResumeFromChat(
                      jobTitle: titleController.text.trim(),
                      jobDescription: descController.text.trim(),
                    );
                    _scrollToBottom();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Tailor & Sync'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentOptions(AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE0D0E15),
      elevation: 10,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Attachment Options',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                    child: Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accent),
                  ),
                  title: Text(
                    'Upload PDF Resume',
                    style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Upload a new resume to guide the mentoring sessions',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      if (file.bytes != null) {
                        await state.sendPdfMessage(file.bytes!, file.name);
                        _scrollToBottom();
                      }
                    }
                  },
                ),
                const Divider(color: Colors.white12, height: 24),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: state.isGoogleDriveConnected
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    child: Icon(
                      state.isGoogleDriveConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: state.isGoogleDriveConnected ? Colors.green : Colors.amber,
                    ),
                  ),
                  title: Text(
                    state.isGoogleDriveConnected ? 'Google Drive Connected' : 'Connect Google Drive',
                    style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    state.isGoogleDriveConnected
                        ? 'Email: ${state.googleDriveEmail ?? ''}'
                        : 'Connect Google Drive to auto-sync tailored resumes',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: state.isGoogleDriveConnected
                      ? null
                      : Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!state.isGoogleDriveConnected) {
                      final url = state.getGoogleDriveAuthorizeUrl();
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 36,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How can I help you grow today?',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask about your roadmap, request a code roast, or practice interviews.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildSuggestionGrid(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionGrid(AppState state) {
    final suggestions = [
      {'icon': '🔥', 'title': 'Roast my code', 'desc': 'Get critical feedback on your repository style.'},
      {'icon': '🗺️', 'title': 'Explain my roadmap', 'desc': 'Understand the next milestone in your career.'},
      {'icon': '💼', 'title': 'Mock interview prep', 'desc': 'Challenge yourself with high-impact tech questions.'},
      {'icon': '💻', 'title': 'Suggest a project', 'desc': 'Get real-world recommendations matching your stack.'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return InkWell(
          onTap: () {
            String cleanText = item['title']!;
            if (cleanText == 'Roast my code') {
              cleanText = 'Roast my current code quality';
            } else if (cleanText == 'Explain my roadmap') {
              cleanText = 'Explain my current roadmap milestone and what to do next';
            } else if (cleanText == 'Mock interview prep') {
              cleanText = 'Give me a challenging technical mock interview question';
            } else if (cleanText == 'Suggest a project') {
              cleanText = 'Suggest a real-world coding project based on my stack';
            }
            state.sendMessage(cleanText);
            _scrollToBottom();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: AppTheme.border, width: 1.0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    item['desc']!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageRow(MentorMessage msg, AppState state) {
    final isUser = msg.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isUser ? Colors.white24 : AppTheme.accent.withValues(alpha: 0.5)),
              gradient: isUser
                  ? const LinearGradient(colors: [Color(0xFF2D3748), Color(0xFF1A202C)])
                  : LinearGradient(colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)]),
            ),
            child: Center(
              child: isUser
                  ? Text(
                      state.username.isNotEmpty ? state.username[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          // Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Name
                Text(
                  isUser ? 'You' : 'DevMentor AI',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isUser ? AppTheme.textSecondary : AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 6),
                // Markdown Content (ChatGPT styled: clean full-width, no card bubble background)
                MarkdownBody(
                  data: msg.content,
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      final url = Uri.parse(href);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: TextStyle(
                      color: AppTheme.textMain,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    a: TextStyle(
                      color: AppTheme.accent,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    code: TextStyle(
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppTheme.textMain,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 12),
                  // Chat Action Buttons (translucent, clean ChatGPT style)
                  Row(
                    children: [
                      AnimatedCopyButton(
                        text: msg.content,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.volume_up_rounded, size: 15),
                        color: AppTheme.textSecondary,
                        tooltip: 'Read Aloud',
                        onPressed: () {
                          SpeechHelper.speak(msg.content);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobileBrowser = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isMobileBrowser ? 0.0 : 20.0,
              sigmaY: isMobileBrowser ? 0.0 : 20.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x330D0E15) : const Color(0x40FFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file_rounded, color: AppTheme.textSecondary, size: 20),
                    tooltip: 'Attachment Options',
                    onPressed: () => _showAttachmentOptions(state),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(color: AppTheme.textMain, fontSize: 15),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Message AI Mentor...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          state.sendMessage(val.trim());
                          _controller.clear();
                          _scrollToBottom();
                          _focusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        state.sendMessage(text);
                        _controller.clear();
                        _scrollToBottom();
                        _focusNode.requestFocus();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
