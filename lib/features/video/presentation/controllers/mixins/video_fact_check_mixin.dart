import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
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

  final RxBool hasFactCheckError = false.obs;
  final RxBool hasAttemptedFactCheck = false.obs;
  String? _lastAttemptedFactCheckUrl;

  Future<void> loadFactCheckData([String? overrideUrl, bool force = false]) async {
    if (!video.hasAiCredibility) {
      factCheckData.clear();
      hasFactCheckError.value = false;
      hasAttemptedFactCheck.value = true;
      return;
    }

    var rawUrl = (overrideUrl != null && overrideUrl.isNotEmpty)
        ? overrideUrl
        : video.factCheckUrl;

    if (rawUrl.isEmpty) {
      final cached = VideoMediaService.credibilityCache[video.id];
      if (cached != null && cached.factCheckUrl.isNotEmpty) {
        rawUrl = cached.factCheckUrl;
      } else {
        try {
          final fetched = await VideoMediaService().getCredibility(video.id);
          if (fetched.factCheckUrl.isNotEmpty) {
            rawUrl = fetched.factCheckUrl;
          }
        } catch (_) {}
      }
    }

    if (rawUrl.isEmpty) {
      final cached = VideoMediaService.credibilityCache[video.id];
      if (cached != null &&
          (cached.uiReport != null ||
              cached.claims.isNotEmpty ||
              (cached.trustScore > 0 && video.isFactChecked))) {
        factCheckData.value = cached.toMap();
        hasFactCheckError.value = false;
        hasAttemptedFactCheck.value = true;
        return;
      }
      if (video.uiReport != null) {
        factCheckData.value = video.uiReport!.toMap();
        hasFactCheckError.value = false;
        hasAttemptedFactCheck.value = true;
        return;
      }
      factCheckData.clear();
      hasFactCheckError.value = false;
      hasAttemptedFactCheck.value = true;
      return;
    }

    if (isLoadingFactCheck.value) return;
    if (!force &&
        hasAttemptedFactCheck.value &&
        _lastAttemptedFactCheckUrl == rawUrl &&
        (factCheckData.isNotEmpty || hasFactCheckError.value)) {
      return;
    }

    _lastAttemptedFactCheckUrl = rawUrl;
    isLoadingFactCheck.value = true;
    hasFactCheckError.value = false;

    try {
      Map<String, dynamic>? decoded;

      // 1. Try Firebase Storage authenticated SDK first if it is a Storage or gs:// URL
      if (rawUrl.startsWith('gs://') || rawUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(rawUrl);
          final bytes = await ref.getData();
          if (bytes != null && bytes.isNotEmpty) {
            final jsonStr = utf8.decode(bytes);
            decoded = await IsolateComputeUtils.parseJsonMapAsync(jsonStr);
          }
        } catch (storageErr, stack) {
          ErrorHandler.log(
            storageErr,
            stackTrace: stack,
            tag: 'VideoFactCheckMixin.loadFactCheckData.firebaseStorageSdk',
          );
        }
      }

      // 2. If SDK read was not used or failed, resolve fresh download URL and fetch via AppHttpClient
      if (decoded == null) {
        var fetchUrl = rawUrl;
        if (fetchUrl.startsWith('gs://')) {
          fetchUrl = await FirebaseStorage.instance.refFromURL(fetchUrl).getDownloadURL();
        }
        final response = await AppHttpClient.get(Uri.parse(fetchUrl));
        if (response.statusCode == 200) {
          decoded = await IsolateComputeUtils.parseJsonMapAsync(response.body);
        } else {
          throw Exception(
            'Failed to load fact-check data (status: ${response.statusCode}, url: $fetchUrl)',
          );
        }
      }

      factCheckData.value = decoded;
      hasFactCheckError.value = false;
      hasAttemptedFactCheck.value = true;

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
            claims: parsedCred.claims.isNotEmpty
                ? parsedCred.claims
                : (existing?.claims ?? const []),
            sources: parsedCred.sources.isNotEmpty
                ? parsedCred.sources
                : (existing?.sources ?? const []),
            factCheckUrl: rawUrl,
          );
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'VideoFactCheckMixin.loadFactCheckData.cacheCredibility',
          );
        }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoFactCheckMixin.loadFactCheckData',
      );

      // Attempt fallback to cached credibility or Firestore credibility document
      var fallbackSucceeded = false;
      try {
        final cached = VideoMediaService.credibilityCache[video.id] ??
            await VideoMediaService().getCredibility(video.id);
        if (cached.uiReport != null ||
            cached.claims.isNotEmpty ||
            cached.trustScore > 0 ||
            cached.summary.isNotEmpty) {
          factCheckData.value = cached.toMap();
          fallbackSucceeded = true;
          hasFactCheckError.value = false;
        }
      } catch (_) {}

      if (!fallbackSucceeded) {
        if (video.uiReport != null) {
          factCheckData.value = video.uiReport!.toMap();
          hasFactCheckError.value = false;
        } else {
          factCheckData.clear();
          hasFactCheckError.value = true;
        }
      }
      hasAttemptedFactCheck.value = true;
    } finally {
      isLoadingFactCheck.value = false;
    }
  }

  Future<void> fetchFullDisclosure() async {
    if (video.factCheckUrl.isEmpty && factCheckData.isEmpty) {
      AppSnackbar.info('Detailed fact-checking data is not available for this video.');
      return;
    }

    if (factCheckData.isNotEmpty) {
      showFullDisclosurePanel();
      return;
    }

    isLoadingFactCheck.value = true;
    try {
      var url = video.factCheckUrl;
      if (url.startsWith('gs://')) {
        url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
      }

      final response = await AppHttpClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        factCheckData.value = await IsolateComputeUtils.parseJsonMapAsync(response.body);
        showFullDisclosurePanel();
      } else {
        final cached = VideoMediaService.credibilityCache[video.id] ??
            await VideoMediaService().getCredibility(video.id);
        if (cached.uiReport != null || cached.summary.isNotEmpty) {
          factCheckData.value = cached.toMap();
          showFullDisclosurePanel();
          return;
        }
        throw Exception(
          'Failed to load fact-check disclosure (status: ${response.statusCode}, url: $url)',
        );
      }
    } catch (e) {
      ErrorHandler.log(e, tag: 'VideoFactCheckMixin.fetchFullDisclosure');
      final cached = VideoMediaService.credibilityCache[video.id];
      if (cached != null && (cached.uiReport != null || cached.summary.isNotEmpty)) {
        factCheckData.value = cached.toMap();
        showFullDisclosurePanel();
        return;
      }
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
}
