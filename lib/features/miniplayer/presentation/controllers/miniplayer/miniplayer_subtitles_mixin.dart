import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_state_base.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Mixin providing subtitle track loading, parsing, and real-time syncing.
mixin MiniplayerSubtitlesMixin on MiniplayerStateBase {
  /// Toggle subtitle visibility and sync with global subtitle preference.
  void toggleSubtitles() {
    final enabled = !subtitlesEnabled.value;
    subtitlesEnabled.value = enabled;
    TowerPlayerController.globalSubtitlesEnabled = enabled;

    if (enabled) {
      loadBestSubtitleTrack();
    } else {
      subtitleSegments.clear();
      currentSubtitle.value = '';
    }
  }

  /// Resolve and load the best matching subtitle track (defaulting to English).
  Future<void> loadBestSubtitleTrack() async {
    final video = currentVideo.value;
    if (video == null) return;

    final subs = Map<String, String>.from(video.mediaSubtitles);
    final primaryLang = normalizeLanguageCode(video.language.isNotEmpty ? video.language : 'en');
    if (video.transcriptionUrl.isNotEmpty &&
        !subs.containsKey(primaryLang) &&
        !subs.containsKey(video.language)) {
      subs[primaryLang] = video.transcriptionUrl;
    }
    if (subs.isEmpty) return;

    // Find the primary/first available subtitle track
    final selectedUrl = subs[primaryLang] ?? subs['en'] ?? subs.values.firstOrNull;
    if (selectedUrl == null) return;

    await fetchAndParseSubtitles(selectedUrl);
  }

  /// Fetch subtitles from HTTP or Firebase Storage and parse segments.
  Future<void> fetchAndParseSubtitles(String url) async {
    if (url.isEmpty) return;
    try {
      String? content;
      try {
        final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
        final headers = await StorageUtils.getMediaHeaders();
        final response = await AppHttpClient.get(
          Uri.parse(resolvedUrl),
          headers: headers,
        );
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (e) {
        logger.warning(
          'Miniplayer fast download HTTP probe for subtitles skipped or failed: $e',
          tag: 'MiniplayerController.fetchSubtitlesHttp',
        );
      }

      if (content == null || content.isEmpty) {
        try {
          Uint8List? data;
          final ref = StorageUtils.getStorageRef(url);
          if (ref != null) {
            data = await StorageUtils.getDataWithTimeout(ref);
          }
          if (data != null && data.isNotEmpty) {
            content = utf8.decode(data, allowMalformed: true);
          }
        } catch (_) {}
      }

      if (content != null && content.isNotEmpty) {
        subtitleSegments.assignAll(await IsolateComputeUtils.parseSubtitlesAsync(content));
      }
    } catch (e, s) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('unauthorized') ||
          errStr.contains('permission-denied') ||
          errStr.contains('object-not-found')) {
        logger.warning(
          'Miniplayer subtitle parsing skipped (unavailable or unauthorized): $e',
          tag: 'MiniplayerController.parseSubtitles',
        );
      } else {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.parseSubtitles',
        );
      }
      subtitleSegments.clear();
    }
  }

  /// Find the active subtitle segment for the given playback position.
  SubtitleSegment? findSubtitle(Duration pos) {
    return SubtitleParser.findActiveSubtitle(subtitleSegments, pos);
  }
}
