import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_plans_widgets.dart';
import 'package:truthworld/theme/app_theme.dart' hide kDesktopBreakpoint;

export 'plans/premium_plans_widgets.dart';

/// Modernized TruthWorld Premium Plans screen presenting tiers, benefits, and checkout.
class PremiumPlansScreen extends StatelessWidget {
  const PremiumPlansScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  PremiumController _resolveController() {
    return Get.isRegistered<PremiumController>()
        ? Get.find<PremiumController>()
        : Get.put(PremiumController());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _resolveController();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context, controller);
        } else if (isTablet) {
          return _buildTabletLayout(context, controller);
        } else {
          return _buildMobileLayout(context, controller);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, PremiumController controller) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildModernAppBar(context, isDesktop: true),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: _buildMainContentSections(
                  context,
                  controller,
                  isDesktop: true,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: PremiumDesktopSidebar(controller: controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, PremiumController controller) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildModernAppBar(context, isTablet: true),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _buildMainContentSections(
            context,
            controller,
            isTablet: true,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, PremiumController controller) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildModernAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: _buildMainContentSections(context, controller),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Get.back();
              },
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 28, borderRadius: 6),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Truthworld Premium',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.feedback_outlined,
          onPressed: () => Get.toNamed('/feedback'),
          tooltip: 'Feedback',
        ),
        _buildAppBarAction(
          icon: Icons.more_vert_rounded,
          onPressed: () => showPremiumMoreOptionsSheet(context),
          tooltip: 'Options',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: buttonBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContentSections(
    BuildContext context,
    PremiumController controller, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Obx(() {
      final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
      final isPremium = auth?.isPremiumUser.value ?? false;
      final currentPlanId = auth?.premiumPlanId.value;

      return Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Premium Style Hero Banner
              PremiumHeroSection(
                isPremium: isPremium,
                planId: currentPlanId,
                isDesktop: isDesktop,
                isTablet: isTablet,
                controller: controller,
              ),
              const SizedBox(height: 32),

              // 2. User Membership Status & Sandbox Panel (on Mobile/Tablet)
              if (!isDesktop) ...[
                PremiumMembershipStatusCard(
                  isPremium: isPremium,
                  planId: currentPlanId,
                  controller: controller,
                ),
                const SizedBox(height: 32),
              ],

              // 3. Plan Selector & Upgrades ("Choose the plan that fits for you")
              PremiumPlanSelectorSection(
                isDesktop: isDesktop,
                isTablet: isTablet,
                controller: controller,
              ),
              const SizedBox(height: 48),

              // 4. Feature Cards Grid ("All-Inclusive Benefits")
              PremiumFeaturesGrid(
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              const SizedBox(height: 48),

              // 5. Compare Free vs Premium Table
              const PremiumComparisonSection(),
              const SizedBox(height: 48),

              // 6. Frequently Asked Questions
              const PremiumFaqSection(),
              const SizedBox(height: 60),
            ],
          ),

          // Loading overlay
          if (controller.rxIsLoading.value || controller.isSimulating.value)
            Positioned.fill(
              child: ColoredBox(
                color: bgColor.withValues(alpha: 0.8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textPrimary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing membership details...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
