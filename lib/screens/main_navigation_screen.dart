import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../routes/route_paths.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/glass_card.dart';
import '../providers/app_state.dart';
import '../core/utils/web_helper.dart';
import 'home/home_screen.dart';
import 'repositories/discover_repos_screen.dart';
import 'roadmap/roadmap_screen.dart';
import 'profile/profile_screen.dart';
import 'prompts/prompt_hub_screen.dart';

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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  double _pageOffset = 0.0;
  bool _isUpdatingUrl = false;
  int? _targetPageIndex;
  bool get _isChangingPageInternally => _targetPageIndex != null;

  int _lastNotificationCount = 0;
  String? _lastNotificationId;
  late final AppState _appState;

  bool _showWalkthrough = false;
  int _walkthroughStep = 0;

  final List<WalkthroughStep> _walkthroughSteps = const [
    WalkthroughStep(
      icon: Icons.grid_view_rounded,
      title: 'Personalized Hub 🚀',
      description: 'Your home dashboard showing AI Insights, Developer DNA, and your profile Roast. All dynamically tailored to your stack and goals.',
      tabIndex: 0,
    ),
    WalkthroughStep(
      icon: Icons.explore_outlined,
      title: 'Explore Projects 📂',
      description: 'Discover curated open-source repositories and hands-on projects suited to your learning aspirations and goals.',
      tabIndex: 1,
    ),
    WalkthroughStep(
      icon: Icons.psychology_outlined,
      title: 'AI Mentor Chat & Prompts 💬',
      description: 'Interact with your AI Mentor. Save topics directly to your Development Memory to customize your future roadmaps.',
      tabIndex: 2,
    ),
    WalkthroughStep(
      icon: Icons.route_outlined,
      title: 'Interactive Roadmaps 🗺️',
      description: 'Follow milestones and structured step-by-step paths curated for you. Tap nodes to see advanced details.',
      tabIndex: 3,
    ),
    WalkthroughStep(
      icon: Icons.settings_outlined,
      title: 'Settings & Security ⚙️',
      description: 'Manage preferences, update your personal memory, and lock down your GitHub account sync to ensure your data stays private.',
      tabIndex: 4,
    ),
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverReposScreen(),
    const PromptHubScreen(),
    const RoadmapScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    _pageOffset = _selectedIndex.toDouble();
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
      }
    });

    _appState = Provider.of<AppState>(context, listen: false);
    _lastNotificationCount = _appState.notifications.length;
    if (_appState.notifications.isNotEmpty) {
      _lastNotificationId = _appState.notifications.first['id'] as String?;
    }
    _appState.addListener(_onAppStateChanged);
    
    // Request actual OS/browser notification permission
    requestNotificationPermission();

    // Sync AppState with the initial tab from URL and check walkthrough status
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _appState.setTabIndex(_selectedIndex);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasCompleted = prefs.getBool('has_completed_walkthrough') ?? false;
        if (!hasCompleted && mounted) {
          setState(() {
            _showWalkthrough = true;
            _walkthroughStep = 0;
            _selectedIndex = 0;
          });
          _pageController.jumpToPage(0);
        }
      } catch (_) {}
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      final username = state.uri.queryParameters['username'];
      final token = state.uri.queryParameters['token'];
      if (username != null && username.isNotEmpty && token != null && token.isNotEmpty) {
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
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      if (!_isChangingPageInternally) {
        setState(() {
          _selectedIndex = widget.initialTabIndex;
        });
        if (_pageController.hasClients && _pageController.page?.round() != _selectedIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(_selectedIndex);
            }
          });
        }
      }
    }
  }

  void _nextWalkthroughStep() async {
    if (_walkthroughStep < _walkthroughSteps.length - 1) {
      setState(() {
        _walkthroughStep++;
        _selectedIndex = _walkthroughSteps[_walkthroughStep].tabIndex;
      });
      _pageController.animateToPage(
        _selectedIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_walkthrough', true);
      setState(() {
        _showWalkthrough = false;
        _selectedIndex = 0;
      });
      _pageController.jumpToPage(0);
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
                      child: Icon(
                        step.icon,
                        size: 32,
                        color: AppTheme.accent,
                      ),
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
                            await prefs.setBool('has_completed_walkthrough', true);
                            setState(() {
                              _showWalkthrough = false;
                              _selectedIndex = 0;
                            });
                            _pageController.jumpToPage(0);
                          },
                          child: Text(
                            'SKIP TOUR',
                            style: GoogleFonts.jetBrainsMono(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _nextWalkthroughStep,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
    final double diff = (_pageOffset - _pageOffset.round()).abs();
    final double transitionProgress = (diff * 2.0).clamp(0.0, 1.0);

    return LiquidGlassBackground(
      transitionProgress: transitionProgress,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          onPageChanged: (index) {
            if (!_isChangingPageInternally) {
              setState(() {
                _selectedIndex = index;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Provider.of<AppState>(context, listen: false).setTabIndex(index);
                  _updateUrlSilently(index);
                }
              });
            }
          },
          children: _screens,
        ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
                child: GlassCard(
                  borderRadius: 30,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    height: 70,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        final itemWidth = totalWidth / 5;
                        return Stack(
                          children: [
                            // Sliding Glass Pill Indicator
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutBack,
                              left: _selectedIndex * itemWidth + 8,
                              top: 8,
                              bottom: 8,
                              width: itemWidth - 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.accent.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            // The Items on Top
                            Positioned.fill(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildNavItem(0, 'HOME', Icons.grid_view_rounded, itemWidth),
                                  _buildNavItem(1, 'EXPLORE', Icons.explore_outlined, itemWidth),
                                  _buildNavItem(2, 'PROMPTS', Icons.psychology_outlined, itemWidth),
                                  _buildNavItem(3, 'ROADMAP', Icons.route_outlined, itemWidth),
                                  _buildNavItem(4, 'SETTINGS', Icons.settings_outlined, itemWidth),
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
          if (_showWalkthrough) _buildWalkthroughOverlay(),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, double width) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedIndex == index) return;
        _targetPageIndex = index;
        setState(() {
          _selectedIndex = index;
        });
        Provider.of<AppState>(context, listen: false).setTabIndex(index);
        _pageController.jumpToPage(index);
        _targetPageIndex = null;
        _updateUrlSilently(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
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
  State<_SimulatedPushNotificationBanner> createState() => _SimulatedPushNotificationBannerState();
}

class _SimulatedPushNotificationBannerState extends State<_SimulatedPushNotificationBanner> with SingleTickerProviderStateMixin {
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

    _yAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

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
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12 + _yAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: GlassCard(
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1.5),
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
                        icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
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
        );
      },
    );
  }
}

