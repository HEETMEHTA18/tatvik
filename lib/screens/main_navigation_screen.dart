import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import '../core/theme/app_theme.dart';
import '../routes/route_paths.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_glass_button.dart';
import '../providers/app_state.dart';
import '../core/utils/web_helper.dart';
import 'home/home_screen.dart';
import 'repositories/discover_repos_screen.dart';
import 'roadmap/roadmap_screen.dart';
import 'profile/profile_screen.dart';
import 'prompts/prompt_hub_screen.dart';
import 'desktop/desktop_scaffold.dart';
import 'world/world_monitor_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialTabIndex;
  const MainNavigationScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class WalkthroughStep {
  final IconData icon;
  final String title;
  final String description;
  final int tabIndex;

  const WalkthroughStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.tabIndex,
  });
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isUpdatingUrl = false;

  late AnimationController _transitionController;
  late Animation<double> _transitionAnimation;

  int _lastNotificationCount = 0;
  String? _lastNotificationId;
  late final AppState _appState;

  bool _showWalkthrough = false;
  int _walkthroughStep = 0;

  final List<WalkthroughStep> _walkthroughSteps = const [
    WalkthroughStep(
      icon: Icons.grid_view_rounded,
      title: 'Personalized Hub 🚀',
      description:
          'Your home dashboard showing Tatvik Insights, Developer DNA, and your profile Roast. All dynamically tailored to your stack and goals.',
      tabIndex: 0,
    ),
    WalkthroughStep(
      icon: Icons.explore_outlined,
      title: 'Explore Projects 📂',
      description:
          'Discover curated open-source repositories and hands-on projects suited to your learning aspirations and goals.',
      tabIndex: 1,
    ),
    WalkthroughStep(
      icon: Icons.psychology_outlined,
      title: 'Tatvik Chat & Prompts 💬',
      description:
          'Interact with your AI Mentor. Save topics directly to your Development Memory to customize your future roadmaps.',
      tabIndex: 2,
    ),
    WalkthroughStep(
      icon: Icons.route_outlined,
      title: 'Interactive Roadmaps 🗺️',
      description:
          'Follow milestones and structured step-by-step paths curated for you. Tap nodes to see advanced details.',
      tabIndex: 3,
    ),
    WalkthroughStep(
      icon: Icons.settings_outlined,
      title: 'Settings & Security ⚙️',
      description:
          'Manage preferences, update your personal memory, and lock down your GitHub account sync to ensure your data stays private.',
      tabIndex: 4,
    ),
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverReposScreen(),
    const PromptHubScreen(),
    const RoadmapScreen(),
    const WorldMonitorScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _appState = Provider.of<AppState>(context, listen: false);

    if (widget.initialTabIndex >= 0) {
      _selectedIndex = widget.initialTabIndex;
    } else {
      _selectedIndex = _appState.currentTabIndex;
    }

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _transitionAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60.0,
      ),
    ]).animate(_transitionController);

    _lastNotificationCount = _appState.notifications.length;
    if (_appState.notifications.isNotEmpty) {
      _lastNotificationId = _appState.notifications.first['id'] as String?;
    }
    _appState.addListener(_onAppStateChanged);

    // Sync AppState with the initial tab from URL
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _appState.setSelectedTab(_selectedIndex);
      }
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;

    if (_appState.notifications.length > _lastNotificationCount) {
      final newNotification = _appState.notifications.first;
      final newId = newNotification['id'] as String?;

      if (newId != _lastNotificationId) {
        _lastNotificationId = newId;
        _lastNotificationCount = _appState.notifications.length;

        if (_appState.pushNotifications) {
          if (isAppWindowBackgrounded()) {
            showBrowserNotification(
              newNotification['title'] ?? 'New Notification',
              newNotification['body'] ?? '',
            );
          } else {
            _showSimulatedPushNotification(
              newNotification['title'] ?? 'New Notification',
              newNotification['body'] ?? '',
            );
          }
        }
      }
    } else {
      _lastNotificationCount = _appState.notifications.length;
      if (_appState.notifications.isNotEmpty) {
        _lastNotificationId = _appState.notifications.first['id'] as String?;
      } else {
        _lastNotificationId = null;
      }
    }
  }

  void _showSimulatedPushNotification(String title, String body) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _SimulatedPushNotificationBanner(
        title: title,
        body: body,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  /// Updates the browser URL bar to reflect the selected tab
  /// without triggering a go_router navigation/rebuild.
  void _updateUrlSilently(int index) {
    if (_isUpdatingUrl) return;
    _isUpdatingUrl = true;
    final router = GoRouter.of(context);
    Router.neglect(context, () {
      router.go(RoutePaths.appTab(index));
    });
    _isUpdatingUrl = false;
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _transitionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      final username = state.uri.queryParameters['username'];
      final token = state.uri.queryParameters['token'];
      if (username != null &&
          username.isNotEmpty &&
          token != null &&
          token.isNotEmpty) {
        final appState = Provider.of<AppState>(context, listen: false);
        if (appState.githubUsername != username) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appState.setGithubSession(username, token);
          });
        }
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex >= 0 &&
        widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() {
        _selectedIndex = widget.initialTabIndex;
      });
      _appState.setSelectedTab(widget.initialTabIndex);
    }
  }

  void _nextWalkthroughStep() async {
    if (_walkthroughStep < _walkthroughSteps.length - 1) {
      setState(() {
        _walkthroughStep++;
      });
      _onTabSelected(_walkthroughSteps[_walkthroughStep].tabIndex);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_walkthrough', true);
      setState(() {
        _showWalkthrough = false;
      });
      _onTabSelected(0);
      _checkAndShowNotificationPrompt();
    }
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;

    // Apple HIG: light haptic response on tab selection
    HapticFeedback.lightImpact();

    setState(() {
      _selectedIndex = index;
    });
    _appState.setSelectedTab(index);
    _updateUrlSilently(index);

    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    if (!isMobileBrowser) {
      // Trigger transition overlay shutter animation in parallel for visual polish
      _transitionController.forward(from: 0.0);
    }
  }

  Widget _buildWalkthroughOverlay() {
    final step = _walkthroughSteps[_walkthroughStep];
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'STEP ${_walkthroughStep + 1} OF ${_walkthroughSteps.length}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                            letterSpacing: 2,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            _walkthroughSteps.length,
                            (index) => Container(
                              margin: const EdgeInsets.only(left: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _walkthroughStep == index
                                    ? AppTheme.accent
                                    : AppTheme.border,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(step.icon, size: 32, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'has_completed_walkthrough',
                              true,
                            );
                            setState(() {
                              _showWalkthrough = false;
                            });
                            _onTabSelected(0);
                          },
                          child: Text(
                            'SKIP TOUR',
                            style: GoogleFonts.jetBrainsMono(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        LiquidGlassButton(
                          onPressed: _nextWalkthroughStep,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          borderRadius: 12,
                          child: Text(
                            _walkthroughStep == _walkthroughSteps.length - 1
                                ? 'GET STARTED'
                                : 'NEXT',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return AnimatedBuilder(
      animation: _transitionAnimation,
      builder: (context, child) {
        return LiquidGlassBackground(
          transitionProgress: _transitionAnimation.value,
          child: child!,
        );
      },
      child: Stack(
        children: [
          if (isDesktop)
            DesktopScaffold(
              selectedIndex: _selectedIndex,
              onTabSelected: _onTabSelected,
              constrainBodyWidth:
                  _selectedIndex != 4, // Allow World Monitor to be full width
              body: IndexedStack(index: _selectedIndex, children: _screens),
              // We can add a TatvikContextPanel here later. For now, let the screens breathe.
              rightPanel: null,
            )
          else
            Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: IndexedStack(index: _selectedIndex, children: _screens),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        // Deep ambient shadow
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.50 : 0.12,
                          ),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                          spreadRadius: -4,
                        ),
                        // Tight shadow for depth
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.30 : 0.08,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: isMobileBrowser
                              ? 25.0
                              : (isDark ? 40.0 : 30.0),
                          sigmaY: isMobileBrowser
                              ? 25.0
                              : (isDark ? 40.0 : 30.0),
                        ),
                        child: Container(
                          height: 68,
                          decoration: BoxDecoration(
                            color: isMobileBrowser
                                ? (isDark
                                          ? const Color(0xFF1C1C1E)
                                          : Colors.white)
                                      .withValues(alpha: isDark ? 0.45 : 0.70)
                                : (isDark
                                          ? const Color(0xFF1C1C1E)
                                          : Colors.white)
                                      .withValues(alpha: isDark ? 0.25 : 0.55),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: isMobileBrowser
                                    ? 0.25
                                    : (isDark ? 0.18 : 0.45),
                              ),
                              width: 0.5,
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final totalWidth = constraints.maxWidth;
                              final itemWidth = totalWidth / 6;
                              return Stack(
                                children: [
                                  // iOS Liquid Glass Pill Indicator
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    left: _selectedIndex * itemWidth + 6,
                                    top: 6,
                                    bottom: 6,
                                    width: itemWidth - 12,
                                    child: OCLiquidGlassGroup(
                                      settings: const OCLiquidGlassSettings(
                                        refractStrength: -0.07,
                                        blurRadiusPx: 4.0,
                                        specStrength: 28.0,
                                      ),
                                      child: Stack(
                                        children: [
                                          // 1. Refractive liquid glass shader
                                          Positioned.fill(
                                            child: OCLiquidGlass(
                                              borderRadius: 22,
                                              color: Colors.transparent,
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                          // 2. High fidelity glass container backing (with sheen and thin border)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.12,
                                                      )
                                                    : Colors.white.withValues(
                                                        alpha: 0.70,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.20
                                                            : 0.60,
                                                      ),
                                                  width: 0.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: isDark
                                                              ? 0.25
                                                              : 0.06,
                                                        ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Glossy specular reflection gradient
                                                  Positioned.fill(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              22,
                                                            ),
                                                        gradient: LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            Colors.white
                                                                .withValues(
                                                                  alpha: isDark
                                                                      ? 0.15
                                                                      : 0.45,
                                                                ),
                                                            Colors.white
                                                                .withValues(
                                                                  alpha: 0.0,
                                                                ),
                                                          ],
                                                          stops: const [
                                                            0.0,
                                                            0.5,
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Xcode style glossy top reflection lip
                                                  Positioned(
                                                    top: 0.5,
                                                    left: 11.0,
                                                    right: 11.0,
                                                    height: 1.0,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.white
                                                                .withValues(
                                                                  alpha: 0.0,
                                                                ),
                                                            Colors.white
                                                                .withValues(
                                                                  alpha: isDark
                                                                      ? 0.40
                                                                      : 0.80,
                                                                ),
                                                            Colors.white
                                                                .withValues(
                                                                  alpha: 0.0,
                                                                ),
                                                          ],
                                                        ),
                                                      ),
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
                                  // Nav Items
                                  Positioned.fill(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _MainNavigationItem(
                                          index: 0,
                                          label: 'Home',
                                          icon: Icons.home_rounded,
                                          width: itemWidth,
                                          isSelected: _selectedIndex == 0,
                                          onTap: () => _onTabSelected(0),
                                        ),
                                        _MainNavigationItem(
                                          index: 1,
                                          label: 'Explore',
                                          icon: Icons.explore_rounded,
                                          width: itemWidth,
                                          isSelected: _selectedIndex == 1,
                                          onTap: () => _onTabSelected(1),
                                        ),
                                        _MainNavigationItem(
                                          index: 2,
                                          label: 'Prompts',
                                          icon: Icons.auto_awesome_rounded,
                                          width: itemWidth,
                                          isSelected: _selectedIndex == 2,
                                          onTap: () => _onTabSelected(2),
                                        ),
                                        _MainNavigationItem(
                                          index: 3,
                                          label: 'Roadmap',
                                          icon: Icons.route_rounded,
                                          width: itemWidth,
                                          isSelected: _selectedIndex == 3,
                                          onTap: () => _onTabSelected(3),
                                        ),
                                        _MainNavigationItem(
                                          index: 4,
                                          label: 'World',
                                          icon: Icons.public_rounded,
                                          width: itemWidth,
                                          isSelected: _selectedIndex == 4,
                                          onTap: () => _onTabSelected(4),
                                        ),
                                        _MainNavigationItem(
                                          index: 5,
                                          label: 'Settings',
                                          icon: Icons.settings_rounded,
                                          width: itemWidth,
                                          isSelected: _selectedIndex == 5,
                                          onTap: () => _onTabSelected(5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                    ),
                  ),
                ],
              ),
            ),
          if (_showWalkthrough) _buildWalkthroughOverlay(),
        ],
      ),
    );
  }

  void _checkAndShowNotificationPrompt() async {
    if (!kIsWeb) return;
    final status = getNotificationPermissionStatus();
    debugPrint("DEBUG NOTIFICATION STATUS: $status");
    if (status != 'granted') {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showNotificationPermissionDialog();
        }
      });
    }
  }

  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'STAY UPDATED',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enable push notifications to receive real-time updates from your 24/7 AI Research Agent and live GitHub activity feeds.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'LATER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiquidGlassButton(
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          Navigator.pop(context);
                          final granted =
                              await requestNotificationPermissionGesture();
                          if (granted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Notifications enabled successfully!',
                                ),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        },
                        color: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: 12,
                        child: Text(
                          'ENABLE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
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
    );
  }
}

class _SimulatedPushNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _SimulatedPushNotificationBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  State<_SimulatedPushNotificationBanner> createState() =>
      _SimulatedPushNotificationBannerState();
}

class _SimulatedPushNotificationBannerState
    extends State<_SimulatedPushNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _yAnimation = Tween<double>(
      begin: -100,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Auto dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12 + _yAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      color: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: 0.4),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: AppTheme.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.body,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              _controller.reverse().then((_) {
                                widget.onDismiss();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MainNavigationItem extends StatefulWidget {
  final int index;
  final String label;
  final IconData icon;
  final double width;
  final bool isSelected;
  final VoidCallback onTap;

  const _MainNavigationItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.width,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MainNavigationItem> createState() => _MainNavigationItemState();
}

class _MainNavigationItemState extends State<_MainNavigationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 125),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack, // spring response
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          _pressController.forward();
          HapticFeedback.lightImpact(); // Apple tactile feedback
        },
        onTapUp: (_) {
          _pressController.reverse();
        },
        onTapCancel: () {
          _pressController.reverse();
        },
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: _isHovered
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03))
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: widget.isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    widget.icon,
                    color: widget.isSelected
                        ? (isDark ? Colors.white : const Color(0xFF007AFF))
                        : (isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF8E8E93)),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontSize: 10,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: widget.isSelected
                        ? (isDark ? Colors.white : const Color(0xFF007AFF))
                        : (isDark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
