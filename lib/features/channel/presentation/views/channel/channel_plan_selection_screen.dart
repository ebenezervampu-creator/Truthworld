import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_plan_selection_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_models.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'package:truthworld/features/channel/presentation/views/channel/plan_selection/plan_selection_barrel.dart';

/// Screen allowing creators to select between Standard and Custom channel plans.
class ChannelPlanSelectionScreen extends StatelessWidget {
  const ChannelPlanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService.to.hasChannel.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/studio');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final controller = Get.isRegistered<ChannelPlanSelectionController>()
        ? Get.find<ChannelPlanSelectionController>()
        : Get.put(ChannelPlanSelectionController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPage : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.textPrimary : AppColors.bgPage,
          ),
          onPressed: Get.back,
        ),
      ),
      body: FadeTransition(
        opacity: controller.fadeAnim,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64.0 : 24.0,
              vertical: 24,
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Choose Your Creator Path',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 48 : 32,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF1A202C),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select the monetization plan that aligns with your goals.\nYou can choose standard YouTube-like sharing or our unique Custom plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF1E293B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 56),

                // Plan Cards
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ChannelPlanCard(
                          controller: controller,
                          type: ChannelPlanType.standard,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: ChannelPlanCard(
                          controller: controller,
                          type: ChannelPlanType.custom,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ChannelPlanCard(
                        controller: controller,
                        type: ChannelPlanType.standard,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      ChannelPlanCard(
                        controller: controller,
                        type: ChannelPlanType.custom,
                        isDark: isDark,
                      ),
                    ],
                  ),

                const SizedBox(height: 56),

                // Continue Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isDesktop ? 400 : double.infinity,
                  height: 56,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: controller.selectedPlan.value != null
                          ? controller.proceedToChannelCreation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: controller.selectedPlan.value != null
                            ? 8
                            : 0,
                        shadowColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.5),
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: controller.selectedPlan.value != null
                              ? AppColors.textPrimary
                              : (isDark
                                    ? AppColors.textTertiary
                                    : Colors.black26),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
