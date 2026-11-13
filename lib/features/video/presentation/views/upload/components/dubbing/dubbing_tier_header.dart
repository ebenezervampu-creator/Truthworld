import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';
import 'package:truthworld/features/video/data/models/video/video_duration_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Header displaying video duration context and the 5-Tier Production Dubbing Selector.
/// Designed with ElevenLabs modern, minimalist dark aesthetic.
class DubbingTierHeader extends StatelessWidget {
  const DubbingTierHeader({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Duration & Channel Summary Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14151B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262834)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.translate,
                      color: Color(0xFFA78BFA),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.durationSeconds > 0
                              ? 'Video Duration: ${VideoDurationUtils.formatDurationSeconds(controller.durationSeconds)}'
                              : 'Standard Video Length',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Duration Tier: ${controller.dubbingTier.name} (${controller.dubbingTier.durationLabel})',
                          style: const TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: controller.isCustomChannel
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF222430),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: controller.isCustomChannel
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF333646),
                      ),
                    ),
                    child: Text(
                      controller.isCustomChannel ? 'CUSTOM' : 'STANDARD',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF101116),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.audiotrack,
                      size: 14,
                      color: Color(0xFFA78BFA),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Channel Source Language: ${controller.channelLanguageDisplayName} (Original track preserved)',
                        style: const TextStyle(
                          color: Color(0xFFD4D4D8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. Dubbing Production Tier Selector Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.layers_outlined, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Dubbing Plan: Audio Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Obx(() {
              final activeTierId = controller.selectedDubbingTier.value;
              final tier = DubbingProductionTier.allTiers.firstWhere(
                (t) => t.id == activeTierId,
                orElse: () => DubbingProductionTier.audioTrack,
              );
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFA78BFA),
                  ),
                ),
                child: Text(
                  tier.badge,
                  style: const TextStyle(
                    color: Color(0xFFC4B5FD),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Studio vocal identity, precision translation context, voice synthesis, and 100% background music preservation.',
          style: TextStyle(
            color: Color(0xFFA1A1AA),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),

        // Tier cards list (ElevenLabs clean radio cards)
        Obx(() {
          final activeTierId = controller.selectedDubbingTier.value;
          return Column(
            children: DubbingProductionTier.allTiers.map((tier) {
              final isSelected = activeTierId == tier.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => controller.selectTier(tier.id),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF181A24)
                          : const Color(0xFF13141B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF262834),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFFA78BFA)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFA78BFA)
                                          : const Color(0xFF52525B),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  tier.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262834),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'AUDIO DUB',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '\$${tier.tenMinutePriceUSD.toStringAsFixed(0)} / 10m',
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFA78BFA)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tier.description,
                                style: const TextStyle(
                                  color: Color(0xFFA1A1AA),
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mic_none,
                                    size: 12,
                                    color: Color(0xFF71717A),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'ASR: ${tier.asrProvider}',
                                      style: const TextStyle(
                                        color: Color(0xFF8E90A2),
                                        fontSize: 10.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.record_voice_over_outlined,
                                    size: 12,
                                    color: Color(0xFF71717A),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'TTS: ${tier.ttsEngine}',
                                      style: const TextStyle(
                                        color: Color(0xFF8E90A2),
                                        fontSize: 10.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.sync_lock,
                                    size: 12,
                                    color: Color(0xFFA78BFA),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Cadence: ${tier.visualSync}',
                                      style: const TextStyle(
                                        color: Color(0xFFA78BFA),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF261D45),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.verified_outlined,
                                        color: Color(0xFFA78BFA),
                                        size: 13,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Anti-Uncanny Protection: Speech is strictly clamped to mouth closure points so your voice never lingers awkwardly when lips stop moving.',
                                          style: TextStyle(
                                            color: Color(0xFFDDD6FE),
                                            fontSize: 10.5,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}
