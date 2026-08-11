import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../memory/memory_screen.dart';
import '../pulse/pulse_screen.dart';
import '../studio/studio_screen.dart';
import '../career/career_screen.dart';

class DesktopScaffold extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;
  final Widget? rightPanel;
  final bool constrainBodyWidth;

  const DesktopScaffold({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.body,
    this.rightPanel,
    this.constrainBodyWidth = true,
  });

  @override
  State<DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<DesktopScaffold> {
  int? _hoveredIndex;

  static const List<String> _navItems = ['Home', 'Explore', 'Chat', 'Roadmap', 'Settings'];
  static const List<IconData> _navIcons = [
    Icons.home_rounded, Icons.explore_rounded, Icons.chat_bubble_rounded, Icons.route_rounded, Icons.settings_rounded,
  ];

  static const List<String> _subPageItems = ['Memory', 'Pulse', 'Studio', 'Career'];
  static const List<IconData> _subPageIcons = [
    Icons.memory_rounded, Icons.travel_explore_rounded, Icons.build_circle_rounded, Icons.route_rounded,
  ];
  static const List<Widget> _subPages = [
    MemoryScreen(), PulseScreen(), StudioScreen(), CareerScreen(),
  ];

  void _openSubPage(int index) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _subPages[index]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          Container(
            width: 250,
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3))),
                      child: Icon(Icons.psychology_rounded, color: AppTheme.accent, size: 24)),
                    const SizedBox(width: 16),
                    Text('Tatvik', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppTheme.textMain)),
                  ]),
                ),
                const SizedBox(height: 8),
                ...List.generate(_navItems.length, (index) {
                  final isSelected = widget.selectedIndex == index;
                  final isHovered = _hoveredIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: InkWell(
                        onTap: () => widget.onTabSelected(index),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : isHovered ? AppTheme.textMain.withValues(alpha: 0.05) : Colors.transparent,
                            border: Border.all(color: isSelected ? AppTheme.accent.withValues(alpha: 0.3) : Colors.transparent),
                          ),
                          child: Row(children: [
                            Icon(_navIcons[index], size: 22,
                              color: isSelected ? AppTheme.accent : (isHovered ? AppTheme.textMain : AppTheme.textSecondary)),
                            const SizedBox(width: 16),
                            Text(_navItems[index], style: GoogleFonts.inter(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppTheme.accent : (isHovered ? AppTheme.textMain : AppTheme.textSecondary))),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text('AI OS', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
                ...List.generate(_subPageItems.length, (index) {
                  final isHovered = _hoveredIndex == _navItems.length + index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = _navItems.length + index),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: InkWell(
                        onTap: () => _openSubPage(index),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isHovered ? AppTheme.textMain.withValues(alpha: 0.05) : Colors.transparent,
                          ),
                          child: Row(children: [
                            Icon(_subPageIcons[index], size: 18, color: isHovered ? AppTheme.accent : AppTheme.textSecondary),
                            const SizedBox(width: 16),
                            Text(_subPageItems[index], style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: isHovered ? AppTheme.textMain : AppTheme.textSecondary)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(width: 1, color: AppTheme.border.withValues(alpha: 0.2)),
          Expanded(
            flex: 5,
            child: widget.constrainBodyWidth
                ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: widget.body))
                : widget.body,
          ),
          if (widget.rightPanel != null) ...[
            Container(width: 1, color: AppTheme.border.withValues(alpha: 0.2)),
            Expanded(flex: 3, child: widget.rightPanel!),
          ],
        ],
      ),
    );
  }
}
