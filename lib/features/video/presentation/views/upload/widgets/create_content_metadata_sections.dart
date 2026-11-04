import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 3: Video Title input with live character counter and validation
class CreateContentTitleSection extends StatelessWidget {
  const CreateContentTitleSection({
    required this.titleController,
    super.key,
  });

  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. Video Title',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: titleController,
            builder: (context, value, _) {
              final text = value.text.trim();
              final validation = text.isNotEmpty
                  ? ContentValidator.validate(
                      text,
                      fieldName: 'Title',
                      minLength: 5,
                      maxLength: 100,
                    )
                  : null;
              final hasError = validation != null &&
                  !validation.isValid &&
                  (text.length >= 5 ||
                      validation.message.contains('inappropriate') ||
                      validation.message.contains('offensive') ||
                      validation.message.contains('prohibited'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextField(
                        controller: titleController,
                        maxLength: 100,
                        inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter video title',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          counterText: '',
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 14, 60, 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        child: Text(
                          '${value.text.length}/100',
                          style: TextStyle(
                            color: hasError
                                ? const Color(0xFFEF4444)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            validation.message,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Give your video a clear and catchy title.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 4: Video Description input with character counter and validation
class CreateContentDescriptionSection extends StatelessWidget {
  const CreateContentDescriptionSection({
    required this.descriptionController,
    super.key,
  });

  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4. Description',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: descriptionController,
            builder: (context, value, _) {
              final text = value.text.trim();
              final validation = text.isNotEmpty
                  ? ContentValidator.validate(
                      text,
                      fieldName: 'Description',
                      minLength: 10,
                      maxLength: ContentValidator.defaultMaxDescriptionLength,
                      checkPhoneNumbers: true,
                    )
                  : null;
              final hasError = validation != null &&
                  !validation.isValid &&
                  (text.length >= 10 ||
                      validation.message.contains('inappropriate') ||
                      validation.message.contains('offensive') ||
                      validation.message.contains('prohibited'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        maxLength: ContentValidator.defaultMaxDescriptionLength,
                        inputFormatters: TruthworldTextInputFormatters.withLimit(
                          ContentValidator.defaultMaxDescriptionLength,
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Describe your video',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          counterText: '',
                          fillColor: const Color(0xFF0F0F11),
                          filled: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 14, 16, 30),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: hasError
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 10,
                        child: Text(
                          '${value.text.length}/${ContentValidator.defaultMaxDescriptionLength}',
                          style: TextStyle(
                            color: hasError
                                ? const Color(0xFFEF4444)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            validation.message,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Tell viewers what your video is about.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 5: Video Tags input with comma-separation and validation
class CreateContentTagsSection extends StatelessWidget {
  const CreateContentTagsSection({
    required this.tagsController,
    super.key,
  });

  final TextEditingController tagsController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5. Tags',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: tagsController,
            builder: (context, value, _) {
              final rawTags = value.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              final validation = rawTags.isNotEmpty
                  ? ContentValidator.validateTags(
                      rawTags,
                    )
                  : null;
              final hasError = validation != null && !validation.isValid;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: tagsController,
                    maxLength: 200,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: TruthworldTextInputFormatters.withLimit(200),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Add tags separated by commas (e.g. Space, Tech, Science)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      fillColor: const Color(0xFF0F0F11),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: hasError
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color:
                              hasError ? const Color(0xFFEF4444) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            validation.message,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Add relevant tags to help others find your video.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
