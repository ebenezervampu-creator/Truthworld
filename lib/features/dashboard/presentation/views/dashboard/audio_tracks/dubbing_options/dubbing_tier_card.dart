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
        ? (tier.isCinemaGrade
            ? AppColors.warning
            : (tier.isLipSync ? AppColors.textLink : Colors.white))
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
                  ? (tier.isCinemaGrade ? AppColors.warning : Colors.white)
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
    if (tier.id == 'audio_starter') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Standard Neural Voice',
          style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      );
    } else if (tier.id == 'audio_ultra' || tier.isVoiceClone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Studio Voice Cloning',
          style: TextStyle(fontSize: 10, color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold),
        ),
      );
    } else if (tier.isCinemaGrade) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Cinema Grade',
          style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold),
        ),
      );
    } else if (tier.isLipSync) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'AI Lip-Sync',
          style: TextStyle(fontSize: 10, color: AppColors.textLink, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Expressive Voice',
        style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _getHighlightSubtitle() {
    if (tier.id == 'audio_starter') return 'Natural neural narration';
    if (tier.id == 'audio_pro') return 'Expressive emotional nuances';
    if (tier.id == 'audio_ultra') return 'Full vocal identity match';
    if (tier.id == 'video_pro') return 'Face & mouth synchronization';
    if (tier.id == 'video_ultra') return 'Cinema theatrical visual sync';
    return 'Studio vocal synthesis';
  }
}
