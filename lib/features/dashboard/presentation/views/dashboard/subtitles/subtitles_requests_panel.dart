import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesRequestsPanel extends StatelessWidget {
  const SubtitlesRequestsPanel({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    super.key,
  });

  final SubtitlesController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_chat_unread_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Viewer Requests',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final reqs = controller.languageRequests
                      .where((r) => r.type == 'subtitle')
                      .toList();
                  if (reqs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reqs.length}',
                      style: AppTextStyles.badge.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: Obx(() {
              final reqs = controller.languageRequests
                  .where((r) => r.type == 'subtitle')
                  .toList();
              if (controller.isLoadingRequests.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                );
              }
              if (reqs.isEmpty) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.translate_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No requests yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reqs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = reqs[index];
                  final matchingLanguage = supportedLanguages.firstWhereOrNull(
                    (l) => l.name.toLowerCase() == r.language.toLowerCase(),
                  );
                  final langCode = matchingLanguage?.code ?? r.language;
                  final isAlreadyAdded = controller.availableLanguages.contains(
                    langCode,
                  );

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    matchingLanguage?.name ?? r.language,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  if (matchingLanguage != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      matchingLanguage.nativeName,
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.count}',
                                    style: AppTextStyles.badge.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: isAlreadyAdded
                              ? OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Provisioned',
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    disabledForegroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: AppColors.bgDivider,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    controller.addLanguageTrack(langCode);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  label: Text(
                                    'Add Track',
                                    style: AppTextStyles.buttonText.copyWith(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
