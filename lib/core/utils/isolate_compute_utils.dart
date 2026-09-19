import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Top-level helper function for decoding JSON Map in an isolate.
Map<String, dynamic> _decodeJsonMapWorker(String jsonString) {
  try {
    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// Top-level helper function for parsing subtitles in an isolate.
List<SubtitleSegment> _parseSubtitlesWorker(String content) {
  return SubtitleParser.parse(content);
}

/// Utility for running heavy computational and parsing workloads on background isolates
/// to guarantee zero UI thread lag or frame drops on mobile and desktop devices.
class IsolateComputeUtils {
  /// Asynchronously decodes a JSON string into a `Map<String, dynamic>` off the UI thread.
  ///
  /// For short strings (< 2KB), runs synchronously to avoid isolate dispatch overhead.
  /// For larger payloads, dispatches to [compute] worker isolate.
  static Future<Map<String, dynamic>> parseJsonMapAsync(String jsonString) async {
    if (jsonString.isEmpty) return <String, dynamic>{};
    if (jsonString.length < 2048) {
      return _decodeJsonMapWorker(jsonString);
    }
    return compute(_decodeJsonMapWorker, jsonString);
  }

  /// Asynchronously parses subtitle files (SRT, VTT, JSON transcripts) on a background isolate.
  static Future<List<SubtitleSegment>> parseSubtitlesAsync(String content) async {
    if (content.isEmpty) return <SubtitleSegment>[];
    if (content.length < 2048) {
      return _parseSubtitlesWorker(content);
    }
    return compute(_parseSubtitlesWorker, content);
  }
}
