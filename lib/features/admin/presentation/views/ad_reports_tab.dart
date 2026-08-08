import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdReportsTab extends StatelessWidget {
  final AdminController controller;
  const AdReportsTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                const Icon(
                  Icons.report_problem_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Advertiser Reports',
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
              'Review user reports submitted against active advertiser campaigns and take enforcement actions.',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Live Stream of ad_reports
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ad_reports')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.warning),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 56,
                            color: AppColors.success,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Advertiser Reports',
                            style: AppTextStyles.sectionHeader.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All advertiser campaigns are currently clean with zero user reports.',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final reports = docs.map((d) => d.data()).toList();
                  reports.sort((a, b) {
                    final tA = a['createdAt'] ?? '';
                    final tB = b['createdAt'] ?? '';
                    return tB.toString().compareTo(tA.toString());
                  });

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final reportId = report['id'] ?? docs[index].id;
                      final adId = report['adId'] ?? '';
                      final advertiser = report['advertiser'] ?? 'Advertiser';
                      final campaignTitle =
                          report['campaignTitle'] ?? 'Campaign';
                      final reason = report['reason'] ?? 'Unspecified';
                      final details = report['details'] ?? '';
                      final userName = report['userName'] ?? 'User';
                      final userEmail = report['userEmail'] ?? '';
                      final status = report['status'] ?? 'pending';
                      final isResolved = status == 'resolved';

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isResolved
                                ? AppColors.bgDivider
                                : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isResolved
                                        ? AppColors.bgDivider
                                        : AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isResolved ? 'RESOLVED' : 'PENDING REVIEW',
                                    style: TextStyle(
                                      color: isResolved
                                          ? AppColors.textTertiary
                                          : AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    campaignTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Advertiser: $advertiser',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                              color: AppColors.bgDivider,
                              height: 20,
                            ),

                            // Report Content
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.report_gmailerrorred_rounded,
                                  color: AppColors.textPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reason: $reason',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (details.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Details: "$details"',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        'Reported by: $userName${userEmail.isNotEmpty ? " ($userEmail)" : ""}',
                                        style: const TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Actions Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('ad_campaigns')
                                          .doc(adId)
                                          .update({'status': 'verification_rejected'});

                                      await FirebaseFirestore.instance
                                          .collection('ad_reports')
                                          .doc(reportId)
                                          .update({'status': 'resolved'});

                                      AppSnackbar.show(
                                        'Campaign Paused',
                                        'Ad campaign status set to rejected and report resolved.',
                                      );
                                    } catch (e) {
                                      AppSnackbar.show(
                                        'Error',
                                        'Failed to pause ad campaign: $e',
                                        backgroundColor: AppColors.error,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.pause_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text('Pause & Reject Ad'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('ad_reports')
                                          .doc(reportId)
                                          .update({'status': 'resolved'});

                                      AppSnackbar.show(
                                        'Report Resolved',
                                        'Report marked as resolved.',
                                      );
                                    } catch (e) {
                                      debugPrint(
                                        'Error resolving report: $e',
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isResolved
                                        ? 'Resolved'
                                        : 'Mark as Resolved',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: AppColors.bgDivider,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
