import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Language dub layers manager styled like the Channel Creation Categories pattern.
/// Uses a clean selector container and modal picker rather than listing all languages directly.
class AudioTracksLanguagesManager extends StatelessWidget {
  const AudioTracksLanguagesManager({
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.onAddLanguage,
    super.key,
  });

  final AudioTracksController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDarkMode;
  final VoidCallback onAddLanguage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Section 1: Configured Language Dub Layers Header
        Row(
          children: [
            const Icon(
              Icons.language_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Configured Language Dub Layers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onAddLanguage,
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.black,
              ),
              label: const Text(
                'Add Language Layer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Channel Creation Category-Style Selector Container
        GestureDetector(
          onTap: () => AudioTracksDialogs.showLanguagePickerBottomSheet(
            context: context,
            controller: controller,
            isDarkMode: isDarkMode,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(
                    () {
                      if (controller.availableLanguages.isEmpty) {
                        return const Text(
                          'Select languages for dubbing',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        );
                      }
                      final names = controller.availableLanguages
                          .map(controller.getLanguageName)
                          .toList();
                      return Text(
                        names.join(', '),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),

        // Selected Language Pills (Matching Channel Creation Category Card)
        Obx(() {
          final langs = controller.availableLanguages;
          if (langs.isEmpty) {
            return const SizedBox.shrink();
          }
          final baseLang = controller.selectedVideo.value?.language ?? 'en';

          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: langs.map((code) {
                final isBase = code.toLowerCase() == baseLang.toLowerCase();
                final name = controller.getLanguageName(code);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.bgElevated),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$name${isBase ? ' (Base)' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isBase) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => controller.removeLanguageLayer(code),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),

        const SizedBox(height: 28),

        // Section 2: Video Dubbing & Neural Lip-Sync Studio (Video Pro & Video Ultra)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_camera_back_rounded,
                      color: AppColors.textLink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Video Dubbing & Neural Lip-Sync Studio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Re-render video tracks with studio visual lip synchronization and vocal identity.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Two Video Tier Option Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final videoProCard = _buildVideoTierOptionCard(
                    context: context,
                    title: 'Video Pro',
                    badge: 'LATENTSYNC 1080P',
                    rateText: r'$4 / 10 min ($0.40/min)',
                    badgeColor: AppColors.info,
                    description:
                        'Synchronized mouth movement re-targeting with CodeFormer face restoration and ElevenLabs voice cloning.',
                    specs: const [
                      'LatentSync GPU Diffusion',
                      'ElevenLabs v4 Voice Cloning',
                      'AssemblyAI + Sarvam AI',
                      '100% Studio BGM Preservation (Discrete Stems)',
                    ],
                    onGenerate: () => AudioTracksDialogs.showAddVideoTrackWithOptionsModal(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    ),
                  );

                  final videoUltraCard = _buildVideoTierOptionCard(
                    context: context,
                    title: 'Video Ultra (Hollywood Cinema)',
                    badge: 'HOLLYWOOD CINEMA',
                    rateText: r'$5 / 10 min ($0.50/min)',
                    badgeColor: AppColors.warning,
                    description:
                        'Theatrical grade for movies, web series & films with Demucs M&E stem isolation & Gemini 4 Argon isometry.',
                    specs: const [
                      'Gemini 4 Argon Theatrical Isometry',
                      'Demucs M&E Stem Isolation',
                      'Poisson Occlusion Blending',
                    ],
                    isUltra: true,
                    onGenerate: () => AudioTracksDialogs.showAddVideoTrackWithOptionsModal(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                      initialTier: 'video_ultra',
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        videoProCard,
                        const SizedBox(height: 12),
                        videoUltraCard,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: videoProCard),
                      const SizedBox(width: 12),
                      Expanded(child: videoUltraCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Section 3: Audio Track Options & Studio Tools
        const Text(
          'Audio Track Options & Studio Tools',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Action Card A: Upload Audio Track from File
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Upload Audio Track from file',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => AudioTracksDialogs.showUploadTrackDialog(
                  context: context,
                  controller: controller,
                  isDarkMode: isDarkMode,
                ),
                icon: const Icon(
                  Icons.upload_rounded,
                  size: 14,
                  color: Colors.black,
                ),
                label: const Text(
                  'Upload',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action Card B: Add Commentary
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Add Commentary Track',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => AudioTracksDialogs.showAddCommentaryDialog(
                  context: context,
                  controller: controller,
                  isDarkMode: isDarkMode,
                ),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: Colors.black,
                ),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildVideoTierOptionCard({
    required BuildContext context,
    required String title,
    required String badge,
    required String rateText,
    required Color badgeColor,
    required String description,
    required List<String> specs,
    required VoidCallback onGenerate,
    bool isUltra = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUltra
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.bgSurface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isUltra ? AppColors.warning : AppColors.textLink,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  rateText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: specs.map((spec) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  spec,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: Colors.black,
              ),
              label: Text(
                'Generate $title',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Community dubbing requests grid displaying viewer language demands.
class AudioTracksRequestsGrid extends StatelessWidget {
  const AudioTracksRequestsGrid({
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.onUploadDubForRequest,
    super.key,
  });

  final AudioTracksController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final void Function(String langCode) onUploadDubForRequest;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reqs = controller.languageRequests
          .where((r) => r.type == 'audio')
          .toList();
      if (reqs.isEmpty) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.appBarSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Text(
              'No pending dubbing requests from viewers.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const Text(
            'Viewer Audio Dubbing Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...reqs.map((req) {
            final langName = controller.getLanguageName(req.language);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.appBarSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgSurface),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.bgSurface),
                    ),
                    child: const Icon(
                      Icons.mark_chat_unread_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requested by ${req.count} viewers',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => onUploadDubForRequest(req.language),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'Add Dub',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }
}
