import 'package:flutter/foundation.dart';
import 'package:truthworld/core/services/seo_listener.dart';
import 'package:truthworld/core/services/seo_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Helper functions for SEO updates with dynamic content
class SeoHelpers {
  /// Update SEO for video page with absolute URLs
  static void updateVideoSeo(Video video) {
    final description = video.description.length > 160
        ? '${video.description.substring(0, 160)}...'
        : video.description;

    // Ensure thumbnail URL is absolute
    final thumbnailUrl = _toAbsoluteUrl(video.thumbnailUrl);
    final videoUrl = _toAbsoluteUrl(video.videoUrl);

    // Use setVideoMetadata for proper video SEO
    SeoHelper.setVideoMetadata(
      title: video.title,
      description: description,
      url: '/watch/${video.id}',
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: _parseDuration(video.duration),
      uploadDate: video.uploadedAt.toDate(),
    );

    // Also update manual SEO for fallback
    SeoRouteListener.updateSeo(
      title: video.title,
      description: description,
      url: '/watch/${video.id}',
      image: thumbnailUrl,
      keywords: video.tags.isNotEmpty ? video.tags.join(', ') : video.category,
      author: video.channelName,
    );
  }

  /// Update SEO for channel page with validated images
  static void updateChannelSeo(
    String channelName,
    String description,
    String? channelImage,
  ) {
    final desc = description.length > 160
        ? '${description.substring(0, 160)}...'
        : description;

    final absoluteImage = _toAbsoluteUrl(channelImage ?? '');

    SeoRouteListener.updateSeo(
      title: '$channelName - Channel',
      description: desc,
      url: '/channel/${channelName.toLowerCase().replaceAll(' ', '-')}',
      image: absoluteImage,
      author: channelName,
    );
  }

  /// Update SEO for playlist page
  static void updatePlaylistSeo(
    String playlistName,
    String description,
    int videoCount,
  ) {
    SeoRouteListener.updateSeo(
      title: '$playlistName - Playlist',
      description: '$description • $videoCount videos',
      url: '/playlist/${playlistName.toLowerCase().replaceAll(' ', '-')}',
      keywords: 'playlist, videos, collection, organize',
    );
  }

  /// Update SEO for search results
  static void updateSearchSeo(String query, int resultCount) {
    SeoRouteListener.updateSeo(
      title: 'Search Results for "$query"',
      description: 'Found $resultCount results for "$query" on TruthWorld',
      url: '/search?q=${query.replaceAll(' ', '+')}',
      keywords: query,
    );
  }

  /// Update SEO for category page
  static void updateCategorySeo(String categoryName, int videoCount) {
    SeoRouteListener.updateSeo(
      title: '$categoryName Videos',
      description:
          'Browse $videoCount videos in the $categoryName category on TruthWorld',
      url: '/category/$categoryName',
      keywords: categoryName.toLowerCase(),
    );
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Convert relative URL to absolute URL
  static String _toAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://www.truthworld.in/og-image.png';
    }

    // Already absolute URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Firebase Storage URL
    if (url.contains('firebasestorage.googleapis.com')) {
      return url;
    }

    // Relative URL - prepend domain
    if (url.startsWith('/')) {
      return 'https://www.truthworld.in$url';
    }

    // Relative path without slash
    return 'https://www.truthworld.in/$url';
  }

  /// Parse duration string (e.g., "01:23:45" or "123") to Duration
  static Duration _parseDuration(String durationStr) {
    if (durationStr.isEmpty) return Duration.zero;

    try {
      // Try parsing as seconds first
      final seconds = int.tryParse(durationStr);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }

      // Try parsing as HH:MM:SS format
      final parts = durationStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }

      // Try parsing as MM:SS format
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      }

      return Duration.zero;
    } catch (e) {
      debugPrint('⚠️ Failed to parse duration: $durationStr');
      return Duration.zero;
    }
  }
}





