import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section 11: Mandatory creator copyright & rights declaration
class CreateContentCopyrightSection extends StatelessWidget {
  final UploadController controller;

  const CreateContentCopyrightSection({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isConfirmed = controller.hasConfirmedCopyrightDeclaration.value;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isConfirmed
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConfirmed
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.12),
            width: isConfirmed ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '11. Creator Copyright & Rights Declaration',
                        style: context.themeTypography.title.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mandatory statutory confirmation before publishing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                controller.hasConfirmedCopyrightDeclaration.value =
                    !controller.hasConfirmedCopyrightDeclaration.value;
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isConfirmed
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isConfirmed,
                      onChanged: (val) {
                        controller.hasConfirmedCopyrightDeclaration.value =
                            val ?? false;
                      },
                      activeColor: const Color(0xFF10B981),
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    "I confirm and declare that I own all rights to this video or have obtained all necessary statutory licenses, permissions, and authorizations to publish it. This video does not infringe upon any third-party copyright, trademark, privacy, or proprietary rights, and strictly complies with Truthworld's ",
                              ),
                              WidgetSpan(
                                child: InkWell(
                                  onTap: () => Get.toNamed('/terms'),
                                  child: const Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              WidgetSpan(
                                child: InkWell(
                                  onTap: () => Get.toNamed('/community-guidelines'),
                                  child: const Text(
                                    'Community Guidelines',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
