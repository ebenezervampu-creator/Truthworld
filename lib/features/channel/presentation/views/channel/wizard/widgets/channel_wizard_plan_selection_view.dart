import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/plan_selection/plan_selection_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'plan_selection/plan_selection_widgets.dart';

/// Plan selection screen coordinator for the Channel Creation Wizard.
class ChannelWizardPlanSelectionView extends StatelessWidget {
  ChannelWizardPlanSelectionView({
    required this.controller,
    required this.isDesktop,
    required this.isDarkMode,
    this.onClose,
    super.key,
  });

  final ChannelController controller;
  final bool isDesktop;
  final bool isDarkMode;
  final VoidCallback? onClose;

  final RxBool _isShowingAllFeatures = false.obs;

  void _toggleShowAllFeatures() {
    _isShowingAllFeatures.value = !_isShowingAllFeatures.value;
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlanSelectionScreen(context, isDesktop, isDarkMode);
  }

  Widget _buildPlanHeader(bool isDesktop) {
    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Channel Plan',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Choose your monetization & features plan before creating your channel.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => (onClose ?? Get.back)(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => (onClose ?? Get.back)(),
            ),
            const Expanded(
              child: Text(
                'Select Channel Plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose your monetization & features plan before creating your channel.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelectionScreen(
    BuildContext context,
    bool isDesktop,
    bool isDarkMode,
  ) {
    final bodyContent = Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1040 : 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _buildPlanHeader(isDesktop),
            SizedBox(height: isDesktop ? 10 : 20),

            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StandardPlanCard(
                      controller: controller,
                      isDarkMode: isDarkMode,
                      isDesktop: isDesktop,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomPlanCard(
                      controller: controller,
                      isDarkMode: isDarkMode,
                      isDesktop: isDesktop,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  StandardPlanCard(
                    controller: controller,
                    isDarkMode: isDarkMode,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 16),
                  CustomPlanCard(
                    controller: controller,
                    isDarkMode: isDarkMode,
                    isDesktop: isDesktop,
                  ),
                ],
              ),

            SizedBox(height: isDesktop ? 10 : 16),

            WhyChoosePlanCard(controller: controller, isDesktop: isDesktop),

            CustomTierBreakdownTable(
              controller: controller,
              isDesktop: isDesktop,
            ),

            SizedBox(height: isDesktop ? 8 : 16),

            PlanNoticeCard(isDesktop: isDesktop),

            Obx(
              () => _isShowingAllFeatures.value
                  ? Column(
                      children: [
                        SizedBox(height: isDesktop ? 10 : 16),
                        PlanHighlightsCard(
                          controller: controller,
                          isDesktop: isDesktop,
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            SizedBox(height: isDesktop ? 12 : 20),

            PlanFooterAction(
              controller: controller,
              isDesktop: isDesktop,
              isShowingAllFeatures: _isShowingAllFeatures,
              onToggleShowAllFeatures: _toggleShowAllFeatures,
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 16 : 16,
      ),
      child: bodyContent,
    );
  }
}
