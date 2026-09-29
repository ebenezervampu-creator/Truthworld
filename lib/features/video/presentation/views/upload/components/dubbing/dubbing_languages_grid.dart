import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Grid of 70+ neural dubbing languages.
class DubbingLanguagesGrid extends StatelessWidget {
  const DubbingLanguagesGrid({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final langs = controller.filteredLanguages;

      if (langs.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Text(
              'No matching dubbing languages found.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 68,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: langs.length,
        itemBuilder: (context, index) {
          final lang = langs[index];
          final isSource = controller.isSourceLanguage(lang);
          final isSelected = controller.isLanguageSelected(lang);

          if (isSource) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lang.name,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 10, color: Colors.white38),
                            SizedBox(width: 4),
                            Text(
                              'ORIGINAL SOURCE',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.white24, size: 16),
                ],
              ),
            );
          }

          return InkWell(
            onTap: () => controller.toggleLanguage(lang),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF27272E) : const Color(0xFF141418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lang.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang.nativeName.isNotEmpty ? lang.nativeName : lang.code.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white30,
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
                ],
              ),
            ),
          );
        },
      );
    });
  }

}
