import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

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
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Configured Language Dub Layers',
              style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onAddLanguage,
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
              label: const Text('Add Language Layer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage available language streams for viewer audio track switching.',
          style: TextStyle(fontSize: 13, color: textSecondaryColor),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final langs = controller.availableLanguages;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: langs.map((code) {
              final name = controller.getLanguageName(code);
              return Chip(
                avatar: const Icon(Icons.language_rounded, size: 16, color: Colors.white),
                label: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                backgroundColor: surfaceColor,
                side: BorderSide(color: borderColor),
              );
            }).toList(),
          );
        }),

        const SizedBox(height: 28),
        Text(
          'Supported Language Catalog (Click to add Dub Track)',
          style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.supportedLanguages.map((lang) {
            final isConfigured = controller.availableLanguages.contains(lang.code);
            return ActionChip(
              avatar: Icon(
                isConfigured ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(lang.name),
              backgroundColor: isConfigured
                  ? AppColors.brand.withValues(alpha: 0.15)
                  : (isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9)),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isConfigured ? FontWeight.bold : FontWeight.normal,
                color: isConfigured ? AppColors.textPrimary : textColor,
              ),
              onPressed: () {
                if (!isConfigured) {
                  controller.addLanguageLayer(lang.code);
                } else {
                  controller.switchLanguageTrack(lang.code);
                  controller.setActiveTab('tracks');
                }
              },
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
      final reqs = controller.languageRequests.where((r) => r.type == 'audio').toList();
      if (reqs.isEmpty) {
        return Center(
          child: Text(
            'No pending dubbing requests from viewers.',
            style: TextStyle(fontSize: 14, color: textSecondaryColor),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Viewer Audio Dubbing Requests (${reqs.length})',
            style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          ...reqs.map((req) {
            final langName = controller.getLanguageName(req.language);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_chat_unread_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Language: $langName',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          'Requested by ${req.count} viewers',
                          style: TextStyle(fontSize: 12, color: textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => onUploadDubForRequest(req.language),
                    icon: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
                    label: const Text('Add Dub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
