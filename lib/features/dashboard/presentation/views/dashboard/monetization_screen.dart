import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/theme/app_theme.dart';

class MonetizationScreen extends StatelessWidget {

  const MonetizationScreen({required this.isDarkMode, super.key});
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.background
          : AppTheme.colors.textPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Channel Monetization',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.colors.textPrimary
                    : AppTheme.colors.background,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Grow with our Partner Program. Get access to exclusive features, creator support, and more.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            _buildEligibilitySection(controller),
            const SizedBox(height: 32),
            _buildRevenueSummary(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilitySection(DashboardController controller) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Join',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Obx(() {
            final subsStr = controller.channelStats['subscribers']?.toString() ?? '0';
            
            final subs = _parseFormattedNumber(subsStr);
            final watchHours = controller.watchHours.round();

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressIndicator(
                  value: subs,
                  goal: 1000,
                  label: 'Subscribers',
                ),
                _buildProgressIndicator(
                  value: watchHours,
                  goal: 4000,
                  label: 'Public watch hours',
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: null, // Disabled until eligibility is met
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colors.info,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Apply to Partner Program'),
            ),
          ),
        ],
      ),
    );
  }

  int _parseFormattedNumber(String formatted) {
    try {
      if (formatted.endsWith('M')) {
        return (double.parse(formatted.replaceAll('M', '')) * 1000000).toInt();
      } else if (formatted.endsWith('K')) {
        return (double.parse(formatted.replaceAll('K', '')) * 1000).toInt();
      }
      return int.parse(formatted.replaceAll(',', ''));
    } catch (_) {
      return 0;
    }
  }



  Widget _buildRevenueSummary(DashboardController controller) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated Revenue',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final revenue = controller.channelStats['revenue'] ?? r'$0.00';
            return _buildRevenueRow('Last 28 days', revenue);
          }),
          _buildRevenueRow('Last 90 days', r'$0.00'),
          _buildRevenueRow('Lifetime', r'$0.00'),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String period, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            period,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary70
                  : AppTheme.colors.background54,
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator({
    required int value,
    required int goal,
    required String label,
  }) {
    final percent = (value / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 60,
          lineWidth: 10,
          percent: percent,
          center: Text(
            NumberFormat.compact().format(value),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          progressColor: AppTheme.colors.info,
          backgroundColor: isDarkMode
              ? AppTheme.colors.textSecondary
              : AppTheme.colors.textSecondary,
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(
          'Goal: ${NumberFormat.compact().format(goal)}',
          style: TextStyle(color: AppTheme.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.colors.surface
            : AppTheme.colors.textPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppTheme.colors.textSecondary
              : AppTheme.colors.textSecondary,
        ),
      ),
      child: child,
    );
  }
}




