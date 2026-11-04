import 'package:flutter/material.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Hero card inviting the creator to join the TruthWorld Monetization Program.
/// Displayed on the Revenue & Payouts tab when the channel has not yet qualified or applied,
/// ensuring creators are not prematurely prompted for bank account and KYC details.
class MonetizationJoinHeroCard extends StatelessWidget {
  const MonetizationJoinHeroCard({
    required this.channel,
    required this.controller,
    required this.onJoinPressed,
    super.key,
  });

  final Channel? channel;
  final DashboardController controller;
  final VoidCallback onJoinPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.15)),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TruthWorld Partner Program',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Monetize your verified content & earn from day 1',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'To join the monetization program, at least one video on your channel must reach 1,000 views and 10 hours of watch time. Once reached, you can submit your verification details for admin approval.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _buildFeatureBullet(
            icon: Icons.check_circle_outline_rounded,
            title: '1k Views & 10 Hours Gate',
            desc: 'Cross this milestone on ANY video to unlock the application',
          ),
          const SizedBox(height: 8),
          _buildFeatureBullet(
            icon: Icons.people_outline_rounded,
            title: 'Zero Subscriber Barrier',
            desc: 'No follower or subscriber thresholds required (0 required)',
          ),
          const SizedBox(height: 8),
          _buildFeatureBullet(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Admin Verification & Payouts',
            desc: 'Direct bank account disbursements once approved by an admin',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onJoinPressed,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.black,
              ),
              label: const Text(
                'Join Monetization Program',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Status card displayed when a monetization application has been submitted and is awaiting admin review.
class MonetizationApplicationUnderReviewCard extends StatelessWidget {
  const MonetizationApplicationUnderReviewCard({
    required this.channel,
    super.key,
  });

  final Channel? channel;

  @override
  Widget build(BuildContext context) {
    final app = channel?.monetizationApplication;
    final applicantName = app?['applicantName']?.toString() ??
        app?['legalName']?.toString() ??
        '';
    final bankName = app?['bankName']?.toString() ?? '';
    final maskedAcc = app?['accountNumberMasked']?.toString() ?? '';
    final videoTitle = app?['qualifiedVideoTitle']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.15)),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Application Under Review',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pending Administrator Verification',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'UNDER REVIEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your monetization application has been submitted and is currently being verified by an administrator. Once approved, your channel will be monetized and earnings will become active.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (videoTitle.isNotEmpty || applicantName.isNotEmpty || bankName.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (videoTitle.isNotEmpty)
                    _buildSummaryRow(
                      icon: Icons.video_library_rounded,
                      label: 'Qualified Video',
                      value: videoTitle,
                    ),
                  if (applicantName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Applicant Name',
                      value: applicantName,
                    ),
                  ],
                  if (bankName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Payout Account',
                      value: '$bankName $maskedAcc',
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verification typically completes within 24-48 hours. No further action is required.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
