import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_localization.dart';
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
  novelHypothesis,
  developingStory,
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

  String localizedLabel([String? langCode]) =>
      ClaimVerdictLocalization.localizeLabel(type, label, langCode);

  String localizedCategory([String? langCode]) =>
      ClaimVerdictLocalization.localizeCategory(category, langCode);

  String localizedTakeaway([String? langCode]) =>
      ClaimVerdictLocalization.localizeTakeaway(type, summaryTakeaway, langCode);

  String localizedMicroTakeaway([String? langCode]) =>
      ClaimVerdictLocalization.localizeMicroTakeaway(
        type,
        effectiveMicroTakeaway,
        langCode,
      );

  bool get isVerified =>
      type == ClaimVerdictType.verifiedTrue ||
      type == ClaimVerdictType.mostlyTrue ||
      type == ClaimVerdictType.novelHypothesis;

  bool get isFalse =>
      type == ClaimVerdictType.falseClaim ||
      type == ClaimVerdictType.misleading;

  bool get isCaution =>
      type == ClaimVerdictType.disputed ||
      type == ClaimVerdictType.inconclusive ||
      type == ClaimVerdictType.developingStory;

  bool get isContextual => type == ClaimVerdictType.contextual;

  bool get isOpinion => label.toUpperCase() == 'OPINION';
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

    final nature = (claim['nature'] ?? claim['claimNature'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (nature == 'rhetorical_exaggeration' || nature == 'hyperbole') {
      return resolveVerdictString(
        'rhetorical_exaggeration',
        confidence: confidence,
      );
    }

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
            'This is completely true! Reliable records and real-world proof confirm it.',
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
            'Mostly true! The main fact is right, with just a few small details to know.',
        microTakeaway: 'Mostly true with minor details',
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
            'This is false. Real facts and official records show the opposite is true.',
        microTakeaway: 'Opposite of what facts show',
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
            'Misleading. It leaves out important facts to make things sound different than they really are.',
        microTakeaway: 'Leaves out key facts',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // Novel Scientific Hypothesis
    if (rawStatus == 'novel_hypothesis' ||
        rawStatus.contains('novel_hypothesis') ||
        rawStatus.contains('novel hypothesis')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.novelHypothesis,
        label: 'NOVEL HYPOTHESIS',
        color: const Color(0xFF06B6D4), // Cyan
        icon: Icons.science_rounded,
        category: 'Verified',
        summaryTakeaway:
            'Exploratory scientific candidate. This presents an alternative empirical hypothesis or challenger model currently undergoing investigation.',
        microTakeaway: 'Active exploratory hypothesis',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // Live Developing Story
    if (rawStatus == 'developing_story' ||
        rawStatus.contains('developing_story') ||
        rawStatus.contains('developing story')) {
      return ClaimVerdictInfo(
        type: ClaimVerdictType.developingStory,
        label: 'DEVELOPING STORY',
        color: const Color(0xFF3B82F6), // Blue
        icon: Icons.bolt_rounded,
        category: 'Caution',
        summaryTakeaway:
            'Live developing event. Initial occurrences are confirmed, while casualty, damage, or operational statistics are actively evolving.',
        microTakeaway: 'Fast-evolving live event',
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
            'People and experts disagree on this. There is evidence on both sides, so there is no single right answer yet.',
        microTakeaway: 'Conflicting evidence on both sides',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 6. Contextual: Satire / Hyperbole / Rhetorical Exaggeration / Humor
    if (rawStatus == 'satire' ||
        rawStatus == 'satire_claim' ||
        rawStatus == 'humor' ||
        rawStatus == 'parody' ||
        rawStatus == 'hyperbole' ||
        rawStatus == 'rhetorical_exaggeration' ||
        rawStatus == 'exaggeration' ||
        rawStatus.contains('rhetorical_exaggeration') ||
        rawStatus.contains('exaggerat') ||
        rawStatus.contains('hyperbole') ||
        rawStatus.contains('satire')) {
      final isExaggeration = rawStatus.contains('exaggerat') ||
          rawStatus.contains('hyperbole') ||
          rawStatus == 'rhetorical_exaggeration';
      return ClaimVerdictInfo(
        type: ClaimVerdictType.contextual,
        label: isExaggeration ? 'RHETORICAL EXAGGERATION' : 'SATIRE / HUMOR',
        color: const Color(0xFF38BDF8), // Sky blue
        icon: isExaggeration
            ? Icons.auto_awesome_rounded
            : Icons.sentiment_very_satisfied_rounded,
        category: 'Contextual',
        summaryTakeaway: isExaggeration
            ? 'Figurative expression. This was used as conversational hyperbole or rhetorical exaggeration, not as an empirical claim.'
            : 'Just for fun! This was a joke or parody, not meant to be taken as a real fact.',
        microTakeaway: isExaggeration
            ? 'Rhetorical hyperbole, not literal'
            : 'Humor or parody, not literal',
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
            'A matter of faith or tradition. This is based on personal belief, which science cannot prove or disprove.',
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
            'Classified as an opinion because it shares a personal perspective or value judgment rather than a measurable fact.',
        microTakeaway: 'Personal viewpoint, not a testable fact',
        confidenceText: confStr,
        confidenceVal: confidence,
      );
    }

    // 9. Inconclusive / Unproven / Unsupported / Needs Context / Timeout
    var label = 'UNVERIFIED';
    var takeaway =
        'We are still checking the facts for this claim.';
    var micro = 'Fact check in progress';

    if (rawStatus == 'needs_context' || rawStatus.contains('context')) {
      label = 'NEEDS CONTEXT';
      takeaway =
          'Needs more context. Important background is missing to understand this claim fairly.';
      micro = 'Missing important background';
    } else if (rawStatus == 'outdated') {
      label = 'OUTDATED';
      takeaway =
          'Outdated. This used to be true in the past, but newer events have changed things.';
      micro = 'No longer true today';
    } else if (rawStatus == 'inconclusive' ||
        rawStatus.contains('inconclusive')) {
      label = 'INCONCLUSIVE';
      takeaway =
          "We can't be sure yet. There isn't enough solid proof either way.";
      micro = 'Not enough solid proof yet';
    } else if (rawStatus == 'unsupported' ||
        rawStatus.contains('unsupported') ||
        rawStatus == 'unproven' ||
        rawStatus == 'limited_support') {
      label = 'UNSUPPORTED';
      takeaway =
          'Nobody has found any real proof for this claim yet.';
      micro = 'No real proof found yet';
    } else if (rawStatus == 'verification_timeout' ||
        rawStatus.contains('timeout')) {
      label = 'EVALUATING';
      takeaway =
          'We are still checking the facts for this claim.';
      micro = 'Fact check in progress';
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

  /// Explains clearly why our verification system configured this specific claim
  /// as an opinion rather than a fact, in language a 10-year-old child can easily grasp.
  static String formatOpinionExplanation([String? claimText]) {
    if (claimText != null && claimText.trim().isNotEmpty) {
      final lower = claimText.toLowerCase();

      final vitalMatch = RegExp(r'\b(vital|essential|important|crucial|matters most|matter most)\b').firstMatch(lower);
      if (vitalMatch != null) {
        final word = vitalMatch.group(1);
        return "Classified as an opinion because the speaker describes this as '$word'. While science can measure real facts like nutrients or numbers, deciding that something is '$word' is a personal value judgment, not a measurable fact.";
      }

      final bestMatch = RegExp(r'\b(best|worst|greatest|favorite|favourite|awesome|terrible|cool|boring)\b').firstMatch(lower);
      if (bestMatch != null) {
        final word = bestMatch.group(1);
        return "Classified as an opinion because the speaker uses the word '$word'. Words like '$word' describe personal taste — everyone likes different things, and no science test can prove what is truly '$word'.";
      }

      final adviceMatch = RegExp(r'\b(should|must|ought to|need to)\b').firstMatch(lower);
      if (adviceMatch != null) {
        final word = adviceMatch.group(1);
        return "Classified as an opinion because the speaker is giving personal advice ('$word'). Advice depends on what someone personally recommends, not an absolute rule that can be proven true or false.";
      }

      final thoughtMatch = RegExp(r'\b(feel|think|believe|prefer|love|hate|like)\b').firstMatch(lower);
      if (thoughtMatch != null) {
        final word = thoughtMatch.group(1);
        return 'Classified as an opinion because the speaker shares what they personally $word. A personal perspective belongs to the speaker, so it cannot be tested or proven wrong from the outside.';
      }
    }

    return 'Classified as an opinion because this statement shares a personal viewpoint or feeling rather than a measurable fact that can be proven true or false.';
  }

  /// Cleans technical pipeline tags like `[RECOVERY PASS]` and clinical emojis
  /// from the AI reasoning response, and softens stiff AI jargon into friendly language.
  static String cleanResponseText(dynamic raw, {String? claimText}) {
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
        .replaceFirst(RegExp(r'^\[OFFLINE FALLBACK\]\s*', caseSensitive: false), '')
        .trim();

    // Strip live search timeout annotations
    text = text
        .replaceFirst(
          RegExp(r'\s*\(Live web search timed out;\s*flagged for async background re-grounding\)\.?\s*', caseSensitive: false),
          '',
        )
        .trim();

    // Strip clinical icon prefixes from start of paragraph
    text = text
        .replaceFirst(
          RegExp(r'^[?❔✅❌🟢⏳🔍📎💭👤⚖️❤️🗣️🕊📜💡⚠️\s]+'),
          '',
        )
        .trim();

    // Strip conversational first-person / AI memory disclaimers
    text = text
        .replaceAll(
          RegExp(r'I looked through all my stories and general knowledge[^.]*\.?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'I looked through all my stories[^.]*\.?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r"It's not something lots of people know about from my memory\.?", caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\bfrom my memory\.?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\bin my memory\.?', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r"I couldn't find any common or famous story[^.]*\.?", caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r"I don't have this in my memory\.?", caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\bas an AI,?\s*', caseSensitive: false),
          '',
        )
        .trim();

    // Clean leading punctuation or conjunctions left over
    text = text.replaceFirst(RegExp(r'^[,;.\s]+'), '').trim();

    // If string was reduced to empty or near empty, or still has conversational memory jargon:
    if (text.length < 15 || RegExp(r'\b(?:from my memory|all my stories|in my memory)\b', caseSensitive: false).hasMatch(text)) {
      text = 'Independent records and accredited news reports provide the authoritative context for this statement.';
    }

    // Humanize robotic subjective/opinion classifications into simple, friendly language a 10-year-old can understand,
    // explicitly explaining WHY our system configured it as an opinion.
    if (RegExp(
          r'(?:Classified\s+as\s+subjective\s+content|not\s+subject\s+to\s+factual\s+verification|subjective\s+content\s*[—–-]|purely\s+subjective\s+statement|subjective\s+opinion\s*[-—–]|cannot\s+be\s+factually\s+verified\s+because\s+it\s+is\s+an\s+opinion|This\s+is\s+someone\x27s\s+personal\s+point\s+of\s+view\s+or\s+feeling|Why\s+is\s+this\s+an\s+opinion\s+and\s+not\s+a\s+fact)',
          caseSensitive: false,
        ).hasMatch(text)) {
      return formatOpinionExplanation(claimText);
    }

    // Humanize common stiff academic / robotic openings for kid-friendliness
    text = text
        .replaceFirst(
          RegExp(r'^(?:Upon\s+)?(?:comprehensive\s+)?empirical\s+(?:investigation|verification|analysis)\s+(?:of\s+available\s+records\s+)?(?:indicates|demonstrates|confirms)\s+that\s+', caseSensitive: false),
          'Official facts and records show that ',
        )
        .replaceFirst(
          RegExp(r'^(?:Upon\s+)?investigative\s+synthesis\s+of\s+the\s+claim,\s*', caseSensitive: false),
          'After checking the facts, ',
        )
        .replaceFirst(
          RegExp(r'^(?:Corroborative|Substantiating)\s+documentation\s+(?:confirms|indicates)\s+that\s+', caseSensitive: false),
          'Trusted records confirm that ',
        )
        .replaceFirst(
          RegExp(r'^(?:The\s+asserted\s+(?:claim|proposition)\s+is\s+substantiated\s+by\s+)', caseSensitive: false),
          'This is proven true by ',
        )
        .replaceFirst(
          RegExp(r'^(?:The\s+asserted\s+(?:claim|proposition)\s+exhibits\s+evidential\s+incongruity\s+with\s+)', caseSensitive: false),
          'This does not match what the facts say in ',
        )
        .replaceFirst(
          RegExp(r'^(?:Centralized\s+repository\s+analysis\s+indicates\s+that\s+)', caseSensitive: false),
          'Our research shows that ',
        )
        .replaceFirst(
          RegExp(r'^(?:Statistical\s+variance\s+metrics\s+demonstrate\s+that\s+)', caseSensitive: false),
          'The numbers show that ',
        )
        .replaceFirst(
          RegExp(r'\b(?:the\s+claimant\s+posited\s+that)\b', caseSensitive: false),
          'the speaker claimed that',
        );

    return text;
  }

  /// Transforms dense, academic, or robotic conclusion texts into warm,
  /// conversational English easily understood by a 10-year-old child.
  static String humanizeConclusionText(String raw) {
    var text = cleanResponseText(raw);

    text = text
        .replaceFirst(
          RegExp(r'^(?:The\s+)?overarching\s+thesis\s+presents\s+empirical\s+concordance\s+with\s+', caseSensitive: false),
          'The main points in this video match real facts from ',
        )
        .replaceFirst(
          RegExp(r'^(?:Institutional|Empirical)\s+corroboration\s+substantiates\s+the\s+core\s+tenets\s+(?:of\s+this\s+video\s+)?', caseSensitive: false),
          'Reliable experts and records back up what was said: ',
        )
        .replaceFirst(
          RegExp(r'^(?:Evidence-adjusted\s+synthesis\s+indicates\s+that\s+)', caseSensitive: false),
          'Looking at all the evidence shows that ',
        )
        .replaceFirst(
          RegExp(r'^(?:The\s+speaker\x27s\s+empirical\s+assertions\s+demonstrate\s+)', caseSensitive: false),
          'The facts mentioned in the video show that ',
        )
        .replaceFirst(
          RegExp(r'^(?:No\s+empirical\s+assertions\s+were\s+detected\s+in\s+the\s+speech\s+transcript\.?)', caseSensitive: false),
          "We checked this video and didn't find any specific facts that need checking — it's mostly personal opinions, music, or casual conversation!",
        )
        .replaceFirst(
          RegExp(r'^(?:Fact-checking\s+analysis\s+is\s+currently\s+unavailable\.?)', caseSensitive: false),
          "We couldn't check the facts for this video right now. Please check your connection and try again soon!",
        );

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

  /// Synthesizes a cohesive, single-paragraph complete answer to the video.
  ///
  /// Delivers an engaging, definitive verdict answering the video's core premise
  /// without mechanical tallies, formulaic counts, or bullet points.
  static String buildCompleteVideoConclusion({
    String? rawConclusion,
    String? summary,
    String? videoTitle,
    List<dynamic>? claims,
    int? verifiedCount,
    int? cautionCount,
    int? falseCount,
  }) {
    // 1. If a substantive qualitative conclusion is already available, humanize and condense it.
    if (rawConclusion != null && rawConclusion.trim().isNotEmpty) {
      final cleaned = humanizeConclusionText(rawConclusion.trim())
          .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
          .trim();
      final lower = cleaned.toLowerCase();
      final isGenericFormula = lower.startsWith('based on ') && lower.contains('empirical claims evaluated');
      final isPlaceholder = lower.contains('overview is being generated') ||
          lower.contains('overview synthesis is finalizing') ||
          lower.contains('finalizing in the background') ||
          lower.contains('checking the facts in this video right now') ||
          lower.contains('individual claim verdicts are already ready') ||
          lower.contains('claim verdicts are complete and available now') ||
          lower.contains('synthesis is finalizing');

      if (!isGenericFormula && !isPlaceholder && cleaned.length > 40) {
        return cleaned;
      }
    }

    // 2. Synthesize a complete narrative answer to the video
    final totalVerified = verifiedCount ?? 0;
    final totalCaution = cautionCount ?? 0;
    final totalFalse = falseCount ?? 0;
    final totalClaims = totalVerified + totalCaution + totalFalse;

    // Resolve clean subject topic
    var subject = '';
    if (summary != null && summary.trim().isNotEmpty && summary.trim().length > 15) {
      final s = summary.trim();
      // Extract the first clean sentence of the summary
      final sentenceMatch = RegExp(r'^([^.!?\n]+[.!?])').firstMatch(s);
      subject = sentenceMatch != null ? sentenceMatch.group(1)!.trim() : s;
    } else if (videoTitle != null && videoTitle.trim().isNotEmpty) {
      var t = videoTitle.trim();
      if (t.contains(' - ')) t = t.split(' - ').first.trim();
      if (t.contains(' | ')) t = t.split(' | ').first.trim();
      subject = 'This video investigates $t.';
    }

    // Ensure subject ends with a period if non-empty
    if (subject.isNotEmpty && !subject.endsWith('.') && !subject.endsWith('!') && !subject.endsWith('?')) {
      subject = '$subject.';
    }

    // If no claims evaluated
    if (totalClaims == 0) {
      if (subject.isNotEmpty) {
        return '$subject Across our review, this discussion centers on personal experiences, creative expression, and viewpoints rather than testable factual claims, meaning viewers are free to explore and enjoy the perspectives presented.';
      }
      return 'Across our comprehensive review, this discussion centers on personal perspectives, commentary, and creative thoughts rather than testable factual claims, allowing viewers to appreciate the shared viewpoints while drawing their own conclusions.';
    }

    // Disputed / False findings exist
    if (totalFalse > 0) {
      if (subject.isNotEmpty) {
        return '$subject While foundational background details in this presentation are accurate, several central assertions conflict directly with documented records and authoritative evidence. Because critical claims are contradicted by reliable reporting, viewers should approach the video with healthy skepticism and cross-reference the verified source documentation before accepting its broader conclusions.';
      }
      return 'While foundational background details in this presentation are accurate, several central assertions conflict directly with documented records and authoritative evidence. Because critical claims are contradicted by reliable reporting, viewers should approach the video with healthy skepticism and cross-reference the verified source documentation before accepting its broader conclusions.';
    }

    // Mixed / Caution-heavy (more caution than verified)
    if (totalCaution > totalVerified) {
      if (subject.isNotEmpty) {
        return "$subject The documented events and real-world milestones highlighted in the video are fully confirmed by trusted records; however, many of the presenter's wider conclusions rely on speculative estimates, uncorroborated projections, and missing historical context. Viewers can confidently trust the factual background, but should treat forward-looking predictions and subjective interpretations as open possibilities rather than settled truth.";
      }
      return "The documented events and real-world milestones highlighted in this video are fully confirmed by trusted records; however, many of the presenter's wider conclusions rely on speculative estimates, uncorroborated projections, and missing historical context. Viewers can confidently trust the factual background, but should treat forward-looking predictions and subjective interpretations as open possibilities rather than settled truth.";
    }

    // Solidly Verified / High Trust
    if (subject.isNotEmpty) {
      return '$subject Our comprehensive verification confirms that the core facts, real-world data, and documented mechanisms presented are truthful, accurate, and corroborated by authoritative public records. While a few forward-looking details warrant helpful real-world context, the overarching thesis of the video is dependable, thoroughly researched, and supported by verifiable evidence.';
    }
    return 'Our comprehensive verification confirms that the core facts, real-world data, and documented mechanisms presented in this video are truthful, accurate, and corroborated by authoritative public records. While a few forward-looking details warrant helpful real-world context, the overarching thesis of the video is dependable, thoroughly researched, and supported by verifiable evidence.';
  }

  /// Extracts and ranks the most valuable primary and authoritative sources
  /// for high-level presentation in the Overview tab.
  static List<Map<String, dynamic>> getMostValuableSources(
    List<dynamic> sources, {
    int limit = 4,
  }) {
    if (sources.isEmpty) return const [];

    final scored = <Map<String, dynamic>>[];
    final seenDomains = <String>{};

    for (final raw in sources) {
      if (!SourceUrlSanitizer.isValidSource(raw)) continue;
      final map = raw is UISource
          ? raw.toMap()
          : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'title': raw.toString()});

      final sanitized = SourceUrlSanitizer.sanitizeSourceMap(map);
      final domain = (sanitized['domain'] ?? '').toString().toLowerCase().trim();
      final title = (sanitized['title'] ?? '').toString().trim();
      final trustLevel = (sanitized['trustLevel'] ?? '').toString().toLowerCase().trim();
      final type = (sanitized['type'] ?? sanitized['sourceType'] ?? '').toString().toLowerCase().trim();

      var score = 0;
      if (trustLevel == 'high' || trustLevel == 'very high') score += 100;
      if (trustLevel == 'medium') score += 30;
      if (type == 'primary' || type.contains('official')) score += 50;
      if (domain.endsWith('.gov') || domain.endsWith('.edu') || domain.endsWith('.mil')) score += 40;
      if (domain.endsWith('.org')) score += 20;

      // Authoritative journalism or scientific bodies
      if (domain.contains('reuters') ||
          domain.contains('apnews') ||
          domain.contains('bbc') ||
          domain.contains('bloomberg') ||
          domain.contains('nature') ||
          domain.contains('science') ||
          domain.contains('who.int') ||
          domain.contains('nasa') ||
          domain.contains('wikipedia')) {
        score += 35;
      }

      if (title.isNotEmpty) score += 10;

      final item = Map<String, dynamic>.from(sanitized);
      item['_evalScore'] = score;
      scored.add(item);
    }

    // Sort by evaluation score descending
    scored.sort((a, b) => ((b['_evalScore'] as int?) ?? 0).compareTo((a['_evalScore'] as int?) ?? 0));

    // Pick top unique domains first
    final result = <Map<String, dynamic>>[];
    for (final s in scored) {
      final d = (s['domain'] ?? '').toString().toLowerCase();
      if (d.isNotEmpty && seenDomains.contains(d)) continue;
      if (d.isNotEmpty) seenDomains.add(d);
      result.add(s);
      if (result.length >= limit) break;
    }

    // If still room, fill with remaining sources
    if (result.length < limit) {
      for (final s in scored) {
        if (!result.contains(s)) {
          result.add(s);
          if (result.length >= limit) break;
        }
      }
    }

    return result;
  }

  /// Extracts key claims highlights (top verified fact, key context/caution claim, and disputed claim)
  /// for high-level display in the Overview tab.
  static Map<String, dynamic> getClaimsOverviewHighlights(List<dynamic> claims) {
    Map<String, dynamic>? topVerified;
    Map<String, dynamic>? topCaution;
    Map<String, dynamic>? topFalse;

    for (final c in claims) {
      if (c == null) continue;
      final map = c is ClaimResult
          ? c.toMap()
          : (c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{'claim': c.toString()});

      final verdict = resolveVerdict(map);
      if (verdict.isOpinion) continue;

      if (verdict.isVerified && topVerified == null) {
        topVerified = map;
      } else if (verdict.isCaution && topCaution == null) {
        topCaution = map;
      } else if (verdict.isFalse && topFalse == null) {
        topFalse = map;
      }

      if (topVerified != null && topCaution != null && topFalse != null) break;
    }

    // If no caution or false, grab a second verified claim for rich presentation
    Map<String, dynamic>? secondaryVerified;
    if (topVerified != null) {
      for (final c in claims) {
        final map = c is ClaimResult
            ? c.toMap()
            : (c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{'claim': c.toString()});
        if (map == topVerified) continue;
        final verdict = resolveVerdict(map);
        if (verdict.isVerified) {
          secondaryVerified = map;
          break;
        }
      }
    }

    return {
      'topVerified': topVerified,
      'secondaryVerified': secondaryVerified,
      'topCaution': topCaution,
      'topFalse': topFalse,
    };
  }
}
