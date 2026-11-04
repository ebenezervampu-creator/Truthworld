import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Bottom action bar and toggle for channel plan selection.
class PlanFooterAction extends StatelessWidget {
  const PlanFooterAction({
    required this.controller,
    required this.isDesktop,
    required this.isShowingAllFeatures,
    required this.onToggleShowAllFeatures,
    super.key,
  });

  final ChannelController controller;
  final bool isDesktop;
  final RxBool isShowingAllFeatures;
  final VoidCallback onToggleShowAllFeatures;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedPlan = controller.selectedPlan.value;
      final hasSelected = selectedPlan.isNotEmpty;
      final isCustom = selectedPlan == 'custom';
      final buttonText = hasSelected
          ? 'Continue with ${isCustom ? 'Pro' : 'Standard'} Channel'
          : 'Select Standard or Pro Plan';

      final toggleText = isShowingAllFeatures.value
          ? 'Hide All Features'
          : 'Show More / Compare All Features';

      void handleProceed() {
        if (!hasSelected) {
          AppSnackbar.info(
            'Please tap on either Standard or Pro channel plan to select your plan.',
            title: 'Select Channel Plan',
          );
          return;
        }
      }

      if (isDesktop) {
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            GestureDetector(
              onTap: onToggleShowAllFeatures,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isShowingAllFeatures.value
                          ? Icons.keyboard_arrow_up
                          : Icons.insert_chart_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      toggleText,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: handleProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF3F3F46),
                  foregroundColor: Colors.white,
                  elevation: hasSelected ? 6 : 1,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: handleProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF3F3F46),
                foregroundColor: Colors.white,
                elevation: hasSelected ? 6 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onToggleShowAllFeatures,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isShowingAllFeatures.value
                        ? Icons.keyboard_arrow_up
                        : Icons.insert_chart_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    toggleText,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
