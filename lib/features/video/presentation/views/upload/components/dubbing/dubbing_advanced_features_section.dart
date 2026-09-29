import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Advanced AI dubbing features section: Voice cloning, diarization, and audio preservation.
class DubbingAdvancedFeaturesSection extends StatelessWidget {
  const DubbingAdvancedFeaturesSection({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Studio Dubbing Features & Options',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Voice Cloning / Vocal Identity Tile
          Obx(() {
            final isCloned = controller.voiceType.value == 'cloned';
            final sampleName = controller.voiceSampleName;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCloned
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCloned
                      ? const Color(0xFF8B5CF6)
                      : Colors.white10,
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
                          Icon(
                            Icons.record_voice_over,
                            color: isCloned ? const Color(0xFFA78BFA) : Colors.white60,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Studio Vocal Identity & Voice Cloning',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isCloned,
                        activeColor: Colors.white,
                        onChanged: (val) {
                          controller.voiceType.value = val ? 'cloned' : 'standard';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.isCustomChannel
                        ? '✓ Custom Channel Partner: Studio voice cloning included at zero extra cost. Replicates your vocal pitch, tone, and inflection in all dubbed languages.'
                        : 'Standard channels utilize high-fidelity neural voices. Upgrade to Custom Channel for full voice cloning & studio identity.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  if (isCloned) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: controller.pickVoiceSample,
                          icon: const Icon(Icons.mic, size: 14, color: Colors.black),
                          label: const Text(
                            'Select Voice Sample',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                        if (sampleName != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sample: $sampleName',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 10),

          // Speaker Diarization Tile
          Obx(() {
            final isDiarization = controller.isDiarizationEnabled.value;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Speaker Diarization (Multi-Speaker AI)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Identifies distinct speakers in podcasts, interviews, and roundtables, assigning appropriate individual voices.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDiarization,
                    activeColor: Colors.white,
                    onChanged: (val) => controller.isDiarizationEnabled.value = val,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),

          // Background Audio & Music Preservation Tile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Background Music & Audio Track Preservation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Neural vocal separation preserves background score, sound effects, and Foley while replacing spoken voice tracks.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
