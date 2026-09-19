import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardPlanCard extends StatelessWidget {
  final ChannelController controller;
  final bool isDarkMode;
  final bool contentOnly;

  const ChannelWizardPlanCard({
    required this.controller,
    required this.isDarkMode,
    super.key,
    this.contentOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (contentOnly) {
      return buildContent(context);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '9. Channel Plan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          buildContent(context),
        ],
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    final planNames = {
      'standard': 'Standard',
      'custom': 'Custom plan',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your channel plan.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => GestureDetector(
            onTap: () => _showPlanPicker(context, planNames),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      planNames[controller.selectedPlan.value] ?? 'Standard',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPlanPicker(BuildContext context, Map<String, String> planNames) {
    Get.bottomSheet(
      Material(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Channel Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...planNames.entries.map((entry) {
                return Obx(() {
                  final isSelected = controller.selectedPlan.value == entry.key;
                  return ListTile(
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      controller.selectedPlan.value = entry.key;
                      controller.planSelectionError.value = false;
                      Get.back();
                    },
                  );
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // CARD 10: AGREEMENTS & SUBMIT BUTTON
  // ========================================================================
}

class ChannelWizardAgreementsCard extends StatelessWidget {
  final ChannelController controller;
  final bool isDarkMode;
  final bool contentOnly;
  final VoidCallback onSubmit;

  const ChannelWizardAgreementsCard({
    required this.controller,
    required this.isDarkMode,
    required this.onSubmit,
    super.key,
    this.contentOnly = false,
  });

  Future<void> _openTermsPage() async {
    final result = await Get.toNamed(
      '/terms',
      arguments: {'requireAgreement': true},
    );
    if (result == true) {
      controller.agreeTerms.value = true;
      controller.isAgreed.value =
          controller.agreeTerms.value && controller.agreeGuidelines.value;
    }
  }

  Future<void> _openGuidelinesPage() async {
    final result = await Get.toNamed(
      '/community-guidelines',
      arguments: {'requireAgreement': true},
    );
    if (result == true) {
      controller.agreeGuidelines.value = true;
      controller.isAgreed.value =
          controller.agreeTerms.value && controller.agreeGuidelines.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (contentOnly) {
      return buildContent(context);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '10. Agreements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          buildContent(context),
        ],
      ),
    );
  }

  Widget buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Obx(
          () => _buildCheckboxRow(
            value: controller.agreeTerms.value,
            onChanged: (val) {
              if (controller.agreeTerms.value && val == false) {
                controller.agreeTerms.value = false;
                controller.isAgreed.value = false;
              } else {
                _openTermsPage();
              }
            },
            text: 'I agree to the ',
            linkText: 'Terms and Conditions',
            onLinkTap: _openTermsPage,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => _buildCheckboxRow(
            value: controller.agreeGuidelines.value,
            onChanged: (val) {
              if (controller.agreeGuidelines.value && val == false) {
                controller.agreeGuidelines.value = false;
                controller.isAgreed.value = false;
              } else {
                _openGuidelinesPage();
              }
            },
            text: 'I agree to the ',
            linkText: 'Community Guidelines',
            onLinkTap: _openGuidelinesPage,
          ),
        ),
        const SizedBox(height: 24),
        // Create Channel Button (Full width button with progress indication)
        Obx(
          () => SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: controller.isSubmitting.value ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: controller.isSubmitting.value
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Creating Channel...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Create Channel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
    required String linkText,
    required VoidCallback onLinkTap,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            checkColor: Colors.black,
            side: const BorderSide(color: Color(0xFF52525B)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                children: [
                  TextSpan(text: text),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // REUSABLE FIELD HELPERS
  // ========================================================================
}
