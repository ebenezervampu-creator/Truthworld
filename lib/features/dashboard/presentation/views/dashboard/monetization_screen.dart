import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';

import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

class MonetizationScreen extends StatelessWidget {
  final bool isDarkMode;

  const MonetizationScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.find<DashboardController>();
    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.background
          : AppTheme.colors.textPrimary,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Channel Monetization',
              style: GoogleFonts.roboto(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.colors.textPrimary
                    : AppTheme.colors.background,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Grow with our Partner Program. Get access to exclusive features, creator support, and more.',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: AppTheme.colors.textSecondary,
              ),
            ),
            SizedBox(height: 32),
            _buildEligibilitySection(controller),
            SizedBox(height: 32),
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
          Text(
            'How to Join',
            style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 24),
          Obx(() {
            final subsStr = controller.channelStats['subscribers']?.toString() ?? '0';
            final watchTimeStr = controller.channelStats['watchTime']?.toString() ?? '0h';
            
            // Parse numbers from formatted strings (e.g., "1.2K" -> 1200)
            int subs = _parseFormattedNumber(subsStr);
            int watchHours = _parseWatchHours(watchTimeStr);

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
          SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: null, // Disabled until eligibility is met
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colors.info,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text('Apply to Partner Program'),
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

  int _parseWatchHours(String formatted) {
    try {
      return int.parse(formatted.replaceAll('h', '').replaceAll('m', ''));
    } catch (_) {
      return 0;
    }
  }

  Widget _buildRevenueSummary(DashboardController controller) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Revenue',
            style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 16),
          Obx(() {
            final revenue = controller.channelStats['revenue'] ?? '\$0.00';
            return _buildRevenueRow('Last 28 days', revenue);
          }),
          _buildRevenueRow('Last 90 days', '\$0.00'),
          _buildRevenueRow('Lifetime', '\$0.00'),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String period, String amount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            period,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary70
                  : AppTheme.colors.background54,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
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
    double percent = (value / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 60.0,
          lineWidth: 10.0,
          percent: percent,
          center: Text(
            NumberFormat.compact().format(value),
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          progressColor: AppTheme.colors.info,
          backgroundColor: isDarkMode
              ? AppTheme.colors.textSecondary
              : AppTheme.colors.textSecondary,
          circularStrokeCap: CircularStrokeCap.round,
        ),
        SizedBox(height: 8),
        Text(label, style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
        Text(
          'Goal: ${NumberFormat.compact().format(goal)}',
          style: TextStyle(color: AppTheme.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(20),
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





