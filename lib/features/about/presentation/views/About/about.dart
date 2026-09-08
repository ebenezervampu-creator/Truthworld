import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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
// PRODUCTION-READY ABOUT PAGE
// ==========================================================================

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
              final isTablet =
                  constraints.maxWidth >= kMobileBreakpoint &&
                  constraints.maxWidth < kDesktopBreakpoint;
              final isMobile = constraints.maxWidth < kMobileBreakpoint;

              return Scaffold(
                backgroundColor: bgColor,
                appBar: !widget.isDashboard
                    ? _buildModernAppBar(context, isTablet: isTablet)
                    : null,
                body: SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeroSection(
                          context,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildPlatformPillars(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildVerificationPipeline(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildMonetizationModel(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildLeadershipSection(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildCorporateAndGrievance(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildCTASection(
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                        _buildFooter(
                          context,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isMobile: isMobile,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // APP BAR (MATCHING LIBRARY SCREEN)
  // ==========================================================================

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
    bool isTablet = false,
  }) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          const AppLogo(
            size: 28,
            borderRadius: 6,
          ),
          const SizedBox(width: 12),
          Text(
            'About Truthworld',
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.toNamed('/terms'),
          style: TextButton.styleFrom(foregroundColor: secondaryText),
          child: const Text(
            'Terms',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: secondaryText,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Get.toNamed('/privacy'),
          style: TextButton.styleFrom(foregroundColor: secondaryText),
          child: const Text(
            'Privacy',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: secondaryText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(() {
          if (AuthService.to.hasChannel.value) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => Get.toNamed('/channelscreen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 16),
      ],
    );
  }

  // ==========================================================================
  // 1. HERO SECTION (MISSION & VALUE PROPOSITION)
  // ==========================================================================

  Widget _buildHeroSection(
    BuildContext context, {
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          const AppLogo(
            size: 64,
            borderRadius: 16,
          ),
          const SizedBox(height: 24),
          // Tagline Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: const Text(
              'TRUTH-FIRST VIDEO PLATFORM • VERIFIED MEDIA INFRASTRUCTURE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: secondaryText,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Main Headline
          Text(
            'The Next Generation of\nTrusted Video Publishing',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 44 : (isTablet ? 34 : 26),
              fontWeight: FontWeight.bold,
              color: primaryText,
              letterSpacing: -1.0,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 20),

          // Subtitle Paragraph
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: const Text(
              'Truthworld is an enterprise-grade verified video streaming platform built to eliminate misinformation and empower authentic digital creators. By combining automated claim verification, creator-backed source attribution, and global multilingual AI dubbing, Truthworld delivers transparent, accountable, and rewarding video experiences across more than 70 languages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: secondaryText,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Action Buttons
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              Obx(() {
                if (AuthService.to.hasChannel.value) {
                  return const SizedBox.shrink();
                }
                return ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Get.toNamed('/channelscreen');
                  },
                  icon: const Icon(
                    Icons.rocket_launch_rounded,
                    color: AppColors.bgPage,
                    size: 18,
                  ),
                  label: const Text('Start Creating'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.bgPage,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.toNamed('/upload');
                },
                icon: const Icon(
                  Icons.fact_check_outlined,
                  color: primaryText,
                  size: 18,
                ),
                label: const Text('Upload Verified Video'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: primaryText,
                  side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. PLATFORM PILLARS (CORE CAPABILITIES)
  // ==========================================================================

  Widget _buildPlatformPillars({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    final pillars = [
      _featureCard(
        Icons.verified_user_outlined,
        'Content Validation Layer',
        'Transparent fact-checking framework analyzing factual claims, linking creator citations, and generating verifiable credibility metrics for viewers.',
        'Trust by Design',
      ),
      _featureCard(
        Icons.g_translate_rounded,
        'AI Multilingual Dubbing',
        'Automatic transcription, voice preservation, and dubbing across 70+ languages, opening global audiences to every creator effortlessly.',
        'Global Reach',
      ),
      _featureCard(
        Icons.monetization_on_outlined,
        'Creator-First Economics',
        '100% net ad revenue to video creators and a transparent 75/25 subscription split, setting a new benchmark for ethical creator monetization.',
        'Equitable Revenue',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: bgColor,
      child: Column(
        children: [
          Text(
            'Core Platform Pillars',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: primaryText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Engineered to solve the crisis of digital trust while providing world-class creator tools.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryText),
          ),
          const SizedBox(height: 44),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pillars[0]),
                const SizedBox(width: 20),
                Expanded(child: pillars[1]),
                const SizedBox(width: 20),
                Expanded(child: pillars[2]),
              ],
            )
          else
            Column(
              children: [
                pillars[0],
                const SizedBox(height: 16),
                pillars[1],
                const SizedBox(height: 16),
                pillars[2],
              ],
            ),
        ],
      ),
    );
  }

  Widget _featureCard(
    IconData icon,
    String title,
    String description,
    String tagline,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.textPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tagline,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: secondaryText,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: secondaryText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. VERIFICATION PIPELINE (HOW IT WORKS)
  // ==========================================================================

  Widget _buildVerificationPipeline({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: bgColor,
      child: Column(
        children: [
          Text(
            'How Content Verification Works',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A structured four-step pipeline guaranteeing factual integrity and public transparency.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryText),
          ),
          const SizedBox(height: 44),
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                _stepRow(
                  1,
                  'Upload & Automated Claim Extraction',
                  'Upon video upload, the system automatically transcribes audio, identifies factual assertions, and extracts key claims for structured evaluation.',
                ),
                _stepRow(
                  2,
                  'Creator Source & Citation Attribution',
                  'Creators attach verifiable source links, academic citations, historical documents, and evidence directly to highlighted claims.',
                ),
                _stepRow(
                  3,
                  'Cross-Verification & Consistency Check',
                  'Our verification engine cross-evaluates claims against reputable academic, scientific, and news databases to detect inaccuracies.',
                ),
                _stepRow(
                  4,
                  'Public Credibility Scorecard',
                  'Videos receive a transparent credibility badge (Verified ✓, Disputed ⚠, or Unverified ?), allowing viewers to inspect claims and sources before watching.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: buttonBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: secondaryText,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 4. CREATOR-FIRST MONETIZATION MODEL
  // ==========================================================================

  Widget _buildMonetizationModel({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    final revenueCards = [
      _revenueCard(
        '100%',
        'Net Ad Revenue to Creators',
        'Creators receive 100% of video ad earnings, deducting only transparent pass-through bandwidth and infrastructure costs.',
      ),
      _revenueCard(
        '75%',
        'Subscription Revenue to Creators',
        'Direct creator support with 75% going to creators and 25% allocated for platform infrastructure and continuous AI research.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: bgColor,
      child: Column(
        children: [
          Text(
            'Creator-First Monetization',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A fair, transparent revenue model that treats creators as equal partners.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryText),
          ),
          const SizedBox(height: 44),
          if (isDesktop)
            Row(
              children: [
                Expanded(child: revenueCards[0]),
                const SizedBox(width: 20),
                Expanded(child: revenueCards[1]),
              ],
            )
          else
            Column(
              children: [
                revenueCards[0],
                const SizedBox(height: 16),
                revenueCards[1],
              ],
            ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: const Text(
              'Truthworld sustains platform operations through strategic non-intrusive discovery placements, preserving creator margins without compromise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(String pct, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            pct,
            style: const TextStyle(
              color: primaryText,
              fontSize: 44,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 5. LEADERSHIP SECTION
  // ==========================================================================

  Widget _buildLeadershipSection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: bgColor,
      child: Column(
        children: [
          Text(
            'Executive Leadership',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 40),

          // Founder Card
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: EdgeInsets.all(isDesktop ? 36 : 24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                // Minimal Accent bar
                Container(
                  height: 3,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 22),

                const Text(
                  'Vampu Ebenezer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Founder, Director & Lead Platform Architect',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Vampu Ebenezer is the founder and managing director of TowerVSP Services (OPC) Private Limited. Leading platform engineering, AI verification architectures, and scalable media streaming pipelines, he established Truthworld to create a transparent, reliable, and globally accessible video distribution ecosystem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 24),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _chip('AI Verification Architecture'),
                    _chip('Cloud-Native Infrastructure'),
                    _chip('Media Distribution Systems'),
                    _chip('Platform Governance'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ==========================================================================
  // 6. STATUTORY, CORPORATE & GRIEVANCE OFFICER SECTION
  // ==========================================================================

  Widget _buildCorporateAndGrievance({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    final corporateInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CORPORATE IDENTITY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 18),
        _infoRow('Legal Entity', 'TOWERVSP SERVICES (OPC) PRIVATE LIMITED'),
        _infoRow('CIN', 'U63111TS2025OPC207488'),
        _infoRow('Incorporation Date', 'December 10, 2025'),
        _infoRow('RoC Jurisdiction', 'RoC Hyderabad, Telangana, India'),
        _infoRow('Registered Office', 'Ramaram, Yadadri Bhuvanagiri, Telangana - 508116'),
        _infoRow('Status', 'Active (Registered with MCA, Govt. of India)', isStatus: true),
      ],
    );

    final grievanceInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATUTORY GRIEVANCE & SUPPORT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 18),
        _infoRow('Grievance Officer', 'Vampu Ebenezer'),
        _infoRow('Grievance Email', 'ebenezervampu@truthworld.in'),
        _infoRow('Customer Support', 'support@truthworld.in'),
        _infoRow('Business Contact', '+91 9390617877'),
        _infoRow('Support Hours', 'Mon – Fri, 9:00 AM – 6:00 PM IST'),
        _infoRow('Compliance', 'IT (Intermediary Guidelines) Rules, 2021'),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: bgColor,
      child: Column(
        children: [
          Text(
            'Corporate & Legal Information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Official entity registration, compliance details, and grievance redressal channels.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryText),
          ),
          const SizedBox(height: 44),
          Container(
            constraints: const BoxConstraints(maxWidth: 860),
            padding: EdgeInsets.all(isDesktop ? 36 : 24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: isDesktop || isTablet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: corporateInfo),
                      const SizedBox(width: 40),
                      Expanded(child: grievanceInfo),
                    ],
                  )
                : Column(
                    children: [
                      corporateInfo,
                      const SizedBox(height: 28),
                      const Divider(color: AppColors.bgDivider),
                      const SizedBox(height: 28),
                      grievanceInfo,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.success),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              val,
              style: const TextStyle(
                color: primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 7. CALL TO ACTION SECTION
  // ==========================================================================

  Widget _buildCTASection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final margin = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(margin),
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 56 : 36,
        horizontal: isDesktop ? 56 : 24,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Join the Truthworld Movement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Publish verified content, reach international audiences, and earn equitable revenue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryText),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Get.toNamed('/channelscreen');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.bgPage,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Start Creating Verified Content',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 8. FOOTER SECTION
  // ==========================================================================

  Widget _buildFooter(
    BuildContext context, {
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 40,
      ),
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.bgDivider, height: 1),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'TOWERVSP SERVICES (OPC) PRIVATE LIMITED',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              _footerLink('support@truthworld.in', () => _sendEmail('support@truthworld.in')),
              _footerLink('ebenezervampu@truthworld.in', () => _sendEmail('ebenezervampu@truthworld.in')),
              _footerLink('Terms of Service', () => Get.toNamed('/terms')),
              _footerLink('Privacy Policy', () => Get.toNamed('/privacy')),
              _footerLink('Copyright & DMCA', () => Get.toNamed('/copyright-complaint')),
              _footerLink('LinkedIn', () => _launchUrl('https://www.linkedin.com/in/ebenezer-vampu-10b9883a9/')),
              _footerLink('X', () => _launchUrl('https://x.com/ebenezervampu1')),
              _footerLink('+91 9390617877', () => _callPhone('+919390617877')),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '© 2026 TowerVSP Services (OPC) Private Limited. All rights reserved. Built for the future of trusted video publishing.',
            style: TextStyle(color: secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // URL & INTENT UTILITIES
  // ==========================================================================

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri);
  }

  Future<void> _callPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    await launchUrl(uri);
  }
}
