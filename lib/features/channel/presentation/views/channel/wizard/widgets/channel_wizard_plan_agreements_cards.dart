import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_models.dart';
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  '9. Channel Plan',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openComparisonPage(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        color: Color(0xFF818CF8),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Compare',
                        style: TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
      'custom': 'Pro plan',
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
        const SizedBox(height: 10),
        // Interactive "Compare Plans" button option
        InkWell(
          onTap: () => _openComparisonPage(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.compare_arrows_rounded,
                  color: Color(0xFF818CF8),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compare Standard & Pro Benefits',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF818CF8),
                  size: 11,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openComparisonPage(BuildContext context) async {
    final result = await Get.toNamed(
      '/channel-plan-comparison',
      arguments: {'initialPlan': controller.selectedPlan.value},
    );
    if (result is String && (result == 'standard' || result == 'custom')) {
      controller.selectedPlan.value = result;
      controller.planSelectionError.value = false;
    } else if (result is ChannelPlanType) {
      controller.selectedPlan.value =
          result == ChannelPlanType.custom ? 'custom' : 'standard';
      controller.planSelectionError.value = false;
    }
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
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFF27272A)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.back();
                    _openComparisonPage(context);
                  },
                  icon: const Icon(
                    Icons.compare_arrows_rounded,
                    color: Color(0xFF818CF8),
                    size: 18,
                  ),
                  label: const Text(
                    'Compare Standard & Pro Benefits',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
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
