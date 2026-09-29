import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive Card displaying an individual Channel Membership Tier.
class MembershipTierCard extends StatelessWidget {
  const MembershipTierCard({
    required this.tier,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDuplicate,
    required this.onDelete,
    this.isDarkMode = true,
    super.key,
  });

  final ChannelMembershipTier tier;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: TWRadius.xlBorderRadius,
        border: Border.all(
          color: tier.isEnabled
              ? (isDarkMode ? AppColors.bgDivider : Colors.grey.shade200)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: tier.badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tier.badgeColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          tier.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!tier.isEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: TWRadius.smBorderRadius,
                          ),
                          child: const Text(
                            'PAUSED',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: TWRadius.mdBorderRadius,
                  ),
                  child: Text(
                    '${tier.formattedPrice} / mo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: TWRadius.mdBorderRadius,
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      onEdit();
                    } else if (val == 'toggle') {
                      onToggleStatus();
                    } else if (val == 'duplicate') {
                      onDuplicate();
                    } else if (val == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Tier',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            tier.isEnabled
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            tier.isEnabled ? 'Pause Tier' : 'Enable Tier',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Duplicate Tier',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete Tier',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (tier.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tier.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
            const SizedBox(height: 14),
            Text(
              'INCLUDED PERKS & BENEFITS (${tier.perks.length}):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            if (tier.perks.isEmpty)
              const Text(
                '• Loyalty badge beside name in comments',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tier.perks.map((perk) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgSurfaceHigh
                          : Colors.grey.shade100,
                      borderRadius: TWRadius.mdBorderRadius,
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.bgDivider
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          perk,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty State Illustration & Quick Actions when no tiers have been created.
class EmptyTiersView extends StatelessWidget {
  const EmptyTiersView({
    required this.onApplyStarterBundles,
    required this.onCreateTier,
    this.isDarkMode = true,
    super.key,
  });

  final bool isDarkMode;
  final VoidCallback onApplyStarterBundles;
  final VoidCallback onCreateTier;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: TWRadius.xlBorderRadius,
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.bgSurfaceHigh
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 48,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Membership Tiers Created Yet',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              r'Set up membership levels (e.g. Bronze $2/mo, Silver VIP $5/mo, Gold Patron $10/mo) so fans can support your channel directly with 0% platform commission.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onApplyStarterBundles,
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 18,
                ),
                label: const Text('Setup Default Starter Tiers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: TWRadius.mdBorderRadius,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onCreateTier,
                icon: Icon(
                  Icons.add_rounded,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  size: 18,
                ),
                label: const Text('Create Custom Tier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDarkMode
                      ? AppColors.textPrimary
                      : Colors.black87,
                  side: BorderSide(
                    color: isDarkMode
                        ? AppColors.bgDivider
                        : Colors.grey.shade400,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: TWRadius.mdBorderRadius,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
