import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class PremiumPlansScreen extends StatelessWidget {
  const PremiumPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PremiumController>();
    final typo = context.twTypography;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        title: Text(
          'Truthworld Premium',
          style: typo.headline.copyWith(
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final auth = AuthService.to;
          final isPremium = auth.isPremiumUser.value;
          final currentPlanId = auth.premiumPlanId.value;

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. YouTube Premium Style Hero Banner
                    _buildHeroSection(
                      context,
                      controller,
                      isPremium,
                      currentPlanId,
                    ),

                    // 2. Feature Cards List
                    _buildFeatureGrid(context),

                    // 3. User Membership Status / Sandbox Panel
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: _buildMembershipStatusCard(
                        context,
                        controller,
                        isPremium,
                        currentPlanId,
                      ),
                    ),

                    // 4. Plan Selector ($2 Individual, $5 Family, $10 4K & Factchecked)
                    if (!isPremium) ...[
                      const SizedBox(height: 32),
                      Text(
                        'Choose the plan that fits you',
                        style: typo.display.copyWith(
                          fontSize: 22,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Ad-free videos, background play, offline downloads, and verified fact-checking.',
                          textAlign: TextAlign.center,
                          style: typo.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildPlansList(context, controller),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildCheckoutButton(context, controller),
                      ),
                    ],

                    // 5. Compare Free vs Premium Table
                    const SizedBox(height: 48),
                    Text(
                      'Compare Free vs Premium',
                      style: typo.display.copyWith(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildComparisonTable(context),
                    ),

                    // 6. Frequently Asked Questions
                    const SizedBox(height: 48),
                    Text(
                      'Frequently asked questions',
                      style: typo.display.copyWith(
                        fontSize: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildFaqSection(context),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Loading overlay
              if (controller.rxIsLoading.value || controller.isSimulating.value)
                ColoredBox(
                  color: AppColors.bgPage.withValues(alpha: 0.75),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Processing membership details...',
                          style: typo.body.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    PremiumController controller,
    bool isPremium,
    String? planId,
  ) {
    final typo = context.twTypography;
    final selectedId = controller.selectedPlanId.value;

    var trialText = r'7 days free • Then $2/month';
    if (selectedId == 'family_monthly') {
      trialText = r'7 days free • Then $5/month for up to 6 accounts';
    } else if (selectedId == '4k_factchecked_monthly') {
      trialText = r'7 days free • Then $10/month (4K + Fact-Checked)';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.bgSurfaceHigh, AppColors.bgPage],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Truthworld',
                style: typo.logo.copyWith(
                  fontSize: 32,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PREMIUM',
                  style: typo.overline.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Ad-free, offline, 4K & Fact-Checked',
            textAlign: TextAlign.center,
            style: typo.hero.copyWith(
              fontSize: 26,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enjoy uninterrupted Truthworld videos with ad-free playback, offline downloads, background play, 4K Ultra HD streaming, and real-time AI fact-checking on every video.',
            textAlign: TextAlign.center,
            style: typo.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: 280,
              height: 52,
              child: ElevatedButton(
                onPressed: () => controller.purchasePlan(selectedId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.bgPage,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  'Try 7 Days Free',
                  style: typo.button.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bgPage,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trialText,
              style: typo.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Only new members are eligible for trials. Cancel anytime.',
              style: typo.caption.copyWith(color: AppColors.textTertiary),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Active Premium Member',
                    style: typo.label.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final typo = context.twTypography;
    final features = [
      _FeatureItem(
        icon: Icons.play_disabled_rounded,
        title: 'Ad-free playback',
        description:
            'Watch videos without ad interruptions. Enjoy Truthworld seamlessly across mobile, desktop, TV, and tablet.',
      ),
      _FeatureItem(
        icon: Icons.verified_rounded,
        title: 'Every Video Fact-Checked',
        description:
            'Get real-time AI claim verification, source transparency badges, and truth-score breakdowns on every video.',
      ),
      _FeatureItem(
        icon: Icons.hd_rounded,
        title: '4K Ultra HD & High Bitrate',
        description:
            'Experience ultra-crisp 4K UHD streaming with enhanced bitrate audio and crystal clear visuals.',
      ),
      _FeatureItem(
        icon: Icons.download_for_offline_rounded,
        title: 'Download and go',
        description:
            'Save your favorite videos and playlists offline for uninterrupted viewing when traveling or low on data.',
      ),
      _FeatureItem(
        icon: Icons.picture_in_picture_rounded,
        title: 'Background play & PiP',
        description:
            'Keep audio and videos playing when your screen is locked or while multitasking in other apps.',
      ),
      _FeatureItem(
        icon: Icons.translate_rounded,
        title: 'Multilingual AI Dubbing',
        description:
            'Unlock instant multilingual AI voice dubbing and auto-translated audio tracks for global content.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: features.map((feat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurfaceHover,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(feat.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feat.title,
                        style: typo.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        feat.description,
                        style: typo.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMembershipStatusCard(
    BuildContext context,
    PremiumController controller,
    bool isPremium,
    String? planId,
  ) {
    final typo = context.twTypography;
    final auth = AuthService.to;

    if (auth.isTrialExpired || (!isPremium && auth.premiumExpiresAt.value != null)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_off_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  '7-Day Free Trial Expired',
                  style: typo.title.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your 7-day free trial ended on ${auth.formattedExpiresDate}. Premium features (4K, ad-free streaming, background play, and fact-checking) have been paused.',
              style: typo.bodySmall.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose a plan below to resume your Premium membership.',
              style: typo.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isPremium) {
      var planName = r'$2 Individual Plan';
      var planPrice = r'$2/month';
      if (planId == 'family_monthly') {
        planName = r'$5 Family Plan';
        planPrice = r'$5/month';
      } else if (planId == '4k_factchecked_monthly') {
        planName = r'$10 4K & Fact-Checked Plan';
        planPrice = r'$10/month';
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Membership Details',
                  style: typo.headline.copyWith(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.bgDivider),
            const SizedBox(height: 12),
            _buildInfoRow(context, 'Plan', planName),
            _buildInfoRow(context, 'Price', planPrice),
            _buildInfoRow(context, 'Billing Cycle', '7 Days Free Trial'),
            _buildInfoRow(context, 'Activated On', auth.formattedStartedDate),
            _buildInfoRow(context, 'Expires / Renews On', auth.formattedExpiresDate),
            _buildInfoRow(context, 'Time Remaining', auth.formattedRemainingTime),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => controller.cancelSimulated(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Cancel Membership',
                  style: typo.button.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Developer Sandbox simulation card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Developer Sandbox Panel',
                style: typo.title.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Instantly toggle Premium activation to verify ad-free playback, 4K quality, offline downloads, and fact-checking status locally.',
            style: typo.caption.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.offline_bolt_rounded,
                color: Colors.white,
              ),
              label: Text(
                'Simulate Premium Unlock',
                style: typo.button.copyWith(
                  color: AppColors.bgPage,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                final auth = AuthService.to;
                if (!auth.isAuthenticated.value) {
                  AppSnackbar.show(
                    'Authentication Required',
                    'Please sign in to simulate premium upgrade.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.error,
                    colorText: AppColors.textPrimary,
                  );
                } else {
                  await controller.upgradeSimulated(
                    controller.selectedPlanId.value,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansList(
    BuildContext context,
    PremiumController controller,
  ) {
    final typo = context.twTypography;
    final plans = [
      _PlanDetails(
        id: 'individual_monthly',
        title: r'$2 Individual Plan',
        priceLabel: r'$2/month',
        tagline: '7 Days Free Trial',
        description:
            'Ad-free streaming, background play, and offline downloads for 1 personal account.',
      ),
      _PlanDetails(
        id: 'family_monthly',
        title: r'$5 Family Plan',
        priceLabel: r'$5/month',
        tagline: '7 Days Free Trial',
        description:
            'Share Premium benefits with up to 5 family members (6 accounts total) in your household.',
      ),
      _PlanDetails(
        id: '4k_factchecked_monthly',
        title: r'$10 4K & Fact-Checked Plan',
        priceLabel: r'$10/month',
        tagline: 'Ultimate 4K + Every Video Fact-Checked',
        description:
            'Includes 4K Ultra HD streaming priority + Every video Fact-Checked with real-time AI claim analysis and source links.',
      ),
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plans.length,
      separatorBuilder: (context, idx) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final plan = plans[idx];
        final isSelected = controller.selectedPlanId.value == plan.id;

        return InkWell(
          onTap: () => controller.selectPlan(plan.id),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.bgSurfaceHover
                  : AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.error : AppColors.bgDivider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              plan.title,
                              style: typo.title.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            plan.priceLabel.split('/')[0],
                            style: typo.title.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.errorContainer
                                  : AppColors.bgDivider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plan.tagline,
                              style: typo.caption.copyWith(
                                color: isSelected
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '/${plan.priceLabel.split('/')[1]}',
                            style: typo.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        plan.description,
                        style: typo.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    PremiumController controller,
  ) {
    final typo = context.twTypography;
    final selectedId = controller.selectedPlanId.value;
    var label = 'Start 7-Day Free Trial';
    if (selectedId == '4k_factchecked_monthly') {
      label = r'Get 4K & Fact-Checked Plan ($10/mo)';
    } else if (selectedId == 'family_monthly') {
      label = r'Get Family Plan ($5/mo)';
    } else {
      label = r'Get Individual Plan ($2/mo)';
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () => controller.purchasePlan(selectedId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.bgPage,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          label,
          style: typo.button.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.bgPage,
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(1.2),
          },
          children: [
            _buildTableHeaderRow(context),
            _buildTableRow(
              context,
              'Ad-free Video & Audio',
              'With Ads',
              'Ad-Free',
            ),
            _buildTableRow(context, 'Offline Downloads', 'No', 'Unlimited'),
            _buildTableRow(context, 'Background & PiP Play', 'No', 'Included'),
            _buildTableRow(
              context,
              'Stream Quality',
              'Up to 1080p',
              r'4K Ultra HD ($10)',
            ),
            _buildTableRow(
              context,
              'Fact-Checked Videos',
              'Standard',
              r'Every Video Verified ($10)',
            ),
            _buildTableRow(
              context,
              'Multilingual AI Dubbing',
              'Basic',
              'Unlocked',
            ),
            _buildTableRow(
              context,
              'Family Sharing (6 accounts)',
              'No',
              r'Family ($5)',
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeaderRow(BuildContext context) {
    final typo = context.twTypography;
    return TableRow(
      decoration: const BoxDecoration(color: AppColors.bgElevated),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Features',
            style: typo.title.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Free',
            style: typo.title.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Premium',
            style: typo.title.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(
    BuildContext context,
    String feature,
    String freeVal,
    String premiumVal,
  ) {
    final typo = context.twTypography;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            feature,
            style: typo.bodySmall.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            freeVal,
            style: typo.caption.copyWith(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            premiumVal,
            style: typo.caption.copyWith(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaqSection(BuildContext context) {
    final typo = context.twTypography;
    final faqs = [
      _FaqItem(
        q: 'What is Truthworld Premium?',
        a: 'Truthworld Premium is a subscription service providing ad-free viewing, background play, offline downloads, 4K video quality, and automated AI fact-checking on every video.',
      ),
      _FaqItem(
        q: r'What is included in the $10 4K & Fact-Checked Plan?',
        a: r'The $10/month plan unlocks 4K Ultra HD high-bitrate streaming priority as well as comprehensive fact-checking badges, claim breakdowns, and verified source citations on every video on Truthworld.',
      ),
      _FaqItem(
        q: r'How does the $5 Family Plan work?',
        a: r'The $5/month Family Plan allows you to share premium privileges with up to 5 family members (6 accounts total) living in your household. Each member gets their own private recommendations.',
      ),
      _FaqItem(
        q: r'How does the $2 Individual Plan work?',
        a: r'The $2/month Individual Plan gives single-account access to ad-free videos, background playback, and offline downloads on all devices.',
      ),
      _FaqItem(
        q: 'Can I cancel my subscription at any time?',
        a: 'Yes. You can cancel your subscription at any time directly through the Premium screen or your Account Settings. Cancelled plans remain active until the end of your billing cycle.',
      ),
      _FaqItem(
        q: 'How does the 7-day free trial work?',
        a: "First-time subscribers receive a 7-day free trial. You won't be charged until the trial ends, and you can cancel anytime before then.",
      ),
    ];

    return Column(
      children: faqs.map((faq) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: ExpansionTile(
            title: Text(
              faq.q,
              style: typo.title.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            shape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                faq.a,
                style: typo.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final typo = context.twTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: typo.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: typo.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
}

class _PlanDetails {
  _PlanDetails({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.tagline,
    required this.description,
  });
  final String id;
  final String title;
  final String priceLabel;
  final String tagline;
  final String description;
}

class _FaqItem {
  _FaqItem({required this.q, required this.a});
  final String q;
  final String a;
}
