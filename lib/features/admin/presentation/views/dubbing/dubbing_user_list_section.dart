import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single filter chip button for filtering dubbing user list.
class DubbingFilterChip extends StatelessWidget {
  final String filterKey;
  final String label;
  final String currentFilter;
  final VoidCallback onTap;

  const DubbingFilterChip({
    required this.filterKey,
    required this.label,
    required this.currentFilter,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentFilter == filterKey;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Left master pane: searchable, filterable list of user accounts with live dubbing balances.
class DubbingUserListSection extends StatelessWidget {
  final AdminController controller;
  final bool isDesktop;

  const DubbingUserListSection({
    required this.controller,
    required this.isDesktop,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Dubbing Accounts',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Obx(
                            () => Text(
                              '${controller.filteredDubbingUsers.length} of ${controller.allDubbingUsers.length} accounts',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
                      tooltip: 'Refresh User Accounts',
                      onPressed: () => controller.fetchDubbingUsers(force: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Input
                TextField(
                  controller: controller.dubbingSearchController,
                  onChanged: controller.searchDubbingUsers,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by user name, email, or UID...',
                    hintStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    suffixIcon: Obx(
                      () => controller.dubbingSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                              onPressed: () {
                                controller.dubbingSearchController.clear();
                                controller.searchDubbingUsers('');
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter Chips
                Obx(() {
                  final active = controller.dubbingFilterOption.value;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DubbingFilterChip(
                          filterKey: 'all',
                          label: 'All Users',
                          currentFilter: active,
                          onTap: () => controller.setDubbingFilterOption('all'),
                        ),
                        const SizedBox(width: 8),
                        DubbingFilterChip(
                          filterKey: 'with_discount',
                          label: 'Special Discounts',
                          currentFilter: active,
                          onTap: () => controller.setDubbingFilterOption('with_discount'),
                        ),
                        const SizedBox(width: 8),
                        DubbingFilterChip(
                          filterKey: 'free_waiver',
                          label: '100% Free Waivers',
                          currentFilter: active,
                          onTap: () => controller.setDubbingFilterOption('free_waiver'),
                        ),
                        const SizedBox(width: 8),
                        DubbingFilterChip(
                          filterKey: 'with_credits',
                          label: 'With Credits',
                          currentFilter: active,
                          onTap: () => controller.setDubbingFilterOption('with_credits'),
                        ),
                        const SizedBox(width: 8),
                        DubbingFilterChip(
                          filterKey: 'zero_credits',
                          label: 'Zero Balance',
                          currentFilter: active,
                          onTap: () => controller.setDubbingFilterOption('zero_credits'),
                        ),
                        const SizedBox(width: 8),
                        DubbingFilterChip(
                          filterKey: 'channels',
                          label: 'Channels & Creators',
                          currentFilter: active,
                          onTap: () => controller.setDubbingFilterOption('channels'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          // User List
          Expanded(
            child: Obx(() {
              if (controller.isFetchingDubbingUsers.value && controller.allDubbingUsers.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                );
              }

              final users = controller.filteredDubbingUsers;
              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No User Accounts Found',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try adjusting your search query or filter status.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => controller.fetchDubbingUsers(force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
                          label: const Text(
                            'Reload Accounts',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final userId = (user['id'] ?? user['uid'] ?? '').toString();
                  final isSelected = controller.selectedDubbingUser.value?['id'] == userId;

                  final name = (user['displayName'] ?? 'User').toString();
                  final email = (user['email'] ?? '').toString();
                  final photoUrl = (user['photoURL'] ?? '').toString();
                  final credits = (user['balanceCredits'] as num?)?.toInt() ?? 0;
                  final usd = (user['balanceUsd'] as num?)?.toDouble() ?? 0.0;
                  final isFree = user['isDubbingFree'] == true;
                  final discountPercent = (user['specialDiscountPercent'] as num?)?.toDouble() ?? 0.0;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => controller.selectDubbingUser(user),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.06),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.bgSurface,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          // Name, Email & Badges
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontFamily: TWTypography.brandFamily,
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Discount Badge
                                    if (isFree)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                        ),
                                        child: const Text(
                                          '100% FREE',
                                          style: TextStyle(
                                            fontFamily: TWTypography.brandFamily,
                                            color: Colors.greenAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else if (discountPercent > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          '${discountPercent.round()}% OFF',
                                          style: const TextStyle(
                                            fontFamily: TWTypography.brandFamily,
                                            color: Colors.amberAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email.isNotEmpty ? email : userId,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Stats chips
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.bolt_rounded, size: 12, color: AppColors.warning),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${credits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
                                            style: const TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              color: AppColors.textPrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (usd > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '\$${usd.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontFamily: TWTypography.uiFamily,
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
