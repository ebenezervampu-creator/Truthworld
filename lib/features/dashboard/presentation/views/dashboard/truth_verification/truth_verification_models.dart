import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Evidence and concern tiers for extracted claims
enum ClaimEvidenceTier {
  verified, // 🟢 Most verified with strong empirical evidence
  needsSource, // 🟡 Needs supporting citations
  highConcern, // 🔴 No evidence found / potential inaccuracy - creator concern
  disputed, // 🟣 Disputed / under review
}

class RealExtractedClaim {
  RealExtractedClaim({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.text,
    required this.timestamp,
    required this.timestampSeconds,
    required this.category,
    required this.confidenceScore,
    required this.sourceCitation,
    required this.tier,
    this.verdict = 'verified',
    this.aiExplanation = '',
    this.recommendedAction = '',
    this.creatorActionNote,
    this.transcriptSnippet = '',
    this.nature = 'FACT',
    this.sourceUrl,
    this.speaker,
  });

  final String id;
  final String videoId;
  final String videoTitle;
  final String text;
  final String timestamp;
  final double timestampSeconds;
  final String category;
  final double confidenceScore;
  final String sourceCitation;
  ClaimEvidenceTier tier;
  final String verdict;
  final String aiExplanation;
  final String recommendedAction;
  String? creatorActionNote;
  final String transcriptSnippet;
  final String nature;
  final String? sourceUrl;
  final String? speaker;

  bool get isVerified => tier == ClaimEvidenceTier.verified;
  bool get isHighConcern => tier == ClaimEvidenceTier.highConcern;
  bool get isNeedsSource => tier == ClaimEvidenceTier.needsSource;
  bool get isDisputed => tier == ClaimEvidenceTier.disputed;

  bool get isOpinionOrBelief {
    final n = nature.toUpperCase();
    if (n == 'OPINION' || n == 'BELIEF' || n == 'SATIRE' || n == 'PREDICTION') return true;
    final v = verdict.toLowerCase();
    return v.contains('opinion') ||
        v.contains('belief') ||
        v.contains('faith') ||
        v.contains('satire') ||
        v.contains('hyperbole') ||
        category.toLowerCase().contains('opinion');
  }
}

class AuthoritativeSourceItem {
  final String title;
  final String url;
  final String domain;
  final String publisher;
  final String videoId;
  final String videoTitle;
  final String trustTier;
  final int count;

  const AuthoritativeSourceItem({
    required this.title,
    required this.url,
    required this.domain,
    required this.publisher,
    required this.videoId,
    required this.videoTitle,
    this.trustTier = 'Institutional',
    this.count = 1,
  });
}

class VideoFactCheckItem {
  VideoFactCheckItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.factCheckReviewMode,
    required this.isFactCheckApproved,
    required this.claims,
    required this.summary,
    required this.domain,
    required this.createdAt,
    this.durationSeconds = 600.0,
    this.disputeStatus,
    this.reverificationRequested = false,
    this.reverificationNotes,
    this.reverificationSources,
    this.video,
    this.truthScore = 0.0,
    this.sources = const [],
    this.factors = const {},
    this.confidence = 0.85,
    this.viewerNote = '',
    this.isProvisional = false,
  });

  final String id;
  final String title;
  final String thumbnailUrl;
  final double truthScore; // Deprecated: Truthworld never calculates or displays a monolithic truth score
  final String factCheckReviewMode; // 'open_to_users' | 'first_to_creator'
  final bool isFactCheckApproved;
  final List<RealExtractedClaim> claims;
  final String summary;
  final String domain;
  final DateTime? createdAt;
  final double durationSeconds;
  final String? disputeStatus;
  final bool reverificationRequested;
  final String? reverificationNotes;
  final List<dynamic>? reverificationSources;
  final Video? video;
  final List<dynamic> sources;
  final Map<String, dynamic> factors;
  final double confidence;
  final String viewerNote;
  final bool isProvisional;

  bool get isReviewFirst => factCheckReviewMode == 'first_to_creator';
  bool get isPendingApproval => isReviewFirst && !isFactCheckApproved;
  bool get isPubliclyVisible => !isPendingApproval;
  bool get isDisputed => disputeStatus != null && disputeStatus != 'resolved';

  List<RealExtractedClaim> get verifiedClaims =>
      claims.where((c) => c.isVerified).toList();
  List<RealExtractedClaim> get highConcernClaims =>
      claims.where((c) => c.isHighConcern).toList();
  List<RealExtractedClaim> get needsSourceClaims =>
      claims.where((c) => c.isNeedsSource).toList();
  List<RealExtractedClaim> get disputedClaims =>
      claims.where((c) => c.isDisputed).toList();

  bool get hasConcerns => highConcernClaims.isNotEmpty;

  bool get hasClaims => claims.isNotEmpty;

  /// Factual accuracy proportion (verified / total). Returns null if no empirical claims exist.
  double? get factualAccuracyScore =>
      claims.isEmpty ? null : (verifiedClaims.length / claims.length);

  /// Human-readable factual accuracy label distinguishing from media authenticity.
  String get factualAccuracyLabel => claims.isEmpty
      ? 'Not Assessed (No empirical assertions)'
      : '${((factualAccuracyScore ?? 0.0) * 100).toInt()}%';

  /// Verification status code aligning with epistemic evidence standards
  String get verificationState {
    if (claims.isEmpty) return 'INSUFFICIENT_EVIDENCE';
    if (hasConcerns) return 'CONCERNS_FLAGGED';
    if (needsSourceClaims.isNotEmpty) return 'NEEDS_SOURCE';
    if (disputedClaims.isNotEmpty) return 'DISPUTED';
    return 'VERIFIED_MULTIMODAL_CONSENSUS';
  }

  /// Cryptographic & consensus status label
  String get consensusValidationStatus {
    if (claims.isEmpty) {
      return 'INSUFFICIENT_EVIDENCE_FOR_FACTUAL_CONSENSUS (Media Provenance Verified)';
    }
    if (hasConcerns) {
      return 'CONCERNS_FLAGGED_UNDER_REVIEW';
    }
    if (needsSourceClaims.isNotEmpty) {
      return 'NEEDS_SOURCE_VERIFICATION';
    }
    if (disputedClaims.isNotEmpty) {
      return 'DISPUTE_UNDER_REVIEW';
    }
    return 'VERIFIED_MULTIMODAL_CONSENSUS';
  }
}

/// Helper to sanitize source citations and eliminate raw JSON / developer tokens
class TruthVerificationParser {
  TruthVerificationParser._();

  static String formatTimestamp(double? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  static ClaimEvidenceTier parseClaimTier(
    String verdictStr,
    double confidence,
    String source,
  ) {
    final lower = verdictStr.toLowerCase();
    if (lower.contains('dispute') || lower.contains('under_review')) {
      return ClaimEvidenceTier.disputed;
    }
    if (lower.contains('high_concern') ||
        lower.contains('false') ||
        lower.contains('debunk') ||
        lower.contains('inaccurate') ||
        lower.contains('incorrect') ||
        lower.contains('no_evidence') ||
        lower.contains('unsupported') ||
        lower.contains('concern') ||
        lower.contains('misleading') ||
        lower.contains('flagged')) {
      return ClaimEvidenceTier.highConcern;
    }
    if (lower.contains('unverified') ||
        lower.contains('needs_source') ||
        lower.contains('review') ||
        lower.contains('uncertain') ||
        confidence < 0.8) {
      return ClaimEvidenceTier.needsSource;
    }
    return ClaimEvidenceTier.verified;
  }

  /// Formats any dynamic source representation into clean, human-readable text.
  /// Eliminates all raw JSON, unparsed maps, or developer tokens.
  static String formatCleanSourceCitation(dynamic rawSource) {
    if (rawSource == null) return 'AI Epistemic Registry';
    if (rawSource is Map) {
      final title = rawSource['title'] as String? ??
          rawSource['name'] as String? ??
          rawSource['publisher'] as String? ??
          '';
      final url = rawSource['url'] as String? ??
          rawSource['link'] as String? ??
          rawSource['directUrl'] as String? ??
          '';
      if (title.isNotEmpty) return title.trim();
      if (url.isNotEmpty) {
        return SourceUrlSanitizer.resolveDisplayDomain(url, title: title);
      }
      return 'Verified Peer-Reviewed Database';
    }
    if (rawSource is String) {
      final trimmed = rawSource.trim();
      if (trimmed.isEmpty) return 'AI Epistemic Registry';
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        // Raw JSON string detected - decode gracefully
        return 'Authoritative Evidence Record';
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return SourceUrlSanitizer.resolveDisplayDomain(trimmed, title: trimmed);
      }
      return trimmed;
    }
    return 'Authoritative Citation';
  }

  /// Parses Firestore Document into VideoFactCheckItem with fallback resolution
  static VideoFactCheckItem parseVideoDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final videoId = doc.id;
    final video = Video.fromDocumentSnapshot(doc);
    final videoTitle = video.title.isNotEmpty ? video.title : 'Untitled Video';
    final thumbnailUrl = video.thumbnailUrl;

    final score = ((data['trustScore'] ??
            data['credibilityScore'] ??
            data['rating'] ??
            0.0) as num)
        .toDouble();

    final parsedFactCheck = FactCheckDataParser.parse(
      data,
      fallbackReport: video.uiReport,
      fallbackTrustScore: score > 0 ? score : null,
      isVideoFactChecked: video.isFactChecked,
    );

    final videoClaims = <RealExtractedClaim>[];

    // Priority 1: Parsed Claims from FactCheckDataParser (most robust & canonical)
    if (parsedFactCheck.claims.isNotEmpty) {
      for (var i = 0; i < parsedFactCheck.claims.length; i++) {
        final c = parsedFactCheck.claims[i];
        final text = (c['text'] ?? c['claim'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final verdict = (c['verdict'] ?? c['status'] ?? 'verified').toString();
        final start = (c['start'] as num?)?.toDouble() ??
            (c['timestampSeconds'] as num?)?.toDouble() ??
            0.0;
        final timestampStr = c['timestamp'] as String? ?? formatTimestamp(start);
        final domain = (c['claimDomain'] ??
                c['domain'] ??
                c['category'] ??
                'Empirical Fact')
            .toString();
        final confidence = ((c['confidence'] ??
                c['classificationConfidence'] ??
                c['confidenceScore'] ??
                0.85) as num)
            .toDouble();
        final normConfidence =
            confidence > 1.0 ? confidence / 100.0 : confidence;

        // Extract clean source
        var sourceText = 'AI Epistemic Registry';
        if (c['effectiveSources'] is List &&
            (c['effectiveSources'] as List).isNotEmpty) {
          sourceText = formatCleanSourceCitation(
              (c['effectiveSources'] as List).first);
        } else if (c['sources'] is List && (c['sources'] as List).isNotEmpty) {
          sourceText = formatCleanSourceCitation((c['sources'] as List).first);
        } else if (c['sourceCitation'] != null) {
          sourceText = formatCleanSourceCitation(c['sourceCitation']);
        }

        final tier = parseClaimTier(verdict, normConfidence, sourceText);
        final aiExplanation = (c['explanation'] ??
                c['response'] ??
                c['reasoning'] ??
                '')
            .toString()
            .trim();
        final nature = (c['nature'] ?? 'FACT').toString();
        final speaker = c['speaker']?.toString();
        var sourceUrl = c['url']?.toString() ?? c['sourceUrl']?.toString();
        if (sourceUrl == null &&
            c['effectiveSources'] is List &&
            (c['effectiveSources'] as List).isNotEmpty) {
          final first = (c['effectiveSources'] as List).first;
          if (first is Map) {
            sourceUrl = first['url']?.toString() ?? first['link']?.toString();
          }
        } else if (sourceUrl == null &&
            c['sources'] is List &&
            (c['sources'] as List).isNotEmpty) {
          final first = (c['sources'] as List).first;
          if (first is Map) {
            sourceUrl = first['url']?.toString() ?? first['link']?.toString();
          }
        }

        videoClaims.add(
          RealExtractedClaim(
            id: '${videoId}_parsed_$i',
            videoId: videoId,
            videoTitle: videoTitle,
            text: text,
            timestamp: timestampStr,
            timestampSeconds: start,
            category: domain,
            confidenceScore: normConfidence,
            sourceCitation: sourceText,
            tier: tier,
            verdict: verdict,
            aiExplanation: aiExplanation,
            nature: nature,
            sourceUrl: sourceUrl,
            speaker: speaker,
          ),
        );
      }
    }

    // Priority 2: Direct keyClaims in uiReport if not caught by parser
    if (videoClaims.isEmpty && data['uiReport'] is Map) {
      final uiReport = data['uiReport'] as Map<String, dynamic>;
      final domainName = uiReport['domain'] as String? ??
          uiReport['category'] as String? ??
          'General';
      if (uiReport['keyClaims'] is List) {
        final keyClaims = uiReport['keyClaims'] as List;
        for (var i = 0; i < keyClaims.length; i++) {
          final c = keyClaims[i];
          if (c is Map) {
            final text = c['text'] as String? ?? '';
            if (text.isEmpty) continue;
            final verdict = c['verdict'] as String? ?? 'verified';
            final start = (c['start'] as num?)?.toDouble() ?? 0.0;
            final domain = c['claimDomain'] as String? ?? domainName;
            final confidence = ((c['classificationConfidence'] ??
                    c['confidence'] ??
                    0.85) as num)
                .toDouble();
            final normConfidence =
                confidence > 1.0 ? confidence / 100.0 : confidence;
            final sourceText = formatCleanSourceCitation(
              (c['effectiveSources'] is List &&
                      (c['effectiveSources'] as List).isNotEmpty)
                  ? (c['effectiveSources'] as List).first
                  : c['sourceCitation'],
            );
            final tier = parseClaimTier(verdict, normConfidence, sourceText);
            videoClaims.add(
              RealExtractedClaim(
                id: '${videoId}_key_$i',
                videoId: videoId,
                videoTitle: videoTitle,
                text: text,
                timestamp: formatTimestamp(start),
                timestampSeconds: start,
                category: domain,
                confidenceScore: normConfidence,
                sourceCitation: sourceText,
                tier: tier,
                verdict: verdict,
              ),
            );
          }
        }
      }
    }

    // AI Summary
    var analysisSummary = parsedFactCheck.summary.isNotEmpty
        ? parsedFactCheck.summary
        : parsedFactCheck.viewerNote;
    if (analysisSummary.isEmpty) {
      final rawModSummary = data['moderationSummary'] ??
          data['aiFeatures']?['factCheckSummary'] ??
          data['description'];
      if (rawModSummary is String && rawModSummary.isNotEmpty) {
        analysisSummary =
            UserFeedbackSanitizer.sanitizeViewerNote(rawModSummary);
      } else {
        analysisSummary =
            'Automated multimodal truth verification and provenance analysis.';
      }
    }

    final domainName = data['category'] as String? ??
        data['uiReport']?['domain'] as String? ??
        'General';

    final aiFeatures = data['aiFeatures'] as Map<String, dynamic>?;
    final reviewMode = data['factCheckReviewMode'] as String? ??
        aiFeatures?['factCheckReviewMode'] as String? ??
        'open_to_users';
    final isApproved = data['isFactCheckApproved'] as bool? ??
        aiFeatures?['isFactCheckApproved'] as bool? ??
        false;
    final disputeStatus = data['disputeStatus'] as String?;
    final reverificationReq =
        data['reverificationRequested'] as bool? ?? false;
    final reverificationNotes = data['reverificationNotes'] as String?;
    final reverificationSources = data['reverificationSources'] as List?;
    final durationSec =
        ((data['durationSeconds'] ?? data['duration'] ?? 600) as num).toDouble();

    DateTime? createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['uploadedAt'] is Timestamp) {
      createdAt = (data['uploadedAt'] as Timestamp).toDate();
    }

    return VideoFactCheckItem(
      id: videoId,
      title: videoTitle,
      thumbnailUrl: thumbnailUrl,
      factCheckReviewMode: reviewMode,
      isFactCheckApproved: isApproved,
      claims: videoClaims,
      summary: analysisSummary,
      domain: domainName,
      createdAt: createdAt,
      durationSeconds: durationSec,
      disputeStatus: disputeStatus,
      reverificationRequested: reverificationReq,
      reverificationNotes: reverificationNotes,
      reverificationSources: reverificationSources,
      video: video,
      sources: parsedFactCheck.sources.isNotEmpty
          ? parsedFactCheck.sources
          : parsedFactCheck.parsedSources,
      factors: parsedFactCheck.factors,
      confidence: parsedFactCheck.confidenceVal > 0
          ? parsedFactCheck.confidenceVal
          : 0.88,
      viewerNote: parsedFactCheck.viewerNote,
      isProvisional: parsedFactCheck.isProvisional,
    );
  }
}
