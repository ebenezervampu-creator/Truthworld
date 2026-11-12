import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Advanced AI dubbing features section: Voice cloning, diarization, and audio preservation.
/// Formatted in ElevenLabs clean, modern dark aesthetic.
class DubbingAdvancedFeaturesSection extends StatelessWidget {
  const DubbingAdvancedFeaturesSection({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262834)),
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
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Voice Cloning / Vocal Identity Tile
          Obx(() {
            final isCloned = controller.voiceType.value == 'cloned';
            final sampleName = controller.voiceSampleName;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCloned
                    ? const Color(0xFF1A1C26)
                    : const Color(0xFF101116),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCloned
                      ? const Color(0xFFA78BFA).withValues(alpha: 0.6)
                      : const Color(0xFF222430),
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
                            color: isCloned ? const Color(0xFFA78BFA) : const Color(0xFFA1A1AA),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Studio Vocal Identity & Voice Cloning',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isCloned,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF7C3AED),
                        onChanged: (val) {
                          controller.voiceType.value = val ? 'cloned' : 'standard';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Replicates your natural vocal pitch, tone, and inflection in all dubbed languages with studio-grade ElevenLabs voice cloning.',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 11.5,
                      height: 1.35,
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
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        if (sampleName != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sample: $sampleName',
                              style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 11),
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

          // 2. Speaker Diarization Tile
          Obx(() {
            final isDiarization = controller.isDiarizationEnabled.value;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDiarization
                    ? const Color(0xFF181A24)
                    : const Color(0xFF101116),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDiarization
                      ? const Color(0xFF60A5FA).withValues(alpha: 0.5)
                      : const Color(0xFF222430),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFFA1A1AA), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speaker Diarization (Multi-Speaker AI)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Identifies distinct speakers in podcasts, interviews, and roundtables, assigning appropriate individual voices.',
                          style: TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDiarization,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      controller.isDiarizationEnabled.value = val;
                    },
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // 3. Audio Track & BGM Preservation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101116),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF222430)),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note_outlined, color: Color(0xFFA1A1AA), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Background Music & Audio Track Preservation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Neural vocal separation preserves background score, sound effects, and Foley while replacing spoken voice tracks.',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3b. Anti-Uncanny Cadence Locking (Built into Audio Track)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16152B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_lock_outlined, color: Color(0xFFA78BFA), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anti-Uncanny Viseme Cadence Locking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Clamps neural voice timing to original mouth closure endpoints to eliminate speech overhang on camera shots.',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
