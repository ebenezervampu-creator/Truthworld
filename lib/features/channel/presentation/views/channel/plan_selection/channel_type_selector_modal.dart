import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_models.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_type_selector_components.dart';
import 'package:truthworld/theme/app_colors.dart';

/// GetX controller managing reactive selection state for the channel type selector modal.
class ChannelTypeSelectorController extends GetxController {
  ChannelTypeSelectorController({
    ChannelPlanType initialPlan = ChannelPlanType.standard,
  }) : selectedPlan = initialPlan.obs;

  final Rx<ChannelPlanType> selectedPlan;

  void selectPlan(ChannelPlanType plan) {
    selectedPlan.value = plan;
  }
}

/// Reusable modal sheet for selecting Channel Type anywhere in TruthWorld.
/// Converted to a declarative zero-setState StatelessWidget with GetX reactivity.
class ChannelTypeSelectorModal extends StatelessWidget {
  const ChannelTypeSelectorModal({
    this.initialPlan = ChannelPlanType.standard,
    this.onSelect,
    this.controllerTag,
    super.key,
  });

  final ChannelPlanType initialPlan;
  final ValueChanged<ChannelPlanType>? onSelect;
  final String? controllerTag;

  static Future<ChannelPlanType?> show(
    BuildContext context, {
    ChannelPlanType initialPlan = ChannelPlanType.standard,
  }) {
    final tag =
        'ChannelTypeSelector_${DateTime.now().microsecondsSinceEpoch}';
    Get.put(
      ChannelTypeSelectorController(initialPlan: initialPlan),
      tag: tag,
    );

    return showModalBottomSheet<ChannelPlanType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ChannelTypeSelectorModal(
          initialPlan: initialPlan,
          controllerTag: tag,
          onSelect: (selected) => Navigator.of(ctx).pop(selected),
        ),
      ),
    ).whenComplete(() {
      if (Get.isRegistered<ChannelTypeSelectorController>(tag: tag)) {
        Get.delete<ChannelTypeSelectorController>(tag: tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = (controllerTag != null &&
            Get.isRegistered<ChannelTypeSelectorController>(tag: controllerTag))
        ? Get.find<ChannelTypeSelectorController>(tag: controllerTag)
        : (Get.isRegistered<ChannelTypeSelectorController>()
            ? Get.find<ChannelTypeSelectorController>()
            : Get.put(
                ChannelTypeSelectorController(initialPlan: initialPlan),
              ));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final selectedPlanVal = controller.selectedPlan.value;
      final isStandard = selectedPlanVal == ChannelPlanType.standard;
      final primaryColor = isStandard
          ? const Color(0xFF3B82F6)
          : const Color(0xFF8B5CF6);

      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgSurface : AppColors.textPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Channel Type',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose your channel monetization & infrastructure plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.bgDivider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChannelTypeOptionCard(
                      title: 'Standard Channel',
                      subtitle:
                          '70% Ads & Subs • 100% Superchats & Memberships',
                      icon: Icons.storefront_rounded,
                      primaryColor: const Color(0xFF3B82F6),
                      gradientStart: const Color(0xFF60A5FA),
                      isDark: isDark,
                      isSelected: selectedPlanVal == ChannelPlanType.standard,
                      onTap: () =>
                          controller.selectPlan(ChannelPlanType.standard),
                    ),
                    const SizedBox(height: 16),
                    ChannelTypeOptionCard(
                      title: 'Custom Channel',
                      subtitle:
                          r'100% Gross Revenue Share • Plans $15, $30, $45/mo • Unlimited Uploads',
                      icon: Icons.rocket_launch,
                      primaryColor: const Color(0xFF8B5CF6),
                      gradientStart: const Color(0xFFA78BFA),
                      isDark: isDark,
                      isSelected: selectedPlanVal == ChannelPlanType.custom,
                      onTap: () =>
                          controller.selectPlan(ChannelPlanType.custom),
                    ),
                    const SizedBox(height: 24),
                    ChannelTypeBenefitsBox(
                      isStandard: isStandard,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgPage : const Color(0xFFF8FAFC),
                border:
                    const Border(top: BorderSide(color: AppColors.bgDivider)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (onSelect != null) {
                      onSelect!(selectedPlanVal);
                    } else {
                      Navigator.of(context).pop(selectedPlanVal);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'Continue with ${isStandard ? 'Standard Channel' : 'Custom Channel'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
