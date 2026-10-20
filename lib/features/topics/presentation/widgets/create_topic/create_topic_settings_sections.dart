import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic/create_topic_theme_helpers.dart';

/// Section 5: Topic Category Dropdown
Widget buildSection5Category(
  BuildContext context,
  CreateTopicController controller,
  List<String> availableCategories, {
  String title = '5. Topic Category',
}) {
  final rawVal = controller.categoryController.text.trim();
  final normalizedVal = AppCategories.normalizeCategory(rawVal);
  final initialValue = availableCategories.contains(rawVal)
      ? rawVal
      : (availableCategories.contains(normalizedVal)
          ? normalizedVal
          : (availableCategories.isNotEmpty ? availableCategories.first : 'Business'));

  if (controller.categoryController.text != initialValue) {
    controller.categoryController.text = initialValue;
  }

  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, title),
        const SizedBox(height: 4),
        Text(
          'Choose the category that best fits your topic.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: initialValue,
          dropdownColor: const Color(0xFF161618),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: buildCreateTopicInputDecoration(
            hintText: 'Select category',
            prefixIcon: const Icon(Icons.science_outlined, color: Colors.white, size: 20),
          ),
          items: availableCategories
              .map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              controller.categoryController.text = val;
            }
          },
        ),
      ],
    ),
  );
}

/// Backward compatibility alias for Section 5 Category
Widget buildSection6Category(
  BuildContext context,
  CreateTopicController controller,
  List<String> availableCategories, {
  String title = '5. Topic Category',
}) => buildSection5Category(context, controller, availableCategories, title: title);

/// Section 6: Topic Type (Public / Private with Passcode)
Widget buildSection6TopicType(
  BuildContext context,
  CreateTopicController controller, {
  String title = '6. Topic Type',
}) {
  return buildCreateTopicCardContainer(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCreateTopicSectionTitle(context, title),
        const SizedBox(height: 4),
        Text(
          'Choose who can view this topic',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Obx(() {
          final isPublic = controller.selectedVisibility.value == TopicVisibilityType.public;
          return InkWell(
            onTap: () => controller.selectedVisibility.value = TopicVisibilityType.public,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isPublic ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPublic ? Colors.white : Colors.white.withValues(alpha: 0.12),
                  width: isPublic ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Public', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          'Anyone can view this topic',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  Radio<TopicVisibilityType>(
                    value: TopicVisibilityType.public,
                    groupValue: controller.selectedVisibility.value,
                    onChanged: (val) => controller.selectedVisibility.value = val!,
                    activeColor: Colors.white,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        Obx(() {
          final isPrivate = controller.selectedVisibility.value == TopicVisibilityType.private;
          return Column(
            children: [
              InkWell(
                onTap: () => controller.selectedVisibility.value = TopicVisibilityType.private,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPrivate ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrivate ? Colors.white : Colors.white.withValues(alpha: 0.12),
                      width: isPrivate ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Private', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(
                              'Only you can view this topic',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      Radio<TopicVisibilityType>(
                        value: TopicVisibilityType.private,
                        groupValue: controller.selectedVisibility.value,
                        onChanged: (val) => controller.selectedVisibility.value = val!,
                        activeColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              if (isPrivate) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller.accessCodeController,
                  obscureText: controller.obscureAccessCode.value,
                  maxLength: 20,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(20),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: buildCreateTopicInputDecoration(
                    hintText: 'Enter Private Passcode',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
                      onPressed: controller.togglePasscodeVisibility,
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
      ],
    ),
  );
}

/// Backward compatibility alias for Section 6 Topic Type
Widget buildSection7TopicType(
  BuildContext context,
  CreateTopicController controller, {
  String title = '6. Topic Type',
}) => buildSection6TopicType(context, controller, title: title);
