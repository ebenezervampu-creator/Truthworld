import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_add_money_dialog.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/create_campaign_wizard_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card widget displaying a single campaign with analytics, status toggles, and fund top-up.
class AdvertiserCampaignCard extends StatelessWidget {
  final AdvertiserPortalController controller;
  final AdItem campaign;

  const AdvertiserCampaignCard({
    required this.controller,
    required this.campaign,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isSkippable = campaign.isSkippableAd;
    final budgetStr = campaign.budgetTier ?? 'Starter';
    final totalBudget = campaign.totalBudget;
    final spent = campaign.spent;
    final remaining = campaign.remaining;
    final progress = campaign.budgetProgress;
    final isBudgetExhausted = remaining <= 0;
    final amountStr =
        '₹${totalBudget.toStringAsFixed(totalBudget == totalBudget.roundToDouble() ? 0 : 2)}';
    final isPaused = campaign.status == 'paused';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: campaign.gradientColors),
                  ),
                  child: Center(
                    child: Icon(
                      campaign.adType == 'video_sponsor'
                          ? Icons.stars_rounded
                          : isSkippable
                          ? Icons.play_circle_filled_rounded
                          : Icons.ad_units_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            campaign.advertiser,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.bgSurface),
                          ),
                          child: Text(
                            campaign.adType == 'video_sponsor'
                                ? 'Sponsor Ad'
                                : isSkippable
                                ? 'Video Ad'
                                : 'Feed Ad',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      campaign.title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign.description,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amountStr,
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        child: Text(
                          budgetStr,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Spent: ₹${spent.toStringAsFixed(spent == spent.roundToDouble() ? 0 : 2)}',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Rem: ₹${remaining.toStringAsFixed(remaining == remaining.roundToDouble() ? 0 : 2)}',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: isBudgetExhausted
                              ? AppColors.error
                              : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isBudgetExhausted
                              ? AppColors.error
                              : campaign.status == 'paused'
                              ? AppColors.textSecondary
                              : campaign.status == 'underReview'
                              ? AppColors.warning
                              : campaign.status == 'verification_rejected'
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBudgetExhausted
                            ? 'Exhausted'
                            : campaign.status == 'paused'
                            ? 'Paused'
                            : campaign.status == 'underReview'
                            ? 'Under Review'
                            : campaign.status == 'verification_rejected'
                            ? 'Rejected'
                            : 'Active',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isBudgetExhausted
                              ? AppColors.error
                              : campaign.status == 'paused'
                              ? AppColors.textSecondary
                              : campaign.status == 'underReview'
                              ? AppColors.warning
                              : campaign.status == 'verification_rejected'
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (campaign.status == 'verification_rejected' &&
                      campaign.moderationReason != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Get.defaultDialog(
                          title: 'Moderation Details',
                          titleStyle: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          middleText: campaign.moderationReason!,
                          middleTextStyle: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                          ),
                          backgroundColor: AppColors.appBarSurface,
                          textConfirm: 'OK',
                          confirmTextColor: Colors.black,
                          buttonColor: Colors.white,
                          onConfirm: Get.back,
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Why?',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.error,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ad_reports')
                        .where('adId', isEqualTo: campaign.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final reports = snapshot.data?.docs ?? [];
                      if (reports.isEmpty) return const SizedBox.shrink();
                      final firstReport = reports.first.data();
                      final reason =
                          firstReport['reason'] ?? 'User Feedback Received';

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.report_problem_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${reports.length} User Report(s): "$reason"',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => AdvertiserAddMoneyDialog.show(context, controller: controller, campaign: campaign),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.bgSurface),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Add Money',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => AdService.to.toggleCampaignStatus(campaign.id),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.bgSurface),
                          ),
                          child: Icon(
                            (campaign.status == 'underReview' ||
                                    campaign.status == 'verification_rejected')
                                ? Icons.lock_outline
                                : isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => showCreateCampaignWizard(
                          context,
                          controller,
                          existingCampaign: campaign,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.bgSurface),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Get.defaultDialog(
                            title: 'Delete Campaign',
                            titleStyle: const TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            middleText:
                                'Are you sure you want to delete "${campaign.title}"?',
                            middleTextStyle: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                            ),
                            backgroundColor: AppColors.appBarSurface,
                            textConfirm: 'Delete',
                            textCancel: 'Cancel',
                            confirmTextColor: Colors.white,
                            cancelTextColor: AppColors.textSecondary,
                            buttonColor: AppColors.error,
                            onConfirm: () {
                              AdService.to.deleteCampaign(campaign.id);
                              Get.back();
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.bgSurface),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Campaign Budget & Spending',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% spent',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.bgSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBudgetExhausted
                          ? AppColors.error
                          : AppColors.success,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialMetric(
                        label: 'Total Paid',
                        value:
                            '₹${totalBudget.toStringAsFixed(totalBudget == totalBudget.roundToDouble() ? 0 : 2)}',
                        valueColor: Colors.white,
                      ),
                    ),
                    Container(width: 1, height: 24, color: AppColors.bgSurface),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _buildFinancialMetric(
                          label: 'Spent',
                          value: '₹${spent.toStringAsFixed(2)}',
                          valueColor: AppColors.warning,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 24, color: AppColors.bgSurface),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _buildFinancialMetric(
                          label: 'Remaining',
                          value: '₹${remaining.toStringAsFixed(2)}',
                          valueColor: isBudgetExhausted
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          AdvertiserAddMoneyDialog.show(context, controller: controller, campaign: campaign),
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: const Text(
                        'Add Money',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.bgElevated),
                        backgroundColor: AppColors.bgSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isBudgetExhausted) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Budget exhausted! Add more money to keep this campaign active and reaching viewers.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        AdvertiserAddMoneyDialog.show(context, controller: controller, campaign: campaign),
                    child: const Text(
                      'Add Funds',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (campaign.status == 'verification_rejected') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Rejection Error: ',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: campaign.moderationReason ??
                                'Violation of Community Guidelines',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildFinancialMetric({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

}
