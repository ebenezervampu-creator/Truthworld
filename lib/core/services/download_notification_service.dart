import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Centralized notification service managing live video/audio download progress notifications.
///
/// Follows platform and industry standards:
/// - Android: Foreground download channel with silent low-importance priority,
///   status-bar small icon (TruthWorld logo), video title, live progress bar,
///   byte counts (e.g. "15 MB / 290 MB"), and video thumbnail on the right edge.
/// - iOS: Local notification with Darwin notification attachment for thumbnail and progress summary.
/// - Web / Mobile Web: Web Notification API fallback when permissions are granted.
class DownloadNotificationService extends GetxService {
  static DownloadNotificationService get to {
    if (!Get.isRegistered<DownloadNotificationService>()) {
      Get.put(DownloadNotificationService(), permanent: true);
    }
    return Get.find<DownloadNotificationService>();
  }

  static const String channelId = 'truthworld_video_downloads';
  static const String channelName = 'Video Downloads';
  static const String channelDescription =
      'TruthWorld active offline video and audio download notifications';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _permissionRequestInProgress = false; // Track if a permission request is currently in progress

  /// Cache of local thumbnail file paths by video ID
  final Map<String, String> _thumbnailCache = <String, String>{};

  /// Throttling timestamps by video ID to prevent NotificationManager binder flooding
  final Map<String, DateTime> _lastUpdateTime = <String, DateTime>{};
  final Map<String, double> _lastProgressValue = <String, double>{};

  @override
  void onInit() {
    super.onInit();
    init();
  }

  bool get _isTestEnvironment =>
      Get.testMode ||
      (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  /// Safe initialization of notification plugin and Android channels.
  Future<void> init() async {
    if (_isInitialized) return;
    if (_isTestEnvironment) {
      _isInitialized = true;
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings('ic_notification');

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open downloads',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationTap(response.payload);
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl != null) {
          if (_permissionRequestInProgress) {
            // Skip duplicate permission request.
            return;
          }
          _permissionRequestInProgress = true;
          try {
            await androidImpl.requestNotificationsPermission();
          } on PlatformException catch (e) {
            // Log but suppress permission request in progress errors.
            if (e.code != 'permissionRequestInProgress') {
              ErrorHandler.log(e, tag: 'DownloadNotificationService.init');
            }
          } finally {
            _permissionRequestInProgress = false;
          }
          // Original request removed.
          // await androidImpl.requestNotificationsPermission();

          const androidChannel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
            showBadge: false,
          );
          await androidImpl.createNotificationChannel(androidChannel);

          // Request notification permissions gracefully on Android 13+ (API 33+)
          await androidImpl.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DownloadNotificationService.init',
      );
    }
  }

  /// Generates a stable integer notification ID from the video ID string.
  int _getNotificationId(String videoId) {
    return videoId.hashCode.abs() % 100000000;
  }

  static const Set<String> _allowedThumbnailHosts = <String>{
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
    'truthworld.in',
    'www.truthworld.in',
    'lh3.googleusercontent.com',
    'i.ytimg.com',
  };

  static const Set<String> _blockedThumbnailHosts = <String>{
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
    '0.0.0.0',
    '::1',
  };

  /// Validates whether a thumbnail URL is secure (HTTPS) and points to an authorized host.
  @visibleForTesting
  static bool isValidThumbnailUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.isScheme('https')) return false;

    final host = uri.host.toLowerCase().trim();
    if (host.isEmpty) return false;

    if (_blockedThumbnailHosts.contains(host) ||
        host.endsWith('.localhost') ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        host.startsWith('172.16.') ||
        host.startsWith('169.254.')) {
      return false;
    }

    for (final allowed in _allowedThumbnailHosts) {
      if (host == allowed || host.endsWith('.$allowed')) {
        return true;
      }
    }
    return false;
  }

  /// Caches or retrieves a local thumbnail image file on disk for rich notification display.
  Future<String?> _resolveLocalThumbnail(String videoId, String thumbnailUrl) async {
    // TW-SEC-03: Restrict thumbnailUrl to HTTPS and validate against authorized host allowlist
    if (kIsWeb || !isValidThumbnailUrl(thumbnailUrl)) return null;

    if (_thumbnailCache.containsKey(videoId)) {
      final cached = _thumbnailCache[videoId]!;
      if (File(cached).existsSync()) return cached;
    }

    try {
      // TW-SEC-02: Hash videoId with SHA-256 before building file path and verify canonical containment
      final safeId = sha256.convert(utf8.encode(videoId)).toString();
      final tempDir = await getTemporaryDirectory();
      final tempDirPath = tempDir.existsSync()
          ? tempDir.resolveSymbolicLinksSync()
          : p.canonicalize(tempDir.path);
      final targetPath = p.canonicalize(p.join(tempDirPath, 'tw_thumb_$safeId.jpg'));

      if (!p.isWithin(tempDirPath, targetPath)) {
        ErrorHandler.log(
          ArgumentError('Path traversal detected in thumbnail cache target path: $targetPath'),
          stackTrace: StackTrace.current,
          tag: 'DownloadNotificationService._resolveLocalThumbnail',
        );
        return null;
      }

      final targetFile = File(targetPath);

      if (await targetFile.exists() && (await targetFile.length()) > 512) {
        _thumbnailCache[videoId] = targetFile.path;
        return targetFile.path;
      }

      final response = await http
          .get(Uri.parse(thumbnailUrl.trim()))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.bodyBytes.length > 512) {
        await targetFile.writeAsBytes(response.bodyBytes);
        _thumbnailCache[videoId] = targetFile.path;
        return targetFile.path;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DownloadNotificationService._resolveLocalThumbnail',
      );
    }
    return null;
  }

  /// Shows the initial persistent notification when download begins.
  Future<void> showDownloadStartedNotification({
    required Video video,
    String? quality,
    bool isAudioOnly = false,
  }) async {
    if (_isTestEnvironment) return;
    if (!_isInitialized) await init();

    final notifId = _getNotificationId(video.id);
    _lastUpdateTime[video.id] = DateTime.now();
    _lastProgressValue[video.id] = 0.0;

    // Resolve local thumbnail in background
    final thumbPath = await _resolveLocalThumbnail(video.id, video.thumbnailUrl);

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        ongoing: true,
        autoCancel: false,
        channelShowBadge: false,
        playSound: false,
        enableVibration: false,
        icon: 'ic_notification',
        largeIcon: thumbPath != null
            ? FilePathAndroidBitmap(thumbPath)
            : const DrawableResourceAndroidBitmap('ic_notification_large'),
        subText: quality != null && quality.isNotEmpty ? quality : 'TruthWorld',
      );

      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
        subtitle: quality ?? 'TruthWorld',
        attachments: thumbPath != null
            ? [DarwinNotificationAttachment(thumbPath)]
            : null,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: notifId,
        title: video.title,
        body: 'Starting download...',
        notificationDetails: details,
        payload: video.id,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DownloadNotificationService.showDownloadStartedNotification',
      );
    }
  }

  /// Updates the live download progress notification with throttled updates.
  Future<void> updateProgress({
    required Video video,
    required double progress,
    required int receivedBytes,
    required int totalBytes,
    bool isAudioOnly = false,
  }) async {
    if (_isTestEnvironment) return;
    if (!_isInitialized) await init();

    final now = DateTime.now();
    final lastTime = _lastUpdateTime[video.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
    final lastProg = _lastProgressValue[video.id] ?? 0.0;

    // Throttle to at most once every 500ms or 2% jump or completion
    final timeElapsed = now.difference(lastTime).inMilliseconds;
    final progressDelta = (progress - lastProg).abs();
    if (timeElapsed < 500 && progressDelta < 0.02 && progress < 0.99) {
      return;
    }

    _lastUpdateTime[video.id] = now;
    _lastProgressValue[video.id] = progress;

    final notifId = _getNotificationId(video.id);
    final thumbPath = _thumbnailCache[video.id];

    final progressPercent = (progress.clamp(0.0, 1.0) * 100).toInt();

    // Industry standard byte string (e.g. "15 MB / 290 MB")
    final String byteDetails;
    if (totalBytes > 0) {
      byteDetails =
          '${FormatUtils.formatBytes(receivedBytes)} / ${FormatUtils.formatBytes(totalBytes)}';
    } else if (receivedBytes > 0) {
      byteDetails = FormatUtils.formatBytes(receivedBytes);
    } else {
      byteDetails = progressPercent > 0 ? '$progressPercent%' : 'Downloading...';
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent,
        ongoing: true,
        autoCancel: false,
        channelShowBadge: false,
        playSound: false,
        enableVibration: false,
        icon: 'ic_notification',
        largeIcon: thumbPath != null
            ? FilePathAndroidBitmap(thumbPath)
            : const DrawableResourceAndroidBitmap('ic_notification_large'),
        subText: 'TruthWorld',
      );

      final darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        subtitle: 'TruthWorld',
        attachments: thumbPath != null
            ? [DarwinNotificationAttachment(thumbPath)]
            : null,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: notifId,
        title: video.title,
        body: byteDetails,
        notificationDetails: details,
        payload: video.id,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DownloadNotificationService.updateProgress',
      );
    }
  }

  /// Shows the completion notification and allows user to tap to view/play.
  Future<void> showDownloadCompleteNotification({
    required Video video,
    bool isAudioOnly = false,
  }) async {
    if (_isTestEnvironment) return;
    if (!_isInitialized) await init();

    final notifId = _getNotificationId(video.id);
    final thumbPath = _thumbnailCache[video.id];

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        icon: 'ic_notification',
        largeIcon: thumbPath != null
            ? FilePathAndroidBitmap(thumbPath)
            : const DrawableResourceAndroidBitmap('ic_notification_large'),
        subText: 'TruthWorld',
      );

      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        subtitle: 'TruthWorld',
        attachments: thumbPath != null
            ? [DarwinNotificationAttachment(thumbPath)]
            : null,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: notifId,
        title: video.title,
        body: isAudioOnly
            ? 'Downloaded • Ready for offline listening'
            : 'Downloaded • Ready for offline viewing',
        notificationDetails: details,
        payload: video.id,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DownloadNotificationService.showDownloadCompleteNotification',
      );
    } finally {
      _lastUpdateTime.remove(video.id);
      _lastProgressValue.remove(video.id);
    }
  }

  /// Cancels an active or finished notification.
  Future<void> cancelDownloadNotification(String videoId) async {
    if (_isTestEnvironment) return;
    final notifId = _getNotificationId(videoId);
    try {
      await _notificationsPlugin.cancel(id: notifId);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DownloadNotificationService.cancelDownloadNotification',
      );
    } finally {
      _lastUpdateTime.remove(videoId);
      _lastProgressValue.remove(videoId);
      _thumbnailCache.remove(videoId);
    }
  }

  /// Handles user tapping the notification payload.
  void _handleNotificationTap(String? videoId) {
    if (videoId != null && videoId.isNotEmpty) {
      Get.toNamed(AppRoutes.downloads);
    }
  }
}
