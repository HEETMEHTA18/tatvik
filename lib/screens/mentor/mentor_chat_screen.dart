import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/mentor_message.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_copy_button.dart';
import '../../utils/speech_helper.dart';
import '../../widgets/liquid_glass_button.dart';

class MentorChatScreen extends StatefulWidget {
  final bool embedded;
  const MentorChatScreen({super.key, this.embedded = false});

  @override
  State<MentorChatScreen> createState() => _MentorChatScreenState();
}

class _MentorChatScreenState extends State<MentorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isListening = false;
  bool _hasText = false;
  String _previousText = '';
  int _lastMessageCount = 0;
  bool _lastTypingState = false;
  String _selectedModel = 'Tatvik AI OS';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
    _controller.addListener(_onTextChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateChanged);
      _lastMessageCount = appState.chatMessages.length;
      _lastTypingState = appState.isMentorTyping;
      // Load saved sessions when entering chat
      appState.loadChatHistory();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    _controller.removeListener(_onTextChanged);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.removeListener(_onAppStateChanged);
    } catch (_) {}
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final currentText = _controller.text;
    final textNotEmpty = currentText.trim().isNotEmpty;
    if (textNotEmpty != _hasText) {
      setState(() {
        _hasText = textNotEmpty;
      });
    }

    final diff = currentText.length - _previousText.length;
    if (diff > 8) {
      final addedText = currentText.substring(currentText.length - diff);
      final isPaste = diff > 20 || 
                      addedText.contains(' ') || 
                      addedText.contains('\n') || 
                      addedText.contains('{') || 
                      addedText.contains('/') ||
                      addedText.contains('.');
      if (isPaste) {
        _previousText = currentText;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          final textToSend = _controller.text.trim();
          if (textToSend.isNotEmpty) {
            final appState = Provider.of<AppState>(context, listen: false);
            appState.sendMessage(textToSend);
            _controller.clear();
            _previousText = '';
            _scrollToBottom();
            _focusNode.requestFocus();
          }
        });
        return;
      }
    }
    _previousText = currentText;
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.chatMessages.length != _lastMessageCount ||
        appState.isMentorTyping != _lastTypingState) {
      _lastMessageCount = appState.chatMessages.length;
      _lastTypingState = appState.isMentorTyping;
      _scrollToBottom();
    }
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

  void _toggleListening(AppState state) {
    if (_isListening) {
      SpeechHelper.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      SpeechHelper.startListening(
        onStart: () {
          setState(() {
            _isListening = true;
          });
        },
        onEnd: () {
          setState(() {
            _isListening = false;
          });
        },
        onResult: (text) {
          if (text.isNotEmpty) {
            _showVoicePipelineConfirmation(state, text);
          }
        },
        onError: (err) {
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      );
    }
  }

  void _showVoicePipelineConfirmation(AppState state, String transcript) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF171717),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Voice Project Creator',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFECECF1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'AI parsed your voice instructions as:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFC5C5D2),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '"$transcript"',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFFECECF1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This will generate .autodev/prompt.md specifications in your repository and start the autonomous agentic implementation loop.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFC5C5D2),
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
                      style: GoogleFonts.inter(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10A37F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      state.sendVoicePipelineCommand(transcript);
                    },
                    child: Text(
                      'Trigger Pipeline',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTailorBottomSheet(AppState state) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 0.5),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFF10A37F)),
                      SizedBox(width: 12),
                      Text(
                        'Tailor Resume',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFFECECF1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Provide the target job details to automatically tailor your resume and sync the output to Google Drive.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFC5C5D2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleController,
                    style: const TextStyle(color: Color(0xFFECECF1), fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Job Title',
                      labelStyle: const TextStyle(color: Color(0xFFC5C5D2)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF10A37F)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter job title'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    style: const TextStyle(color: Color(0xFFECECF1), fontSize: 14),
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Job Description',
                      labelStyle: const TextStyle(color: Color(0xFFC5C5D2)),
                      alignLabelWithHint: true,
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF10A37F)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter job description'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFFC5C5D2)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10A37F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                        child: const Text('Tailor & Sync', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentOptions(AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171717),
      elevation: 10,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 0.5),
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
                    color: const Color(0xFFECECF1),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x2010A37F),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFF10A37F),
                    ),
                  ),
                  title: const Text(
                    'Upload PDF Resume',
                    style: TextStyle(
                      color: Color(0xFFECECF1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Upload a new resume to guide the mentoring sessions',
                    style: TextStyle(
                      color: Color(0xFFC5C5D2),
                      fontSize: 12,
                    ),
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
                const Divider(color: Colors.white10, height: 24),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: state.isGoogleDriveConnected
                        ? const Color(0x2010B981)
                        : const Color(0x20F59E0B),
                    child: Icon(
                      state.isGoogleDriveConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: state.isGoogleDriveConnected
                          ? Colors.green
                          : Colors.amber,
                    ),
                  ),
                  title: Text(
                    state.isGoogleDriveConnected
                        ? 'Google Drive Connected'
                        : 'Connect Google Drive',
                    style: const TextStyle(
                      color: Color(0xFFECECF1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    state.isGoogleDriveConnected
                        ? 'Email: ${state.googleDriveEmail ?? ''}'
                        : 'Connect Google Drive to auto-sync tailored resumes',
                    style: const TextStyle(
                      color: Color(0xFFC5C5D2),
                      fontSize: 12,
                    ),
                  ),
                  trailing: state.isGoogleDriveConnected
                      ? null
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFC5C5D2),
                        ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!state.isGoogleDriveConnected) {
                      final url = state.getGoogleDriveAuthorizeUrl();
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final body = Column(
        children: [
          if (appState.lastUploadedResumeText != null &&
              appState.lastUploadedResumeText!.isNotEmpty)
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
              child: appState.chatMessages.isEmpty
                  ? _buildEmptyState(appState)
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: appState.chatMessages.length,
                      itemBuilder: (context, index) {
                        final msg = appState.chatMessages[index];
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
          if (appState.isMentorTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
              child: Row(
                children: [
                  const BouncingDotsIndicator(),
                  const SizedBox(width: 10),
                  Text(
                    'Tatvik is thinking...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFC5C5D2),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          _buildInputArea(appState),
        ],
      );

    // Embedded mode: skip Scaffold/AppBar, just return the body column
    if (widget.embedded) {
      return Container(
        color: const Color(0xFF212121),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: _buildAppBar(context, appState, isDesktop),
      body: body,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppState appState, bool isDesktop) {
    return AppBar(
      backgroundColor: const Color(0xFF212121),
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFFECECF1)),
      leading: isDesktop
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFECECF1)),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
      title: _buildModelSelector(),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_square, color: Color(0xFFECECF1), size: 20),
          tooltip: 'New Chat',
          onPressed: () {
            appState.startNewChat();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFFECECF1)),
          color: const Color(0xFF171717),
          onSelected: (val) {
            if (val == 'clear') {
              appState.clearAllChatHistory();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Text('Clear conversation', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelSelector() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      color: const Color(0xFF171717),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      onSelected: (String value) {
        setState(() {
          _selectedModel = value;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _selectedModel,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color(0xFFECECF1),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFECECF1), size: 18),
        ],
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'Tatvik AI OS',
          child: Row(
            children: const [
              Icon(Icons.psychology_rounded, color: Colors.blueAccent, size: 18),
              SizedBox(width: 8),
              Text('Tatvik AI OS (Standard)', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'OpenClaw Agent',
          child: Row(
            children: const [
              Icon(Icons.smart_toy_rounded, color: Color(0xFF00BFA5), size: 18),
              SizedBox(width: 8),
              Text('OpenClaw Agent (Coding)', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'Cognee Graph',
          child: Row(
            children: const [
              Icon(Icons.hub_rounded, color: Colors.purpleAccent, size: 18),
              SizedBox(width: 8),
              Text('Cognee Graph (Memory)', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumeStatusBar(AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded, color: Color(0xFF10A37F), size: 20),
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
                        color: const Color(0xFFECECF1),
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
                        color: const Color(0xFFC5C5D2),
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
            child: LiquidGlassButton.icon(
              onPressed: () => _showTailorBottomSheet(state),
              icon: const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(
                'Tailor & Sync',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              color: const Color(0xFF10A37F),
              padding: const EdgeInsets.symmetric(vertical: 10),
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10A37F), Color(0xFF00BFA5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'How can I help you?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFECECF1),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildSuggestionGrid(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionGrid(AppState state) {
    final suggestions = [
      ('🔥', 'Roast my code', 'Get critical feedback on your repository style.'),
      ('🗺️', 'Explain my roadmap', 'Understand the next milestone in your career.'),
      ('💼', 'Mock interview prep', 'Challenge yourself with high-impact tech questions.'),
      ('💻', 'Suggest a project', 'Get real-world recommendations matching your stack.'),
      ('⚡', 'Execute a task', 'Let OpenClaw write code or create a PR for you.'),
      ('🖥️', 'Run terminal', 'Run a command in the agent sandbox environment.'),
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: suggestions.map((s) {
            return _buildSuggestionChip(state, s.$1, s.$2, s.$3);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(AppState state, String icon, String title, String desc) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          String cleanText = title;
          if (title == 'Roast my code') {
            cleanText = 'Roast my current code quality';
          } else if (title == 'Explain my roadmap') {
            cleanText = 'Explain my current roadmap milestone and what to do next';
          } else if (title == 'Mock interview prep') {
            cleanText = 'Give me a challenging technical mock interview question';
          } else if (title == 'Suggest a project') {
            cleanText = 'Suggest a real-world coding project based on my stack';
          } else if (title == 'Execute a task') {
            cleanText = 'Execute a task: add a /health endpoint that returns {status: ok} to my first synced repository';
          } else if (title == 'Run terminal') {
            cleanText = 'Run terminal command: echo Hello from OpenClaw agent';
          }
          state.sendMessage(cleanText);
          _scrollToBottom();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFECECF1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(MentorMessage msg, AppState state) {
    final isUser = msg.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10A37F), Color(0xFF00BFA5)],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tatvik AI',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC5C5D2),
                    ),
                  ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: Container(
              padding: isUser 
                  ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
                  : const EdgeInsets.only(left: 32, right: 16, top: 2, bottom: 8),
              decoration: isUser
                  ? BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      p: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      a: const TextStyle(
                        color: Color(0xFF10A37F),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: const Color(0xFFECECF1),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      h4: const TextStyle(color: Color(0xFFECECF1), fontSize: 15, fontWeight: FontWeight.bold),
                      h3: const TextStyle(color: Color(0xFFECECF1), fontSize: 16, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: Color(0xFFECECF1), fontSize: 17, fontWeight: FontWeight.bold),
                      h1: const TextStyle(color: Color(0xFFECECF1), fontSize: 18, fontWeight: FontWeight.bold),
                      blockquote: const TextStyle(color: Color(0xFFC5C5D2), fontStyle: FontStyle.italic),
                      listBullet: const TextStyle(color: Color(0xFFECECF1)),
                      strong: const TextStyle(color: Color(0xFFECECF1), fontWeight: FontWeight.bold),
                      em: const TextStyle(color: Color(0xFFECECF1), fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AnimatedCopyButton(
                          text: msg.content,
                          size: 14,
                          color: const Color(0xFFC5C5D2),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.volume_up_rounded, size: 14),
                          color: const Color(0xFFC5C5D2),
                          tooltip: 'Read Aloud',
                          onPressed: () => SpeechHelper.speak(msg.content),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (msg.openclawTask != null) ...[
                      const SizedBox(height: 12),
                      _buildOpenClawResultCard(msg.openclawTask!),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppState state) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2F2F2F),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Attachment + Button
                  PlusAttachmentButton(
                    onTap: () => _showAttachmentOptions(state),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Color(0xFFECECF1), fontSize: 15),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything...',
                        hintStyle: TextStyle(
                          color: Color(0xFFC5C5D2),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
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
                  // Templates/Wand, Microphone, Soundwave Button
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC5C5D2), size: 20),
                    tooltip: 'AI Prompt Hub',
                    onPressed: () {
                      context.push('/?tab=prompts');
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? Colors.redAccent : const Color(0xFFC5C5D2),
                      size: 20,
                    ),
                    tooltip: 'Voice Search',
                    onPressed: () => _toggleListening(state),
                  ),
                  const SizedBox(width: 4),
                  WaveformButton(
                    isActive: _isListening || state.isMentorTyping,
                    onTap: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        state.sendMessage(text);
                        _controller.clear();
                        _scrollToBottom();
                        _focusNode.requestFocus();
                      } else {
                        _toggleListening(state);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tatvik can make mistakes. Verify important info.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFC5C5D2).withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenClawResultCard(Map<String, dynamic> task) {
    final bool isStub = task['stub'] == true;
    final bool success = task['success'] == true;
    final String? prUrl = task['pull_request_url'];
    final String? output = task['output'];
    final String? error = task['error'];
    final Color cardColor = isStub || success ? const Color(0xFF00BFA5) : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: cardColor, size: 16),
              const SizedBox(width: 8),
              Text(
                isStub
                    ? '🤖 OpenClaw (Stub Mode)'
                    : success
                    ? '🤖 OpenClaw Executed'
                    : '🤖 OpenClaw Error',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
              ),
            ],
          ),
          if (prUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(prUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                '📎 View Pull Request: $prUrl',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: cardColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          if (output != null) ...[
            const SizedBox(height: 8),
            Text(
              'Output: $output',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFC5C5D2),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: $error',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

// Custom attachment + sign circular button
class PlusAttachmentButton extends StatelessWidget {
  final VoidCallback onTap;
  const PlusAttachmentButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Color(0xFFECECF1),
            size: 18,
          ),
        ),
      ),
    );
  }
}

// Waveform soundwave button on bottom right of input
class WaveformButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;

  const WaveformButton({
    super.key,
    required this.onTap,
    required this.isActive,
  });

  @override
  State<WaveformButton> createState() => _WaveformButtonState();
}

class _WaveformButtonState extends State<WaveformButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant WaveformButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFF3F8CFF), // Beautiful deep blue waveform circle
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(4, (index) {
                  final heights = [10.0, 16.0, 12.0, 8.0];
                  double height = heights[index];
                  if (widget.isActive) {
                    final factor = sin((_controller.value * 2 * pi) + (index * 0.5));
                    height = 8.0 + (factor.abs() * 12.0);
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 2.0,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}



class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({super.key});

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double value = (sin((_controller.value * 2 * pi) - (delay * 2 * pi)) + 1) / 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF10A37F).withValues(alpha: 0.3 + 0.7 * value),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

