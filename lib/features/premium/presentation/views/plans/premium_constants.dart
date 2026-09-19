import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// THEME COLORS
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
// MODELS & TYPEDEFS (BACKWARD COMPATIBILITY)
// ==========================================================================

class PremiumFeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const PremiumFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

typedef FeatureItem = PremiumFeatureItem;

class PremiumPlanDetails {
  final String id;
  final String title;
  final String priceLabel;
  final String tagline;
  final String description;

  const PremiumPlanDetails({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.tagline,
    required this.description,
  });
}

typedef PlanDetails = PremiumPlanDetails;

class PremiumFaqItem {
  final String q;
  final String a;

  const PremiumFaqItem({required this.q, required this.a});
}

typedef FaqItem = PremiumFaqItem;

// ==========================================================================
// DEFAULT DATA LISTS
// ==========================================================================

const List<PremiumFeatureItem> kDefaultPremiumFeatures = [
  PremiumFeatureItem(
    icon: Icons.headphones_rounded,
    title: r'Ad-Free Audio Mode ($0.50 / ₹40)',
    description:
        'Listen to any video in Audio-only Mode completely free of ads. Uninterrupted playback for podcasts and music.',
  ),
  PremiumFeatureItem(
    icon: Icons.play_disabled_rounded,
    title: r'Ad-Free Video Playback ($2)',
    description:
        'Watch all videos without ad interruptions across mobile, desktop, TV, and tablet.',
  ),
  PremiumFeatureItem(
    icon: Icons.verified_outlined,
    title: r'Every Video Fact-Checked ($3)',
    description:
        'Epistemic verification on every video. If unverified, you can fact-check on demand with AI claim analysis.',
  ),
  PremiumFeatureItem(
    icon: Icons.high_quality_rounded,
    title: r'4K Ultra HD Streaming ($2 & $3)',
    description:
        'Experience crisp, studio-grade visual clarity up to 2160p resolution with zero buffering delays.',
  ),
  PremiumFeatureItem(
    icon: Icons.download_for_offline_outlined,
    title: r'Offline Downloads ($2 & $3)',
    description:
        'Save unlimited high-resolution videos for offline playback on flights, subways, and low-connectivity zones.',
  ),
  PremiumFeatureItem(
    icon: Icons.picture_in_picture_alt_rounded,
    title: r'Background Play & PiP ($2 & $3)',
    description:
        'Multitask freely while videos play smoothly in floating Picture-in-Picture or continue with the screen off.',
  ),
  PremiumFeatureItem(
    icon: Icons.translate_rounded,
    title: r'Multilingual AI Dubbing ($2 & $3)',
    description:
        'Unlock instant multilingual AI voice dubbing and auto-translated audio tracks for global content.',
  ),
];

const List<PremiumPlanDetails> kDefaultPremiumPlans = [
  PremiumPlanDetails(
    id: 'audio_monthly',
    title: r'$0.50 Audio Premium Plan',
    priceLabel: r'$0.50/month (₹40)',
    tagline: 'Ad-Free Audio-Only Mode',
    description:
        'Play any video in Truthworld in Audio-only Mode completely ads free. Perfect for uninterrupted podcasts, music, and background listening.',
  ),
  PremiumPlanDetails(
    id: 'individual_monthly',
    title: r'$2 TruthWorld Premium Plan',
    priceLabel: r'$2/month (₹169)',
    tagline: 'All Features • Ad-Free Everything',
    description:
        'Zero ads across all videos and audios, offline downloads, background play & PiP, 4K Ultra HD streaming, and multilingual AI dubbing.',
  ),
  PremiumPlanDetails(
    id: '4k_factchecked_monthly',
    title: r'$3 Premium + Fact-Checked Plan',
    priceLabel: r'$3/month (₹249)',
    tagline: 'Every Video Fact-Checked + On-Demand',
    description:
        'Everything in TruthWorld Premium included, plus every video is fact-checked. If any video is not yet fact-checked, you can fact-check it on demand.',
  ),
];

const List<PremiumFaqItem> kDefaultPremiumFaqs = [
  PremiumFaqItem(
    q: 'What are the Truthworld Premium plans?',
    a: r'Truthworld offers three subscription tiers: 1) Audio Premium ($0.50/month ~ ₹40) for ad-free listening in audio-only mode. 2) Truthworld Premium ($2/month ~ ₹169) for ad-free video streaming, 4K quality, offline downloads, background play, and AI dubbing. 3) Truthworld Premium + Fact-Checked ($3/month ~ ₹249) for all premium features plus verified fact-checking on every video, including on-demand fact-checking.',
  ),
  PremiumFaqItem(
    q: r'How does the $0.50 (₹40) Audio Premium plan work?',
    a: 'With Audio Premium, any video played in Audio-only Mode is completely free of ads. It is designed for listeners who enjoy podcasts, interviews, lectures, and music without video playback.',
  ),
  PremiumFaqItem(
    q: r'What is included in the $2 TruthWorld Premium Plan?',
    a: r'The $2/month (~₹169) plan unlocks ad-free playback on all videos and audios, background playback, PiP, offline video downloads, 4K Ultra HD resolution, and AI voice dubbing.',
  ),
  PremiumFaqItem(
    q: r'What is included in the $3 Premium + Fact-Checked Plan?',
    a: r'The $3/month (~₹249) plan includes all Truthworld Premium features plus full AI fact-checking across every video. If a video is not yet fact-checked, subscribers can trigger on-demand AI fact-checking directly.',
  ),
  PremiumFaqItem(
    q: 'Can I fact-check any video if it is not yet fact-checked?',
    a: r'Yes! If you are subscribed to the $3 Truthworld Premium + Fact-Checked plan and encounter any video that has not yet been fact-checked, you can tap the "Fact-Check This Video" button to immediately queue real-time AI epistemic analysis and claim verification.',
  ),
  PremiumFaqItem(
    q: 'Can I cancel my subscription at any time?',
    a: 'Yes. You can cancel your subscription at any time directly through the Premium screen or your Account Settings. Cancelled plans remain active until the end of your billing cycle.',
  ),
  PremiumFaqItem(
    q: 'How does the 7-day free trial work?',
    a: "First-time subscribers receive a 7-day free trial. You won't be charged until the trial ends, and you can cancel anytime before then.",
  ),
  PremiumFaqItem(
    q: 'How does upgrading between plans work?',
    a: r'Upgrades are prorated with your previous plan fee credited directly! If you have the $0.50 (₹40) Audio Premium plan and want to upgrade to Truthworld Premium ($2 / ₹169), you only pay $2 - 40 rupees (₹129). To upgrade from Audio Premium to the $3 Fact-Checked plan (₹249), you only pay ₹209 ($3 - ₹40). If you have the $2 plan and want to upgrade to the $3 plan, you pay only ₹80 ($3 - $2).',
  ),
];
