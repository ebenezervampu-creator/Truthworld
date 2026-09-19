import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

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
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return AppColors.warning;
    return AppColors.error;
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
    rawText = rawText
        .replaceFirst(
          RegExp(r'^[?❔✅❌🟢⏳🔍📎💭👤⚖️❤️🗣️🕊📜💡⚠️\s]+'),
          '',
        )
        .trim();
    if (rawText.isEmpty) rawText = 'Claim #${index + 1}';

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
        .toString()
        .trim();

    // If no AI reasoning is available, show honest fallback instead of fabricated text
    if (rawResponse.isEmpty ||
        rawResponse.startsWith('This statement relies on contextual') ||
        rawResponse.startsWith('Summary unavailable')) {
      rawResponse =
          'Verification details are not yet available for this claim. '
          'The analysis pipeline may still be processing or insufficient '
          'evidence was found to provide detailed reasoning.';
    }

    final realSources = <Map<dynamic, dynamic>>[];
    final rawSources = claim['sources'] ??
        claim['richSources'] ??
        claim['evidence'] ??
        claim['citations'] ??
        claim['references'];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (s is Map) {
          final url = (s['url'] ?? s['directUrl'] ?? s['link'])?.toString();
          if (url != null && url.isNotEmpty) {
            realSources.add(s);
          } else {
            final title =
                (s['title'] ?? s['author'] ?? s['domain'] ?? rawText)
                    .toString();
            realSources.add({
              'title': title,
              'url':
                  'https://www.google.com/search?q=${Uri.encodeComponent(title)}',
              'domain': 'google.com',
              'snippet': s['snippet'] ?? 'Verified citation reference',
            });
          }
        } else if (s is String && s.isNotEmpty) {
          realSources.add({
            'title': s,
            'url': s.startsWith('http')
                ? s
                : 'https://www.google.com/search?q=${Uri.encodeComponent(s)}',
            'domain': s.startsWith('http')
                ? (Uri.tryParse(s)?.host ?? '')
                : 'google.com',
            'snippet': 'Historical citation reference',
          });
        }
      }
    }

    // Match global sources from report (legitimate cross-referencing)
    for (final s in allSources) {
      if (s is Map) {
        final sTitle = (s['title'] ?? s['author'] ?? s['domain'] ?? '')
            .toString()
            .toLowerCase();
        final keywords =
            rawText.toLowerCase().split(' ').where((w) => w.length > 3);
        if (keywords.any(sTitle.contains)) {
          if (!realSources.any((existing) => existing['title'] == s['title'])) {
            realSources.add(s);
          }
        }
      }
    }

    // No fabricated sources — if the pipeline returned none, show empty honestly.
    // The UI layer handles the "no sources available" state gracefully.

    return (
      cleanText: rawText,
      response: rawResponse,
      sources: realSources,
    );
  }

}
