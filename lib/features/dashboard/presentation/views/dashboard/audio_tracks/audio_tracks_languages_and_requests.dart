import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Language dub layers manager for exploring catalog and configuring available language streams.
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
        // Header
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
                  fontFamily: TWTypography.brandFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
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
                'Add Language',
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
        const SizedBox(height: 4),
        const Text(
          'Manage available language audio streams for viewer track switching.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Configured Language Pills
        Obx(() {
          final langs = controller.availableLanguages;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: langs.map((code) {
              final name = controller.getLanguageName(code);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }),

        const SizedBox(height: 28),
        const Text(
          'Supported Language Catalog (Click to add Dub Track)',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.supportedLanguages.map((lang) {
            final isConfigured =
                controller.availableLanguages.contains(lang.code);
            return InkWell(
              onTap: () {
                if (!isConfigured) {
                  controller.addLanguageLayer(lang.code);
                } else {
                  controller.switchLanguageTrack(lang.code);
                  controller.setActiveTab('tracks');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? const Color(0xFF27272A)
                      : const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isConfigured
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConfigured
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isConfigured ? FontWeight.bold : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
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
              fontFamily: TWTypography.brandFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
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
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF27272A)),
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
