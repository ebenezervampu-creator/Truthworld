import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_comparison/channel_plan_comparison_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_comparison/channel_plan_comparison_guide.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_comparison/channel_plan_comparison_matrix.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_selection/channel_plan_models.dart';
import 'package:truthworld/theme/app_colors.dart';

/// GetX controller managing user plan selection within the comparison page.
class ChannelPlanComparisonController extends GetxController {
  ChannelPlanComparisonController({String initialPlan = 'standard'})
      : selectedPlan = initialPlan.obs;

  final RxString selectedPlan;

  void selectPlan(String plan) {
    selectedPlan.value = plan;
  }
}

/// Dedicated comparison screen explaining the differences & benefits between
/// Standard and Custom channel tiers during the channel creation flow.
class ChannelPlanComparisonScreen extends StatelessWidget {
  const ChannelPlanComparisonScreen({
    this.initialPlan = 'standard',
    this.onPlanSelected,
    super.key,
  });

  final String initialPlan;
  final ValueChanged<String>? onPlanSelected;

  /// Convenience navigation helper that opens this page and returns chosen plan ('standard' or 'custom').
  static Future<String?> show(
    BuildContext context, {
    String initialPlan = 'standard',
  }) async {
    return Get.toNamed<String>(
      '/channel-plan-comparison',
      arguments: {'initialPlan': initialPlan},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial plan from arguments if not provided explicitly
    var resolvedInitial = initialPlan;
    final args = Get.arguments;
    if (args is Map && args.containsKey('initialPlan')) {
      final argPlan = args['initialPlan'];
      if (argPlan is String) {
        resolvedInitial = argPlan;
      } else if (argPlan is ChannelPlanType) {
        resolvedInitial = argPlan == ChannelPlanType.custom ? 'custom' : 'standard';
      }
    } else if (args is Map && args.containsKey('selectedPlan')) {
      final argPlan = args['selectedPlan'];
      if (argPlan is String) {
        resolvedInitial = argPlan;
      } else if (argPlan is ChannelPlanType) {
        resolvedInitial = argPlan == ChannelPlanType.custom ? 'custom' : 'standard';
      }
    }

    final controllerTag = 'PlanComparison_${DateTime.now().microsecondsSinceEpoch}';
    final controller = Get.put(
      ChannelPlanComparisonController(initialPlan: resolvedInitial),
      tag: controllerTag,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (Get.isRegistered<ChannelPlanComparisonController>(tag: controllerTag)) {
          Get.delete<ChannelPlanComparisonController>(tag: controllerTag);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgPage : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            ),
            onPressed: () => Navigator.of(context).pop(controller.selectedPlan.value),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Compare Channel Plans',
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          centerTitle: false,
          actions: [
            Obx(() {
              final isStandard = controller.selectedPlan.value == 'standard';
              final badgeColor = isStandard ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
              final isSmallScreen = MediaQuery.of(context).size.width < 420;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStandard ? Icons.storefront_rounded : Icons.rocket_launch,
                      size: 13,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isStandard
                          ? (isSmallScreen ? 'Standard' : 'Standard Selected')
                          : (isSmallScreen ? 'Custom' : 'Custom Selected'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 64 : 16,
                  vertical: 24,
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1080 : 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Hero
                        _buildHeroHeader(isDesktop, isDark),
                        const SizedBox(height: 28),

                        // Overview Side-by-Side Cards
                        Obx(() {
                          final currentPlan = controller.selectedPlan.value;
                          final standardCard = StandardPlanOverviewCard(
                            isSelected: currentPlan == 'standard',
                            onSelect: () => controller.selectPlan('standard'),
                            isDark: isDark,
                          );
                          final customCard = CustomPlanOverviewCard(
                            isSelected: currentPlan == 'custom',
                            onSelect: () => controller.selectPlan('custom'),
                            isDark: isDark,
                          );

                          if (isDesktop) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: standardCard),
                                const SizedBox(width: 24),
                                Expanded(child: customCard),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              standardCard,
                              const SizedBox(height: 20),
                              customCard,
                            ],
                          );
                        }),

                        const SizedBox(height: 36),

                        // Detailed Tabular Comparison Matrix
                        PlanComparisonMatrixWidget(
                          isDesktop: isDesktop,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 36),

                        // Which Plan is Right For You guide
                        PlanRecommendationGuideCard(
                          isDesktop: isDesktop,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 36),

                        // FAQ Card
                        PlanComparisonFaqWidget(isDark: isDark),

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Persistent Bottom Selection / Action Bar
            _buildBottomActionBar(context, controller, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isDesktop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: Color(0xFF818CF8)),
                  SizedBox(width: 4),
                  Text(
                    'CREATOR ONBOARDING GUIDE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF818CF8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Standard vs Custom Channel',
          style: TextStyle(
            fontSize: isDesktop ? 32 : 24,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'TruthWorld gives you two creator pathways. Choose standard revenue-share with free hosting, or keep 100% of all gross earnings with dedicated infrastructure.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    ChannelPlanComparisonController controller,
    bool isDark,
  ) {
    final isSmallScreen = MediaQuery.of(context).size.width < 420;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final isStandard = controller.selectedPlan.value == 'standard';
          final primaryColor =
              isStandard ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);

          return Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to continue with:',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isStandard
                          ? r'Standard Channel ($0/mo • 70% Ad Split)'
                          : r'Custom Channel (100% Retention • From $15/mo)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  final chosen = controller.selectedPlan.value;
                  if (onPlanSelected != null) {
                    onPlanSelected!(chosen);
                  }
                  Navigator.of(context).pop(chosen);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  isSmallScreen
                      ? 'Continue'
                      : 'Continue with ${isStandard ? 'Standard' : 'Custom'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 14 : 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
