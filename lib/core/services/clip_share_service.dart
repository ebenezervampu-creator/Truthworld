import 'dart:io';
import 'dart:ui' as ui;
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
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Service responsible for extracting, watermarking, caching, and sharing
/// video clips as actual video media files (.mp4) with TikTok-style Truthworld branding.
///
/// Uses Flutter Canvas to generate high-resolution, vector-crisp TikTok watermark badges
/// and FFmpeg overlay to burn the dynamic alternating watermark directly into
/// the video frames with minimal network overhead and reliable cross-platform execution.
class ClipShareService {
  ClipShareService._();
  static final ClipShareService instance = ClipShareService._();

  /// Minimum allowed duration for shareable clips (5 seconds - industry standard)
  static const double minShareDuration = 5.0;

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
  // TikTok-Style Dynamic Watermark Image Generator
  // ────────────────────────────────────────────────

  /// Generates a high-resolution, pixel-perfect transparent PNG overlay badge
  /// styled exactly like TikTok (Truthworld logo badge + "Truthworld" + creator @channel).
  ///
  /// Using native Flutter Canvas guarantees 100% font support, vector sharpness,
  /// and zero dependency on host system font files.
  static Future<File> generateTikTokWatermarkImage({
    String? channelName,
    String? customBrand,
  }) async {
    const width = 320.0;
    const height = 92.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // 1. Frosted dark pill container
    final pillRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6, 6, width - 12, height - 12),
      const Radius.circular(22),
    );

    // Drop shadow
    final shadowPaint = Paint()
      ..color = const Color(0x80000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawRRect(pillRect.shift(const Offset(0, 4)), shadowPaint);

    // Pill background fill
    final bgPaint = Paint()
      ..color = const Color(0xCC111116)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pillRect, bgPaint);

    // Subtle border stroke
    final borderPaint = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(pillRect, borderPaint);

    // 2. TikTok-style Chromatic 3D Logo Icon (Cyan & Magenta offset glow)
    const logoCenterX = 48.0;
    const logoCenterY = 46.0;
    const logoRadius = 24.0;

    final cyanPaint = Paint()
      ..color = const Color(0xD900F2EA)
      ..style = PaintingStyle.fill;
    final magentaPaint = Paint()
      ..color = const Color(0xD9FF0050)
      ..style = PaintingStyle.fill;
    final darkLogoBg = Paint()
      ..color = const Color(0xFF0F0F14)
      ..style = PaintingStyle.fill;

    // Chromatic offset circles
    canvas.drawCircle(const Offset(logoCenterX - 2, logoCenterY), logoRadius, cyanPaint);
    canvas.drawCircle(const Offset(logoCenterX + 2, logoCenterY), logoRadius, magentaPaint);
    canvas.drawCircle(const Offset(logoCenterX, logoCenterY), logoRadius, darkLogoBg);

    // Stylized 'T' inside logo circle
    final logoTextPainter = TextPainter(
      text: const TextSpan(
        text: 'T',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    logoTextPainter.paint(
      canvas,
      Offset(
        logoCenterX - (logoTextPainter.width / 2),
        logoCenterY - (logoTextPainter.height / 2),
      ),
    );

    // 3. Brand Text: Truthworld
    final brandText = customBrand ?? 'Truthworld';
    final brandPainter = TextPainter(
      text: TextSpan(
        text: brandText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 100);
    brandPainter.paint(canvas, const Offset(84, 18));

    // 4. Creator Handle: @channelName or Truthworld Clip
    final cleanHandle = (channelName != null && channelName.trim().isNotEmpty)
        ? (channelName.trim().startsWith('@')
            ? channelName.trim()
            : '@${channelName.trim()}')
        : '@truthworld.in';

    final handlePainter = TextPainter(
      text: TextSpan(
        text: cleanHandle,
        style: const TextStyle(
          color: Color(0xEEFFFFFF),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: width - 100);
    handlePainter.paint(canvas, const Offset(84, 46));

    // 5. Render Picture to PNG byte data
    final picture = recorder.endRecording();
    final img = picture.toImageSync(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final tempDir = await _getSafeTempDir();
    final watermarkDir = Directory('${tempDir.path}/watermarks');
    if (!await watermarkDir.exists()) {
      await watermarkDir.create(recursive: true);
    }
    final watermarkFile = File(
      '${watermarkDir.path}/truthworld_watermark_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await watermarkFile.writeAsBytes(buffer, flush: true);
    return watermarkFile;
  }

  // ────────────────────────────────────────────────
  // URL Resolution (Firebase Storage & Cloud URLs)
  // ────────────────────────────────────────────────

  /// Convert any raw URL (gs://, storage path, https://) to an accessible HTTPS URL
  Future<String?> _toHttpUrl(String? rawUrl) async {
    if (rawUrl == null) return null;
    final clean = rawUrl.trim();
    if (clean.isEmpty) return null;

    try {
      final fast = StorageUtils.getFastDownloadUrl(clean);
      if (fast.isNotEmpty &&
          (fast.startsWith('http://') || fast.startsWith('https://'))) {
        return fast;
      }
      final resolved = await StorageUtils.resolveUrl(clean);
      if (resolved.isNotEmpty &&
          (resolved.startsWith('http://') || resolved.startsWith('https://'))) {
        return resolved;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService._toHttpUrl.storageUtils');
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    try {
      if (clean.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(clean).getDownloadURL();
      }
      return await FirebaseStorage.instance.ref(clean).getDownloadURL();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService._toHttpUrl.firebaseStorage');
    }
    return null;
  }

  /// Resolve source video media URL with comprehensive fallbacks:
  ///   1. In-memory VideoMediaService.streamingCache
  ///   2. Firestore `videos/{videoId}` doc
  ///   3. Firestore `videos/{videoId}/media/streaming` subcollection
  Future<String?> resolveVideoSourceUrl(String videoId) async {
    if (videoId.isEmpty) return null;

    // 1. Check in-memory streaming cache first
    if (VideoMediaService.streamingCache.containsKey(videoId)) {
      final streaming = VideoMediaService.streamingCache[videoId]!;
      final original = await _toHttpUrl(streaming.originalUrl);
      if (original != null && original.isNotEmpty) return original;

      if (streaming.adaptiveResolutions.isNotEmpty) {
        for (final res in streaming.adaptiveResolutions) {
          final url = await _toHttpUrl(res.url);
          if (url != null && url.isNotEmpty) return url;
        }
      }

      final hls = await _toHttpUrl(streaming.hlsUrl);
      if (hls != null && hls.isNotEmpty) return hls;
    }

    // 2. Query Firestore root video doc
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // Check originalUrl
        final original = await _toHttpUrl(data['originalUrl'] as String?);
        if (original != null && original.isNotEmpty) return original;

        // Check videoUrl
        final video = await _toHttpUrl(data['videoUrl'] as String?);
        if (video != null && video.isNotEmpty) return video;

        // Check downloadUrl / fileUrl / sourceUrl
        final downloadUrl = await _toHttpUrl(data['downloadUrl'] as String?) ??
            await _toHttpUrl(data['fileUrl'] as String?) ??
            await _toHttpUrl(data['sourceUrl'] as String?);
        if (downloadUrl != null && downloadUrl.isNotEmpty) return downloadUrl;

        // Check adaptiveResolutions list
        final adaptiveResolutions = data['adaptiveResolutions'] as List?;
        if (adaptiveResolutions != null && adaptiveResolutions.isNotEmpty) {
          for (final item in adaptiveResolutions) {
            if (item is Map && item['url'] != null) {
              final url = await _toHttpUrl(item['url']?.toString());
              if (url != null && url.isNotEmpty) return url;
            }
          }
        }

        // Check media map
        if (data['media'] is Map) {
          final media = data['media'] as Map;
          final mediaUrl = await _toHttpUrl(media['originalUrl']?.toString()) ??
              await _toHttpUrl(media['videoUrl']?.toString()) ??
              await _toHttpUrl(media['downloadUrl']?.toString()) ??
              await _toHttpUrl(media['hlsUrl']?.toString());
          if (mediaUrl != null && mediaUrl.isNotEmpty) return mediaUrl;
        }

        // Check hlsUrl & dashUrl
        final hls = await _toHttpUrl(data['hlsUrl'] as String?);
        if (hls != null && hls.isNotEmpty) return hls;

        final dash = await _toHttpUrl(data['dashUrl'] as String?);
        if (dash != null && dash.isNotEmpty) return dash;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.resolveVideoSourceUrl.firestoreRoot');
    }

    // 3. Check Firestore `media/streaming` subcollection
    try {
      final streamingDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('media')
          .doc('streaming')
          .get();

      if (streamingDoc.exists && streamingDoc.data() != null) {
        final data = streamingDoc.data()!;
        final original = await _toHttpUrl(data['originalUrl'] as String?);
        if (original != null && original.isNotEmpty) return original;

        final adaptive = data['adaptiveResolutions'] as List?;
        if (adaptive != null && adaptive.isNotEmpty) {
          for (final item in adaptive) {
            if (item is Map && item['url'] != null) {
              final url = await _toHttpUrl(item['url']?.toString());
              if (url != null && url.isNotEmpty) return url;
            }
          }
        }

        final hls = await _toHttpUrl(data['hlsUrl'] as String?);
        if (hls != null && hls.isNotEmpty) return hls;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.resolveVideoSourceUrl.streamingSubcollection');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.getCachedClipFile');
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // Core Clip Generation (FFmpeg)
  // ────────────────────────────────────────────────

  /// Generate or retrieve the watermarked trimmed video clip file (.mp4).
  ///
  /// Uses FFmpeg with TikTok-style dynamic watermark overlay:
  ///   1. Seeks to [startSeconds] in the video stream
  ///   2. Trims duration to max 30s
  ///   3. Applies TikTok-style dynamic Truthworld watermark overlay
  ///      (alternating top-left / bottom-right every 3 seconds like TikTok)
  ///   4. Encodes with H.264 (yuv420p) + AAC with +faststart for instant WhatsApp / Social playback
  Future<File?> getOrGenerateClipFile({
    required String videoId,
    required double startSeconds,
    required double endSeconds,
    String? videoUrl,
    String? channelName,
    String? videoTitle,
    String? clipTitle,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (kIsWeb) return null;

    // Safety: enforce min 5-second and max 30-second duration bounds
    final effectiveEnd = (endSeconds - startSeconds < minShareDuration)
        ? startSeconds + minShareDuration
        : endSeconds;
    final clampedEnd =
        effectiveEnd.clamp(startSeconds, startSeconds + maxShareDuration);
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
      onProgress?.call(0.15, 'Locating video source...');
      resolvedUrl = await resolveVideoSourceUrl(videoId);
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty || !resolvedUrl.startsWith('http')) {
      debugPrint(
        '[ClipShareService] ❌ No valid HTTP URL found for videoId=$videoId (URL=$resolvedUrl)',
      );
      return null;
    }

    onProgress?.call(0.35, 'Generating TikTok-style Truthworld watermark...');

    File? watermarkFile;
    File? tempDownloadedFile;
    try {
      // 3. Generate high-resolution TikTok-style watermark PNG
      watermarkFile = await generateTikTokWatermarkImage(
        channelName: channelName,
        customBrand: 'Truthworld',
      );

      final clipsDir = await _clipsDirectory();
      final safeId = _safeId(videoId);
      final outputPath =
          '${clipsDir.path}/clip_${safeId}_${startSeconds.toInt()}_${clampedEnd.toInt()}.mp4';

      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        try {
          await outputFile.delete();
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.getOrGenerateClipFile.deleteExistingOutput');
        }
      }

      onProgress?.call(0.55, 'Trimming & applying Truthworld watermark...');

      // Strategy 1: Dynamic TikTok-style alternating watermark overlay
      var success = await _executeFFmpegClip(
        input: resolvedUrl,
        startSeconds: startSeconds,
        durationSeconds: clipDuration,
        outputPath: outputPath,
        watermarkPath: watermarkFile.path,
      );

      // Strategy 2: Static corner watermark overlay fallback
      if (!success) {
        debugPrint('[ClipShareService] Retrying FFmpeg with static corner watermark...');
        success = await _executeFFmpegClip(
          input: resolvedUrl,
          startSeconds: startSeconds,
          durationSeconds: clipDuration,
          outputPath: outputPath,
          watermarkPath: watermarkFile.path,
          isDynamicTikTok: false,
        );
      }

      // Strategy 3: Pure trim without watermark if overlay filter failed
      if (!success) {
        debugPrint('[ClipShareService] Retrying FFmpeg pure trim without watermark...');
        success = await _executeFFmpegClip(
          input: resolvedUrl,
          startSeconds: startSeconds,
          durationSeconds: clipDuration,
          outputPath: outputPath,
          isDynamicTikTok: false,
        );
      }

      // Strategy 4: Local download buffer then trim locally (for strict CORS / timeout streams)
      if (!success && !resolvedUrl.contains('.m3u8')) {
        onProgress?.call(0.7, 'Buffering video segment locally...');
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
            watermarkPath: watermarkFile.path,
          );
          if (!success) {
            success = await _executeFFmpegClip(
              input: tempDownloadedFile.path,
              startSeconds: startSeconds,
              durationSeconds: clipDuration,
              outputPath: outputPath,
              watermarkPath: watermarkFile.path,
              isDynamicTikTok: false,
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.getOrGenerateClipFile');
    } finally {
      // Clean up temporary watermark image and buffered file
      if (watermarkFile != null && await watermarkFile.exists()) {
        try {
          await watermarkFile.delete();
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.cleanupWatermark');
        }
      }
      if (tempDownloadedFile != null && await tempDownloadedFile.exists()) {
        try {
          await tempDownloadedFile.delete();
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.cleanupTempDownload');
        }
      }
    }

    return null;
  }

  /// Run FFmpeg execution with proper video encoding flags for WhatsApp / Social platforms
  Future<bool> _executeFFmpegClip({
    required String input,
    required double startSeconds,
    required double durationSeconds,
    required String outputPath,
    String? watermarkPath,
    bool isDynamicTikTok = true,
  }) async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      debugPrint('[ClipShareService] FFmpegKit is only supported on mobile/desktop.');
      return false;
    }

    try {
      final isRemote = input.startsWith('http://') || input.startsWith('https://');
      final args = <String>[
        '-y',
        '-protocol_whitelist',
        'file,http,https,tcp,tls,crypto',
        if (isRemote) ...[
          '-reconnect',
          '1',
          '-reconnect_at_eof',
          '1',
          '-reconnect_streamed',
          '1',
          '-reconnect_delay_max',
          '2',
        ],
        '-ss',
        startSeconds.toStringAsFixed(3),
        '-i',
        input,
        '-t',
        durationSeconds.toStringAsFixed(3),
      ];

      if (watermarkPath != null && await File(watermarkPath).exists()) {
        args.addAll(['-i', watermarkPath]);

        if (isDynamicTikTok) {
          // Dynamic TikTok-style alternating watermark:
          // Moves between Top-Left (28, 28) and Bottom-Right (W-w-28, H-h-28) every 3 seconds
          const filter =
              '[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[base]; '
              "[base][1:v]overlay=x='if(lt(mod(t,6),3), 28, main_w-overlay_w-28)':y='if(lt(mod(t,6),3), 28, main_h-overlay_h-28)':eval=frame[v]";
          args.addAll([
            '-filter_complex',
            filter,
            '-map',
            '[v]',
            '-map',
            '0:a?',
          ]);
        } else {
          // Static bottom-right corner overlay
          const filter =
              '[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[base]; '
              '[base][1:v]overlay=main_w-overlay_w-24:main_h-overlay_h-24[v]';
          args.addAll([
            '-filter_complex',
            filter,
            '-map',
            '[v]',
            '-map',
            '0:a?',
          ]);
        }
      } else {
        // Pure trim with even dimension scaling
        args.addAll([
          '-vf',
          'scale=trunc(iw/2)*2:trunc(ih/2)*2',
          '-map',
          '0:v:0',
          '-map',
          '0:a?',
        ]);
      }

      // Universal H.264 / AAC encoding flags with +faststart for WhatsApp
      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '26',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-ar',
        '44100',
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService._executeFFmpegClip');
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
    String? channelName,
    String? videoTitle,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (kIsWeb) return null;
    try {
      final clipFile = await getOrGenerateClipFile(
        videoId: videoId,
        videoUrl: videoUrl,
        channelName: channelName,
        videoTitle: videoTitle,
        clipTitle: clipTitle,
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ClipShareService.saveClipToDevice');
    }
    return null;
  }

  // ────────────────────────────────────────────────
  // Native Sharing
  // ────────────────────────────────────────────────

  /// Share the actual video clip file (.mp4) with TikTok-style Truthworld watermark via SharePlus
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
        channelName: channelName,
        videoTitle: videoTitle,
        clipTitle: clipTitle,
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

  static Future<Directory> _getSafeTempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<Directory> _clipsDirectory() async {
    final tempDir = await _getSafeTempDir();
    final dir = Directory('${tempDir.path}/truthworld_clips');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _safeId(String id) => id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
}


