import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

class VideoAnalysisHelpers {
  static int normalizeTimestampToMs(dynamic raw) {
    if (raw == null) return 0;
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null) {
        return normalizeTimestampToMs(parsed);
      }
      final parts = raw.split(':');
      if (parts.length == 2) {
        final m = double.tryParse(parts[0]) ?? 0;
        final s = double.tryParse(parts[1]) ?? 0;
        return ((m * 60 + s) * 1000).toInt();
      } else if (parts.length == 3) {
        final h = double.tryParse(parts[0]) ?? 0;
        final m = double.tryParse(parts[1]) ?? 0;
        final s = double.tryParse(parts[2]) ?? 0;
        return ((h * 3600 + m * 60 + s) * 1000).toInt();
      }
      return 0;
    }
    if (raw is num) {
      final val = raw.toDouble();
      if (val <= 0) return 0;
      if (val > 10000) {
        return val.toInt();
      }
      return (val * 1000).toInt();
    }
    return 0;
  }


  static String formatFactorKey(String key) {
    return key
        .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .capitalizeFirst ??
        key;
  }


  static Color getScoreColor(double score) {
    return Colors.white;
  }


  static String getRatingLabel(double score) {
    final s = score <= 5.0 ? score * 20 : score;
    if (s >= 90) return 'EXCEPTIONAL INTEGRITY';
    if (s >= 75) return 'HIGH INTEGRITY';
    if (s >= 60) return 'TRUSTWORTHY';
    if (s >= 45) return 'CAUTION ADVISED';
    return 'LOW INTEGRITY';
  }


  static ({String cleanText, String response, List<Map<dynamic, dynamic>> sources})
  resolveRealClaimDetails(
    Map<dynamic, dynamic> claim,
    int index,
    List<dynamic> allSources,
  ) {
    var rawText = (claim['claim'] ??
            claim['text'] ??
            claim['statement'] ??
            'Claim #${index + 1}')
        .toString()
        .trim();
    // Strip leading question marks, emojis, or clinical labels
    rawText = ClaimVerdictHelper.cleanClaimText(rawText, index);

    var basisStr = '';
    final rawBasis = claim['verdictBasis'] ?? claim['basis'];
    if (rawBasis is List && rawBasis.isNotEmpty) {
      basisStr = rawBasis
          .map((b) => b.toString().trim())
          .where((s) => s.isNotEmpty)
          .join('\n\n');
    } else if (rawBasis is String && rawBasis.isNotEmpty) {
      basisStr = rawBasis;
    }

    var rawResponse = (claim['response'] ??
            claim['reasoning'] ??
            claim['whyWrong'] ??
            claim['explanation'] ??
            claim['correction'] ??
            claim['verificationSummary'] ??
            (basisStr.isNotEmpty ? basisStr : null) ??
            claim['details'] ??
            claim['analysis'] ??
            claim['context'] ??
            claim['note'] ??
            claim['aiNote'] ??
            claim['aiResponse'] ??
            claim['verdictReason'] ??
            '')
        .toString()
        .trim();

    rawResponse = ClaimVerdictHelper.cleanResponseText(rawResponse);

    // If no AI reasoning is available, provide polite and informative takeaway from verdict
    if (rawResponse.isEmpty ||
        rawResponse.startsWith('This statement relies on contextual') ||
        rawResponse.startsWith('Summary unavailable')) {
      final verdictInfo = ClaimVerdictHelper.resolveVerdict(claim);
      rawResponse = verdictInfo.summaryTakeaway;
    }

    final realSources = <Map<dynamic, dynamic>>[];
    final rawSources = claim['sources'] ??
        claim['effectiveSources'] ??
        claim['richSources'] ??
        claim['evidence'] ??
        claim['citations'] ??
        claim['references'];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (!SourceUrlSanitizer.isValidSource(s)) continue;
        if (s is UISource) {
          realSources.add(SourceUrlSanitizer.sanitizeSourceMap(s.toMap()));
        } else if (s is Map) {
          final sanitized = SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s));
          realSources.add(sanitized);
        } else if (s is String && s.trim().isNotEmpty) {
          final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s);
          realSources.add({
            'title': s.trim(),
            'url': clean ?? '',
            'directUrl': clean ?? '',
            'domain': SourceUrlSanitizer.resolveDisplayDomain(clean, title: s),
            'snippet': 'Historical citation reference',
          });
        }
      }
    }

    // Match global sources from report (legitimate cross-referencing)
    for (final s in allSources) {
      if (!SourceUrlSanitizer.isValidSource(s)) continue;
      final sMap = s is UISource
          ? SourceUrlSanitizer.sanitizeSourceMap(s.toMap())
          : (s is Map ? SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s)) : null);
      if (sMap != null) {
        final sTitle = (sMap['title'] ?? sMap['author'] ?? sMap['domain'] ?? '')
            .toString()
            .toLowerCase();
        final keywords =
            rawText.toLowerCase().split(' ').where((w) => w.length > 3);
        if (keywords.any(sTitle.contains)) {
          if (!realSources.any((existing) => existing['title'] == sMap['title'])) {
            realSources.add(sMap);
          }
        }
      }
    }

    return (
      cleanText: rawText,
      response: rawResponse,
      sources: realSources,
    );
  }

}
