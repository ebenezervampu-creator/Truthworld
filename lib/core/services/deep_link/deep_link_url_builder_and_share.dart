import 'package:share_plus/share_plus.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Mixin providing canonical URL generation and share integrations for TruthWorld.
mixin DeepLinkUrlBuilderAndShare {
  static const String baseUrl = 'https://www.truthworld.in';

  /// Generates a shareable video URL.
  /// Pattern: https://www.truthworld.in/watch/{videoId}
  static String videoUrl(String videoId) => '$baseUrl/watch/$videoId';

  /// Generates a shareable channel URL.
  /// Pattern: https://www.truthworld.in/@{handle} or https://www.truthworld.in/channel/{channelId}
  static String channelUrl(String channelId, {String? handle}) {
    if (handle != null && handle.trim().isNotEmpty) {
      final clean = handle.replaceAll(RegExp('^@'), '').trim();
      if (clean.isNotEmpty) {
        return '$baseUrl/@$clean';
      }
    }
    return '$baseUrl/channel/$channelId';
  }

  /// Generates a shareable playlist URL.
  /// Pattern: https://www.truthworld.in/playlist/{playlistId}
  static String playlistUrl(String playlistId) =>
      '$baseUrl/playlist/$playlistId';

  /// Generates a shareable topic URL.
  /// Pattern: https://www.truthworld.in/T/{id_or_slug_or_handle}
  static String topicUrl(String slugOrHandle) {
    var clean = slugOrHandle.trim();
    if (clean.startsWith('T/')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('t/')) {
      clean = clean.substring(2);
    }
    return '$baseUrl/T/$clean';
  }

  /// Share a video with title and URL.
  Future<void> shareVideo(
    String videoId,
    String videoTitle, {
    String? channelName,
  }) async {
    try {
      final url = videoUrl(videoId);
      final byChannel = (channelName != null &&
              channelName.isNotEmpty &&
              channelName != 'Channel' &&
              !videoTitle.toLowerCase().contains(channelName.toLowerCase()))
          ? ' by $channelName'
          : '';
      await SharePlus.instance.share(
        ShareParams(
          text: 'Watch "$videoTitle"$byChannel on TruthWorld:\n$url',
          subject: videoTitle,
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.shareVideo');
    }
  }

  /// Share a channel with name, handle, and URL.
  Future<void> shareChannel(
    String channelId, {
    String? channelName,
    String? handle,
  }) async {
    try {
      final url = channelUrl(channelId);
      final cleanHandle = (handle ?? '').replaceAll(RegExp('^@'), '').trim();
      final handleStr = cleanHandle.isNotEmpty ? ' (@$cleanHandle)' : '';
      final text = channelName != null
          ? 'Check out $channelName$handleStr on TruthWorld:\n$url'
          : 'Check out this channel on TruthWorld:\n$url';
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: channelName ?? 'TruthWorld Channel',
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.shareChannel');
    }
  }

  /// Share a playlist with name and URL.
  Future<void> sharePlaylist(String playlistId, String playlistName) async {
    try {
      final url = playlistUrl(playlistId);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out "$playlistName" playlist on TruthWorld:\n$url',
          subject: playlistName,
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.sharePlaylist');
    }
  }

  /// Share a topic with name and URL.
  Future<void> shareTopic(String slugOrHandle, String topicTitle) async {
    try {
      final url = topicUrl(slugOrHandle);
      final cleanTitle = topicTitle.replaceAll(RegExp('^[#Tt]/'), '').trim();
      await SharePlus.instance.share(
        ShareParams(
          text: 'Explore #$cleanTitle on TruthWorld:\n$url',
          subject: '#$cleanTitle',
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.shareTopic');
    }
  }
}
