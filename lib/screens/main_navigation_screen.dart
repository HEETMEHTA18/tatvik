import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../routes/route_paths.dart';
import '../widgets/liquid_glass_background.dart';
import '../providers/app_state.dart';
import '../core/utils/web_helper.dart';
import 'home/home_screen.dart';
import 'repositories/discover_repos_screen.dart';
import 'chat/chat_screen.dart';
import 'roadmap/roadmap_screen.dart';
import 'profile/profile_screen.dart';
import 'desktop/desktop_scaffold.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialTabIndex;
  const MainNavigationScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverReposScreen(),
    const ChatScreen(),
    const RoadmapScreen(),
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
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60.0,
      ),
    ]).animate(_transitionController);

    _lastNotificationCount = _appState.notifications.length;
    if (_appState.notifications.isNotEmpty) {
      _lastNotificationId = _appState.notifications.first['id'] as String?;
    }
    _appState.addListener(_onAppStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _appState.setSelectedTab(_selectedIndex);
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {});
    if (_appState.notifications.length > _lastNotificationCount) {
      final newNotification = _appState.notifications.first;
      final newId = newNotification['id'] as String?;
      if (newId != _lastNotificationId) {
        _lastNotificationId = newId;
        _lastNotificationCount = _appState.notifications.length;
        if (_appState.pushNotifications) {
          if (isAppWindowBackgrounded()) {
            showBrowserNotification(newNotification['title'] ?? '', newNotification['body'] ?? '');
          } else {
            _showSimulatedPushNotification(newNotification['title'] ?? '', newNotification['body'] ?? '');
          }
        }
      }
    } else {
      _lastNotificationCount = _appState.notifications.length;
      _lastNotificationId = _appState.notifications.isNotEmpty ? _appState.notifications.first['id'] as String? : null;
    }
  }

  void _showSimulatedPushNotification(String title, String body) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _SimulatedPushNotificationBanner(title: title, body: body, onDismiss: () => overlayEntry.remove()),
    );
    overlayState.insert(overlayEntry);
  }

  void _updateUrlSilently(int index) {
    if (_isUpdatingUrl) return;
    _isUpdatingUrl = true;
    Router.neglect(context, () => GoRouter.of(context).go(RoutePaths.appTab(index)));
    _isUpdatingUrl = false;
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _transitionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex >= 0 && widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() => _selectedIndex = widget.initialTabIndex);
      _appState.setSelectedTab(widget.initialTabIndex);
    }
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.lightImpact();
    if (index != 2) _appState.setChatOpen(false);
    setState(() => _selectedIndex = index);
    _appState.setSelectedTab(index);
    _updateUrlSilently(index);
    final isMobileBrowser = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
    if (!isMobileBrowser) _transitionController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return AnimatedBuilder(
      animation: _transitionAnimation,
      builder: (context, child) => LiquidGlassBackground(transitionProgress: _transitionAnimation.value, child: child!),
      child: Stack(
        children: [
          if (isDesktop)
            DesktopScaffold(
              selectedIndex: _selectedIndex,
              onTabSelected: _onTabSelected,
              constrainBodyWidth: true,
              body: IndexedStack(index: _selectedIndex, children: _screens),
              rightPanel: null,
            )
          else
            Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Positioned.fill(child: IndexedStack(index: _selectedIndex, children: _screens)),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: 0, right: 0,
                    bottom: _appState.isChatOpen ? -100 : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16161A) : Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08), blurRadius: 20, offset: const Offset(0, -4))],
                        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), width: 0.5)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          height: 64,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final itemWidth = constraints.maxWidth / 5;
                              final indicatorLeft = _selectedIndex * itemWidth + 6;
                              final indicatorWidth = itemWidth - 12;

                              return Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    left: indicatorLeft, top: 6, bottom: 6, width: indicatorWidth,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05), width: 0.5),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Row(
                                      children: [
                                        _navItem(0, 'Home', Icons.home_rounded),
                                        _navItem(1, 'Explore', Icons.explore_rounded),
                                        _navItem(2, 'Chat', Icons.chat_bubble_rounded, isCenter: true),
                                        _navItem(3, 'Roadmap', Icons.route_rounded),
                                        _navItem(4, 'Settings', Icons.settings_rounded),
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _navItem(int index, String label, IconData icon, {bool isCenter = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : (isCenter ? 1.2 : 1.0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Container(
                width: isCenter ? 48 : 36,
                height: isCenter ? 48 : 36,
                decoration: isCenter && isSelected
                    ? BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)],
                      )
                    : null,
                child: Icon(
                  icon,
                  size: isCenter ? 24 : 22,
                  color: isCenter && isSelected
                      ? Colors.white
                      : isSelected
                          ? (isDark ? Colors.white : const Color(0xFF007AFF))
                          : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93)),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro Text',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF007AFF))
                    : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93)),
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
  const _SimulatedPushNotificationBanner({required this.title, required this.body, required this.onDismiss});
  @override
  State<_SimulatedPushNotificationBanner> createState() => _SimulatedPushNotificationBannerState();
}

class _SimulatedPushNotificationBannerState extends State<_SimulatedPushNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _yAnimation = Tween<double>(begin: -100, end: 0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _controller.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12 + _yAnimation.value,
          left: 16, right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.8), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1.5)),
                        child: Icon(Icons.notifications_active_rounded, color: AppTheme.accent, size: 20)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(widget.title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        const SizedBox(height: 4),
                        Text(widget.body, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                      IconButton(icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                          onPressed: () => _controller.reverse().then((_) => widget.onDismiss())),
                    ]),
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
