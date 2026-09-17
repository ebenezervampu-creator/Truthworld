import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';

/// Mixin handling AI fact-check data hydration and full disclosure reports.
mixin VideoFactCheckMixin on GetxController {
  Video get video;
  RxMap<String, dynamic> get factCheckData;
  RxBool get isLoadingFactCheck;

  Future<void> loadFactCheckData([String? overrideUrl]) async {
    final rawUrl = (overrideUrl != null && overrideUrl.isNotEmpty)
        ? overrideUrl
        : video.factCheckUrl;
    if (rawUrl.isEmpty) {
      factCheckData.clear();
      return;
    }

    isLoadingFactCheck.value = true;
    try {
      var url = rawUrl;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        factCheckData.value = decoded;

        try {
          final existing = VideoMediaService.credibilityCache[video.id];
          final parsedCred = VideoMediaCredibility.fromMap(decoded);
          VideoMediaService.credibilityCache[video.id] = VideoMediaCredibility(
            trustScore: parsedCred.trustScore > 0
                ? parsedCred.trustScore
                : (existing?.trustScore ?? video.trustScore),
            trustLabel: parsedCred.trustLabel ??
                existing?.trustLabel ??
                decoded['trustLabel']?.toString() ??
                decoded['label']?.toString(),
            summary: parsedCred.summary.isNotEmpty
                ? parsedCred.summary
                : (existing?.summary ??
                    decoded['summary']?.toString() ??
                    decoded['viewerNote']?.toString() ??
                    ''),
            scoringFactors:
                parsedCred.scoringFactors ?? existing?.scoringFactors,
            deductions: parsedCred.deductions.isNotEmpty
                ? parsedCred.deductions
                : (existing?.deductions ?? const []),
            contextualFlags: parsedCred.contextualFlags.isNotEmpty
                ? parsedCred.contextualFlags
                : (existing?.contextualFlags ?? const []),
            honestyBreakdown:
                parsedCred.honestyBreakdown ?? existing?.honestyBreakdown,
            harmCapApplied: parsedCred.harmCapApplied ||
                (existing?.harmCapApplied ?? false),
            harmCapReason:
                parsedCred.harmCapReason ?? existing?.harmCapReason,
            confidenceNotes: parsedCred.confidenceNotes.isNotEmpty
                ? parsedCred.confidenceNotes
                : (existing?.confidenceNotes ?? const []),
            diagnostics: parsedCred.diagnostics.isNotEmpty
                ? parsedCred.diagnostics
                : (existing?.diagnostics ?? const []),
            factCheckStats:
                parsedCred.factCheckStats ?? existing?.factCheckStats,
            videoCategory:
                parsedCred.videoCategory ?? existing?.videoCategory,
            effectiveCategory:
                parsedCred.effectiveCategory ?? existing?.effectiveCategory,
            hardeningMetadata:
                parsedCred.hardeningMetadata ?? existing?.hardeningMetadata,
            intentToMisleadScore: (parsedCred.intentToMisleadScore != null &&
                    parsedCred.intentToMisleadScore! > 0)
                ? parsedCred.intentToMisleadScore
                : (existing?.intentToMisleadScore ?? 0.0),
            uiReport: parsedCred.uiReport ?? UIReport.fromMap(decoded),
            factCheckUrl: rawUrl,
          );
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'VideoFactCheckMixin.loadFactCheckData.cacheCredibility',
          );
        }
      } else {
        throw Exception('Failed to load fact-check data');
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoFactCheckMixin.loadFactCheckData',
      );
      factCheckData.clear();
    } finally {
      isLoadingFactCheck.value = false;
    }
  }

  Future<void> fetchFullDisclosure() async {
    if (video.factCheckUrl.isEmpty) {
      AppSnackbar.info('Detailed fact-checking data is not available for this video.');
      return;
    }

    isLoadingFactCheck.value = true;
    try {
      var url = video.factCheckUrl;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        factCheckData.value = jsonDecode(response.body) as Map<String, dynamic>;
        showFullDisclosurePanel();
      } else {
        throw Exception('Failed to load fact-check data');
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to retrieve fact check disclosure. Please try again.');
    } finally {
      isLoadingFactCheck.value = false;
    }
  }

  void showFullDisclosurePanel() {
    Get.bottomSheet(
      FactCheckReportWidget(
        data: Map<String, dynamic>.from(factCheckData),
        video: video,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// Backward-compatible alias.
  void _showFullDisclosurePanel() => showFullDisclosurePanel();
}
