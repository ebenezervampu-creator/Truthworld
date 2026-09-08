import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS (EXACT MATCH WITH LIBRARY SCREEN)
// ==========================================================================

const Color bgColor = AppColors.bgPage;
const Color surfaceColor = AppColors.bgPage;
const Color cardColor = Color(0xFF1E1E1E);
const Color primaryText = AppColors.textPrimary;
const Color secondaryText = AppColors.textSecondary;
const Color accentColor = AppColors.textPrimary;
const Color buttonBg = AppColors.bgSurfaceHover;

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================

const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

// ==========================================================================
// MODERNIZED TRUTHWORLD PREMIUM PAGE
// ==========================================================================

class PremiumPlansScreen extends StatefulWidget {
  const PremiumPlansScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends State<PremiumPlansScreen>
    with TickerProviderStateMixin {
  late final PremiumController _controller;

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<PremiumController>()
        ? Get.find<PremiumController>()
        : Get.put(PremiumController());
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context);
        } else if (isTablet) {
          return _buildTabletLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildModernAppBar(context, isDesktop: true),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Content Area
            Expanded(
              flex: 7,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: _buildMainContentSections(context, isDesktop: true),
              ),
            ),
            // Right Sidebar for Membership Status & Quick Benefits
            Expanded(
              flex: 3,
              child: _buildDesktopSidebar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildModernAppBar(context, isTablet: true),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _buildMainContentSections(context, isTablet: true),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildModernAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: _buildMainContentSections(context),
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
        children: [
          const AppLogo(
            size: 28,
            borderRadius: 6,
          ),
          const SizedBox(width: 12),
          Text(
            'Truthworld Premium',
            style: TextStyle(
              fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
              fontWeight: FontWeight.bold,
              color: primaryText,
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
          onPressed: () => _showMoreOptionsBottomSheet(context),
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
            child: Icon(icon, color: secondaryText, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContentSections(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Obx(() {
      final auth = AuthService.to;
      final isPremium = auth.isPremiumUser.value;
      final currentPlanId = auth.premiumPlanId.value;

      return Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. YouTube Premium Style Hero Banner
              _buildHeroSection(
                context,
                isPremium,
                currentPlanId,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              const SizedBox(height: 32),

              // 2. Feature Cards Grid
              _buildFeatureGrid(
                context,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              const SizedBox(height: 32),

              // 3. User Membership Status & Sandbox Panel (on Mobile/Tablet or Main flow)
              if (!isDesktop) ...[
                _buildMembershipStatusCard(context, isPremium, currentPlanId),
                const SizedBox(height: 32),
              ],

              // 4. Plan Selector ($2 Individual, $5 Family, $10 4K & Factchecked)
              if (!isPremium) ...[
                _buildPlanSelectorSection(
                  context,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
                const SizedBox(height: 48),
              ],

              // 5. Compare Free vs Premium Table
              _buildComparisonSection(context),
              const SizedBox(height: 48),

              // 6. Frequently Asked Questions
              _buildFaqSection(context),
              const SizedBox(height: 60),
            ],
          ),

          // Loading overlay
          if (_controller.rxIsLoading.value || _controller.isSimulating.value)
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

  // ==========================================================================
  // HERO SECTION
  // ==========================================================================

  Widget _buildHeroSection(
    BuildContext context,
    bool isPremium,
    String? planId, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final selectedId = _controller.selectedPlanId.value;

    var trialText = r'7 days free • Then $2/month';
    if (selectedId == 'family_monthly') {
      trialText = r'7 days free • Then $5/month for up to 6 accounts';
    } else if (selectedId == '4k_factchecked_monthly') {
      trialText = r'7 days free • Then $10/month (4K + Fact-Checked)';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : (isTablet ? 28 : 20),
        vertical: isDesktop ? 44 : 32,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
        gradient: const LinearGradient(
          colors: [
            buttonBg,
            cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(
                size: 34,
                borderRadius: 8,
              ),
              const SizedBox(width: 10),
              Text(
                'Truthworld',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                  color: primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Ad-free, offline, 4K & Fact-Checked',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 28 : (isTablet ? 24 : 20),
              fontWeight: FontWeight.bold,
              color: primaryText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: const Text(
              'Enjoy uninterrupted Truthworld videos with ad-free playback, offline downloads, background play, 4K Ultra HD streaming, and real-time AI fact-checking on every video.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryText,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!isPremium) ...[
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _controller.purchasePlan(selectedId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Try 7 Days Free',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgPage,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              trialText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only new members are eligible for trials. Cancel anytime.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.success),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Active Premium Member',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 14,
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

  // ==========================================================================
  // FEATURE GRID
  // ==========================================================================

  Widget _buildFeatureGrid(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final features = [
      _FeatureItem(
        icon: Icons.play_disabled_rounded,
        title: 'Ad-free playback',
        description:
            'Watch videos without ad interruptions across mobile, desktop, TV, and tablet.',
      ),
      _FeatureItem(
        icon: Icons.verified_outlined,
        title: 'Every Video Fact-Checked',
        description:
            'Get real-time AI claim verification, source transparency badges, and truth-score breakdowns.',
      ),
      _FeatureItem(
        icon: Icons.hd_rounded,
        title: '4K Ultra HD & High Bitrate',
        description:
            'Experience ultra-crisp 4K UHD streaming with enhanced bitrate audio and crystal clear visuals.',
      ),
      _FeatureItem(
        icon: Icons.file_download_outlined,
        title: 'Download and go',
        description:
            'Save your favorite videos and playlists offline for uninterrupted viewing anywhere.',
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

    if (isDesktop || isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All-Inclusive Benefits',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 145,
            ),
            itemBuilder: (context, index) {
              return _buildFeatureCard(features[index]);
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All-Inclusive Benefits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: features.map((feat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildFeatureCard(feat),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(_FeatureItem feat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              feat.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feat.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feat.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: secondaryText,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MEMBERSHIP STATUS & SANDBOX PANEL
  // ==========================================================================

  Widget _buildMembershipStatusCard(
    BuildContext context,
    bool isPremium,
    String? planId,
  ) {
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
            const Row(
              children: [
                Icon(
                  Icons.timer_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  '7-Day Free Trial Expired',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your 7-day free trial ended on ${auth.formattedExpiresDate}. Premium features (4K, ad-free streaming, background play, and fact-checking) have been paused.',
              style: const TextStyle(
                fontSize: 14,
                color: primaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose a plan below to resume your Premium membership.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: secondaryText,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
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
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Membership Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.bgDivider, height: 1),
            const SizedBox(height: 12),
            _buildInfoRow('Plan', planName),
            _buildInfoRow('Price', planPrice),
            _buildInfoRow('Billing Cycle', '7 Days Free Trial'),
            _buildInfoRow('Activated On', auth.formattedStartedDate),
            _buildInfoRow('Expires / Renews On', auth.formattedExpiresDate),
            _buildInfoRow('Time Remaining', auth.formattedRemainingTime),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.cancelSimulated();
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: buttonBg,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text(
                  'Cancel Membership',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
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
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Developer Sandbox Panel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Instantly toggle Premium activation to verify ad-free playback, 4K quality, offline downloads, and fact-checking status locally.',
            style: TextStyle(
              fontSize: 13,
              color: secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.offline_bolt_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Simulate Premium Unlock',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgPage,
                ),
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
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
                  await _controller.upgradeSimulated(
                    _controller.selectedPlanId.value,
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

  // ==========================================================================
  // PLAN SELECTOR SECTION
  // ==========================================================================

  Widget _buildPlanSelectorSection(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose the plan that fits you',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ad-free videos, background play, offline downloads, and verified fact-checking.',
          style: TextStyle(
            fontSize: 14,
            color: secondaryText,
          ),
        ),
        const SizedBox(height: 20),
        _buildPlansList(context),
        const SizedBox(height: 24),
        _buildCheckoutButton(context),
      ],
    );
  }

  Widget _buildPlansList(BuildContext context) {
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
        final isSelected = _controller.selectedPlanId.value == plan.id;

        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _controller.selectPlan(plan.id);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected ? buttonBg : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.08),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                          ),
                          Text(
                            plan.priceLabel.split('/')[0],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.textPrimary.withValues(alpha: 0.15)
                                  : buttonBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              plan.tagline,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                          ),
                          Text(
                            '/${plan.priceLabel.split('/')[1]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        plan.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                          height: 1.35,
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

  Widget _buildCheckoutButton(BuildContext context) {
    final selectedId = _controller.selectedPlanId.value;
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
        onPressed: () {
          HapticFeedback.mediumImpact();
          _controller.purchasePlan(selectedId);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.bgPage,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
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

  // ==========================================================================
  // COMPARISON SECTION
  // ==========================================================================

  Widget _buildComparisonSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare Free vs Premium',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
            ),
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
                  'Ad-free Video & Audio',
                  'With Ads',
                  'Ad-Free',
                ),
                _buildTableRow('Offline Downloads', 'No', 'Unlimited'),
                _buildTableRow('Background & PiP Play', 'No', 'Included'),
                _buildTableRow(
                  'Stream Quality',
                  'Up to 1080p',
                  r'4K Ultra HD ($10)',
                ),
                _buildTableRow(
                  'Fact-Checked Videos',
                  'Standard',
                  r'Every Video Verified ($10)',
                ),
                _buildTableRow(
                  'Multilingual AI Dubbing',
                  'Basic',
                  'Unlocked',
                ),
                _buildTableRow(
                  'Family Sharing (6 accounts)',
                  'No',
                  r'Family ($5)',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableHeaderRow(BuildContext context) {
    return const TableRow(
      decoration: BoxDecoration(color: buttonBg),
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Features',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Free',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Premium',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(
    String feature,
    String freeVal,
    String premiumVal,
  ) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            feature,
            style: const TextStyle(
              fontSize: 14,
              color: secondaryText,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            freeVal,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            premiumVal,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // FAQ SECTION
  // ==========================================================================

  Widget _buildFaqSection(BuildContext context) {
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: faqs.map((faq) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  title: Text(
                    faq.q,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      faq.a,
                      style: const TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================================================
  // DESKTOP SIDEBAR
  // ==========================================================================

  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MEMBERSHIP OVERVIEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final auth = AuthService.to;
              return _buildMembershipStatusCard(
                context,
                auth.isPremiumUser.value,
                auth.premiumPlanId.value,
              );
            }),
            const SizedBox(height: 32),
            const Text(
              'QUICK SHORTCUTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: secondaryText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildSidebarAction(
              icon: Icons.history_rounded,
              title: 'Watch History',
              onTap: () => Get.toNamed('/watchhistory'),
            ),
            _buildSidebarAction(
              icon: Icons.video_collection_rounded,
              title: 'My Videos',
              onTap: () => Get.toNamed('/myvideos'),
            ),
            _buildSidebarAction(
              icon: Icons.file_download_outlined,
              title: 'Offline Downloads',
              onTap: () => Get.toNamed('/downloads'),
            ),
            _buildSidebarAction(
              icon: Icons.settings_rounded,
              title: 'Account Settings',
              onTap: () => Get.toNamed('/settings'),
            ),
            _buildSidebarAction(
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              onTap: () => Get.toNamed('/feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: primaryText, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.feedback_outlined, color: Colors.white),
              title: const Text(
                'Send Feedback',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Get.toNamed('/feedback');
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: Colors.white),
              title: const Text(
                'Account Settings',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Get.toNamed('/settings');
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
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

