import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

  Map<String, dynamic> normalizeClaim(dynamic rawClaim) {
    if (rawClaim is ClaimResult) {
      return {
        'text': rawClaim.text,
        'claim': rawClaim.text,
        'verdict': rawClaim.verdict,
        'status': rawClaim.verdict,
        'start': rawClaim.start,
        'end': rawClaim.end,
        'effectiveSources':
            rawClaim.effectiveSources.map((s) => s.toMap()).toList(),
        'sources': rawClaim.effectiveSources.map((s) => s.toMap()).toList(),
        'verdictBasis': rawClaim.verdictBasis,
        'reasoning': rawClaim.verdictBasis?.join('. '),
        'response': rawClaim.verdictBasis?.join('. '),
      };
    } else if (rawClaim is Map) {
      return Map<String, dynamic>.from(rawClaim);
    }
    return {'claim': rawClaim.toString(), 'status': 'unverified'};
  }

  Map<String, dynamic> normalizeSource(dynamic rawSource) {
    if (rawSource is UISource) {
      return rawSource.toMap();
    } else if (rawSource is Map) {
      return Map<String, dynamic>.from(rawSource);
    }
    return {'title': rawSource.toString()};
  }

  int normalizeTimestampToMs(dynamic raw) {
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

  double? extractTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) return parsed;
      final parts = val.split(':');
      if (parts.length == 2) {
        final m = double.tryParse(parts[0]) ?? 0;
        final s = double.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      } else if (parts.length == 3) {
        final h = double.tryParse(parts[0]) ?? 0;
        final m = double.tryParse(parts[1]) ?? 0;
        final s = double.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + s;
      }
    }
    return null;
  }

  double? getClaimStartSeconds(Map<String, dynamic> claim) {
    if (claim.containsKey('startMs') && claim['startMs'] is num) {
      return (claim['startMs'] as num).toDouble() / 1000.0;
    }
    if (claim.containsKey('startTimeMs') && claim['startTimeMs'] is num) {
      return (claim['startTimeMs'] as num).toDouble() / 1000.0;
    }
    final raw = claim['start'] ?? claim['timestampStart'] ?? claim['startTime'];
    final sec = extractTimestamp(raw);
    if (sec != null && sec > 10000 && !claim.containsKey('start')) {
      return sec / 1000.0;
    }
    return sec;
  }

  double? getClaimEndSeconds(Map<String, dynamic> claim, [double? startSec]) {
    if (claim.containsKey('endMs') && claim['endMs'] is num) {
      return (claim['endMs'] as num).toDouble() / 1000.0;
    }
    if (claim.containsKey('endTimeMs') && claim['endTimeMs'] is num) {
      return (claim['endTimeMs'] as num).toDouble() / 1000.0;
    }
    final raw = claim['end'] ?? claim['timestampEnd'] ?? claim['endTime'];
    final sec = extractTimestamp(raw);
    if (sec != null && sec > 10000 && !claim.containsKey('end')) {
      return sec / 1000.0;
    }
    if (sec != null) return sec;
    if (startSec != null) return startSec + 8.0;
    return null;
  }

  Color getVerdictColor(String verdict) {
    return ClaimVerdictHelper.resolveVerdictString(verdict).color;
  }

  String getVerdictLabel(String verdict) {
    return ClaimVerdictHelper.resolveVerdictString(verdict).label;
  }

  String formatFactorKey(String key) {
    return key
        .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .capitalizeFirst ??
        key;
  }

  Color getScoreColor(double score) {
    return Colors.white;
  }

  String getRatingLabel(double score) {
    final s = score <= 5.0 ? score * 20 : score;
    if (s >= 90) return 'EXCEPTIONAL INTEGRITY';
    if (s >= 75) return 'HIGH INTEGRITY';
    if (s >= 60) return 'TRUSTWORTHY';
    if (s >= 45) return 'CAUTION ADVISED';
    return 'LOW INTEGRITY';
  }

  String formatSeconds(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$mins:$secs';
    return '$mins:$secs';
  }



void playClaimAt(
  TowerPlayerController ctrl,
  Map<String, dynamic> claimMap,
  double? startSec,
  double? endSec,
) {
  final cleanText = (claimMap['cleanText'] ??
          claimMap['text'] ??
          claimMap['claim'] ??
          '')
      .toString();
  final verdict = (claimMap['verdict'] ??
          claimMap['status'] ??
          claimMap['verificationStatus'] ??
          'unverified')
      .toString();
  final basis = claimMap['verdictBasis'] is List
      ? List<String>.from(claimMap['verdictBasis'])
      : (claimMap['reasoning'] != null
          ? [claimMap['reasoning'].toString()]
          : null);

  final claimResult = ClaimResult(
    text: cleanText,
    verdict: verdict,
    start: startSec,
    end: endSec,
    verdictBasis: basis,
  );
  ctrl.playClaim(claimResult);
}

Future<void> openSourceUrl(String? url, {String? title, String? domain}) async {
  if (url != null && url.isNotEmpty) {
    await SourceUrlSanitizer.launchSourceUrl(
      url: url,
      title: title,
      domain: domain,
    );
  }
}

  ({
    String cleanText,
    String response,
    List<Map<dynamic, dynamic>> sources,
  }) resolveRealClaimDetails(
    Map<dynamic, dynamic> claim,
    int index,
    List<dynamic> allSources,
  ) {
    final langCode = UserLanguagesService.isRegistered
        ? UserLanguagesService.to.primaryLanguageCode
        : 'en';

    var rawText = (claim['claim'] ??
            claim['text'] ??
            claim['statement'] ??
            'Claim #${index + 1}')
        .toString();

    // Inspect cached localized claim texts
    final rawLocMap = claim['localizedTexts'] ?? claim['translations'] ?? claim['localizations'];
    if (rawLocMap is Map) {
      final locText = rawLocMap[langCode] ??
          rawLocMap['text_$langCode'] ??
          rawLocMap['claim_$langCode'];
      if (locText is String && locText.trim().isNotEmpty) {
        rawText = locText.trim();
      } else if (locText is Map) {
        final nested = locText['text'] ?? locText['claim'] ?? locText['statement'];
        if (nested is String && nested.trim().isNotEmpty) {
          rawText = nested.trim();
        }
      }
    } else {
      final directKey = claim['text_$langCode'] ?? claim['claim_$langCode'];
      if (directKey is String && directKey.trim().isNotEmpty) {
        rawText = directKey.trim();
      }
    }

    rawText = ClaimVerdictHelper.cleanClaimText(rawText, index);

    var rawResponse = (claim['response'] ??
            claim['reasoning'] ??
            claim['whyWrong'] ??
            claim['explanation'] ??
            claim['correction'] ??
            claim['verificationSummary'] ??
            claim['details'] ??
            claim['analysis'] ??
            claim['context'] ??
            claim['note'] ??
            '')
        .toString();

    // Inspect cached localized response / reasoning
    if (rawLocMap is Map) {
      final locEntry = rawLocMap[langCode];
      if (locEntry is Map) {
        final locResp = locEntry['response'] ??
            locEntry['reasoning'] ??
            locEntry['explanation'] ??
            locEntry['summaryTakeaway'];
        if (locResp is String && locResp.trim().isNotEmpty) {
          rawResponse = locResp.trim();
        }
      } else if (locEntry is String && locEntry.trim().isNotEmpty && rawText != locEntry.trim()) {
        rawResponse = locEntry.trim();
      }
    }
    final directResp = claim['response_$langCode'] ??
        claim['reasoning_$langCode'] ??
        claim['explanation_$langCode'];
    if (directResp is String && directResp.trim().isNotEmpty) {
      rawResponse = directResp.trim();
    }

    rawResponse = ClaimVerdictHelper.cleanResponseText(rawResponse, claimText: rawText);

    if (rawResponse.isEmpty ||
        rawResponse.startsWith('This statement relies on contextual') ||
        rawResponse.startsWith('Summary unavailable')) {
      final verdictInfo = ClaimVerdictHelper.resolveVerdict(claim);
      if (verdictInfo.isOpinion) {
        rawResponse = ClaimVerdictHelper.formatOpinionExplanation(rawText);
      } else {
        rawResponse = verdictInfo.localizedTakeaway(langCode);
      }
    }

    final sourceStatus = (claim['sourceStatus'] ?? claim['sourcesStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isMissingSources = sourceStatus == 'missing';

    final realSources = <Map<dynamic, dynamic>>[];
    if (!isMissingSources) {
      final rawSources = claim['sources'] ??
          claim['richSources'] ??
          claim['evidence'] ??
          claim['citations'] ??
          claim['references'] ??
          claim['effectiveSources'];
      if (rawSources is List) {
        for (final s in rawSources) {
          if (!SourceUrlSanitizer.isValidSource(s)) continue;
          if (s is UISource) {
            final sanitized = SourceUrlSanitizer.sanitizeSourceMap(s.toMap());
            final url = sanitized['url']?.toString();
            if (url != null && url.isNotEmpty) {
              realSources.add(sanitized);
            }
          } else if (s is Map) {
            final sanitized = SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s));
            final url = sanitized['url']?.toString();
            if (url != null && url.isNotEmpty) {
              realSources.add(sanitized);
            }
          } else if (s is String && s.trim().isNotEmpty) {
            final clean = SourceUrlSanitizer.sanitizeUrl(s, title: s);
            if (clean != null && clean.isNotEmpty) {
              realSources.add({
                'title': s.trim(),
                'url': clean,
                'directUrl': clean,
                'domain': SourceUrlSanitizer.resolveDisplayDomain(clean, title: s),
                'snippet': 'Citation reference',
              });
            }
          }
        }
      }

      for (final s in allSources) {
        if (!SourceUrlSanitizer.isValidSource(s)) continue;
        final sMap = s is UISource
            ? SourceUrlSanitizer.sanitizeSourceMap(s.toMap())
            : (s is Map ? SourceUrlSanitizer.sanitizeSourceMap(Map<dynamic, dynamic>.from(s)) : null);
        if (sMap != null) {
          final url = sMap['url']?.toString();
          if (url == null || url.isEmpty) continue;
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
    }

    return (
      cleanText: rawText,
      response: rawResponse,
      sources: realSources,
    );
  }


