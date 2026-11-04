import 'package:flutter/material.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';

/// Single navigation item button supporting both compact and full display modes.
class NavRailItem extends StatelessWidget {
  const NavRailItem({
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.title,
    required this.index,
    required this.isSelected,
    required this.onTap,
    super.key,
    this.isCompact = false,
    this.requiresAuth = false,
  });

  final IconData selectedIcon;
  final IconData unselectedIcon;
  final String title;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;
  final bool requiresAuth;

  @override
  Widget build(BuildContext context) {
    if (requiresAuth && !AuthService.to.isAuthenticated.value) {
      return const SizedBox.shrink();
    }

    final color = isSelected
        ? Colors.white
        : modernDarkProfessionalTheme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 0 : 16,
              vertical: 12,
            ),
            child: isCompact
                ? _buildCompactNavItem(color)
                : _buildFullNavItem(color),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavItem(Color color) {
    return Tooltip(
      message: title,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? selectedIcon : unselectedIcon,
              key: ValueKey(isSelected),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: modernDarkProfessionalTheme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFullNavItem(Color color) {
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isSelected ? selectedIcon : unselectedIcon,
            key: ValueKey(isSelected),
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: modernDarkProfessionalTheme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Section title header label for navigation groups.
class NavRailSectionHeader extends StatelessWidget {
  const NavRailSectionHeader({
    required this.title,
    super.key,
    this.isCompact = false,
  });

  final String title;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white54 : AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Thin horizontal divider separating navigation sections.
class NavRailDivider extends StatelessWidget {
  const NavRailDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 0.5,
      color: modernDarkProfessionalTheme.dividerColor,
    );
  }
}
