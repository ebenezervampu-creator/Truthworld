import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships/member_avatar_stack.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            if (isMobile) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Subscribed Channel Members',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Obx(() {
                    final count = controller.filteredMembers.length;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        '$count ${count == 1 ? 'Member' : 'Members'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fans actively supporting your channel through recurring memberships.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Subscribed Channel Members',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Obx(() {
                              final count = controller.filteredMembers.length;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? AppColors.bgSurfaceHigh
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? AppColors.bgDivider
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  '$count ${count == 1 ? 'Member' : 'Members'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? AppColors.textSecondary
                                        : Colors.black87,
                                  ),
                                ),
                              );
                            }),
                          ],
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
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Search & Filter Bar
            Obx(() {
              final tiers = controller.tiers;
              final hasMembers = controller.members.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Search field
                      if (hasMembers) ...[
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.bgSurface : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDarkMode
                                    ? AppColors.bgDivider
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: TextField(
                              onChanged: (val) => controller.memberSearchQuery.value = val,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search members by name...',
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: isDarkMode ? AppColors.textSecondary : Colors.black45,
                                ),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      // Tier Filter Dropdown
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.bgSurface : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDarkMode
                                ? AppColors.bgDivider
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedTierFilter.value,
                            dropdownColor: isDarkMode
                                ? AppColors.bgSurfaceHigh
                                : Colors.white,
                            icon: Icon(
                              Icons.filter_list_rounded,
                              size: 18,
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
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
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
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
                        ),
                      ),
                    ],
                  ),
                  if (hasMembers) ...[
                    const SizedBox(height: 12),
                    // Quick Community Avatars Stack Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.bgSurface.withValues(alpha: 0.7)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          MemberAvatarStack(
                            members: controller.members,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${controller.members.length} dedicated supporter${controller.members.length == 1 ? '' : 's'} fueling your creative journey.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }),
            const SizedBox(height: 16),

            // Members List or Empty View
            Obx(() {
              final members = controller.filteredMembers;

              if (members.isEmpty) {
                return EmptyMembersView(
                  isDarkMode: isDarkMode,
                  isFiltered: controller.selectedTierFilter.value != 'all' ||
                      controller.memberSearchQuery.value.isNotEmpty,
                  onResetFilter: () {
                    controller.selectedTierFilter.value = 'all';
                    controller.memberSearchQuery.value = '';
                  },
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final member = members[index];
                  final tier = controller.tiers.firstWhereOrNull((t) => t.id == member.tierId);
                  return MemberItemCard(
                    member: member,
                    tier: tier,
                    isDarkMode: isDarkMode,
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}

/// Single Member Row Card in Members List.
class MemberItemCard extends StatelessWidget {
  const MemberItemCard({
    required this.member,
    this.tier,
    this.isDarkMode = true,
    super.key,
  });

  final ChannelMember member;
  final ChannelMembershipTier? tier;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // User Avatar with clean fallback initials and caching
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(
                photoUrl: member.userAvatarUrl,
                displayName: member.userName,
                backgroundColor: isDarkMode
                    ? AppColors.bgSurfaceHigh
                    : Colors.grey.shade100,
                borderColor: isDarkMode
                    ? AppColors.bgDivider
                    : Colors.grey.shade300,
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: member.status.toLowerCase() == 'active'
                        ? AppColors.success
                        : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? AppColors.bgSurface : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Member Name & Tenure
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.userName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      constraints: const BoxConstraints(maxWidth: 140),
                      decoration: BoxDecoration(
                        color: (tier?.badgeColor ?? AppColors.success)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: (tier?.badgeColor ?? AppColors.success)
                              .withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        member.tierName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: tier?.badgeColor ??
                              (isDarkMode ? AppColors.success : const Color(0xFF059669)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Joined: ${member.joinedAt != null ? DateFormat.yMMMd().format(member.joinedAt!) : 'Recently'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Contribution Amount & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${member.formattedPrice}/mo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                member.autoPay ? 'Auto-renews' : 'Manual',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black45,
                ),
              ),
            ],
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
    this.isFiltered = false,
    this.onResetFilter,
  });

  final bool isDarkMode;
  final bool isFiltered;
  final VoidCallback? onResetFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered ? 'No Members Found in Filter' : 'No Members Subscribed Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              isFiltered
                  ? 'No subscribed members matched the selected tier or search keywords. Try clearing filters to view all members.'
                  : 'When fans subscribe to your membership tiers, their profile avatars, badges, and contribution history will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                height: 1.4,
              ),
            ),
          ),
          if (isFiltered && onResetFilter != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onResetFilter,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDarkMode ? AppColors.textPrimary : Colors.black87,
                side: BorderSide(
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                ),
              ),
              child: const Text('Show All Members'),
            ),
          ],
        ],
      ),
    );
  }
}
