import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet allowing creators to spend earned balance on AI features & infra top-ups.
class SpendRevenueBottomSheet {
  SpendRevenueBottomSheet._();

  static void show(
    BuildContext context,
    DashboardController controller, [
    Video? targetVideo,
  ]) {
    final walletService = ChannelWalletService();
    final ch = controller.currentChannel.value ??
        Channel(
          id: controller.channelId,
          name: 'My Channel',
          nameLowercase: 'my channel',
          handle: '@channel',
          handleLowercase: '@channel',
          description: '',
          avatarUrl: '',
          bannerUrl: '',
          ownerId: controller.channelId,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );

    final totalRev = controller.rxTotalRevenue.value;
    final isCustom = ch.channelType == ChannelType.custom;
    final tipsAndMembers = controller.rxMembershipsRevenue.value +
        controller.rxSuperchatRevenue.value;
    final adAndWatchRev = controller.rxAdsRevenue.value +
        controller.rxWatchTimeRevenue.value;

    final totalWatchHours = controller.recentVideos.fold<double>(
      0.0,
      (acc, v) => acc + controller.getVideoWatchHours(v),
    );
    final eligibleWatchHours = controller.recentVideos
        .where(controller.isVideoWithdrawalEligible)
        .fold<double>(
          0.0,
          (acc, v) => acc + controller.getVideoWatchHours(v),
        );
    final watchRatio = totalWatchHours > 0
        ? (eligibleWatchHours / totalWatchHours).clamp(0.0, 1.0)
        : (controller.recentVideos.any(controller.isVideoWithdrawalEligible)
            ? 1.0
            : 0.0);

    final withdrawable = isCustom
        ? (tipsAndMembers + adAndWatchRev)
        : (tipsAndMembers + (adAndWatchRev * 0.70 * watchRatio));
    final locked = (totalRev - withdrawable).clamp(0.0, double.infinity);

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;
    final totalRevUsd = totalRev > 0 ? (totalRev / rate) : 0.0;
    final withdrawableUsd = withdrawable > 0 ? (withdrawable / rate) : 0.0;
    final lockedUsd = locked > 0 ? (locked / rate) : 0.0;

    final spendable = walletService.getSpendableBalance(
      channel: ch,
      rawTotalRevenue: totalRevUsd,
      withdrawableRevenue: withdrawableUsd,
      lockedRevenue: lockedUsd,
    );

    final effectiveVideo = targetVideo ??
        (controller.recentVideos.isNotEmpty
            ? controller.recentVideos.first
            : null);
    final dubbingDurationSec = effectiveVideo?.durationValue.inSeconds ?? 0;
    final flatRatePerLang = ChannelWalletService.getFlatDubbingPricePerLanguage(
      durationSeconds: dubbingDurationSec,
      channelType: ch.channelType,
    );
    final dubbingTier =
        ChannelWalletService.getDubbingDurationTier(dubbingDurationSec);
    final totalDubbingCost = ChannelWalletService.calculateDubbingCost(
      languageCount: 3,
      durationSeconds: dubbingDurationSec,
      channelType: ch.channelType,
    );

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Spend Revenue & Balances',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                spendable.trialCreditRemaining > 0
                    ? 'Available Spendable: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.fundedBalance.toStringAsFixed(2)} Wallet + \$${spendable.trialCreditRemaining.toStringAsFixed(2)} Promotional Credit + \$${spendable.totalRevenue.toStringAsFixed(2)} Revenue)'
                    : 'Available Spendable: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.fundedBalance.toStringAsFixed(2)} Wallet + \$${spendable.totalRevenue.toStringAsFixed(2)} Revenue)',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Funded Wallet: \$${ch.walletBalanceUSD.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        ChannelWalletTopupSheet.show(
                          context,
                          channel: ch,
                          onTopupSuccess: controller.refreshChannelData,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.black, size: 16),
                      label: const Text(
                        'Add Money',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Section 1: AI Content Intelligence & Localization
              const Text(
                'AI Video Features',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              AiFeatureOptionTile(
                icon: Icons.fact_check_rounded,
                title: 'Fact-Checking & Credibility Report',
                description:
                    'AI claim verification, source citation & Truth Score badge.',
                costText: r'$2.00 • Instant from balance',
                onSelect: () async {
                  if (effectiveVideo == null) {
                    AppSnackbar.info(
                      'Please upload a video to your channel before applying AI features.',
                    );
                    return;
                  }
                  Get.back<void>();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = effectiveVideo.id;
                  final videoTitle = effectiveVideo.title.isNotEmpty
                      ? effectiveVideo.title
                      : 'Video #$videoId';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'factcheck'},
                    targetLanguages: ['en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for Fact-Checking & Credibility verification on "$videoTitle"!',
                  );
                },
              ),
              const SizedBox(height: 10),

              AiFeatureOptionTile(
                icon: Icons.subtitles_rounded,
                title: 'AI Subtitles & Closed Captions',
                description:
                    'Generate automatic synchronized closed-captions and subtitles.',
                costText: r'$0.50 • Instant from balance',
                onSelect: () async {
                  if (effectiveVideo == null) {
                    AppSnackbar.info(
                      'Please upload a video to your channel before applying AI features.',
                    );
                    return;
                  }
                  Get.back<void>();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = effectiveVideo.id;
                  final videoTitle = effectiveVideo.title.isNotEmpty
                      ? effectiveVideo.title
                      : 'Video #$videoId';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'subtitles'},
                    targetLanguages: ['te', 'hi', 'en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for AI Subtitles on "$videoTitle"!',
                  );
                },
              ),
              const SizedBox(height: 10),

              AiFeatureOptionTile(
                icon: Icons.translate_rounded,
                title:
                    'AI Multilingual Dubbing (Flat \$${flatRatePerLang.toStringAsFixed(2)}/lang • ${dubbingTier.label})',
                description: isCustom
                    ? 'Dubbing is NOT free: Flat rate for ${dubbingDurationSec > 0 ? VideoDurationUtils.formatDurationSeconds(dubbingDurationSec) : "detected duration"}. Includes Studio Vocal Identity & Voice Cloning.'
                    : 'Dubbing is NOT free: Predictable flat pricing for ${dubbingDurationSec > 0 ? VideoDurationUtils.formatDurationSeconds(dubbingDurationSec) : "detected duration"} across 3 target languages.',
                costText:
                    '\$${totalDubbingCost.toStringAsFixed(2)} (3 langs • \$${flatRatePerLang.toStringAsFixed(2)}/lang)',
                onSelect: () async {
                  if (effectiveVideo == null) {
                    AppSnackbar.info(
                      'Please upload a video to your channel before applying AI features.',
                    );
                    return;
                  }
                  Get.back<void>();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = effectiveVideo.id;
                  final videoTitle = effectiveVideo.title.isNotEmpty
                      ? effectiveVideo.title
                      : 'Video #$videoId';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'dubbing'},
                    targetLanguages: ['te', 'hi', 'en'],
                    durationSeconds: dubbingDurationSec,
                  );

                  AppSnackbar.success(
                    'Channel balance applied for AI Multilingual Dubbing on "$videoTitle"!',
                  );
                },
              ),
              const SizedBox(height: 10),

              AiFeatureOptionTile(
                icon: Icons.video_library_rounded,
                title: 'AI Chapters & Key Takeaways',
                description:
                    'Auto-generate smart video chapters, tags, and summary.',
                costText: r'$0.50 • Instant from balance',
                onSelect: () async {
                  if (effectiveVideo == null) {
                    AppSnackbar.info(
                      'Please upload a video to your channel before applying AI features.',
                    );
                    return;
                  }
                  Get.back<void>();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = effectiveVideo.id;
                  final videoTitle = effectiveVideo.title.isNotEmpty
                      ? effectiveVideo.title
                      : 'Video #$videoId';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'summary', 'chapters'},
                    targetLanguages: ['en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for AI Chapters & Summary!',
                  );
                },
              ),

              const SizedBox(height: 20),

              // Section 2: Custom Channel Infrastructure & Top-Ups
              const Text(
                'Custom Channel Hosting & Quotas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              AiFeatureOptionTile(
                icon: Icons.cloud_upload_rounded,
                title: '+50 GB Storage Top-Up',
                description:
                    'Expand permanent storage for unlimited high-definition uploads.',
                costText: r'$5.00 • Instant from balance',
                onSelect: () async {
                  Get.back<void>();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final pack = ChannelWalletService.storagePacks[1]; // 50GB
                  await walletService.spendForStorageTopup(
                    channel: ch,
                    userId: uid,
                    pack: pack,
                  );

                  AppSnackbar.success(
                    '+50 GB storage added to your channel from balance!',
                  );
                },
              ),
              const SizedBox(height: 10),

              AiFeatureOptionTile(
                icon: Icons.speed_rounded,
                title: '+250 GB Bandwidth Top-Up',
                description:
                    'High-capacity streaming CDN bandwidth for trending traffic.',
                costText: r'$7.00 • Instant from balance',
                onSelect: () async {
                  Get.back<void>();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final pack = ChannelWalletService.bandwidthPacks[1]; // 250GB
                  await walletService.spendForBandwidthTopup(
                    channel: ch,
                    userId: uid,
                    pack: pack,
                  );

                  AppSnackbar.success(
                    '+250 GB streaming bandwidth added to your channel from balance!',
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Option tile representing single AI feature or quota upgrade.
class AiFeatureOptionTile extends StatelessWidget {
  const AiFeatureOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.costText,
    required this.onSelect,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String costText;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgInput,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              costText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.white,
        ),
        onTap: onSelect,
      ),
    );
  }
}
