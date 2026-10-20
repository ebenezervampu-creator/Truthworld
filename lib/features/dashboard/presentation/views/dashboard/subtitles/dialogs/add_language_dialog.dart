import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';

import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

class AddLanguageDialog {
  static void show(
    BuildContext context,
    SubtitlesController controller, {
    required bool isDarkMode,
    required bool isMobile,
  }) {
    final dialogActiveTab = 0.obs;
    final dialogSelectedLang = Rxn<TranslationLanguage>();
    final dialogTitleController = TextEditingController();
    final dialogTitleError = RxnString();
    final dialogPickedFile = Rxn<PlatformFile>();

    final availableToAdd = supportedLanguages
        .where((lang) => !controller.availableLanguages.contains(lang.code))
        .toList();

    Get.dialog<void>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Obx(() {
          return Container(
            width: isMobile ? double.infinity : 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Subtitle Track',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => dialogActiveTab.value = 0,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: dialogActiveTab.value == 0
                                  ? (isDarkMode
                                      ? Colors.black45
                                      : AppColors.textPrimary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Create Manually',
                              style: AppTextStyles.buttonText.copyWith(
                                fontWeight: dialogActiveTab.value == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                                color: dialogActiveTab.value == 0
                                    ? Colors.white
                                    : (isDarkMode
                                        ? AppColors.textSecondary
                                        : Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => dialogActiveTab.value = 1,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: dialogActiveTab.value == 1
                                  ? (isDarkMode
                                      ? Colors.black45
                                      : AppColors.textPrimary)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Upload File',
                              style: AppTextStyles.buttonText.copyWith(
                                fontWeight: dialogActiveTab.value == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                                color: dialogActiveTab.value == 1
                                    ? Colors.white
                                    : (isDarkMode
                                        ? AppColors.textSecondary
                                        : Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (dialogActiveTab.value == 0) ...[
                  Text(
                    'Select a target language to prepare empty localized cue timings.',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : Colors.black12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableToAdd.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final lang = availableToAdd[index];
                          return ListTile(
                            title: Text(
                              lang.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              lang.nativeName,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            onTap: () {
                              Get.back<void>();
                              controller.addLanguageTrack(lang.code);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Get.back<void>(),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.buttonText.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  DropdownButtonFormField<TranslationLanguage>(
                    initialValue: dialogSelectedLang.value,
                    hint: Text(
                      'Select target language',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                    ),
                    dropdownColor: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : AppColors.textPrimary,
                    items: supportedLanguages.map((lang) {
                      return DropdownMenuItem<TranslationLanguage>(
                        value: lang,
                        child: Text(
                          '${lang.name} (${lang.nativeName})',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      dialogSelectedLang.value = val;
                      if (val != null &&
                          dialogTitleController.text.trim().isEmpty) {
                        dialogTitleController.text = val.name;
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      labelStyle: TextStyle(fontSize: 13),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dialogTitleController,
                    maxLength: 100,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(100),
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Subtitle Track Title',
                      hintText: 'e.g., Spanish (Latin America)',
                      errorText: dialogTitleError.value,
                      labelStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        if (controller.profanityFilter.hasProfanity(val)) {
                          dialogTitleError.value =
                              'Title contains inappropriate language.';
                        } else {
                          dialogTitleError.value = null;
                        }
                      } else {
                        dialogTitleError.value = null;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.textDisabled
                            : AppColors.textSecondary,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dialogPickedFile.value != null
                                ? '${dialogPickedFile.value!.name} (${(dialogPickedFile.value!.size / 1024).toStringAsFixed(1)} KB)'
                                : 'No subtitle file selected (.vtt, .srt)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: dialogPickedFile.value != null
                                  ? (isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black)
                                  : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['vtt', 'srt', 'txt'],
                                withData: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                dialogPickedFile.value = result.files.first;
                              }
                            } on Exception catch (e) {
                              ErrorHandler.log(e, tag: 'SubtitlesPage');
                              controller.showError('Unable to select file. Please try again.');
                            }
                          },
                          icon: const Icon(Icons.file_open_rounded, size: 14, color: Colors.black),
                          label: Text(
                            'Choose',
                            style: AppTextStyles.buttonText.copyWith(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back<void>(),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.buttonText.copyWith(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: controller.isUploadingFile.value
                            ? null
                            : () async {
                                if (dialogSelectedLang.value == null) {
                                  controller.showError(
                                    'Please select a language.',
                                  );
                                  return;
                                }
                                final title = dialogTitleController.text.trim();
                                if (title.isEmpty) {
                                  controller.showError(
                                    'Please enter a track title.',
                                  );
                                  return;
                                }
                                if (dialogPickedFile.value == null) {
                                  controller.showError(
                                    'Please select a subtitle file.',
                                  );
                                  return;
                                }

                                final check = await controller.validateContent(
                                  title,
                                  fieldName: 'Track Title',
                                );
                                if (!check.isValid) {
                                  dialogTitleError.value = check.message;
                                  controller.showError(check.message);
                                  return;
                                }

                                final langCode = dialogSelectedLang.value!.code;
                                final file = dialogPickedFile.value!;
                                Get.back<void>();

                                await controller.uploadSubtitleTrack(
                                  languageCode: langCode,
                                  title: title,
                                  file: file,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                        ),
                        child: controller.isUploadingFile.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : Text(
                                'Upload & Save',
                                style: AppTextStyles.buttonText.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
