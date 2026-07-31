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
    final controller = Get.put(PremiumController());

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // True dark theme background
      appBar: AppBar(
        title: Row(
          children: [
            // Play Button Icon Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Truthworld Premium',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
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
                    // 1. Premium Landing Hero
                    _buildHeroSection(
                      context,
                      controller,
                      isPremium,
                      currentPlanId,
                    ),

                    // 2. Feature Cards List
                    _buildFeatureGrid(context),

                    // 3. User Membership Status Panel / Sandbox Panel
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

                    // 4. Plan Selector (Visible if not subscribed)
                    if (!isPremium) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Choose the plan that fits you',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ad-free videos, offline downloads, background play, and more.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
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

                    // 5. Compare Table
                    const SizedBox(height: 48),
                    const Text(
                      'Compare Free vs Premium',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildComparisonTable(context),
                    ),

                    // 6. FAQs
                    const SizedBox(height: 48),
                    const Text(
                      'Frequently asked questions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
              if (controller.isLoading.value || controller.isSimulating.value)
                ColoredBox(
                  color: AppColors.bgPage.withValues(alpha: 0.75),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.error,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing membership details...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
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
    final selectedId = controller.selectedPlanId.value;
    var trialText = '7 days free • Then ₹150/month';
    if (selectedId == 'individual_yearly') {
      trialText = 'Prepaid plan • ₹1,500/year (~16% discount)';
    } else if (selectedId == 'family_monthly') {
      trialText = '7 days free • Then ₹250/month for up to 6 accounts';
    } else if (selectedId == 'student_monthly') {
      trialText = '7 days free • Then ₹100/month (Verified student rate)';
    } else if (selectedId == 'creator_pro_monthly') {
      trialText = '₹300/month • Includes 4K High-Bitrate Upload Priority';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF231815), Color(0xFF0F0F0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Truthworld',
                style: context.typography.logo.copyWith(
                  fontSize: 32,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
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
          const Text(
            'Ad-free, offline, and in the background',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enjoy Truthworld videos and audio uninterrupted. Experience enhanced 1080p Premium resolution, AI dubbing, offline downloads, and background playback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
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
                  backgroundColor: const Color(0xFF3EA6FF),
                  foregroundColor: AppColors.bgPage,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  selectedId == 'individual_yearly'
                      ? 'Get Prepaid Annual Plan'
                      : 'Try 7 Days Free',
                  style: const TextStyle(
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only new members are eligible for trials. Cancel anytime.',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Active Premium Member',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
    final features = [
      _FeatureItem(
        icon: Icons.play_disabled_rounded,
        title: 'Ad-free playback',
        description:
            'Watch videos without ad interruptions. Enjoy Truthworld videos seamlessly across mobile, desktop, TV, and tablet.',
      ),
      _FeatureItem(
        icon: Icons.download_for_offline_rounded,
        title: 'Download and go',
        description:
            'Save your favorite videos and playlists offline for when you are traveling or low on internet data.',
      ),
      _FeatureItem(
        icon: Icons.picture_in_picture_rounded,
        title: 'Background play & PiP',
        description:
            'Keep videos and audio playing when your screen is locked or while multitasking in other apps.',
      ),
      _FeatureItem(
        icon: Icons.hd_rounded,
        title: 'Enhanced Bitrate 1080p & 4K',
        description:
            'Experience ultra-crisp video clarity with high bitrate 1080p Premium and 4K Ultra HD streaming options.',
      ),
      _FeatureItem(
        icon: Icons.translate_rounded,
        title: 'Multilingual AI Dubbing',
        description:
            'Unlock instant multilingual AI voice dubbing and auto-translated audio tracks for global video content.',
      ),
      _FeatureItem(
        icon: Icons.workspace_premium_rounded,
        title: 'Creator Supporter Perks',
        description:
            'Get exclusive supporter badges in live chat, priority video upload processing, and channel perks.',
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
                    color: Color(0xFF212121),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        feat.description,
                        style: const TextStyle(
                          fontSize: 13,
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
    if (isPremium) {
      var planName = 'Individual Monthly';
      var planPrice = '₹150/month';
      if (planId == 'individual_yearly') {
        planName = 'Individual Annual (Prepaid)';
        planPrice = '₹1,500/year';
      } else if (planId == 'family_monthly') {
        planName = 'Family Monthly';
        planPrice = '₹250/month';
      } else if (planId == 'student_monthly') {
        planName = 'Student Monthly';
        planPrice = '₹100/month';
      } else if (planId == 'creator_pro_monthly') {
        planName = 'Creator Pro Membership';
        planPrice = '₹300/month';
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Membership Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2D2D2D)),
            const SizedBox(height: 12),
            _buildInfoRow('Plan', planName),
            _buildInfoRow('Price', planPrice),
            _buildInfoRow(
              'Billing Cycle',
              planId == 'individual_yearly'
                  ? 'Non-recurring (1 year prepaid)'
                  : 'Recurring monthly',
            ),
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
                child: const Text(
                  'Cancel Membership',
                  style: TextStyle(
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
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Developer Sandbox Panel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Instantly toggle Premium activation to verify ad-free playback, offline downloads, and background mode locally.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
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
              label: const Text(
                'Simulate Premium Unlock',
                style: TextStyle(
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
    final plans = [
      _PlanDetails(
        id: 'individual_monthly',
        title: 'Individual Plan',
        priceLabel: '₹150/month',
        tagline: '7 Days Free Trial',
        description:
            'Enjoy ad-free streaming, background play, and offline downloads on one account.',
      ),
      _PlanDetails(
        id: 'individual_yearly',
        title: 'Individual Annual (Prepaid)',
        priceLabel: '₹1,500/year',
        tagline: 'Save ~16%',
        description:
            '12 months of non-recurring premium access with a single discounted checkout payment.',
      ),
      _PlanDetails(
        id: 'family_monthly',
        title: 'Family Plan',
        priceLabel: '₹250/month',
        tagline: '7 Days Free Trial',
        description:
            'Share with up to 5 family members (ages 13+) living in the same household. Each member gets their own private account recommendations.',
      ),
      _PlanDetails(
        id: 'student_monthly',
        title: 'Student Plan',
        priceLabel: '₹100/month',
        tagline: '7 Days Free Trial',
        description:
            'Verifiable student discount for eligible undergraduate/graduate university students.',
      ),
      _PlanDetails(
        id: 'creator_pro_monthly',
        title: 'Creator Pro Plan',
        priceLabel: '₹300/month',
        tagline: 'For Content Creators',
        description:
            'Includes all Premium perks + 4K high bitrate upload priority, exclusive live chat supporter badges, and custom channel tools.',
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
                  ? const Color(0xFF282828)
                  : const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.error : const Color(0xFF2D2D2D),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selection indicator icon
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            plan.priceLabel.split('/')[0],
                            style: TextStyle(
                              fontSize: 16,
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
                                  ? AppColors.error.withValues(alpha: 0.15)
                                  : AppColors.bgDivider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plan.tagline,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '/${plan.priceLabel.split('/')[1]}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        plan.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
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
    final selectedId = controller.selectedPlanId.value;
    var label = 'Start 7-Day Free Trial';
    if (selectedId == 'individual_yearly') {
      label = 'Get Annual Plan (Prepaid)';
    } else if (selectedId == 'creator_pro_monthly') {
      label = 'Upgrade to Creator Pro';
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
          style: const TextStyle(
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
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D2D)),
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
            _buildTableHeaderRow(),
            _buildTableRow('Ad-free Video & Audio', 'With Ads', 'Ad-Free'),
            _buildTableRow('Offline Downloads', 'No', 'Unlimited'),
            _buildTableRow('Background & PiP Play', 'No', 'Included'),
            _buildTableRow(
              '1080p Premium & 4K Quality',
              'Standard',
              'Enhanced Bitrate',
            ),
            _buildTableRow('Multilingual AI Dubbing', 'Basic', 'Unlocked'),
            _buildTableRow('Family Sharing (5 members)', 'No', 'Family Plan'),
            _buildTableRow('Student Discount', 'No', 'Student Plan'),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeaderRow() {
    return const TableRow(
      decoration: BoxDecoration(color: Color(0xFF2D2D2D)),
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Features',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Free',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Premium',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String feature, String freeVal, String premiumVal) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            feature,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            freeVal,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            premiumVal,
            style: const TextStyle(
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
    final faqs = [
      _FaqItem(
        q: 'What is Truthworld Premium?',
        a: 'Truthworld Premium is a paid membership that elevates your viewing experience with ad-free videos, background play, offline downloads, enhanced 1080p bitrate resolution, and multilingual AI dubbing.',
      ),
      _FaqItem(
        q: 'How does the Family Plan work?',
        a: 'The Family Plan allows you to share premium privileges with up to 5 family members (ages 13+) living in the same household. Each family member gets their own private account recommendations and library.',
      ),
      _FaqItem(
        q: 'Who is eligible for the Student Plan?',
        a: 'Full-time students at accredited universities or higher education establishments are eligible. Annual verification is required to maintain student pricing.',
      ),
      _FaqItem(
        q: 'What extra features are in Creator Pro?',
        a: 'Creator Pro includes all Truthworld Premium features plus priority video encoding queue for 4K video uploads, custom supporter badges in live streams, and channel monetization tools.',
      ),
      _FaqItem(
        q: 'Can I cancel my subscription at any time?',
        a: 'Yes. You can cancel your subscription at any time directly through the Premium screen or your Account Settings page. Cancelled plans remain active until the end of your billing cycle.',
      ),
      _FaqItem(
        q: 'How does the 7-day free trial work?',
        a: "First-time subscribers are eligible for a 7-day free trial. You won't be charged until the trial period ends, and you can cancel anytime before then.",
      ),
    ];

    return Column(
      children: faqs.map((faq) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2D2D2D)),
          ),
          child: ExpansionTile(
            title: Text(
              faq.q,
              style: const TextStyle(
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
                style: const TextStyle(
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
