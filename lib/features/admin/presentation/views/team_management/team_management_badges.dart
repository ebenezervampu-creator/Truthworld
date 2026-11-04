import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Renders a collection of team role badges with semantic colors and overflow wrapping.
class TeamRoleBadges extends StatelessWidget {
  const TeamRoleBadges({
    required this.roles,
    super.key,
  });

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const TeamRoleBadge(role: 'Admin');
    if (roles.contains('Super Admin') ||
        roles.any((r) => r.toLowerCase().contains('owner'))) {
      return const TeamRoleBadge(role: 'Super Admin (All Tabs)');
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: roles.map((r) => TeamRoleBadge(role: r)).toList(),
    );
  }
}

/// Single role badge pill with role-specific semantic background and foreground colors.
class TeamRoleBadge extends StatelessWidget {
  const TeamRoleBadge({
    required this.role,
    super.key,
  });

  final String role;

  @override
  Widget build(BuildContext context) {
    var bg = AppColors.bgSurface;
    var fg = Colors.white;

    final r = role.toLowerCase();
    if (r.contains('super') || r.contains('owner')) {
      bg = AppColors.infoContainer;
      fg = AppColors.info;
    } else if (r.contains('content') || r.contains('mod')) {
      bg = AppColors.infoContainer;
      fg = AppColors.textLink;
    } else if (r.contains('ad')) {
      bg = AppColors.warningContainer;
      fg = AppColors.warning;
    } else if (r.contains('trust') || r.contains('safety')) {
      bg = AppColors.successContainer;
      fg = AppColors.success;
    } else if (r.contains('user')) {
      bg = AppColors.warningContainer;
      fg = AppColors.warning;
    } else if (r.contains('audit') || r.contains('compliance')) {
      bg = AppColors.infoContainer;
      fg = AppColors.info;
    } else if (r.contains('team')) {
      bg = AppColors.infoContainer;
      fg = AppColors.textLink;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Status indicator chip showing active or suspended state with a circular dot.
class TeamStatusChip extends StatelessWidget {
  const TeamStatusChip({
    required this.isSuspended,
    super.key,
  });

  final bool isSuspended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSuspended
            ? AppColors.error.withValues(alpha: 0.15)
            : AppColors.successContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuspended
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSuspended ? AppColors.error : AppColors.success,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isSuspended ? 'Suspended' : 'Active',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSuspended ? AppColors.error : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
