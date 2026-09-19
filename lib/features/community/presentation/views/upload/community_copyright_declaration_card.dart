import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Statutory Creator Copyright & Rights Ownership confirmation card.
class CommunityCopyrightDeclarationCard
    extends GetView<CommunityPostUploadController> {
  const CommunityCopyrightDeclarationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isConfirmed = controller.hasConfirmedCopyrightDeclaration.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConfirmed
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConfirmed
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : context.colors.divider.withValues(alpha: 0.6),
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
                        'Creator Copyright & Rights Declaration',
                        style: context.twTypography.title.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mandatory statutory confirmation before publishing',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                controller.hasConfirmedCopyrightDeclaration.value =
                    !controller.hasConfirmedCopyrightDeclaration.value;
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isConfirmed
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : context.colors.divider,
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
                        child: Text(
                          'I declare that I own or have all necessary rights to publish this post and any attached images, and that this content complies with TruthWorld Community Guidelines.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isConfirmed
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            height: 1.4,
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
