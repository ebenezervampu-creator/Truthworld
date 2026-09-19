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
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
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
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
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

/// Section 3: Title Input
Widget buildSection3Title(BuildContext context, CreateTopicController controller) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, '3. Title'),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: controller.titleController,
              maxLength: 100,
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: buildCreateTopicInputDecoration(hintText: 'Enter a catchy title for your topic'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Title is required';
                return null;
              },
            ),
            Positioned(
              right: 14,
              child: Text(
                '${controller.titleController.text.length}/100',
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
          'This title will be shown on your topic page.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Section 4: Description Input
Widget buildSection4Description(BuildContext context, CreateTopicController controller) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, '4. Description'),
        const SizedBox(height: 12),
        Stack(
          children: [
            TextFormField(
              controller: controller.descriptionController,
              maxLines: 4,
              maxLength: 500,
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: buildCreateTopicInputDecoration(
                hintText: 'Describe your topic. What is it about?',
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 10,
              child: Text(
                '${controller.descriptionController.text.length}/500',
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
          'Share more details about this topic.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Section 5: Tags Input & Tag Chips
Widget buildSection5Tags(BuildContext context, CreateTopicController controller) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, '5. Tags'),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller.tagInputController,
          inputFormatters: [TruthworldTextInputFormatters.englishOnly],
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
