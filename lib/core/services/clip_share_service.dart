import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/utils/format_utils.dart';

/// Service responsible for extracting, watermarking, caching, and sharing
/// video clips as actual video media files (.mp4) with Truthworld branding.
///
/// Uses FFmpeg to trim and burn the Truthworld watermark directly into
/// the video frames with minimal network overhead and reliable cross-platform execution.
class ClipShareService {
  ClipShareService._();
  static final ClipShareService instance = ClipShareService._();

  /// Maximum allowed duration for shareable clips (30 seconds)
  static const double maxShareDuration = 30.0;

  // ────────────────────────────────────────────────
  // Static helpers
  // ────────────────────────────────────────────────

  /// Build interactive deep link web URL for the clip
  static String buildClipUrl({
    required String videoId,
    required double startSeconds,
    required double endSeconds,
    required String clipTitle,
  }) {
    final encodedTitle = Uri.encodeComponent(clipTitle);
    return 'https://www.truthworld.in/watch?v=$videoId'
        '&start=${startSeconds.toInt()}&end=${endSeconds.toInt()}'
        '&clipTitle=$encodedTitle';
  }

  /// Format duration segment text, e.g. "00:10 - 00:25 (15s)"
  static String formatClipSegment(double startSeconds, double endSeconds) {
    final start = FormatUtils.formatDuration(
      Duration(seconds: startSeconds.toInt()),
    );
    final end = FormatUtils.formatDuration(
      Duration(seconds: endSeconds.toInt()),
    );
    final duration = (endSeconds - startSeconds).toInt();
    return '$start - $end (${duration}s)';
  }

  /// Build clean, TikTok-style watermark caption for video clip sharing
  static String buildWatermarkCaption({
    required String clipTitle,
    required String videoTitle,
    required double startSeconds,
    required double endSeconds,
    required String clipUrl,
    String? channelName,
  }) {
    final segment = formatClipSegment(startSeconds, endSeconds);
    final channelStr = (channelName != null && channelName.trim().isNotEmpty)
        ? ' • $channelName'
        : '';

    return '$clipTitle ($segment)$channelStr\n'
        '▶️ Watch full video on Truthworld: $clipUrl';
  }

  // ────────────────────────────────────────────────
  // URL Resolution (Firebase Storage & Cloud URLs)
  // ────────────────────────────────────────────────

  /// Convert any raw URL (gs://, storage path, https://) to an accessible HTTPS URL
  Future<String?> _toHttpUrl(String? rawUrl) async {
    if (rawUrl == null) return null;
    final clean = rawUrl.trim();
    if (clean.isEmpty) return null;

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    try {
      if (clean.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(clean).getDownloadURL();
      }
      return await FirebaseStorage.instance.ref(clean).getDownloadURL();
    } catch (e) {
      debugPrint('[ClipShareService] Could not resolve storage URL for $clean: $e');
    }
    return null;
  }

  /// Resolve source video media URL from Firestore when not provided directly
  Future<String?> resolveVideoSourceUrl(String videoId) async {
    if (videoId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();

      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      // 1. Check originalUrl
      final original = await _toHttpUrl(data['originalUrl'] as String?);
      if (original != null) return original;

      // 2. Check videoUrl
      final video = await _toHttpUrl(data['videoUrl'] as String?);
      if (video != null) return video;

      // 3. Check adaptiveResolutions
      final adaptiveResolutions = data['adaptiveResolutions'] as List?;
      if (adaptiveResolutions != null && adaptiveResolutions.isNotEmpty) {
        for (final item in adaptiveResolutions) {
          if (item is Map && item['url'] != null) {
            final url = await _toHttpUrl(item['url']?.toString());
            if (url != null) return url;
          }
        }
      }

      // 4. Check media map
      if (data['media'] is Map) {
        final media = data['media'] as Map;
        final mediaUrl = await _toHttpUrl(media['originalUrl']?.toString()) ??
            await _toHttpUrl(media['videoUrl']?.toString()) ??
            await _toHttpUrl(media['hlsUrl']?.toString());
        if (mediaUrl != null) return mediaUrl;
      }

      // 5. Check hlsUrl
      final hls = await _toHttpUrl(data['hlsUrl'] as String?);
      if (hls != null) return hls;
    } catch (e) {
      debugPrint('[ClipShareService] Error resolving video URL from Firestore: $e');
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // Cache Management
  // ────────────────────────────────────────────────

  /// Check if the trimmed + watermarked clip is already cached on disk
  Future<File?> getCachedClipFile({
    required String videoId,
    required double startSeconds,
    required double endSeconds,
  }) async {
    if (kIsWeb) return null;
    try {
      final clipsDir = await _clipsDirectory();
      final safeVideoId = _safeId(videoId);
      final file = File(
        '${clipsDir.path}/clip_${safeVideoId}_${startSeconds.toInt()}_${endSeconds.toInt()}.mp4',
      );
      if (await file.exists() && await file.length() > 1024) {
        return file;
      }
    } catch (e) {
      debugPrint('[ClipShareService] Error checking cache: $e');
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // Core Clip Generation (FFmpeg)
  // ────────────────────────────────────────────────

  /// Generate or retrieve the watermarked trimmed video clip file (.mp4).
  ///
  /// Uses FFmpeg to:
  ///   1. Seek directly to [startSeconds] in the video stream
  ///   2. Trim duration to max 30s
  ///   3. Burn "Truthworld" text watermark overlay into the video
  ///   4. Encode with H.264/AAC with +faststart for instant WhatsApp/Social playback
  Future<File?> getOrGenerateClipFile({
    required String videoId,
    required double startSeconds,
    required double endSeconds,
    String? videoUrl,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (kIsWeb) return null;

    // Safety: enforce max 30-second duration
    final clampedEnd =
        endSeconds.clamp(startSeconds, startSeconds + maxShareDuration);
    final clipDuration = clampedEnd - startSeconds;

    // 1. Check disk cache first
    final cached = await getCachedClipFile(
      videoId: videoId,
      startSeconds: startSeconds,
      endSeconds: clampedEnd,
    );
    if (cached != null) {
      onProgress?.call(1.0, 'Ready');
      return cached;
    }

    // 2. Resolve source video URL
    var resolvedUrl = await _toHttpUrl(videoUrl);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      onProgress?.call(0.1, 'Locating video source...');
      resolvedUrl = await resolveVideoSourceUrl(videoId);
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty || !resolvedUrl.startsWith('http')) {
      debugPrint(
        '[ClipShareService] ❌ No valid HTTP URL found for videoId=$videoId (URL=$resolvedUrl)',
      );
      return null;
    }

    onProgress?.call(0.3, 'Trimming & applying watermark...');

    File? tempDownloadedFile;
    try {
      final clipsDir = await _clipsDirectory();
      final safeId = _safeId(videoId);
      final outputPath =
          '${clipsDir.path}/clip_${safeId}_${startSeconds.toInt()}_${clampedEnd.toInt()}.mp4';

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        try {
          await outputFile.delete();
        } catch (_) {}
      }

      // Strategy 1: FFmpeg with drawtext watermark directly from remote URL
      var success = await _executeFFmpegClip(
        input: resolvedUrl,
        startSeconds: startSeconds,
        durationSeconds: clipDuration,
        outputPath: outputPath,
        withWatermark: true,
      );

      // Strategy 2: If drawtext filter failed (e.g. font unavailable), retry without filter
      if (!success) {
        debugPrint('[ClipShareService] Retrying FFmpeg without drawtext filter...');
        success = await _executeFFmpegClip(
          input: resolvedUrl,
          startSeconds: startSeconds,
          durationSeconds: clipDuration,
          outputPath: outputPath,
          withWatermark: false,
        );
      }

      // Strategy 3: If streaming input failed, download to temp file first then trim locally
      if (!success) {
        onProgress?.call(0.5, 'Buffering video segment...');
        debugPrint('[ClipShareService] Retrying with local temp file download...');
        final tempDir = await getTemporaryDirectory();
        tempDownloadedFile = File(
          '${tempDir.path}/source_${safeId}_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );

        final response = await http.get(Uri.parse(resolvedUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await tempDownloadedFile.writeAsBytes(response.bodyBytes);
          success = await _executeFFmpegClip(
            input: tempDownloadedFile.path,
            startSeconds: startSeconds,
            durationSeconds: clipDuration,
            outputPath: outputPath,
            withWatermark: true,
          );
          if (!success) {
            success = await _executeFFmpegClip(
              input: tempDownloadedFile.path,
              startSeconds: startSeconds,
              durationSeconds: clipDuration,
              outputPath: outputPath,
              withWatermark: false,
            );
          }
        }
      }

      if (success && await outputFile.exists() && await outputFile.length() > 1024) {
        onProgress?.call(1.0, 'Clip ready!');
        debugPrint(
          '[ClipShareService] ✅ Clip generated: $outputPath (${await outputFile.length()} bytes)',
        );
        return outputFile;
      }
    } catch (e) {
      debugPrint('[ClipShareService] ❌ Exception during clip generation: $e');
    } finally {
      if (tempDownloadedFile != null && await tempDownloadedFile.exists()) {
        try {
          await tempDownloadedFile.delete();
        } catch (_) {}
      }
    }

    return null;
  }

  /// Run an FFmpeg execution with specific arguments
  Future<bool> _executeFFmpegClip({
    required String input,
    required double startSeconds,
    required double durationSeconds,
    required String outputPath,
    required bool withWatermark,
  }) async {
    try {
      final args = <String>[
        '-y',
        '-ss',
        startSeconds.toStringAsFixed(3),
        '-i',
        input,
        '-t',
        durationSeconds.toStringAsFixed(3),
      ];

      if (withWatermark) {
        args.addAll([
          '-vf',
          "drawtext=text='Truthworld':fontsize=28:fontcolor=white:alpha=0.85:x=w-tw-16:y=h-th-16:box=1:boxcolor=black@0.35:boxborderw=6",
        ]);
      }

      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '28',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-movflags',
        '+faststart',
        '-f',
        'mp4',
        outputPath,
      ]);

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final f = File(outputPath);
        return await f.exists() && await f.length() > 1024;
      }

      final logs = await session.getLogs();
      debugPrint(
        '[ClipShareService] FFmpeg step failed ($returnCode): ${logs.take(5).map((l) => l.getMessage()).join('; ')}',
      );
    } catch (e) {
      debugPrint('[ClipShareService] FFmpeg execution error: $e');
    }
    return false;
  }

  // ────────────────────────────────────────────────
  // Save to Gallery
  // ────────────────────────────────────────────────

  /// Save the clipped + watermarked video to the device's Movies/Truthworld folder
  Future<String?> saveClipToDevice({
    required String videoId,
    required String clipTitle,
    required double startSeconds,
    required double endSeconds,
    String? videoUrl,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (kIsWeb) return null;
    try {
      final clipFile = await getOrGenerateClipFile(
        videoId: videoId,
        videoUrl: videoUrl,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
        onProgress: onProgress,
      );

      if (clipFile == null || !await clipFile.exists()) return null;

      Directory? targetDir;
      if (Platform.isAndroid) {
        final moviesDir = Directory('/storage/emulated/0/Movies/Truthworld');
        final created = await moviesDir.exists() ||
            await moviesDir
                .create(recursive: true)
                .then((_) => true)
                .catchError((_) => false);
        if (created) {
          targetDir = moviesDir;
        } else {
          final dl = Directory('/storage/emulated/0/Download');
          if (await dl.exists()) targetDir = dl;
        }
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      final safeTitle = clipTitle.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile =
          File('${targetDir.path}/Truthworld_${safeTitle}_$timestamp.mp4');
      await clipFile.copy(savedFile.path);
      return savedFile.path;
    } catch (e) {
      debugPrint('[ClipShareService] Error saving clip to device: $e');
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // Native Sharing
  // ────────────────────────────────────────────────

  /// Share the actual video clip file (.mp4) with Truthworld watermark caption via SharePlus
  Future<ShareResult> shareClipWithWatermark({
    required String videoId,
    required String clipTitle,
    required String videoTitle,
    required double startSeconds,
    required double endSeconds,
    String? videoUrl,
    String? channelName,
    BuildContext? context,
    void Function(double progress, String status)? onProgress,
  }) async {
    final clipUrl = buildClipUrl(
      videoId: videoId,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      clipTitle: clipTitle,
    );

    final watermarkCaption = buildWatermarkCaption(
      clipTitle: clipTitle,
      videoTitle: videoTitle,
      channelName: channelName,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      clipUrl: clipUrl,
    );

    File? clipFile;
    if (!kIsWeb) {
      clipFile = await getOrGenerateClipFile(
        videoId: videoId,
        videoUrl: videoUrl,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
        onProgress: onProgress,
      );
    }

    final shareParams = ShareParams(
      files: (clipFile != null && await clipFile.exists())
          ? [
              XFile(
                clipFile.path,
                mimeType: 'video/mp4',
                name: '$clipTitle (Truthworld Clip).mp4',
              ),
            ]
          : null,
      text: watermarkCaption,
      subject: clipTitle,
    );

    return SharePlus.instance.share(shareParams);
  }

  // ────────────────────────────────────────────────
  // Private Utilities
  // ────────────────────────────────────────────────

  Future<Directory> _clipsDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/truthworld_clips');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeId(String id) => id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
}

