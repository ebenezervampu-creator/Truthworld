import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic/create_topic_theme_helpers.dart';

/// Section 1: Topic Name Input
Widget buildSection1TopicName(BuildContext context, CreateTopicController controller) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, '1. Topic Name'),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: controller.nameController,
              maxLength: 60,
              inputFormatters: TruthworldTextInputFormatters.withLimit(60),
              onChanged: (_) => controller.formKey.currentState?.validate(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: buildCreateTopicInputDecoration(hintText: 'Enter topic name'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Topic Name is required';
                if (val.trim().length < 3) return 'Name must be at least 3 characters';
                return null;
              },
            ),
            Positioned(
              right: 14,
              child: Text(
                '${controller.nameController.text.length}/60',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a clear and simple name.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Section 2: Handle Input
Widget buildSection2Handle(BuildContext context, CreateTopicController controller) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, '2. Handle'),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: controller.handleController,
              maxLength: 30,
              inputFormatters: TruthworldTextInputFormatters.withLimit(30),
              onChanged: (_) => controller.onHandleManualEdit(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: buildCreateTopicInputDecoration(
                hintText: 'topic-handle',
                prefixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.white, size: 18),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Handle is required';
                if (val.contains(' ')) return 'Handle cannot contain spaces';
                return null;
              },
            ),
            Positioned(
              right: 14,
              child: Text(
                '${controller.handleController.text.length}/30',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Your unique topic handle. Example: @spaceexploration',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Section 3: Description Input (Previously Section 4, title requirement removed)
Widget buildSection3Description(
  BuildContext context,
  CreateTopicController controller, {
  bool isDesktop = false,
  String title = '3. Description',
}) {
  final minLines = isDesktop ? 12 : 5;
  final maxLines = isDesktop ? 14 : 5;

  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, title),
        const SizedBox(height: 12),
        Stack(
          children: [
            TextFormField(
              controller: controller.descriptionController,
              minLines: minLines,
              maxLines: maxLines,
              maxLength: 500,
              textAlignVertical: TextAlignVertical.top,
              inputFormatters: TruthworldTextInputFormatters.withLimit(500),
              onChanged: (_) => controller.formKey.currentState?.validate(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: buildCreateTopicInputDecoration(
                hintText: 'Describe your topic. What is it about? (at least 10 characters)',
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              ),
              validator: (val) {
                final trimmed = val?.trim() ?? '';
                if (trimmed.isEmpty) return 'Description is required';
                if (trimmed.length < 10) return 'Description must be at least 10 characters';
                return null;
              },
            ),
            Positioned(
              right: 14,
              bottom: 10,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller.descriptionController,
                builder: (context, value, _) {
                  return Text(
                    '${value.text.length}/500',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Share more details about this topic (minimum 10 characters required).',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Backward compatibility alias for Section 3/4 Description
Widget buildSection4Description(
  BuildContext context,
  CreateTopicController controller, {
  bool isDesktop = false,
  String title = '4. Description',
}) => buildSection3Description(context, controller, isDesktop: isDesktop, title: title);

/// Deprecated: Section 3 Title removed. Topic has Topic Name only.
@Deprecated('Title requirement has been removed for Topics. Topics have Topic Name only.')
Widget buildSection3Title(BuildContext context, CreateTopicController controller) => const SizedBox.shrink();

/// Section 7: Tags Input & Tag Chips (Positioned above Add Videos)
Widget buildSection7Tags(
  BuildContext context,
  CreateTopicController controller, {
  String title = '7. Tags',
}) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, title),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.tagInputController,
          maxLength: 30,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: TruthworldTextInputFormatters.withLimit(30),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: buildCreateTopicInputDecoration(hintText: 'Add tags and press Enter'),
          onFieldSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              controller.addTag(val);
            }
          },
        ),
        const SizedBox(height: 12),
        // Interactive Tag Chips
        Obx(() {
          final tags = controller.tagsList.toList();
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$tag ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    InkWell(
                      onTap: () => controller.removeTag(tag),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Add relevant tags to help others find your topic.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Backward compatibility alias for Section 7 Tags
Widget buildSection5Tags(
  BuildContext context,
  CreateTopicController controller, {
  String title = '7. Tags',
}) => buildSection7Tags(context, controller, title: title);
