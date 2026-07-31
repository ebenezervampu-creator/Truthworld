import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AnalyticsTab extends StatelessWidget {
  final AdminController controller;
  const AnalyticsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildViolationCategoryChart()),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: _buildTopOffendersList()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    final bool isSmall = constraints.maxWidth < 800;

    return Obx(() {
      final data = controller.analyticsData;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildMetricCard(
            'Platform Safety Score',
            '${data['safetyScore'] ?? 92}/100',
            Colors.green,
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
          _buildMetricCard(
            'Total Moderated (24h)',
            '${data['moderated24h'] ?? 1420}',
            AppColors.textPrimary,
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
          _buildMetricCard(
            'Auto-Approved Rate',
            '${data['autoApproveRate'] ?? 87}%',
            Colors.blue,
            isSmall ? constraints.maxWidth : constraints.maxWidth / 4 - 16,
          ),
          _buildMetricCard(
            'Active Violations',
            '${data['activeViolations'] ?? 34}',
            AppColors.error,
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
              color: AppColors.textSecondary,
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
          _buildBarChartRow('Hate Speech', 85, Colors.red),
          _buildBarChartRow('Spam', 45, Colors.orange),
          _buildBarChartRow('Harassment', 65, Colors.amber),
          _buildBarChartRow('Nudity', 20, Colors.pink),
        ],
      ),
    );
  }

  Widget _buildBarChartRow(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
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
                  widthFactor: percentage / 100,
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
          const SizedBox(width: 16),
          SizedBox(
            width: 40,
            child: Text(
              '${percentage.toInt()}%',
              style: const TextStyle(color: AppColors.textPrimary),
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.bgElevated,
                    child: Icon(Icons.person, color: AppColors.textPrimary),
                  ),
                  title: Text(
                    'User ${index + 1}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: Text(
                    '${(90 - index * 5)}% rej',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
