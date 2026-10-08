import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/home/presentation/controllers/app_navigation_controller.dart';

/// Mixin managing deep link generation and share sheet presentation for
/// videos, channels, playlists, and topics.
mixin SessionContentShareMixin on BaseController {
  /// Share video functionality
  Future<void> shareVideo(
    String videoId,
    String videoTitle, {
    String? thumbnailUrl,
    String? channelName,
    int? durationMs,
    Duration? currentPosition,
    String? subtitle,
  }) async {
    try {
      final videoUrl = DeepLinkService.videoUrl(videoId);

      ShareBottomSheet.show(
        title: videoTitle,
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        channelName: channelName,
        durationMs: durationMs,
        currentPosition: currentPosition,
        subtitle: subtitle,
        type: 'video',
      );

      // Increment share count in background if AppNavigationController is registered
      if (Get.isRegistered<AppNavigationController>()) {
        Get.find<AppNavigationController>().incrementShareCount(videoId);
      }

      if (kDebugMode) {
        debugPrint('UserSessionController: Video $videoId share sheet opened');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.shareVideo');
      showWarning('Failed to open share options');
    }
  }

  /// Share channel functionality
  Future<void> shareChannel(
    String channelId,
    String channelName, {
    String? avatarUrl,
    String? bannerUrl,
    String? handle,
    int? subscriberCount,
    int? videoCount,
    String? subtitle,
  }) async {
    try {
      final url = DeepLinkService.channelUrl(channelId, handle: handle);

      ShareBottomSheet.show(
        title: channelName,
        url: url,
        avatarUrl: avatarUrl,
        bannerUrl: bannerUrl,
        thumbnailUrl: (bannerUrl != null && bannerUrl.isNotEmpty)
            ? bannerUrl
            : avatarUrl,
        handle: handle,
        subscriberCount: subscriberCount,
        videoCount: videoCount,
        subtitle: subtitle,
        type: 'channel',
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.shareChannel');
      showWarning('Failed to share channel');
    }
  }

  /// Share playlist functionality
  Future<void> sharePlaylist(
    String playlistId,
    String playlistName, {
    String? thumbnailUrl,
    String? channelName,
    int? videoCount,
    String? subtitle,
  }) async {
    try {
      final url = DeepLinkService.playlistUrl(playlistId);

      ShareBottomSheet.show(
        title: playlistName,
        url: url,
        thumbnailUrl: thumbnailUrl,
        channelName: channelName,
        videoCount: videoCount,
        subtitle: subtitle,
        type: 'playlist',
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.sharePlaylist');
      showWarning('Failed to share playlist');
    }
  }

  /// Share topic functionality
  Future<void> shareTopic(
    String slugOrHandle,
    String topicTitle, {
    String? thumbnailUrl,
    int? videoCount,
    int? followerCount,
    String? subtitle,
  }) async {
    try {
      final url = DeepLinkService.topicUrl(slugOrHandle);

      ShareBottomSheet.show(
        title: topicTitle,
        url: url,
        thumbnailUrl: thumbnailUrl,
        followerCount: followerCount,
        videoCount: videoCount,
        handle: slugOrHandle,
        subtitle: subtitle,
        type: 'topic',
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.shareTopic');
      showWarning('Failed to share topic');
    }
  }
}
