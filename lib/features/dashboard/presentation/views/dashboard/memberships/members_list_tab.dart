import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Tab 2: Active Channel Members List and Tier Filter.
class MembersListTab extends StatelessWidget {
  const MembersListTab({
    required this.controller,
    this.isDarkMode = true,
    super.key,
  });

  final MembershipsController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscribed Channel Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fans actively supporting your channel through recurring memberships.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Tier Filter Dropdown
            Obx(() {
              final tiers = controller.tiers;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.bgSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode
                        ? AppColors.bgDivider
                        : Colors.grey.shade300,
                  ),
                ),
                child: DropdownButton<String>(
                  value: controller.selectedTierFilter.value,
                  underline: const SizedBox.shrink(),
                  dropdownColor: isDarkMode
                      ? AppColors.bgSurfaceHigh
                      : Colors.white,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black87,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All Tiers',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                      ),
                    ),
                    ...tiers.map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) controller.selectedTierFilter.value = val;
                  },
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        Obx(() {
          final members = controller.filteredMembers;

          if (members.isEmpty) {
            return EmptyMembersView(isDarkMode: isDarkMode);
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final member = members[index];
              return MemberItemCard(member: member, isDarkMode: isDarkMode);
            },
          );
        }),
      ],
    );
  }
}

/// Single Member Row Card in Members List.
class MemberItemCard extends StatelessWidget {
  const MemberItemCard({
    required this.member,
    this.isDarkMode = true,
    super.key,
  });

  final ChannelMember member;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brand.withValues(alpha: 0.2),
            backgroundImage: member.userAvatarUrl.isNotEmpty
                ? NetworkImage(member.userAvatarUrl)
                : null,
            child: member.userAvatarUrl.isEmpty
                ? Text(
                    member.userName.isNotEmpty
                        ? member.userName[0].toUpperCase()
                        : 'M',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.userName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Joined: ${member.joinedAt != null ? DateFormat.yMMMd().format(member.joinedAt!) : 'Recently'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.bgSurfaceHigh
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              member.tierName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${member.formattedPrice}/mo',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty State for Members Tab.
class EmptyMembersView extends StatelessWidget {
  const EmptyMembersView({
    super.key,
    this.isDarkMode = true,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 44,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 12),
          Text(
            'No Members Subscribed Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When fans subscribe to your membership tiers, their profiles, perks status, and contribution history will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
