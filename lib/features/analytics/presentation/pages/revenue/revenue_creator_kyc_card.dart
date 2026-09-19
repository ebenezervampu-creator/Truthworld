import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/creator_kyc_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildCreatorKycCard(
  BuildContext context,
  RevenueAnalyticsController controller,
) {
  return Obx(() {
    final isVerified = controller.isKycVerified;
    final isPending = controller.isKycPending;
    final isRejected = controller.isKycRejected;
    final kyc = controller.creatorKyc.value;

    Color badgeBg;
    Color badgeBorder;
    Color badgeTextColor;
    String badgeLabel;
    IconData icon;

    if (isVerified) {
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.15);
      badgeBorder = const Color(0xFF10B981).withValues(alpha: 0.3);
      badgeTextColor = const Color(0xFF10B981);
      badgeLabel = 'KYC Verified';
      icon = Icons.verified_rounded;
    } else if (isPending) {
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      badgeBorder = const Color(0xFFF59E0B).withValues(alpha: 0.3);
      badgeTextColor = const Color(0xFFF59E0B);
      badgeLabel = 'Under Review';
      icon = Icons.hourglass_top_rounded;
    } else if (isRejected) {
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      badgeBorder = const Color(0xFFEF4444).withValues(alpha: 0.3);
      badgeTextColor = const Color(0xFFEF4444);
      badgeLabel = 'Action Required';
      icon = Icons.error_outline_rounded;
    } else {
      badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
      badgeBorder = const Color(0xFF3B82F6).withValues(alpha: 0.3);
      badgeTextColor = const Color(0xFF60A5FA);
      badgeLabel = 'Verification Needed';
      icon = Icons.assignment_ind_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFF27272A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator Identity Verification (KYC)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'PAN & Government ID verification for bank payouts',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isVerified && kyc != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAN: ${kyc.maskedPan} (${kyc.panLegalName})',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Verified ID: ${kyc.identityProofType.displayName} • Payouts Active',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => CreatorKycDialog.show(context),
                    child: const Text(
                      'Details',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              isPending
                  ? 'Your documents have been submitted and are currently being reviewed by our compliance team.'
                  : (isRejected
                      ? (kyc?.rejectionReason ?? 'Document verification check failed. Please re-upload your valid government ID.')
                      : 'In compliance with financial regulations, verify your PAN and Government ID to enable direct bank payouts.'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => CreatorKycDialog.show(context),
                icon: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 16),
                label: Text(
                  isPending
                      ? 'View / Update Submitted Documents'
                      : (isRejected ? 'Resubmit KYC Documents' : 'Complete KYC Verification'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isRejected ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  side: BorderSide(
                    color: (isRejected ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  });
}
