import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Semantic classification of a fact-checked claim verdict.
enum ClaimVerdictType {
  verifiedTrue,
  mostlyTrue,
  falseClaim,
  misleading,
  disputed,
  inconclusive,
  contextual,
}

/// Resolved claim verdict presentation data.
class ClaimVerdictInfo {
  const ClaimVerdictInfo({
    required this.type,
    required this.label,
    required this.color,
    required this.icon,
    required this.category,
    required this.summaryTakeaway,
    this.microTakeaway,
    this.confidenceText,
    this.confidenceVal,
  });

  final ClaimVerdictType type;
  final String label;
  final Color color;
  final IconData icon;
  final String category; // 'Verified', 'Caution', 'False', 'Contextual'
  final String summaryTakeaway;
  final String? microTakeaway;
  final String? confidenceText;
  final double? confidenceVal;

  String get effectiveMicroTakeaway => microTakeaway ?? summaryTakeaway;

  bool get isVerified =>
      type == ClaimVerdictType.verifiedTrue ||
      type == ClaimVerdictType.mostlyTrue;

  bool get isFalse =>
      type == ClaimVerdictType.falseClaim ||
      type == ClaimVerdictType.misleading;

  bool get isCaution =>
      type == ClaimVerdictType.disputed ||
      type == ClaimVerdictType.inconclusive;

  bool get isContextual => type == ClaimVerdictType.contextual;
}

/// Centralized utility for resolving claim verdicts, colors, white icons,
/// and cleaning AI response texts across the TruthWorld application.
class ClaimVerdictHelper {
  ClaimVerdictHelper._();

  /// Resolves the comprehensive verdict information for a claim Map, ClaimResult, or String.
  static ClaimVerdictInfo resolveVerdict(dynamic claim) {
    if (claim == null) {
      return _unverifiedDefault();
    }

    if (claim is ClaimResult) {
      return resolveVerdictString(
        claim.verdict,
        confidence: claim.classificationConfidence,
      );
    }

    if (claim is String) {
      return resolveVerdictString(claim);
    }

    if (claim is! Map) {
      return _unverifiedDefault();
    }

    final rawStatus =
        (claim['status'] ??
                claim['verificationStatus'] ??
                claim['verdict'] ??
                claim['label'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    final isVerifiedFlag = claim['isVerified'] == true;
    final confidence = _extractConfidence(claim);

    return _resolveStatus(
      rawStatus,
      isVerifiedFlag: isVerifiedFlag,
      confidence: confidence,
    );
  }

  /// Resolves verdict info directly from a status/verdict string.
  static ClaimVerdictInfo resolveVerdictString(
    String? rawStatus, {
    double? confidence,
  }) {
    if (rawStatus == null || rawStatus.trim().isEmpty) {
      return _unverifiedDefault();
    }
    return _resolveStatus(
      rawStatus.trim().toLowerCase(),
      isVerifiedFlag: false,
      confidence: confidence,
    );
  }

  static ClaimVerdictInfo _unverifiedDefault() {
    return const ClaimVerdictInfo(
      type: ClaimVerdictType.inconclusive,
      label: 'UNVERIFIED',
      color: AppColors.info,
      icon: Icons.help_outline_rounded,
      category: 'Caution',
      summaryTakeaway: 'This claim is currently undergoing evaluation.',
      microTakeaway: 'Currently undergoing evaluation',
    );
  }

  static ClaimVerdictInfo _resolveStatus(
    String rawStatus, {
    required bool isVerifiedFlag,
    double? confidence,
  }) {
    final confStr = _formatConfidence(confidence);

    // 1. Verified True
    if (rawStatus == 'verified_true' ||
        rawStatus == 'verified' ||
        rawStatus == 'true' ||
        rawStatus == 'correct' ||
        rawStatus.contains('verified true') ||
        (isVerifiedFlag &&
            !rawStatus.contains('false') &&
            !rawStatus.contains('mostly'))) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.verifiedTrue,
        label: 'VERIFIED TRUE',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
        category: 'Verified',
        summaryTakeaway:
            'This checks out. Multiple authoritative sources and verifiable records confirm it.',
        microTakeaway: 'Confirmed by reliable sources',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 2. Mostly True / Partially True
    if (rawStatus == 'mostly_true' ||
        rawStatus == 'mostly_correct' ||
        rawStatus == 'partially_true' ||
        rawStatus.contains('mostly true') ||
        rawStatus.contains('mostly correct')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.mostlyTrue,
        label: 'MOSTLY TRUE',
        color: const Color(0xFF10B981), // Emerald
        icon: Icons.check_circle_outline_rounded,
        category: 'Verified',
        summaryTakeaway:
            'Substantially accurate. The core fact is right, with only minor nuances or context.',
        microTakeaway: 'Substantially true with minor nuances',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 3. False / Incorrect
    if (rawStatus == 'false_claim' ||
        rawStatus == 'false' ||
        rawStatus == 'incorrect' ||
        rawStatus == 'verified_false' ||
        rawStatus == 'historical_consensus_denial' ||
        rawStatus.contains('false claim') ||
        rawStatus.startsWith('false')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.falseClaim,
        label: 'FALSE CLAIM',
        color: AppColors.error,
        icon: Icons.cancel_rounded,
        category: 'False',
        summaryTakeaway:
            'This is false. Directly contradicted by reliable public records and verified evidence.',
        microTakeaway: 'Contradicted by verified evidence',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 4. Misleading / Deceptive
    if (rawStatus == 'misleading' ||
        rawStatus == 'distorted' ||
        rawStatus == 'deceptive' ||
        rawStatus.contains('mislead') ||
        rawStatus.contains('mostly_false')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.misleading,
        label: 'MISLEADING',
        color: const Color(0xFFF97316), // Orange
        icon: Icons.warning_rounded,
        category: 'False',
        summaryTakeaway:
            'This is misleading. It leaves out key context or frames details to give a false impression.',
        microTakeaway: 'Missing key context or misleading framing',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 5. Disputed / Contested
    if (rawStatus == 'disputed' ||
        rawStatus == 'contested' ||
        rawStatus == 'contested_interpretation' ||
        rawStatus.contains('dispute')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.disputed,
        label: 'DISPUTED',
        color: AppColors.warning,
        icon: Icons.balance_rounded,
        category: 'Caution',
        summaryTakeaway:
            'Experts disagree on this claim. Credible sources present conflicting evidence or views.',
        microTakeaway: 'Conflicting evidence among sources',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 6. Contextual: Satire / Hyperbole / Humor
    if (rawStatus == 'satire' ||
        rawStatus == 'satire_claim' ||
        rawStatus == 'humor' ||
        rawStatus == 'parody' ||
        rawStatus == 'hyperbole' ||
        rawStatus.contains('satire')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.contextual,
        label: 'SATIRE / HYPERBOLE',
        color: const Color(0xFF38BDF8), // Sky blue
        icon: Icons.sentiment_very_satisfied_rounded,
        category: 'Contextual',
        summaryTakeaway:
            'Figurative speech or satire. This was meant humorously or exaggerated, not as a literal fact.',
        microTakeaway: 'Humor or figurative speech, not a literal claim',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 7. Contextual: Faith / Religion / Tradition
    if (rawStatus == 'faith_based_claim' ||
        rawStatus == 'religious_belief' ||
        rawStatus == 'not_historically_verifiable' ||
        rawStatus == 'historical_tradition' ||
        rawStatus == 'doctrinal_unverifiable' ||
        rawStatus.contains('faith') ||
        rawStatus.contains('tradition')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.contextual,
        label: 'FAITH / TRADITION',
        color: const Color(0xFFA78BFA), // Purple
        icon: Icons.auto_stories_rounded,
        category: 'Contextual',
        summaryTakeaway:
            'Matters of faith or tradition. Based on spiritual belief, not something empirical fact-checking proves or disproves.',
        microTakeaway: 'Based on belief or tradition',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 8. Contextual: Opinion / Value Judgment
    if (rawStatus == 'opinion' ||
        rawStatus == 'opinion_claim' ||
        rawStatus == 'anecdotal_experience' ||
        rawStatus == 'value_judgment' ||
        rawStatus == 'preference_statement' ||
        rawStatus.contains('opinion')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.contextual,
        label: 'OPINION',
        color: const Color(0xFF60A5FA), // Light blue
        icon: Icons.psychology_rounded,
        category: 'Contextual',
        summaryTakeaway:
            'Personal opinion or subjective judgment, rather than a factual statement.',
        microTakeaway: 'Personal viewpoint, not a factual claim',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 9. Inconclusive / Unproven / Unsupported / Needs Context / Timeout
    var label = 'UNVERIFIED';
    var takeaway =
        'Under evaluation. Verification is ongoing or waiting for more corroborating data.';
    var micro = 'Verification is ongoing';

    if (rawStatus == 'needs_context' || rawStatus.contains('context')) {
      label = 'NEEDS CONTEXT';
      takeaway =
          'Needs more context. Important background is missing to fairly judge this claim.';
      micro = 'Missing essential background context';
    } else if (rawStatus == 'outdated') {
      label = 'OUTDATED';
      takeaway =
          'Outdated. This was once accurate but newer information or events have superseded it.';
      micro = 'Superseded by newer developments';
    } else if (rawStatus == 'inconclusive' ||
        rawStatus.contains('inconclusive')) {
      label = 'INCONCLUSIVE';
      takeaway =
          'Inconclusive. The available evidence is split, so a definitive verdict cannot be made yet.';
      micro = 'Evidence is currently split or inconclusive';
    } else if (rawStatus == 'unsupported' ||
        rawStatus.contains('unsupported') ||
        rawStatus == 'unproven' ||
        rawStatus == 'limited_support') {
      label = 'UNSUPPORTED';
      takeaway =
          'Unsupported. No credible documentation or proof was found to back this up.';
      micro = 'No credible proof found to substantiate';
    } else if (rawStatus == 'verification_timeout' ||
        rawStatus.contains('timeout')) {
      label = 'EVALUATING';
      takeaway =
          'Verification is in progress. Awaiting additional indexing and analysis.';
      micro = 'Verification in progress';
    }

    return ClaimVerdictInfo(
      type: ClaimVerdictType.inconclusive,
      label: label,
      color: const Color(0xFFEAB308), // Amber/Yellow
      icon: Icons.help_outline_rounded,
      category: 'Caution',
      summaryTakeaway: takeaway,
      microTakeaway: micro,
      confidenceText: confStr,
      confidenceVal: confidence,
    );
  }

  /// Cleans technical pipeline tags like `[RECOVERY PASS]` and clinical emojis
  /// from the AI reasoning response.
  static String cleanResponseText(dynamic raw) {
    if (raw == null) return '';
    var text = raw.toString().trim();

    // Strip internal pipeline prefixes
    text = text
        .replaceFirst(
          RegExp(r'^\[RECOVERY PASS\]\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^\[FAST KNOWLEDGE RECOVERY\]\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'^\[GROUNDING\]\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\[FAST PASS\]\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\[LLM\]\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\[RECOVERY\]\s*', caseSensitive: false), '')
        .trim();

    // Strip clinical icon prefixes from start of paragraph
    text = text
        .replaceFirst(
          RegExp(r'^[?❔✅❌🟢⏳🔍📎💭👤⚖️❤️🗣️🕊📜💡⚠️\s]+'),
          '',
        )
        .trim();

    return text;
  }

  /// Cleans leading question marks, emojis, or formatting relics from claim statement.
  static String cleanClaimText(dynamic raw, int index) {
    var text = (raw ?? '').toString().trim();
    text = text
        .replaceFirst(
          RegExp(r'^[?❔✅❌🟢⏳🔍📎💭👤⚖️❤️🗣️🕊📜💡⚠️\s]+'),
          '',
        )
        .trim();
    if (text.isEmpty) {
      return 'Claim #${index + 1}';
    }
    return text;
  }

  static double? _extractConfidence(Map claim) {
    final raw =
        claim['confidence'] ??
        claim['verificationConfidence'] ??
        claim['classificationConfidence'];
    if (raw is num) {
      final val = raw.toDouble();
      return val > 1.0 ? (val / 100.0) : val;
    }
    return null;
  }

  static String? _formatConfidence(double? confidence) {
    if (confidence == null || confidence <= 0) return null;
    final pct = (confidence * 100).toInt().clamp(1, 100);
    if (pct >= 80) return 'High ($pct%)';
    if (pct >= 55) return 'Medium ($pct%)';
    return 'Limited ($pct%)';
  }
}
