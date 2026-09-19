import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card container decoration matching dark topic / playlist theme
Widget buildCreateTopicCardContainer({
  required BuildContext context,
  required Widget child,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF161618),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
      ),
    ),
    child: child,
  );
}

/// Standardized section title
Widget buildCreateTopicSectionTitle(BuildContext context, String title) {
  return Text(
    title,
    style: context.themeTypography.title.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 15,
    ),
  );
}

/// Standardized dark theme input decoration
InputDecoration buildCreateTopicInputDecoration({
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: 14,
    ),
    counterText: '',
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    fillColor: const Color(0xFF0F0F11),
    filled: true,
    contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white),
    ),
  );
}

/// Dynamic profanity & moderation warning banner
Widget buildCreateTopicProfanityAlert(CreateTopicController controller) {
  return Obx(() {
    if (controller.profanityError.value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.profanityError.value,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  });
}
