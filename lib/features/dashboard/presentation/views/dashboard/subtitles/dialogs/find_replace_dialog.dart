import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';

class FindReplaceDialog {
  static void show(BuildContext context, SubtitlesController controller) {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();

    Get.dialog<void>(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.find_replace_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Find and Replace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findCtrl,
              decoration: const InputDecoration(
                labelText: 'Find Text',
                hintText: 'Enter word or phrase to find...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replaceCtrl,
              inputFormatters: controller.selectedLanguage.value == 'en'
                  ? TruthworldTextInputFormatters.standard
                  : [TruthworldTextInputFormatters.profanityFilter],
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
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );
  }
}
