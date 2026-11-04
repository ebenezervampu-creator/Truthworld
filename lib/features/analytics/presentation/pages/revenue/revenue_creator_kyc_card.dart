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

    String badgeLabel;
    IconData icon;

    if (isVerified) {
      badgeLabel = 'KYC Verified';
      icon = Icons.verified_rounded;
    } else if (isPending) {
      badgeLabel = 'Under Review';
      icon = Icons.hourglass_top_rounded;
    } else if (isRejected) {
      badgeLabel = 'Action Required';
      icon = Icons.error_outline_rounded;
    } else {
      badgeLabel = 'Verification Needed';
      icon = Icons.assignment_ind_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Exact Library cardColor
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;

              final iconWidget = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              );

              const textContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creator Identity Verification (KYC)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PAN & Government ID verification for bank payouts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              );

              final badgeWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: isVerified ? 0.3 : 0.15),
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconWidget,
                        const SizedBox(width: 10),
                        const Expanded(child: textContent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    badgeWidget,
                  ],
                );
              }

              return Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  const Expanded(child: textContent),
                  const SizedBox(width: 8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (isVerified && kyc != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.bgDivider),
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
                            color: AppColors.textSecondary,
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
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
