import 'package:flutter/material.dart';

/// Enum representing different types of content uploads
/// Future-proofed to support additional content types as the platform grows
enum UploadType {
  /// Long-form video uploads
  video,

  /// Community posts with text, images, and polls
  communityPost,

  /// Playlists
  playlist,

  /// Topics
  topic,
}

/// Extension methods for UploadType to provide UI-related properties
extension UploadTypeExtension on UploadType {
  /// Get the display title for this upload type
  String get title {
    switch (this) {
      case UploadType.video:
        return 'Upload Video';
      case UploadType.communityPost:
        return 'Community Post';
      case UploadType.playlist:
        return 'Create Playlist';
      case UploadType.topic:
        return 'Create Topic';
    }
  }

  /// Get the subtitle/description for this upload type
  String get subtitle {
    switch (this) {
      case UploadType.video:
        return 'Record or upload long-form videos';
      case UploadType.communityPost:
        return 'Share text, images and polls';
      case UploadType.playlist:
        return 'Organize videos into shareable playlists';
      case UploadType.topic:
        return 'Build a topic to organize and curate videos around a theme';
    }
  }

  /// Get the icon for this upload type
  IconData get icon {
    switch (this) {
      case UploadType.video:
        return Icons.video_call_outlined;
      case UploadType.communityPost:
        return Icons.article_outlined;
      case UploadType.playlist:
        return Icons.playlist_add;
      case UploadType.topic:
        return Icons.topic_outlined;
    }
  }

  /// Get the keyboard shortcut for this upload type (web only)
  String? get keyboardShortcut {
    switch (this) {
      case UploadType.video:
        return 'V';
      case UploadType.communityPost:
        return 'C';
      case UploadType.playlist:
        return 'P';
      case UploadType.topic:
        return 'T';
    }
  }

  /// Check if this upload type is currently available for use
  bool get isAvailable {
    switch (this) {
      case UploadType.video:
      case UploadType.communityPost:
      case UploadType.playlist:
      case UploadType.topic:
        return true;
    }
  }

  /// Get the route path for this upload type
  String get routePath {
    switch (this) {
      case UploadType.video:
        return '/upload/video';
      case UploadType.communityPost:
        return '/upload/community';
      case UploadType.playlist:
        return '/create-playlist';
      case UploadType.topic:
        return '/create-topic';
    }
  }
}

/// Extension to convert UploadType to/from string for storage
extension UploadTypeStorage on UploadType {
  /// Convert to string for storage
  String toStorageString() {
    return name;
  }
}

/// Create UploadType from storage string
UploadType uploadTypeFromStorageString(String value) {
  return UploadType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => UploadType.video,
  );
}
