import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AnalyticsTab extends StatelessWidget {
  final AdminController controller;
  const AnalyticsTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger analytics fetch on initial load if analyticsData is empty
    if (controller.analyticsData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.fetchAnalytics();
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildMetricsCards(constraints),
              const SizedBox(height: 32),
              if (constraints.maxWidth > 800)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildViolationCategoryChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTopOffendersList()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildViolationCategoryChart(),
                    const SizedBox(height: 24),
                    _buildTopOffendersList(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Text(
          'Platform Safety Analytics',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Obx(
          () => DropdownButton<String>(
            value: controller.analyticsTimeRange.value,
            dropdownColor: AppColors.bgSurface,
            style: const TextStyle(color: AppColors.textPrimary),
            items: const [
              DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 Days')),
              DropdownMenuItem(value: '90d', child: Text('Last 90 Days')),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.analyticsTimeRange.value = value;
                controller.fetchAnalytics();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsCards(BoxConstraints constraints) {
    final isSmall = constraints.maxWidth < 800;

    return Obx(() {
      final data = controller.analyticsData;
      final safetyScore = data['safetyScore'] ?? 100;
      final totalModerated = data['totalModerated24h'] ?? data['moderated24h'] ?? 0;
      final autoApprovalRate = data['autoApprovalRate'] ?? data['autoApproveRate'] ?? 0;
      final activeViolations = data['activeViolations'] ?? 0;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildMetricCard(
            'Platform Safety Score',
            '$safetyScore/100',
            safetyScore >= 80
                ? Colors.green
                : (safetyScore >= 50 ? Colors.amber : AppColors.error),
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
          _buildMetricCard(
            'Total Moderated',
            '$totalModerated',
            AppColors.textPrimary,
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
          _buildMetricCard(
            'Auto-Approved Rate',
            '$autoApprovalRate%',
            Colors.blue,
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
          _buildMetricCard(
            'Active Violations',
            '$activeViolations',
            activeViolations > 0 ? AppColors.error : Colors.green,
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
        ],
      );
    });
  }

  Widget _buildMetricCard(
    String title,
    String value,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationCategoryChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Violation Category Distribution',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Obx(() {
            final data = controller.analyticsData;
            final categoriesRaw = data['violationCategories'];
            final categories =
                categoriesRaw is Map<String, dynamic> ? categoriesRaw : <String, dynamic>{};

            if (categories.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No violation categories recorded.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            }

            final totalCount = categories.values.fold<int>(
              0,
              (prev, curr) => prev + (curr is num ? curr.toInt() : 0),
            );

            final categoryList = categories.entries.toList()
              ..sort((a, b) => (b.value as num).compareTo(a.value as num));

            final chartColors = [
              Colors.red,
              Colors.orange,
              Colors.amber,
              Colors.pink,
              Colors.purple,
              Colors.blue,
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
          }),
        ],
      ),
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
              style: const TextStyle(color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (percentage / 100).clamp(0.02, 1.0),
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '${percentage.toInt()}% ($count)',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopOffendersList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Offenders',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final data = controller.analyticsData;
            final offendersRaw = data['topOffenders'];
            final offenders = offendersRaw is List ? offendersRaw : [];

            if (offenders.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No repeat offenders recorded.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offenders.length,
              itemBuilder: (context, index) {
                final item = offenders[index];
                final username = (item['user'] ?? 'Unknown User').toString();
                final count = item['violationsCount'] ?? 0;

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.bgElevated,
                      child: Icon(Icons.person, color: AppColors.textPrimary),
                    ),
                    title: Text(
                      username,
                      style: const TextStyle(color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '$count violation${count == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
