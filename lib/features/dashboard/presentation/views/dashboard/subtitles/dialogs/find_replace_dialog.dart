import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class FindReplaceDialog {
  static void show(BuildContext context, SubtitlesController controller) {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();

    Get.dialog<void>(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.find_replace_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Find and Replace', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findCtrl,
              maxLength: 200,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              decoration: const InputDecoration(
                labelText: 'Find Text',
                hintText: 'Enter word or phrase to find...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replaceCtrl,
              maxLength: 200,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: controller.selectedLanguage.value == 'en'
                  ? TruthworldTextInputFormatters.withLimit(200)
                  : TruthworldTextInputFormatters.internationalWithLimit(200),
              decoration: const InputDecoration(
                labelText: 'Replace With',
                hintText: 'Enter replacement text...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final find = findCtrl.text;
              final replace = replaceCtrl.text;
              if (replace.isNotEmpty) {
                final isEn = controller.selectedLanguage.value == 'en';
                final v = ContentValidator.validate(
                  replace,
                  fieldName: 'Replacement Text',
                  checkEnglishOnly: isEn,
                );
                if (!v.isValid) {
                  controller.showWarning(v.message);
                  return;
                }
              }
              Get.back<void>();
              controller.replaceTextInCues(find, replace);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }
}
