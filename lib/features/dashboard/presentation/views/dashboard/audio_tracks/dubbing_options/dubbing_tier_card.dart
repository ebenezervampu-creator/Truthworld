import 'package:flutter/material.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Ultra-clean, premium ElevenLabs-style Dubbing Production Tier Card.
/// Strips all verbose descriptions and model dumps, keeping only essential highlights.
class DubbingTierCard extends StatelessWidget {
  const DubbingTierCard({
    required this.tier,
    required this.isSelected,
    required this.durationSeconds,
    required this.channel,
    required this.onSelect,
    super.key,
  });

  final DubbingProductionTier tier;
  final bool isSelected;
  final int durationSeconds;
  final Channel? channel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cost = ChannelWalletService.calculateProductionTierCost(
      tierId: tier.id,
      languageCount: 1,
      durationSeconds: durationSeconds,
      channel: channel,
    );
    final isFree = channel?.isDubbingFree ?? false;
    final priceLabel = isFree || cost == 0.0
        ? '${tier.tenMinuteRateFormatted} • FREE'
        : '\$${cost.toStringAsFixed(2)} flat';

    final borderColor = isSelected
        ? const Color(0xFFA78BFA)
        : AppColors.bgSurface;

    final bgTint = isSelected
        ? const Color(0xFF1A1A1E)
        : AppColors.bgPage;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          children: [
            // Radio selector
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected
                  ? const Color(0xFFA78BFA)
                  : Colors.white30,
            ),
            const SizedBox(width: 12),

            // Tier Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        tier.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      _buildTierPill(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _getHighlightSubtitle(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Pricing Tag
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  priceLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isFree ? AppColors.success : Colors.white,
                  ),
                ),
                if (!isFree && cost > 0.0)
                  Text(
                    tier.tenMinuteRateFormatted,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Studio Voice Cloning & Cadence Lock',
        style: TextStyle(fontSize: 10, color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getHighlightSubtitle() {
    return 'Full vocal identity match, cadence locking & 100% BGM preserved';
  }
}
