import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdsTab extends StatelessWidget {
  const AdsTab({required this.controller, super.key});

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Ad Campaigns Moderation',
                  style: AppTextStyles.pageTitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Review, approve, or reject advertiser campaign submissions across Feed, Video, and Sponsor formats.',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // Top Metrics Section
            Obx(() => _buildMetricsHeader(context)),
            const SizedBox(height: 20),

            // Filters & Search Bar
            _buildFilterAndSearchBar(context),
            const SizedBox(height: 16),

            // Campaigns List View
            Expanded(
              child: Obx(() {
                final filteredList = _getFilteredAds();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.campaign_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No ad campaigns match the selected filters.',
                          style: AppTextStyles.sectionHeader.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ad = filteredList[index];
                    return _buildAdCard(context, ad);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsHeader(BuildContext context) {
    final total = controller.totalAds.value;
    final pending = controller.pendingAds.value;
    final active = controller.ads.where((a) => a['status'] == 'active').length;
    final rejected = controller.ads
        .where((a) => a['status'] == 'verification_rejected')
        .length;

    return Row(
      children: [
        _buildMetricCard(
          title: 'Total Campaigns',
          value: '$total',
          icon: Icons.auto_awesome_motion_rounded,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 12),
        _buildMetricCard(
          title: 'Under Review',
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(width: 12),
        _buildMetricCard(
          title: 'Active Ads',
          value: '$active',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        const SizedBox(width: 12),
        _buildMetricCard(
          title: 'Rejected Ads',
          value: '$rejected',
          icon: Icons.cancel_rounded,
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchBar(BuildContext context) {
    return Row(
      children: [
        // Filter Chips
        Obx(() {
          final currentFilter = controller.adFilterTab.value;
          final filters = [
            {'id': 'all', 'label': 'All'},
            {'id': 'underReview', 'label': 'Under Review'},
            {'id': 'active', 'label': 'Active'},
            {'id': 'paused', 'label': 'Paused'},
            {'id': 'rejected', 'label': 'Rejected'},
          ];

          return Row(
            children: filters.map((f) {
              final isSelected = currentFilter == f['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f['label']!),
                  selected: isSelected,
                  onSelected: (_) => controller.adFilterTab.value = f['id']!,
                  backgroundColor: AppColors.bgSurface,
                  selectedColor: AppColors.brand,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.bgDivider,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),

        const Spacer(),

        // Search Input
        SizedBox(
          width: 240,
          height: 38,
          child: TextField(
            onChanged: (val) => controller.searchQuery.value = val,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search campaign or advertiser...',
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white,
                size: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.bgDivider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredAds() {
    final filter = controller.adFilterTab.value;
    final query = controller.searchQuery.value.trim().toLowerCase();

    return controller.ads.where((ad) {
      final status = (ad['status'] ?? 'active').toString();
      var matchesFilter = true;
      if (filter == 'underReview') {
        matchesFilter = status == 'underReview';
      } else if (filter == 'active') {
        matchesFilter = status == 'active';
      } else if (filter == 'paused') {
        matchesFilter = status == 'paused';
      } else if (filter == 'rejected') {
        matchesFilter = status == 'verification_rejected';
      }

      if (!matchesFilter) return false;

      if (query.isNotEmpty) {
        final title = (ad['title'] ?? '').toString().toLowerCase();
        final advertiser = (ad['advertiser'] ?? '').toString().toLowerCase();
        final ctaTarget = (ad['ctaTarget'] ?? '').toString().toLowerCase();
        return title.contains(query) ||
            advertiser.contains(query) ||
            ctaTarget.contains(query);
      }

      return true;
    }).toList();
  }

  Widget _buildAdCard(BuildContext context, Map<String, dynamic> ad) {
    final title = (ad['title'] ?? 'Untitled Campaign').toString();
    final advertiser = (ad['advertiser'] ?? 'Unknown Advertiser').toString();
    final description = (ad['description'] ?? '').toString();
    final status = (ad['status'] ?? 'underReview').toString();
    final adType = (ad['adType'] ?? 'homepage').toString();
    final isSkippable = ad['isSkippableAd'] ?? false;
    final budgetAmount = (ad['budgetAmount'] as num?)?.toDouble() ?? 0.0;
    final budgetTier = (ad['budgetTier'] ?? 'Custom').toString();
    final impressions = (ad['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (ad['clicks'] as num?)?.toInt() ?? 0;
    final moderationReason = ad['moderationReason'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ad Banner / Media Thumbnail Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 110,
              height: 70,
              decoration: const BoxDecoration(
                gradient: AppTheme.gradientCrimsonSubtle,
              ),
              child: const Center(
                child: Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        advertiser,
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgDivider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        adType == 'video_sponsor'
                            ? 'Sponsor Ad'
                            : isSkippable
                                ? 'Video Ad'
                                : 'Feed Ad',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: AppTextStyles.sectionHeader.copyWith(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (status == 'verification_rejected' &&
                    moderationReason != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.error,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Rejection Reason: $moderationReason',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Budget & Analytics + Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${budgetAmount.toStringAsFixed(0)}',
                style: AppTextStyles.sectionHeader.copyWith(
                  fontSize: 17,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                budgetTier.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '👁 $impressions  •  👆 $clicks',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons Row
              Row(
                children: [
                  // View Details Button
                  IconButton(
                    tooltip: 'Inspect Campaign Details',
                    onPressed: () => _showAdDetailsDialog(context, ad),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  // Approve Button
                  ElevatedButton.icon(
                    onPressed: status == 'active'
                        ? null
                        : () => controller.moderateAd(
                              ad['id'].toString(),
                              'approve',
                            ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(status == 'active' ? 'Approved' : 'Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'active'
                          ? AppColors.bgDivider
                          : const Color(0xFF2BA640),
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Reject Button
                  OutlinedButton.icon(
                    onPressed: status == 'verification_rejected'
                        ? null
                        : () => _showRejectDialog(context, ad),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      status == 'verification_rejected'
                          ? 'Rejected'
                          : 'Reject',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    if (status == 'underReview') {
      color = AppColors.warning;
      label = 'Under Review';
    } else if (status == 'active') {
      color = AppColors.success;
      label = 'Active';
    } else if (status == 'paused') {
      color = AppColors.textSecondary;
      label = 'Paused';
    } else {
      color = AppColors.error;
      label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, Map<String, dynamic> ad) {
    final reasonController = TextEditingController(
      text: 'Ad creative or content violates advertising guidelines.',
    );

    Get.defaultDialog(
      title: 'Reject Campaign',
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Please provide a moderation reason for rejecting "${ad['title']}":',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter reason for advertiser...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF161616),
      textConfirm: 'Reject Campaign',
      textCancel: 'Cancel',
      confirmTextColor: AppColors.textPrimary,
      cancelTextColor: AppColors.textSecondary,
      buttonColor: AppColors.error,
      onConfirm: () {
        final reason = reasonController.text.trim();
        Get.back();
        controller.moderateAd(
          ad['id'].toString(),
          'reject',
          reason: reason.isNotEmpty ? reason : 'Violates advertising policy',
        );
      },
    );
  }

  void _showAdDetailsDialog(BuildContext context, Map<String, dynamic> ad) {
    Get.defaultDialog(
      title: 'Campaign Full Details',
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      content: SingleChildScrollView(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Campaign Title', (ad['title'] ?? '-').toString()),
              _buildDetailRow('Advertiser', (ad['advertiser'] ?? '-').toString()),
              _buildDetailRow('Advertiser User ID', (ad['userId'] ?? '-').toString()),
              _buildDetailRow('Format', (ad['adType'] ?? 'homepage').toString()),
              _buildDetailRow('CTA Text', (ad['ctaText'] ?? 'Learn More').toString()),
              _buildDetailRow('CTA Target URL', (ad['ctaTarget'] ?? '-').toString()),
              if (ad['videoUrl'] != null)
                _buildDetailRow('Video Source URL', ad['videoUrl'].toString()),
              _buildDetailRow(
                'Budget',
                '₹${ad['budgetAmount'] ?? 0} (${ad['budgetTier'] ?? 'Custom'})',
              ),
              _buildDetailRow('Current Status', (ad['status'] ?? '-').toString()),
              if (ad['moderationReason'] != null)
                _buildDetailRow(
                  'Rejection Reason',
                  ad['moderationReason'].toString(),
                ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFF161616),
      textConfirm: 'Close',
      confirmTextColor: AppColors.textPrimary,
      buttonColor: AppColors.brand,
      onConfirm: Get.back,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
