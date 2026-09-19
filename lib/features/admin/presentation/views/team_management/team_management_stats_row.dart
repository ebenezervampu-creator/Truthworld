import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Overview stats row for team management displaying total admins, active accounts,
/// super admins, and moderators.
class TeamManagementStatsRow extends StatelessWidget {
  const TeamManagementStatsRow({
    required this.controller,
    super.key,
  });

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final members = controller.adminMembers;
      final total = members.length;
      final active = members
          .where((m) => (m['status'] ?? 'active') != 'suspended')
          .length;
      final superAdmins = members
          .where((m) => (m['role'] ?? '').toString().contains('Super'))
          .length;
      final moderators = members
          .where((m) => (m['role'] ?? '').toString().contains('Mod'))
          .length;

      return LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 1000
              ? 4
              : (constraints.maxWidth > 600 ? 2 : 1);

          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: cols == 1 ? 3.0 : 2.0,
            children: [
              TeamManagementMetricCard(
                title: 'Total Administrators',
                value: '$total',
                subtitle: 'Registered access keys',
                icon: Icons.shield_outlined,
              ),
              TeamManagementMetricCard(
                title: 'Active Accounts',
                value: '$active',
                subtitle: 'Currently authorized',
                icon: Icons.verified_user_outlined,
              ),
              TeamManagementMetricCard(
                title: 'Super Admins',
                value: '$superAdmins',
                subtitle: 'Full system privileges',
                icon: Icons.admin_panel_settings_outlined,
              ),
              TeamManagementMetricCard(
                title: 'Moderators',
                value: '$moderators',
                subtitle: 'Queue review operators',
                icon: Icons.remove_red_eye_outlined,
              ),
            ],
          );
        },
      );
    });
  }
}

/// Single metric tile card in the overview stats grid.
class TeamManagementMetricCard extends StatelessWidget {
  const TeamManagementMetricCard({
    required this.icon,
    required this.subtitle,
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
