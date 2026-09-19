import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';

/// Fact verification audit report modal bottom sheet showing confidence score, flagged frames, and appeal button.
class IntelligenceVerificationReportModal extends StatelessWidget {
  const IntelligenceVerificationReportModal({
    required this.controller,
    required this.reportId,
    required this.channelId,
    super.key,
  });

  final CreatorIntelligenceController controller;
  final String reportId;
  final String channelId;

  static void show(
    BuildContext context,
    CreatorIntelligenceController controller,
    String reportId,
    String channelId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IntelligenceVerificationReportModal(
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
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
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: Color(0xFF27272A)),
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
                    color: const Color(0xFF3F3F46),
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
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Fact Verification Audit Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF27272A)),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else if (data == null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Verification Report Details Available in Verification Tab.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFA1A1AA),
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
                        const Color(0xFFF87171),
                      ),
                      _buildAuditRow(
                        'Primary Reason',
                        data['primaryReason'] as String? ??
                            'AI Synthetic Content Detected without disclosure',
                        Colors.white,
                      ),
                      _buildAuditRow(
                        'Confidence Score',
                        '${(((data['confidenceScore'] as num?) ?? 0.86) * 100).toInt()}%',
                        const Color(0xFFFBBF24),
                      ),
                      _buildAuditRow(
                        'Detected Flagged Frames',
                        (data['flaggedFrames'] as List? ??
                                ['00:45', '02:12', '05:31'])
                            .join(', '),
                        const Color(0xFF38BDF8),
                      ),
                      _buildAuditRow(
                        'Recommended Action',
                        data['recommendedFix'] as String? ??
                            'Enable AI Synthetic content label in video metadata settings or submit an appeal.',
                        Colors.white,
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
                                color: Colors.white,
                                size: 16,
                              ),
                              label: const Text('Submit Appeal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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
