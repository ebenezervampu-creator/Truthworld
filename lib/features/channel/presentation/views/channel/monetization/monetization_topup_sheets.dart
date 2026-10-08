import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shows modal bottom sheet for purchasing video storage top-up packs.
void showStorageTopupSheet(
  BuildContext context,
  ChannelMonetizationController controller,
) {
  final typography = context.twTypography;
  final spendable = controller.spendableBalance;
  final channel = controller.channel;

  Get.bottomSheet(
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
                    Icon(Icons.storage_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Buy Extra Storage with Balance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: Get.back,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Available Spendable Balance: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.totalRevenue.toStringAsFixed(2)} Revenue)',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...ChannelWalletService.storagePacks.map((pack) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.bgSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pack.title,
                                style: typography.title.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (pack.badge.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    pack.badge,
                                    style: typography.caption.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${pack.gigabytes} GB permanent add-on video storage',
                            style: typography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        final auth = AuthService.to;
                        final uid = auth.uid.isNotEmpty ? auth.uid : channel.ownerId;
                        final canAfford = spendable.canAfford(pack.priceUSD);
                        final ok = canAfford
                            ? await controller.walletService.spendForStorageTopup(
                                channel: channel,
                                userId: uid,
                                pack: pack,
                              )
                            : await controller.walletService.buyStoragePackWithCashfree(
                                channel: channel,
                                pack: pack,
                              );
                        if (ok) {
                          final cur = channel.infraConfig?.storageQuotaBytes ?? 53687091200;
                          final updated = CustomChannelInfraConfig(
                            stripeConnectAccountId:
                                channel.infraConfig?.stripeConnectAccountId ?? '',
                            subscriptionId:
                                channel.infraConfig?.subscriptionId ?? '',
                            storageQuotaBytes: cur + pack.bytes,
                            storageUsedBytes: channel.infraConfig?.storageUsedBytes ?? 0,
                            bandwidthQuotaBytesThisMonth:
                                channel.infraConfig?.bandwidthQuotaBytesThisMonth ??
                                    214748364800,
                            bandwidthUsedBytesThisMonth:
                                channel.infraConfig?.bandwidthUsedBytesThisMonth ?? 0,
                            planTier: channel.infraConfig?.planTier ?? 'starter_15',
                          );
                          controller.channelRx.value = Channel(
                            id: channel.id,
                            name: channel.name,
                            nameLowercase: channel.nameLowercase,
                            handle: channel.handle,
                            handleLowercase: channel.handleLowercase,
                            description: channel.description,
                            avatarUrl: channel.avatarUrl,
                            bannerUrl: channel.bannerUrl,
                            ownerId: channel.ownerId,
                            createdAt: channel.createdAt,
                            updatedAt: Timestamp.now(),
                            subscriberCount: channel.subscriberCount,
                            videoCount: channel.videoCount,
                            metrics: channel.metrics,
                            status: channel.status,
                            isVerified: channel.isVerified,
                            category: channel.category,
                            categories: channel.categories,
                            language: channel.language,
                            monetizationTier: channel.monetizationTier,
                            channelType: channel.channelType,
                            infraConfig: updated,
                          );
                          AppSnackbar.success(
                            'Added +${pack.gigabytes} GB storage to your channel.',
                            title: 'Storage Added!',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: spendable.canAfford(pack.priceUSD)
                            ? AppColors.bgSurface
                            : AppColors.bgElevated,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        spendable.canAfford(pack.priceUSD)
                            ? '\$${pack.priceUSD.toStringAsFixed(0)} Balance'
                            : '\$${pack.priceUSD.toStringAsFixed(0)} (Pay)',
                        style: typography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

/// Shows modal bottom sheet for purchasing streaming CDN bandwidth top-up packs.
void showBandwidthTopupSheet(
  BuildContext context,
  ChannelMonetizationController controller,
) {
  final typography = context.twTypography;
  final spendable = controller.spendableBalance;
  final channel = controller.channel;

  Get.bottomSheet(
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
                    Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Buy Extra Bandwidth with Balance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: Get.back,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Available Spendable Balance: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.totalRevenue.toStringAsFixed(2)} Revenue)',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...ChannelWalletService.bandwidthPacks.map((pack) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.bgSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cell_tower_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pack.title,
                                style: typography.title.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (pack.badge.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    pack.badge,
                                    style: typography.caption.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${pack.gigabytes} GB streaming bandwidth valid this month',
                            style: typography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        final auth = AuthService.to;
                        final uid = auth.uid.isNotEmpty ? auth.uid : channel.ownerId;
                        final canAfford = spendable.canAfford(pack.priceUSD);
                        final ok = canAfford
                            ? await controller.walletService.spendForBandwidthTopup(
                                channel: channel,
                                userId: uid,
                                pack: pack,
                              )
                            : await controller.walletService.buyBandwidthPackWithCashfree(
                                channel: channel,
                                pack: pack,
                              );
                        if (ok) {
                          final cur =
                              channel.infraConfig?.bandwidthQuotaBytesThisMonth ?? 214748364800;
                          final updated = CustomChannelInfraConfig(
                            stripeConnectAccountId:
                                channel.infraConfig?.stripeConnectAccountId ?? '',
                            subscriptionId:
                                channel.infraConfig?.subscriptionId ?? '',
                            storageQuotaBytes:
                                channel.infraConfig?.storageQuotaBytes ?? 53687091200,
                            storageUsedBytes: channel.infraConfig?.storageUsedBytes ?? 0,
                            bandwidthQuotaBytesThisMonth: cur + pack.bytes,
                            bandwidthUsedBytesThisMonth:
                                channel.infraConfig?.bandwidthUsedBytesThisMonth ?? 0,
                            planTier: channel.infraConfig?.planTier ?? 'starter_15',
                          );
                          controller.channelRx.value = Channel(
                            id: channel.id,
                            name: channel.name,
                            nameLowercase: channel.nameLowercase,
                            handle: channel.handle,
                            handleLowercase: channel.handleLowercase,
                            description: channel.description,
                            avatarUrl: channel.avatarUrl,
                            bannerUrl: channel.bannerUrl,
                            ownerId: channel.ownerId,
                            createdAt: channel.createdAt,
                            updatedAt: Timestamp.now(),
                            subscriberCount: channel.subscriberCount,
                            videoCount: channel.videoCount,
                            metrics: channel.metrics,
                            status: channel.status,
                            isVerified: channel.isVerified,
                            category: channel.category,
                            categories: channel.categories,
                            language: channel.language,
                            monetizationTier: channel.monetizationTier,
                            channelType: channel.channelType,
                            infraConfig: updated,
                          );
                          AppSnackbar.success(
                            'Added +${pack.gigabytes} GB streaming bandwidth to your channel.',
                            title: 'Bandwidth Added!',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: spendable.canAfford(pack.priceUSD)
                            ? AppColors.bgSurface
                            : AppColors.bgElevated,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        spendable.canAfford(pack.priceUSD)
                            ? '\$${pack.priceUSD.toStringAsFixed(0)} Balance'
                            : '\$${pack.priceUSD.toStringAsFixed(0)} (Pay)',
                        style: typography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}
