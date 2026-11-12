import 'package:flutter/material.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Meter bar displaying resource consumption against allocated quota.
class ChannelMeterBar extends StatelessWidget {
  final String title;
  final String valueText;
  final double progress;

  const ChannelMeterBar({
    required this.title,
    required this.valueText,
    required this.progress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.twTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: typography.bodySmall.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueText,
              style: typography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgSurfaceHigh,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

/// Infrastructure metering section displaying storage and CDN bandwidth usage with top-up options.
class ChannelInfrastructureSection extends StatelessWidget {
  final ChannelMonetizationController controller;
  final double infraCost;
  final VoidCallback onStorageTopup;
  final VoidCallback onBandwidthTopup;

  const ChannelInfrastructureSection({
    required this.controller,
    required this.infraCost,
    required this.onStorageTopup,
    required this.onBandwidthTopup,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final channel = controller.channel;
    final typography = context.twTypography;
    final storageGB = controller.storageUsedBytes / (1024 * 1024 * 1024);
    final bandwidthGB = controller.bandwidthUsedBytes / (1024 * 1024 * 1024);
    final storageQuotaGB =
        (channel.infraConfig?.storageQuotaBytes ?? 53687091200) /
            (1024 * 1024 * 1024);
    final bandwidthQuotaGB =
        (channel.infraConfig?.bandwidthQuotaBytesThisMonth ?? 214748364800) /
            (1024 * 1024 * 1024);

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
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_queue, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Infrastructure Metering',
                        style: typography.headline.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onStorageTopup,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: const Text(
                        '+ Storage',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.bgDivider),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onBandwidthTopup,
                      icon: const Icon(
                        Icons.speed_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: const Text(
                        '+ Bandwidth',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.bgDivider),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Storage Meter
          ChannelMeterBar(
            title: 'Video Storage',
            valueText:
                '${storageGB.toStringAsFixed(1)} GB / ${storageQuotaGB.toStringAsFixed(0)} GB',
            progress: (storageGB / storageQuotaGB).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 12),

          // Bandwidth Meter
          ChannelMeterBar(
            title: 'CDN Streaming Bandwidth',
            valueText:
                '${bandwidthGB.toStringAsFixed(1)} GB / ${bandwidthQuotaGB.toStringAsFixed(0)} GB',
            progress: (bandwidthGB / bandwidthQuotaGB).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Estimated Cloud Cost:',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${infraCost.toStringAsFixed(2)} / mo',
                style: typography.title.copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
