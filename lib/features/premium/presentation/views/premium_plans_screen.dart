import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';

class PremiumPlansScreen extends StatelessWidget {
  const PremiumPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PremiumController());

    return Scaffold(
      backgroundColor: const Color(
        0xFF0F0F0F,
      ), // True YouTube dark theme background
      appBar: AppBar(
        title: Row(
          children: [
            // Play Button Icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Premium',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        final auth = AuthService.to;
        final bool isPremium = auth.isPremiumUser.value;
        final String? currentPlanId = auth.premiumPlanId.value;

        return Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. YouTube Premium Landing Hero
                  _buildYouTubeHeroSection(
                    context,
                    controller,
                    isPremium,
                    currentPlanId,
                  ),

                  // 2. Feature Cards List (YouTube Premium Style)
                  _buildFeatureGrid(context),

                  // 3. User Membership Status Panel / Sandbox Panel
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
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
                    Text(
                      'Choose the plan that fits you',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildYouTubePlansList(context, controller),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildCheckoutButton(context, controller),
                    ),
                  ],

                  // 5. Compare Table
                  const SizedBox(height: 48),
                  Text(
                    'Compare Free vs Premium',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildComparisonTable(context),
                  ),

                  // 6. FAQs
                  const SizedBox(height: 48),
                  Text(
                    'Frequently asked questions',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildFaqSection(context),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Loading overlay
            if (controller.isLoading.value || controller.isSimulating.value)
              Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing membership details...',
                        style: TextStyle(
                          color: Colors.white70,
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
    );
  }

  Widget _buildYouTubeHeroSection(
    BuildContext context,
    PremiumController controller,
    bool isPremium,
    String? planId,
  ) {
    String selectedId = controller.selectedPlanId.value;
    String trialText = "7 days free • Then ₹129.00/month";
    if (selectedId == 'individual_yearly') {
      trialText = "Prepaid plan • ₹1,290.00/year";
    } else if (selectedId == 'family_monthly') {
      trialText = "7 days free • Then ₹189.00/month";
    } else if (selectedId == 'student_monthly') {
      trialText = "7 days free • Then ₹79.00/month";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F1F1F), Color(0xFF0F0F0F)],
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Premium',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Ad-free, offline, and in the background',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enjoy Truthworld and Truthworld Music uninterrupted. Plus, get enhanced bitrate 1080p Premium quality.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              height: 52,
              child: ElevatedButton(
                onPressed: () => controller.purchasePlan(selectedId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF3EA6FF,
                  ), // Classic YouTube blue button
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  selectedId == 'individual_yearly'
                      ? 'Get Prepaid Plan'
                      : 'Try it free',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trialText,
              style: const TextStyle(fontSize: 13, color: Colors.white38),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only new members are eligible for trials. Cancel anytime.',
              style: TextStyle(fontSize: 11, color: Colors.white30),
            ),
          ] else ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Active Premium Member',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.amber,
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
            'Watch videos without interruptions. Enjoy Truthworld videos without ads on your mobile device, tablet, computer, or TV.',
      ),
      _FeatureItem(
        icon: Icons.download_for_offline_rounded,
        title: 'Download and go',
        description:
            'Save videos for when you are low on data or cannot get online—like when you are on a plane or commuting.',
      ),
      _FeatureItem(
        icon: Icons.picture_in_picture_rounded,
        title: 'Background play',
        description:
            'Keep videos playing when your screen is off or you are using other apps. Listen to your favorite creators while multitasking.',
      ),
      _FeatureItem(
        icon: Icons.hd_rounded,
        title: 'Enhanced 1080p Quality',
        description:
            'Get extra crisp video quality with our high bitrate 1080p Premium resolution option.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        children: features.map((feat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
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
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        feat.description,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          color: Colors.white54,
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
      String planName = "Individual Monthly";
      String planPrice = "₹129/month";
      if (planId == "individual_yearly") {
        planName = "Individual Annual";
        planPrice = "₹1,290/year";
      } else if (planId == "family_monthly") {
        planName = "Family Monthly";
        planPrice = "₹189/month";
      } else if (planId == "student_monthly") {
        planName = "Student Monthly";
        planPrice = "₹79/month";
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.3),
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
                  color: Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Membership details',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                  ? 'Non-recurring (1 year)'
                  : 'Recurring monthly',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => controller.cancelSimulated(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Cancel Membership',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Developer sandbox simulation card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2D2D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Developer Sandbox Panel',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bypass external payment loops and instantly activate/deactivate Premium tiers to test restriction bypasses.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.offline_bolt_rounded,
                color: Colors.black87,
              ),
              label: Text(
                'Simulate Upgrade (Unlock)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                final auth = AuthService.to;
                if (!auth.isAuthenticated.value) {
                  AppSnackbar.show(
                    'Authentication Required',
                    'Please sign in to upgrade.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                } else {
                  controller.upgradeSimulated(controller.selectedPlanId.value);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
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

  Widget _buildYouTubePlansList(
    BuildContext context,
    PremiumController controller,
  ) {
    final plans = [
      _PlanDetails(
        id: 'individual_monthly',
        title: 'Individual Membership',
        priceLabel: '₹129.00/month',
        tagline: '7 days free trial',
        description:
            'Enjoy ad-free streaming, background play, and offline downloads on one account.',
      ),
      _PlanDetails(
        id: 'individual_yearly',
        title: 'Annual Membership (Prepaid)',
        priceLabel: '₹1,290.00/year',
        tagline: 'Save ~17%',
        description:
            '12 months of non-recurring premium access. Single checkout payment.',
      ),
      _PlanDetails(
        id: 'family_monthly',
        title: 'Family Membership',
        priceLabel: '₹189.00/month',
        tagline: '7 days free trial',
        description:
            'Add up to 5 family members (ages 13+) living in the same household.',
      ),
      _PlanDetails(
        id: 'student_monthly',
        title: 'Student Membership',
        priceLabel: '₹79.00/month',
        tagline: '7 days free trial',
        description:
            'Verifiable student discount for eligible undergraduate/graduate students.',
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
                color: isSelected ? Colors.red : const Color(0xFF2D2D2D),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio icon selector
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? Colors.red : Colors.white54,
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
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            plan.priceLabel.split('/')[0],
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.red : Colors.white,
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
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plan.tagline,
                              style: TextStyle(
                                color: isSelected ? Colors.red : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '/${plan.priceLabel.split('/')[1]}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        plan.description,
                        style: const TextStyle(
                          color: Colors.white54,
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
    String label = "Start 7-Day Free Trial";
    if (selectedId == 'individual_yearly') {
      label = "Get Annual Plan (Prepaid)";
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () => controller.purchasePlan(selectedId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors
              .white, // YouTube styles the primary action button white in dark pages
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
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
        border: Border.all(color: const Color(0xFF2D2D2D), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.0),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.2),
          },
          children: [
            _buildTableHeaderRow(),
            _buildTableRow('Ad-free Video Playback', 'With Ads', 'Ad-Free'),
            _buildTableRow('Offline Downloads', 'No', 'Unlimited'),
            _buildTableRow('Background Play', 'No', 'Yes'),
            _buildTableRow(
              '1080p Premium Resolution',
              'Standard',
              'Enhanced Bitrate + 4K',
            ),
            _buildTableRow('AI Dubbing & Translation', 'Basic', 'Unlocked'),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFF2D2D2D)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Features',
            style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Free',
            style: TextStyle(fontFamily: 'Roboto', color: Colors.white54),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Premium',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.red,
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Text(
            feature,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Text(
            freeVal,
            style: const TextStyle(fontSize: 13, color: Colors.white38),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Text(
            premiumVal,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.red,
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
        q: "What is Truthworld Premium?",
        a: "Truthworld Premium is a paid membership that elevates your viewing experience with ad-free videos, background play, offline downloads, and higher-quality 1080p Premium bitrates.",
      ),
      _FaqItem(
        q: "How does the Family Plan work?",
        a: "The Family Plan allows you to share premium privileges with up to 5 family members (ages 13+) living in the same household. Each family member gets their own personalized account recommendations and library.",
      ),
      _FaqItem(
        q: "Who is eligible for the Student Plan?",
        a: "Full-time students at accredited universities or higher education establishments are eligible. Annual verification is required to maintain student pricing.",
      ),
      _FaqItem(
        q: "Can I cancel my subscription at any time?",
        a: "Yes. You can cancel your subscription at any time directly through the Premium screen or your Account Settings page. Cancelled plans remain active until the end of your billing cycle.",
      ),
      _FaqItem(
        q: "How does the 7-day free trial work?",
        a: "First-time subscribers are eligible for a 7-day free trial. You won't be charged until the trial period ends, and you will receive a reminder beforehand.",
      ),
    ];

    return Column(
      children: faqs.map((faq) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2D2D2D), width: 1),
          ),
          child: ExpansionTile(
            title: Text(
              faq.q,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            shape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                faq.a,
                style: const TextStyle(
                  color: Colors.white54,
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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
  final IconData icon;
  final String title;
  final String description;
  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _PlanDetails {
  final String id;
  final String title;
  final String priceLabel;
  final String tagline;
  final String description;

  _PlanDetails({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.tagline,
    required this.description,
  });
}

class _FaqItem {
  final String q;
  final String a;
  _FaqItem({required this.q, required this.a});
}
