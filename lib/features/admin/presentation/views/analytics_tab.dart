import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AnalyticsTab extends StatelessWidget {
  final AdminController controller;
  const AnalyticsTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger analytics fetch on initial load if analyticsData is empty
    if (controller.analyticsData.isEmpty && !controller.isLoadingAnalytics.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.fetchAnalytics();
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Obx(() {
          final isLoading = controller.isLoadingAnalytics.value;
          final data = controller.analyticsData;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                if (isLoading && data.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else ...[
                  _buildMetricsCards(constraints, data),
                  const SizedBox(height: 24),
                  _buildPlatformOverviewBar(data),
                  const SizedBox(height: 32),
                  _buildContentBreakdownSection(constraints, data),
                  const SizedBox(height: 32),
                  if (constraints.maxWidth > 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildViolationCategoryChart(data)),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _buildTopOffendersList(data)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildViolationCategoryChart(data),
                        const SizedBox(height: 24),
                        _buildTopOffendersList(data),
                      ],
                    ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Safety & Moderation Analytics',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Obx(() {
              final lastUpdated = controller.analyticsData['lastUpdated'];
              final formattedTime = (lastUpdated is DateTime)
                  ? DateFormat('hh:mm a').format(lastUpdated)
                  : 'Live';
              return Text(
                'Live aggregate insights from Firestore · Last updated: $formattedTime',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              );
            }),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time Range Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Obx(
                () => DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.analyticsTimeRange.value,
                    dropdownColor: const Color(0xFF1F1F1F),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                      DropdownMenuItem(value: '30d', child: Text('Last 30 Days')),
                      DropdownMenuItem(value: '90d', child: Text('Last 90 Days')),
                      DropdownMenuItem(value: 'all', child: Text('All Time')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.analyticsTimeRange.value = value;
                        controller.fetchAnalytics();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Refresh Button
            Obx(() {
              final isFetching = controller.isLoadingAnalytics.value;
              return Tooltip(
                message: 'Refresh Analytics',
                child: InkWell(
                  onTap: isFetching ? null : controller.fetchAnalytics,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: isFetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsCards(BoxConstraints constraints, Map<String, dynamic> data) {
    final isSmall = constraints.maxWidth < 900;
    final cardWidth = isSmall ? constraints.maxWidth : (constraints.maxWidth - 48) / 4;

    final safetyScore = data['safetyScore'] ?? 100;
    final totalModerated = data['totalModerated'] ?? data['totalModerated24h'] ?? 0;
    final autoApprovalRate = data['autoApprovalRate'] ?? data['autoApproveRate'] ?? 100;
    final activeViolations = data['activeViolations'] ?? 0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildMetricCard(
          title: 'Platform Safety Score',
          value: '$safetyScore/100',
          subtitle: safetyScore >= 80 ? 'Optimal Platform Health' : (safetyScore >= 50 ? 'Moderate Risk' : 'High Risk Backlog'),
          color: safetyScore >= 80 ? const Color(0xFF4CAF50) : (safetyScore >= 50 ? Colors.amber : AppColors.error),
          icon: Icons.shield_outlined,
          width: cardWidth,
        ),
        _buildMetricCard(
          title: 'Total Content Moderated',
          value: '$totalModerated',
          subtitle: 'Videos, Posts, Media & Reports',
          color: AppColors.textPrimary,
          icon: Icons.fact_check_outlined,
          width: cardWidth,
        ),
        _buildMetricCard(
          title: 'Auto-Approved Rate',
          value: '$autoApprovalRate%',
          subtitle: 'Clean Content Pass Rate',
          color: const Color(0xFF42A5F5),
          icon: Icons.verified_user_outlined,
          width: cardWidth,
        ),
        _buildMetricCard(
          title: 'Active Violations',
          value: '$activeViolations',
          subtitle: activeViolations > 0 ? 'Pending action or unresolved reports' : 'Zero active violations',
          color: activeViolations > 0 ? AppColors.error : const Color(0xFF4CAF50),
          icon: Icons.warning_amber_rounded,
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: color,
              fontSize: 28,
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
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformOverviewBar(Map<String, dynamic> data) {
    final totals = data['platformTotals'] as Map<String, dynamic>? ?? {};
    final users = totals['totalUsers'] ?? 0;
    final videos = totals['totalVideos'] ?? 0;
    final channels = totals['totalChannels'] ?? 0;
    final reports = totals['totalReports'] ?? 0;
    final appeals = totals['totalAppeals'] ?? 0;
    final banned = totals['bannedUsers'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildStatChip('Total Users', '$users', Icons.people_alt_outlined),
          _buildStatChip('Total Videos', '$videos', Icons.video_library_outlined),
          _buildStatChip('Total Channels', '$channels', Icons.account_circle_outlined),
          _buildStatChip('Total Reports', '$reports', Icons.flag_outlined),
          _buildStatChip('Content Appeals', '$appeals', Icons.gavel_outlined),
          _buildStatChip('Banned Accounts', '$banned', Icons.block_flipped),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String count, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentBreakdownSection(BoxConstraints constraints, Map<String, dynamic> data) {
    final breakdown = data['breakdown'] as Map<String, dynamic>? ?? {};
    final vStats = breakdown['videos'] as Map<String, dynamic>? ?? {};
    final mStats = breakdown['media'] as Map<String, dynamic>? ?? {};
    final cStats = breakdown['channels'] as Map<String, dynamic>? ?? {};
    final rStats = breakdown['reports'] as Map<String, dynamic>? ?? {};
    final aStats = breakdown['appeals'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Moderation Funnel',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Breakdown of review actions and compliance statuses across queues',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFunnelCard(
                  title: 'Videos Queue',
                  total: vStats['total'] ?? 0,
                  approved: vStats['approved'] ?? 0,
                  rejected: vStats['rejected'] ?? 0,
                  pending: vStats['pending'] ?? 0,
                  icon: Icons.video_collection_outlined,
                ),
                const SizedBox(width: 16),
                _buildFunnelCard(
                  title: 'Media & Posts',
                  total: mStats['total'] ?? 0,
                  approved: mStats['approved'] ?? 0,
                  rejected: mStats['rejected'] ?? 0,
                  pending: mStats['pending'] ?? 0,
                  icon: Icons.image_outlined,
                ),
                const SizedBox(width: 16),
                _buildFunnelCard(
                  title: 'Channels Queue',
                  total: cStats['total'] ?? 0,
                  approved: cStats['approved'] ?? 0,
                  rejected: cStats['rejected'] ?? 0,
                  pending: cStats['pending'] ?? 0,
                  icon: Icons.tv_outlined,
                ),
                const SizedBox(width: 16),
                _buildFunnelCard(
                  title: 'User Reports',
                  total: rStats['total'] ?? 0,
                  approved: rStats['resolved'] ?? 0,
                  rejected: rStats['dismissed'] ?? 0,
                  pending: rStats['pending'] ?? 0,
                  approvedLabel: 'Resolved',
                  rejectedLabel: 'Dismissed',
                  icon: Icons.report_problem_outlined,
                ),
                const SizedBox(width: 16),
                _buildFunnelCard(
                  title: 'Appeals',
                  total: aStats['total'] ?? 0,
                  approved: aStats['overturned'] ?? 0,
                  rejected: aStats['upheld'] ?? 0,
                  pending: aStats['pending'] ?? 0,
                  approvedLabel: 'Overturned',
                  rejectedLabel: 'Upheld',
                  icon: Icons.gavel_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelCard({
    required String title,
    required int total,
    required int approved,
    required int rejected,
    required int pending,
    required IconData icon,
    String approvedLabel = 'Approved',
    String rejectedLabel = 'Rejected',
  }) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$total',
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),
          _buildMiniStatusRow(approvedLabel, approved, const Color(0xFF4CAF50)),
          const SizedBox(height: 4),
          _buildMiniStatusRow(rejectedLabel, rejected, AppColors.error),
          const SizedBox(height: 4),
          _buildMiniStatusRow('Pending', pending, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildMiniStatusRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildViolationCategoryChart(Map<String, dynamic> data) {
    final categoriesRaw = data['violationCategories'];
    final categories = categoriesRaw is Map<String, dynamic>
        ? categoriesRaw
        : <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Violation Category Distribution',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (categories.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${categories.length} Categories',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Accurate breakdown of verified content violations and user reports',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          if (categories.isEmpty)
            _buildZeroViolationsState()
          else
            _buildCategoriesList(categories),
        ],
      ),
    );
  }

  Widget _buildZeroViolationsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Zero Violations Recorded',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No community guidelines violations or safety breaches have been detected in the selected time range.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(Map<String, dynamic> categories) {
    final totalCount = categories.values.fold<int>(
      0,
      (prev, curr) => prev + (curr is num ? curr.toInt() : 0),
    );

    final categoryList = categories.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    final chartColors = [
      const Color(0xFFEF5350), // Red
      const Color(0xFFFF7043), // Deep Orange
      const Color(0xFFFFA726), // Amber
      const Color(0xFFEC407A), // Pink
      const Color(0xFFAB47BC), // Purple
      const Color(0xFF42A5F5), // Blue
      const Color(0xFF26A69A), // Teal
    ];

    return Column(
      children: List.generate(categoryList.length, (index) {
        final entry = categoryList[index];
        final count = entry.value is num ? (entry.value as num).toInt() : 0;
        final percentage = totalCount > 0
            ? ((count / totalCount) * 100).roundToDouble()
            : 0.0;
        final color = chartColors[index % chartColors.length];

        return _buildBarChartRow(entry.key, percentage, count, color);
      }),
    );
  }

  Widget _buildBarChartRow(
    String label,
    double percentage,
    int count,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (percentage / 100).clamp(0.02, 1.0),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 75,
            child: Text(
              '${percentage.toInt()}% ($count)',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopOffendersList(Map<String, dynamic> data) {
    final offendersRaw = data['topOffenders'];
    final offenders = offendersRaw is List ? offendersRaw : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Repeat Offenders',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (offenders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${offenders.length} Accounts',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Accounts with multiple strikes, bans, or policy rejections',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          if (offenders.isEmpty)
            _buildZeroOffendersState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offenders.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 12,
              ),
              itemBuilder: (context, index) {
                final item = offenders[index];
                final username = (item['user'] ?? 'Unknown User').toString();
                final email = item['email']?.toString() ?? '';
                final count = item['violationsCount'] ?? 0;
                final strikes = item['strikes'] ?? 0;
                final isBanned = item['isBanned'] == true;

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isBanned
                          ? AppColors.error.withValues(alpha: 0.2)
                          : const Color(0xFF242424),
                      child: Icon(
                        isBanned ? Icons.block_rounded : Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            username,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isBanned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BANNED',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      email.isNotEmpty ? email : 'Strikes: $strikes',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count violation${count == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (strikes > 0)
                          Text(
                            '$strikes strike${strikes == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildZeroOffendersState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Repeat Offenders Recorded',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'All creators and users are currently within community guideline limits in this time period.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
