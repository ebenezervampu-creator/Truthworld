import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Fact verification audit report modal bottom sheet showing confidence score, flagged frames, and appeal button.
class ChannelNotificationsVerificationModal extends StatelessWidget {
  const ChannelNotificationsVerificationModal({
    required this.controller,
    required this.reportId,
    required this.channelId,
    super.key,
  });

  final ChannelNotificationsController controller;
  final String reportId;
  final String channelId;

  static void show(
    BuildContext context,
    ChannelNotificationsController controller,
    String reportId,
    String channelId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChannelNotificationsVerificationModal(
        controller: controller,
        reportId: reportId,
        channelId: channelId,
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: controller.fetchVerificationReport(reportId),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AppColors.bgDivider),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.bgDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHover,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.bgDivider,
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Fact Verification Audit Report',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                    ),
                  ),
                )
              else if (data == null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Verification Report Details Available in Verification Tab.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      _buildAuditRow(
                        'Status',
                        (data['status'] ?? 'Rejected').toString().toUpperCase(),
                        AppColors.error,
                      ),
                      _buildAuditRow(
                        'Primary Reason',
                        data['primaryReason'] as String? ??
                            'AI Synthetic Content Detected without disclosure',
                        AppColors.textPrimary,
                      ),
                      _buildAuditRow(
                        'Confidence Score',
                        '${(((data['confidenceScore'] as num?) ?? 0.86) * 100).toInt()}%',
                        AppColors.warning,
                      ),
                      _buildAuditRow(
                        'Detected Flagged Frames',
                        (data['flaggedFrames'] as List? ??
                                ['00:45', '02:12', '05:31'])
                            .join(', '),
                        AppColors.info,
                      ),
                      _buildAuditRow(
                        'Recommended Action',
                        data['recommendedFix'] as String? ??
                            'Enable AI Synthetic content label in video metadata settings or submit an appeal.',
                        AppColors.textPrimary,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Get.to<void>(
                                  () => TruthVerificationDashboardPage(
                                    channelId: channelId,
                                    isDarkMode: true,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.gavel_rounded,
                                color: Colors.black,
                                size: 16,
                              ),
                              label: const Text('Submit Appeal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
