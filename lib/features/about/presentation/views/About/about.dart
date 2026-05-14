import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  final bool isDashboard;
  const AboutPage({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: !isDashboard ? _buildAppBar() : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(),
            _buildCoreFeatures(),
            _buildCompanyOverview(),
            _buildContentValidationFeature(),
            _buildValidationUseCases(),
            _buildHowValidationWorks(),
            _buildTechnicalArchitecture(),
            _buildMonetizationDetailed(),
            _buildProductsDetailed(),
            _buildTeamSection(),
            _buildCompanyInformation(),
            _buildCTASection(),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.toc_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Truthworld',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.toNamed('/terms');
          },
          child: Text(
            'Terms And Conditions',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Get.toNamed('/privacy');
          },
          child: Text(
            'Privacy Policy',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        if (!AuthService.to.hasChannel.value)
          ElevatedButton(
            onPressed: () => Get.toNamed('/channelscreen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Get Started'),
          ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgPage,
            AppColors.brand,
            AppTokens.colors.border,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'TRUTH-FIRST VIDEO PLATFORM • PROPRIETARY SAAS INFRASTRUCTURE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTokens.colors.hoverAccent,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 30),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                height: 1.1,
                letterSpacing: -1.5,
              ),
              children: [
                TextSpan(
                  text: 'The Infrastructure of\n',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                TextSpan(
                  text: 'Verified Video',
                  style: TextStyle(color: AppColors.brand),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Text(
              "Truthworld is a cloud-native SaaS video platform that integrates automated content validation into the publishing pipeline. Creators upload videos with supporting sources, and the system generates transcripts, extracts factual claims, and applies AI-assisted verification to produce structured credibility summaries for viewers. The platform combines scalable media processing, metadata-driven validation, and multilingual infrastructure to deliver transparent, accountable video distribution across more than 70 languages.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!AuthService.to.hasChannel.value) ...[
                ElevatedButton.icon(
                  onPressed: () => Get.toNamed('/channelscreen'),
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text('Start Creating'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  Get.toNamed('/uploadscreen');
                },
                icon: const Icon(Icons.fact_check),
                label: const Text('Upload your First Verified Video'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: AppTokens.colors.hoverAccent,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoreFeatures() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Three Revolutionary Pillars',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 60),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _coreFeatureCard(
                  Icons.fact_check,
                  'Content Validation',
                  'Built-in trust layer with AI fact-checking, source verification, and transparent credibility scoring.',
                  AppTokens.colors.hoverAccent,
                  'Combat Misinformation',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _coreFeatureCard(
                  Icons.translate,
                  'AI Global Dubbing',
                  'Automatic translation and dubbing into 70+ languages with voice preservation and lip-sync.',
                  const Color(0xFF8B5CF6),
                  'Break Language Barriers',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _coreFeatureCard(
                  Icons.monetization_on,
                  'Fair Monetization',
                  '100% ad revenue to creators (minus costs) and transparent 75/25 subscription splits.',
                  AppColors.brand,
                  'Empower Creators',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coreFeatureCard(
    IconData icon,
    String title,
    String description,
    Color color,
    String tagline,
  ) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Color(0xFFFFB703),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tagline,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: Color(0xFFFFB703),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Truthworld',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Truthworld is a proprietary SaaS platform revolutionizing video delivery. We combine enterprise-grade infrastructure with AI-powered accessibility and creator-first monetization.',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unlike traditional platforms, Truthworld is engineered from the ground up to maximize creator earnings and ensure content transparency through a built-in trust layer.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTokens.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEGAL STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTokens.colors.hoverAccent,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _companyDetail(
                    'Legal Name',
                    'TRUTHWORLD SERVICES (OPC) PRIVATE LIMITED',
                  ),
                  _companyDetail('CIN', 'U63111TS2025OPC207488'),
                  _companyDetail('Incorporated', 'December 10, 2025'),
                  _companyDetail(
                    'Status',
                    'Active',
                    color: AppTokens.colors.hoverAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentValidationFeature() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'TruthWorld Content Validation & Transparency',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(50),
            decoration: BoxDecoration(
              color: Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTokens.colors.hoverAccent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Truthworld\'s Content Validation feature is a built-in trust layer that analyzes factual claims in uploaded videos, attaches creator-provided sources, and allows viewers to see a structured credibility summary before engaging with the content.',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'KEY VALIDATION CAPABILITIES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.colors.hoverAccent,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: _validationCapability(
                        Icons.analytics,
                        'Automated Claim Analysis',
                        'AI-powered detection of factual claims.',
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _validationCapability(
                        Icons.link,
                        'Source Attribution',
                        'Evidence attached to every claim.',
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _validationCapability(
                        Icons.dashboard,
                        'Credibility Dashboard',
                        'Real-time trust metrics for viewers.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationUseCases() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Solving Information Problems',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 60),
          Row(
            children: [
              Expanded(
                child: _useCaseMiniCard(
                  'News',
                  'Combat viral misinformation.',
                  const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _useCaseMiniCard(
                  'Science',
                  'Peer-reviewed evidence trails.',
                  AppColors.brand,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _useCaseMiniCard(
                  'Education',
                  'Verified textbook references.',
                  AppTokens.colors.hoverAccent,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _useCaseMiniCard(
                  'Social',
                  'Fact vs Opinion labeling.',
                  const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowValidationWorks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: Color(0xFFFFB703),
      child: Column(
        children: [
          Text(
            'The Validation Workflow',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 80),
          _stepRow(
            1,
            'Upload & Claim Detection',
            'AI transcribes audio and extracts factual claims automatically.',
            AppColors.brand,
          ),
          _stepRow(
            2,
            'Source Attribution',
            'Creator provides links, citations, and documents for each claim.',
            AppTokens.colors.hoverAccent,
          ),
          _stepRow(
            3,
            'Automated Verification',
            'AI cross-checks claims against academic and historical databases.',
            const Color(0xFF8B5CF6),
          ),
          _stepRow(
            4,
            'Community Validation',
            'Expert reviews and viewer fact-checking add a layer of human wisdom.',
            const Color(0xFFF59E0B),
          ),
          _stepRow(
            5,
            'Credibility Scoring',
            'Video is marked as Verified âœ“, Disputed âš , or Unconfirmed ?.',
            const Color(0xFFEC4899),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalArchitecture() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Technical Substrate',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(50),
            decoration: BoxDecoration(
              color: Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTokens.colors.border),
            ),
            child: Wrap(
              spacing: 30,
              runSpacing: 30,
              children: [
                _techLayer('Application Layer', AppColors.brand, [
                  'Flutter Web/Mobile',
                  'Creator Studio',
                  'Admin Panel',
                ]),
                _techLayer('AI Orchestration', const Color(0xFF8B5CF6), [
                  'Neural Dubbing',
                  'Lip-sync ML Models',
                  'Claim Analysis',
                ]),
                _techLayer('Video Processing', const Color(0xFF06B6D4), [
                  'Distributed Transcoding',
                  'Adaptive Streaming',
                  'Live Pipelines',
                ]),
                _techLayer('Infrastructure', AppTokens.colors.hoverAccent, [
                  'Global CDN (100+ Edge)',
                  'Object Storage',
                  'Kubernetes',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonetizationDetailed() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: Color(0xFFFFB703),
      child: Column(
        children: [
          Text(
            'Creator-First Monetization',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 60),
          Row(
            children: [
              Expanded(
                child: _revenueCard(
                  '100%',
                  'Ad Revenue to Creators',
                  'Minus actual infra costs (Bandwidth, Storage, CDN).',
                  AppTokens.colors.hoverAccent,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _revenueCard(
                  '75%',
                  'Subscription to Creators',
                  '25% to Platform for AI R&D and operations.',
                  AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Platform sustainability is achieved through Strategic Ads (Homepage, Search, Discovery) which DO NOT impact creator earnings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsDetailed() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Product Roadmap',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 60),
          _productCard(
            'Truthworld Platform',
            'Beta',
            0.85,
            'Video Hosting, AI Dubbing, Validation Engine.',
            'Q3 2026',
          ),
          const SizedBox(height: 24),
          _productCard(
            'Creator Studio',
            'Alpha',
            0.60,
            'Timeline Editing, AI Thumbnail Gen, SEO Tools.',
            'Q1 2027',
          ),
          const SizedBox(height: 24),
          _productCard(
            'Mobile Apps',
            'In Dev',
            0.70,
            'Offline Downloads, PiP, Cross-Device Sync.',
            'Q2 2027',
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
      child: Column(
        children: [
          Text(
            "Founding Team",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Truthworld is currently built by a solo founding team and is in its early growth stage. The company is architected for scale, with plans to expand into a multi-engineer organization as the platform grows globally.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 60),

          // Premium Founder Card
          Container(
            constraints: const BoxConstraints(maxWidth: 920),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.bgPage, Color(0xFF020617)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTokens.colors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgPage.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                // Accent bar
                Container(
                  height: 4,
                  width: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  "Vampu Ebenezer",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Founder & CEO â€¢ Lead Platform Engineer",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Vampu Ebenezer is the founder and sole developer behind Truthworld, leading platform architecture, AI validation systems, and scalable cloud infrastructure. He is building Truthworld as a cloud-native SaaS video platform focused on transparency, fact validation, and accountable media distribution. As the platform scales, the company will expand by hiring engineers and specialists to support global growth.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 28),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _premiumChip("AI Validation Systems"),
                    _premiumChip("Cloud Infrastructure"),
                    _premiumChip("Video Platform Engineering"),
                    _premiumChip("Product Architecture"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTokens.colors.divider),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCompanyInformation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'Company Information',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 60),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('CIN', 'U63111TS2025OPC207488'),
                    _infoRow('ROC', 'Hyderabad'),
                    _infoRow('Incorporation', 'Dec 10, 2025'),
                    _infoRow('Capital (Paid-up)', 'â‚¹10,000'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Activity', 'Data Processing & Software'),
                    _infoRow('Status', 'Active'),
                    _infoRow('Address', 'Ramaram Yadadri, Telangana - 508116'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(80),
      margin: const EdgeInsets.all(80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand, AppTokens.colors.hoverAccent],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'Join the Truth Revolution',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'The first platform where trust is visible and creators are rewarded fairly.',
            style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Get.toNamed('/channelscreen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            child: const Text(
              'Start Creating Verified Content',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri);
  }

  Future<void> _callPhone(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    await launchUrl(uri);
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(80),
      color: AppColors.bgPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Flexible(
                child: Text(
                  'TRUTHWORLD SERVICES (OPC) PRIVATE LIMITED',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.email,
                      color: AppColors.textTertiary,
                      size: 16,
                    ),
                    TextButton(
                      onPressed: () =>
                          _sendEmail('ebenezervampu@truthworld.in'),
                      child: const Text(
                        'ebenezervampu@truthworld.in',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _sendEmail('ebenezer@truthworld.in'),
                      child: const Text(
                        'ebenezer@truthworld.in',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _sendEmail('ebenezervampu777@gmail.com'),
                      child: const Text(
                        'ebenezervampu777@gmail.com',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _launchUrl(
                        'https://www.linkedin.com/in/ebenezer-vampu-10b9883a9/',
                      ),
                      child: const Text(
                        'LinkedIn',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _launchUrl('https://x.com/ebenezervampu1'),
                      child: const Text(
                        'X',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Icon(
                      Icons.phone,
                      color: AppColors.textTertiary,
                      size: 16,
                    ),
                    TextButton(
                      onPressed: () => _callPhone('+919390617877'),
                      child: const Text(
                        '+91 9390617877',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(color: Color(0xFFFFB703)),
          const SizedBox(height: 20),
          const Text(
            '© 2026 TruthWorld Services. Built for the future of trusted video.',
            style: TextStyle(color: Color(0xFF475569), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _companyDetail(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _validationCapability(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTokens.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTokens.colors.hoverAccent, size: 32),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _useCaseMiniCard(String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFFFB703),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int step, String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 25,
            child: Text(
              step.toString(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _techLayer(String title, Color color, List<String> items) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'â€¢ $i',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(String pct, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            pct,
            style: TextStyle(
              color: color,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _productCard(
    String title,
    String stage,
    double progress,
    String desc,
    String timeline,
  ) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Color(0xFFFFB703),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                stage,
                style: TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(desc, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgPage,
            color: AppColors.brand,
          ),
          const SizedBox(height: 10),
          Text(
            'Launch: $timeline',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            val,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}




