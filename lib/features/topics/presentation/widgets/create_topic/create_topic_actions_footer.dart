import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';

/// Desktop footer actions (Cancel & Create Topic buttons)
Widget buildCreateTopicDesktopFooterActions(
  BuildContext context,
  CreateTopicController controller,
  Future<void> Function(CreateTopicController) onCreateTopicSubmitted,
) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton(
        onPressed: Get.back,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('Cancel'),
      ),
      const SizedBox(width: 16),
      Obx(() {
        return ElevatedButton(
          onPressed: controller.isSubmitting.value
              ? null
              : () async {
                  HapticFeedback.lightImpact();
                  final isValid = await controller.validateFormBeforeSubmit();
                  if (!isValid) return;
                  controller.isSubmitting.value = true;
                  try {
                    await onCreateTopicSubmitted(controller);
                    if (context.mounted) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Get.back();
                      }
                    }
                  } catch (e, s) {
                    ErrorHandler.log(e, stackTrace: s, context: 'CreateTopicDialog.submit');
                    final msg = e.toString();
                    if (!msg.contains('Video Required') &&
                        !msg.contains('Description') &&
                        !msg.contains('Handle') &&
                        !msg.contains('Title') &&
                        !msg.contains('Sign In')) {
                      AppSnackbar.error('Unable to create topic. Please try again.');
                    }
                  } finally {
                    controller.isSubmitting.value = false;
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: controller.isSubmitting.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Create Topic',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        );
      }),
    ],
  );
}

/// Mobile sticky bottom footer bar with full-width submit button
Widget buildCreateTopicMobileStickyFooter(
  BuildContext context,
  CreateTopicController controller,
  Future<void> Function(CreateTopicController) onCreateTopicSubmitted,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF161618),
      border: Border(
        top: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    ),
    child: SizedBox(
      width: double.infinity,
      height: 48,
      child: Obx(() {
        return ElevatedButton(
          onPressed: controller.isSubmitting.value
              ? null
              : () async {
                  HapticFeedback.lightImpact();
                  final isValid = await controller.validateFormBeforeSubmit();
                  if (!isValid) return;
                  controller.isSubmitting.value = true;
                  try {
                    await onCreateTopicSubmitted(controller);
                    if (context.mounted) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Get.back();
                      }
                    }
                  } catch (e, s) {
                    ErrorHandler.log(e, stackTrace: s, context: 'CreateTopicDialog.mobileSubmit');
                    final msg = e.toString();
                    if (!msg.contains('Video Required') &&
                        !msg.contains('Description') &&
                        !msg.contains('Handle') &&
                        !msg.contains('Title') &&
                        !msg.contains('Sign In')) {
                      AppSnackbar.error('Unable to create topic. Please try again.');
                    }
                  } finally {
                    controller.isSubmitting.value = false;
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: controller.isSubmitting.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Create Topic',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
        );
      }),
    ),
  );
}
