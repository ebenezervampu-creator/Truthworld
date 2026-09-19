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
    var bg = const Color(0xFF202020);
    var fg = Colors.white;

    final r = role.toLowerCase();
    if (r.contains('super') || r.contains('owner')) {
      bg = const Color(0xFF332040);
      fg = const Color(0xFFD8B4FE);
    } else if (r.contains('content') || r.contains('mod')) {
      bg = const Color(0xFF1E2D4A);
      fg = const Color(0xFF93C5FD);
    } else if (r.contains('ad')) {
      bg = const Color(0xFF3E3218);
      fg = const Color(0xFFFDE68A);
    } else if (r.contains('trust') || r.contains('safety')) {
      bg = const Color(0xFF1A3828);
      fg = const Color(0xFF86EFAC);
    } else if (r.contains('user')) {
      bg = const Color(0xFF34231E);
      fg = const Color(0xFFFDBA74);
    } else if (r.contains('audit') || r.contains('compliance')) {
      bg = const Color(0xFF2E2638);
      fg = const Color(0xFFE9D5FF);
    } else if (r.contains('team')) {
      bg = const Color(0xFF16323B);
      fg = const Color(0xFF67E8F9);
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
            : const Color(0xFF1E3A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuspended
              ? AppColors.error.withValues(alpha: 0.3)
              : const Color(0xFF2BA640).withValues(alpha: 0.3),
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
              color: isSuspended ? AppColors.error : const Color(0xFF2BA640),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isSuspended ? 'Suspended' : 'Active',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSuspended ? AppColors.error : const Color(0xFF4ADE80),
            ),
          ),
        ],
      ),
    );
  }
}
