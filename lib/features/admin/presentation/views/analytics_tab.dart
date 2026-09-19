import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/analytics/admin_analytics_barrel.dart';

export 'package:truthworld/features/admin/presentation/views/analytics/admin_analytics_barrel.dart';

/// Platform Safety & Moderation Analytics tab view for Admin Dashboard.
///
/// Implemented as a declarative StatelessWidget adhering strictly to TruthWorld's
/// Zero setState Policy, sub-500 LOC ceiling, and UI contrast guidelines.
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({
    required this.controller,
    super.key,
  });

  final AdminController controller;

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
                AdminAnalyticsHeader(controller: controller),
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
                  AdminAnalyticsMetricsCards(
                    constraints: constraints,
                    data: data,
                  ),
                  const SizedBox(height: 24),
                  AdminAnalyticsPlatformOverviewBar(data: data),
                  const SizedBox(height: 32),
                  AdminAnalyticsContentFunnel(
                    constraints: constraints,
                    data: data,
                  ),
                  const SizedBox(height: 32),
                  if (constraints.maxWidth > 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AdminAnalyticsViolationChart(data: data),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: AdminAnalyticsTopOffenders(data: data),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        AdminAnalyticsViolationChart(data: data),
                        const SizedBox(height: 24),
                        AdminAnalyticsTopOffenders(data: data),
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
}
