import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../auth/login_screen.dart';
import '../../widgets/glass_card.dart';
import '../mentor/mentor_chat_screen.dart';
import '../../widgets/liquid_glass_button.dart';
import 'timeline_screen.dart';
import '../intelligence/developer_growth_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildProfileCard(context, appState),
            const SizedBox(height: 32),
            _buildSection(context, 'CONNECTIONS', [
              _buildSettingItem(
                context,
                Icons.hub_outlined,
                'GitHub Account',
                trailing: '@${appState.githubUsername}',
                onTap: appState.githubUsernameLocked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'GitHub account is locked to your authenticated session for privacy.',
                            ),
                            backgroundColor: AppTheme.accent,
                          ),
                        );
                      }
                    : () => _showEditGitHubDialog(context, appState),
              ),
              _buildSettingItem(
                context,
                Icons.lock_outline_rounded,
                'Lock GitHub Connection',
                hasSwitch: true,
                switchValue: appState.githubUsernameLocked,
                onToggle: () => appState.togglePreference('github_lock'),
              ),
              _buildSettingItem(
                context,
                appState.isGoogleDriveConnected
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_outlined,
                'Google Drive',
                trailing: appState.isGoogleDriveConnected
                    ? 'Connected'
                    : 'Connect',
                onTap: () {
                  if (!appState.isGoogleDriveConnected) {
                    final url = appState.getGoogleDriveAuthorizeUrl();
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Google Drive connected as ${appState.googleDriveEmail ?? ''}'),
                        backgroundColor: AppTheme.accent,
                      ),
                    );
                  }
                },
              ),
            ]),
            const SizedBox(height: 24),
            _buildDeveloperMemorySection(context, appState),
            const SizedBox(height: 24),
            _buildSection(context, 'PREFERENCES', [
              _buildSettingItem(
                context,
                Icons.notifications_none_rounded,
                'Push Notifications',
                hasSwitch: true,
                switchValue: appState.pushNotifications,
                onToggle: () => appState.togglePreference('notifications'),
              ),
              _buildSettingItem(
                context,
                Icons.bug_report_outlined,
                'Test Notification Banner',
                trailing: 'Test',
                onTap: () {
                  appState.addNotification(
                    title: 'Test Notification 🚀',
                    body: 'This is a beautifully styled test banner.',
                    type: 'opportunity',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Test notification dispatched'),
                      backgroundColor: AppTheme.accent,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                context,
                Icons.auto_awesome_outlined,
                'AI Insights',
                hasSwitch: true,
                switchValue: appState.aiInsights,
                onToggle: () => appState.togglePreference('ai'),
              ),
              _buildSettingItem(
                context,
                Icons.assignment_outlined,
                'Weekly Progress Report',
                hasSwitch: true,
                switchValue: appState.weeklyReport,
                onToggle: () => appState.togglePreference('report'),
              ),
              _buildSettingItem(
                context,
                appState.themeModeSetting == 'dark'
                    ? Icons.dark_mode_outlined
                    : (appState.themeModeSetting == 'light'
                          ? Icons.light_mode_outlined
                          : Icons.settings_brightness_outlined),
                'Appearance',
                trailing: appState.themeModeSetting == 'dark'
                    ? 'Dark'
                    : (appState.themeModeSetting == 'light' ? 'Light' : 'Auto'),
                onTap: () => _showAppearanceBottomSheet(context, appState),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, 'HISTORY & TIMELINE', [
              _buildSettingItem(
                context,
                Icons.timeline_rounded,
                'View Developer Timeline',
                trailing: 'New!',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimelineScreen()),
                  );
                },
              ),
              _buildSettingItem(
                context,
                Icons.history_rounded,
                'View Chat History',
                trailing: '${appState.chatSessions.length} chats',
                onTap: () => _showChatHistoryBottomSheet(context, appState),
              ),
              _buildSettingItem(
                context,
                Icons.add_comment_outlined,
                'Start New Chat',
                onTap: () async {
                  await appState.startNewChat();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('New chat started'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MentorChatScreen(),
                      ),
                    );
                  }
                },
              ),
              _buildSettingItem(
                context,
                Icons.delete_sweep_outlined,
                'Clear All Chat History',
                onTap: () => _showClearChatHistoryDialog(context, appState),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, 'ACCOUNT', [
              _buildSettingItem(
                context,
                Icons.privacy_tip_outlined,
                'Privacy & Security',
                onTap: () => _showPrivacyBottomSheet(context, appState),
              ),
              _buildSettingItem(
                context,
                Icons.help_outline_rounded,
                'Help & Support',
                onTap: () => _showHelpBottomSheet(context),
              ),
            ]),
            const SizedBox(height: 32),
            _buildDestructiveButton(context, appState),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'TATVIK v1.0.1',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AppState state) {
    // Generate simple initials from username
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(16),
              image: state.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(state.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: state.avatarUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      state.username,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRO',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '@${state.githubUsername.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(child: Column(children: items)),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    IconData icon,
    String title, {
    String? trailing,
    bool hasSwitch = false,
    bool switchValue = false,
    VoidCallback? onToggle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMain),
              ),
            ),
            if (hasSwitch)
              Switch(
                value: switchValue,
                onChanged: (v) => onToggle?.call(),
                activeThumbColor: AppTheme.accent,
                activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.textSecondary,
                inactiveTrackColor: AppTheme.border,
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              )
            else if (trailing != null)
              Row(
                children: [
                  Text(
                    trailing,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              )
            else
              Icon(
                Icons.chevron_right,
                size: 16,
                color: AppTheme.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructiveButton(BuildContext context, AppState state) {
    return GestureDetector(
      onTap: () => _showSignOutConfirmDialog(context, state),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.destructive.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.destructive.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.destructive, size: 20),
            const SizedBox(width: 16),
            Text(
              'Sign Out',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.destructive,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Edit GitHub username dialog
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
                      color: AppTheme.accent,
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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

  // Appearance Bottom Sheet
  void _showAppearanceBottomSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1.5),
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Appearance',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTheme.textMain,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select your theme style. The liquid glass styling adapts to both light and dark backgrounds.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        _buildThemeOption(
                          context,
                          state,
                          'Liquid Glass (Light)',
                          'light',
                          Icons.light_mode_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildThemeOption(
                          context,
                          state,
                          'Cosmic Glass (Dark)',
                          'dark',
                          Icons.dark_mode_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildThemeOption(
                          context,
                          state,
                          'System Sync (Auto)',
                          'system',
                          Icons.settings_brightness_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    AppState appState,
    String label,
    String targetMode,
    IconData icon,
  ) {
    final isSelected = appState.themeModeSetting == targetMode;
    return GestureDetector(
      onTap: () {
        appState.setThemeMode(targetMode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.surface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.4)
                : AppTheme.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textMain
                      : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }

  // Privacy & Security Bottom Sheet
  void _showPrivacyBottomSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1.5),
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Privacy & Security',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTheme.textMain,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 20),
                        // 1. Share Analytics Switch
                        _buildSheetSwitch(
                          context,
                          Icons.analytics_outlined,
                          'Share Usage Analytics',
                          'Help us improve Tatvik by sending anonymous usage statistics.',
                          state.shareAnalytics,
                          (val) {
                            state.togglePreference('analytics');
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        // 2. 2FA Switch
                        _buildSheetSwitch(
                          context,
                          Icons.security_outlined,
                          'Two-Factor Authentication',
                          'Add an extra layer of protection to your Tatvik account.',
                          state.twoFactorAuth,
                          (val) async {
                            if (!state.twoFactorAuth) {
                              // Simulating enabling 2FA
                              bool? confirm = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) {
                                  final TextEditingController codeController = TextEditingController();
                                  bool hasError = false;
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        backgroundColor: AppTheme.surface,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Column(
                                          children: [
                                            Icon(Icons.security_rounded, size: 48, color: AppTheme.accent),
                                            const SizedBox(height: 16),
                                            Text('Enable 2FA', style: GoogleFonts.outfit(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Set up a 6-digit PIN to enable Two-Factor Authentication.',
                                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),
                                            TextField(
                                              controller: codeController,
                                              keyboardType: TextInputType.number,
                                              maxLength: 6,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.jetBrainsMono(
                                                fontSize: 24,
                                                letterSpacing: 8,
                                                color: AppTheme.textMain,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '------',
                                                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                                counterText: '',
                                                errorText: hasError ? 'Invalid PIN. Must be 6 digits.' : null,
                                                filled: true,
                                                fillColor: AppTheme.background,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                              onChanged: (val) {
                                                if (hasError) setState(() => hasError = false);
                                              },
                                            ),
                                          ],
                                        ),
                                        actionsAlignment: MainAxisAlignment.center,
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                                          ),
                                          const SizedBox(width: 16),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.accent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            ),
                                            onPressed: () {
                                              if (codeController.text.length == 6) {
                                                Navigator.pop(ctx, true);
                                              } else {
                                                setState(() => hasError = true);
                                              }
                                            },
                                            child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                              if (confirm != true) return;
                            }
                            state.togglePreference('2fa');
                            setModalState(() {});
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.twoFactorAuth
                                      ? 'Two-Factor Authentication Enabled.'
                                      : 'Two-Factor Authentication Disabled.',
                                ),
                                backgroundColor: AppTheme.accent,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // 3. Biometric / Face ID Switch
                        _buildSheetSwitch(
                          context,
                          Icons.fingerprint_rounded,
                          'Face ID / Biometric Lock',
                          'Require biometric authentication to open Tatvik.',
                          state.biometricLock,
                          (val) async {
                            final LocalAuthentication auth = LocalAuthentication();
                            bool authenticated = false;
                            try {
                              final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
                              final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
                              
                              if (canAuthenticate) {
                                authenticated = await auth.authenticate(
                                  localizedReason: state.biometricLock
                                      ? 'Authenticate to disable Biometric Lock'
                                      : 'Authenticate to enable Biometric Lock',
                                  biometricOnly: true,
                                  persistAcrossBackgrounding: true,
                                );
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Biometric authentication is not supported or enrolled on this device.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                                return;
                              }
                            } on PlatformException catch (e) {
                              debugPrint('Biometric Error: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Biometrics not available on this device. ($e)'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                              return;
                            }
                            if (authenticated) {
                              state.togglePreference('biometric');
                              setModalState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      state.biometricLock
                                          ? 'Face ID / Biometric Lock Enabled.'
                                          : 'Face ID / Biometric Lock Disabled.',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Local cache database cleared.',
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                child: Text(
                                  'Clear Cache',
                                  style: TextStyle(color: AppTheme.textMain),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LiquidGlassButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Export sent to: ${state.githubUsername}@github.com',
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                },
                                color: AppTheme.accent,
                                borderRadius: 16,
                                child: const Text('Export Data'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Legal section
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showTermsAndConditions(context);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.gavel_rounded, size: 16, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                'Terms and Conditions',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetSwitch(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
    bool val,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.accent, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: val,
          onChanged: onChanged,
          activeThumbColor: AppTheme.accent,
          activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
          inactiveThumbColor: AppTheme.textSecondary,
          inactiveTrackColor: AppTheme.border,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    );
  }

  // Help & Support Bottom Sheet
  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Help & Support',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textMain,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 20),
                      // FAQ Section
                      Text(
                        'FREQUENTLY ASKED QUESTIONS',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFAQItem(
                        context,
                        'How does the AI calculate my Developer Score?',
                        'Tatvik analyzes your commit activity, code complexity, testing coverage, and architectural patterns in linked GitHub repositories to calculate your score.',
                      ),
                      _buildFAQItem(
                        context,
                        'How often are career roadmaps updated?',
                        'Your roadmap updates dynamically as you complete projects, master milestones, or when our AI detects new skills gaps in your commits.',
                      ),
                      _buildFAQItem(
                        context,
                        'Can I suggest other repos for mentoring?',
                        'Yes! Simply tap "Chat with Mentor" on the Dashboard and send the repo link. The AI will analyze and add it to your explore page.',
                      ),
                      const SizedBox(height: 24),
                      // Support Action Buttons
                      LiquidGlassButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MentorChatScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat with AI Support Mentor'),
                        color: AppTheme.accent,
                        borderRadius: 16,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Support email client launched.',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.email_outlined),
                        label: Text(
                          'Email Support Desk',
                          style: TextStyle(color: AppTheme.textMain),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.border),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAQItem(BuildContext context, String q, String a) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          q,
          style: TextStyle(
            color: AppTheme.textMain,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconColor: AppTheme.accent,
        collapsedIconColor: AppTheme.textSecondary,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              a,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sign out confirmation dialog
  void _showSignOutConfirmDialog(BuildContext context, AppState state) {
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
                  'Sign Out',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to sign out from Tatvik?',
                  style: TextStyle(color: AppTheme.textSecondary),
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
                      onPressed: () async {
                        // Perform sign out
                        await state.clearSession();
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      color: AppTheme.destructive,
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white),
                      ),
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

  Widget _buildDeveloperMemorySection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEVELOPER MEMORY',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
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
                    'PERSONALIZED AI MEMORY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showEditMemoryDialog(context, state),
                    child: Text(
                      'EDIT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.flag_rounded, color: AppTheme.peach, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT CAREER GOAL',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.personalGoal,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.layers_rounded, color: AppTheme.blue, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREFERRED TECH STACK',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.preferredStack,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LiquidGlassButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeveloperGrowthScreen(),
                    ),
                  );
                },
                color: AppTheme.secondaryAccent,
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Developer Growth & Badges',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditMemoryDialog(BuildContext context, AppState state) {
    final goalController = TextEditingController(text: state.personalGoal);
    final stackController = TextEditingController(text: state.preferredStack);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.isDark
              ? const Color(0xFF1E1E24)
              : Colors.white,
          title: Text(
            'Edit Developer Memory',
            style: TextStyle(color: AppTheme.textMain),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: goalController,
                style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'CAREER GOAL',
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  hintText: 'e.g. Become Full Stack AI Engineer',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stackController,
                style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'PREFERRED STACK',
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  hintText: 'e.g. Flutter, FastAPI, PostgreSQL',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                state.saveDeveloperMemory(
                  goalController.text.trim(),
                  stackController.text.trim(),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'AI personalized memory updated successfully.',
                    ),
                  ),
                );
              },
              child: Text('Save', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  void _showChatHistoryBottomSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final sessions = appState.getChatSessions();
                return DraggableScrollableSheet(
                  initialChildSize: 0.6,
                  maxChildSize: 0.9,
                  minChildSize: 0.4,
                  expand: false,
                  builder: (context, scrollController) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chat History',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppTheme.textMain,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Switch to a previous chat session or delete old history.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: sessions.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 48,
                                            color: AppTheme.textSecondary
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No saved chats yet.',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: scrollController,
                                      itemCount: sessions.length,
                                      itemBuilder: (context, idx) {
                                        final session = sessions[idx];
                                        final id = session['id'] as String;
                                        final title =
                                            session['title'] as String;
                                        final startedAt =
                                            DateTime.tryParse(
                                              session['startedAt'] ?? '',
                                            ) ??
                                            DateTime.now();
                                        final formattedDate =
                                            "${startedAt.day}/${startedAt.month}/${startedAt.year} ${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}";
                                        final msgCount =
                                            (session['messages']
                                                    as List<dynamic>?)
                                                ?.length ??
                                            0;

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: GlassCard(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            borderRadius: 16,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.chat_bubble_outline,
                                                  color: AppTheme.accent,
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () async {
                                                      await appState
                                                          .loadChatSession(id);
                                                      if (context.mounted) {
                                                        Navigator.pop(context);
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                const MentorChatScreen(),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: AppTheme
                                                                .textMain,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          '$formattedDate • $msgCount messages',
                                                          style: TextStyle(
                                                            color: AppTheme
                                                                .textSecondary,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: AppTheme.destructive,
                                                  ),
                                                  onPressed: () async {
                                                    await appState
                                                        .deleteChatSession(id);
                                                    setModalState(() {});
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showClearChatHistoryDialog(BuildContext context, AppState appState) {
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
                  'Clear Chat History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to permanently clear all saved chat sessions and history? This action cannot be undone.',
                  style: TextStyle(color: AppTheme.textSecondary),
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
                      onPressed: () async {
                        await appState.clearAllChatHistory();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('All chat history cleared.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      },
                      color: AppTheme.destructive,
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.white),
                      ),
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
  void _showTermsAndConditions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.border, width: 1.5)),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Terms and Conditions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    '''1. Acceptance of Terms
By using Tatvik ("the App"), you agree to be bound by these Terms and Conditions.

2. Security & Privacy
Tatvik processes code and metadata locally where possible. However, the AI functionalities utilize the OpenClaw pipeline. By using this service, you agree not to submit extremely sensitive credentials, though we automatically redact API keys and PII.

3. Face ID / Biometrics
If enabled, Tatvik uses the device's native biometric APIs. Tatvik does not store your biometric data.

4. Intellectual Property
Code generated by Tatvik's AI is free to use in your projects under your own responsibility.

5. Liability
Tatvik is provided "as is". We are not liable for any code issues, bugs, or downtime caused by generated or suggested code.

6. Account Termination
We reserve the right to suspend accounts that abuse our API rate limits or violate these terms.''',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: LiquidGlassButton(
                  onPressed: () => Navigator.pop(context),
                  color: AppTheme.accent,
                  child: const Text('I Understand'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
