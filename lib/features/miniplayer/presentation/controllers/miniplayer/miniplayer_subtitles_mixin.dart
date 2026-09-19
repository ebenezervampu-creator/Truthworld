import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_state_base.dart';
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

    final subs = video.mediaSubtitles;
    if (subs.isEmpty) return;

    // Find the primary/first available subtitle track
    final selectedUrl = subs['en'] ?? subs.values.firstOrNull;
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
        final response = await AppHttpClient.get(Uri.parse(resolvedUrl));
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'MiniplayerController.fetchSubtitlesHttp',
        );
      }

      if (content == null || content.isEmpty) {
        try {
          Uint8List? data;
          if (url.startsWith('gs://') ||
              url.startsWith('https://storage.googleapis.com/') ||
              url.startsWith('https://firebasestorage.googleapis.com/')) {
            data = await FirebaseStorage.instance.refFromURL(url).getData();
          } else if (url.startsWith('subtitles/') || url.startsWith('transcripts/')) {
            data = await FirebaseStorage.instance.ref(url).getData();
          }
          if (data != null && data.isNotEmpty) {
            content = utf8.decode(data, allowMalformed: true);
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'MiniplayerController.fetchSubtitlesStorage',
          );
        }
      }

      if (content != null && content.isNotEmpty) {
        subtitleSegments.assignAll(await IsolateComputeUtils.parseSubtitlesAsync(content));
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'MiniplayerController.parseSubtitles',
      );
      subtitleSegments.clear();
    }
  }

  /// Find the active subtitle segment for the given playback position.
  SubtitleSegment? findSubtitle(Duration pos) {
    return SubtitleParser.findActiveSubtitle(subtitleSegments, pos);
  }
}
