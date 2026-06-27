import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;
  final Widget? rightPanel;
  
  const DesktopScaffold({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.body,
    this.rightPanel,
  });

  static const List<String> _navItems = [
    'Home',
    'Explore',
    'Prompts',
    'Roadmap',
    'World',
    'Settings',
  ];

  static const List<IconData> _navIcons = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.auto_awesome_rounded,
    Icons.route_rounded,
    Icons.public_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 250,
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'DevMentor',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_navItems.length, (index) {
                  final isSelected = selectedIndex == index;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.accent.withValues(alpha: 0.1),
                    leading: Icon(
                      _navIcons[index],
                      color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                    title: Text(
                      _navItems[index],
                      style: GoogleFonts.inter(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                    ),
                    onTap: () => onTabSelected(index),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  );
                }),
              ],
            ),
          ),
          
          // Vertical Divider
          Container(width: 1, color: AppTheme.border.withValues(alpha: 0.2)),
          
          // Center Content
          Expanded(
            flex: 5,
            child: body,
          ),
          
          // Right Context Panel (Only if provided)
          if (rightPanel != null) ...[
            Container(width: 1, color: AppTheme.border.withValues(alpha: 0.2)),
            Expanded(
              flex: 3,
              child: rightPanel!,
            ),
          ],
        ],
      ),
    );
  }
}
