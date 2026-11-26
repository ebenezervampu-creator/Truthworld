import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_language_card.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Modal bottom sheet for viewing and selecting from the 32 Source Languages provided.
///
/// Built with TruthWorld Dark Theme (`AppColors`, `TWTypography`) and strict
/// Zero `setState` Policy (GetX reactive state).
class DubbingSourceLanguageSheet extends StatelessWidget {
  DubbingSourceLanguageSheet({super.key});

  final RxString query = ''.obs;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DubbingStudioController>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source Language (From)',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'English available now · 31 more available soon',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            onChanged: (val) => query.value = val.trim(),
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search languages…',
              hintStyle: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.bgInput,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 32 Languages Grid
          Expanded(
            child: Obx(() {
              final q = query.value.toLowerCase();
              final currentSource = controller.sourceLanguage.value;

              final filtered = DubbingLanguage.source32Languages.where((l) {
                if (q.isEmpty) return true;
                return l.name.toLowerCase().contains(q) ||
                    l.nativeName.toLowerCase().contains(q) ||
                    l.code.toLowerCase().contains(q);
              }).toList();

              return GridView.builder(
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 290,
                  mainAxisExtent: 82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final lang = filtered[index];
                  final isClickable = lang.isAvailableAsSource;
                  final isNotPlanned = lang.isNotPlannedAsSource;
                  final isChosen = isClickable && currentSource == lang.code;

                  return DubbingLanguageCard(
                    language: lang,
                    isAvailable: isClickable,
                    isNotPlanned: isNotPlanned,
                    isSelected: isChosen,
                    onTap: isClickable
                        ? () {
                            controller.setSourceLanguage(lang.code);
                            Get.back();
                          }
                        : () {
                            if (isNotPlanned) {
                              AppSnackbar.info("${lang.name} isn't supported yet.");
                            } else {
                              AppSnackbar.info(
                                '${lang.name} will be available soon. Currently available source language: English.',
                              );
                            }
                          },
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 12),

          // Confirm button (White bg, Black text)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: Get.back,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Obx(() {
                final source = controller.sourceLanguage.value.toUpperCase();
                return Text(
                  'Confirm Source Language ($source)',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
