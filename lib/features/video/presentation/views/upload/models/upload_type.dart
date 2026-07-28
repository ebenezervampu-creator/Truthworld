import 'package:flutter/material.dart';

/// Enum representing different types of content uploads
/// Future-proofed to support additional content types as the platform grows
enum UploadType {
  /// Long-form video uploads
  video,
  
  /// Community posts with text, images, and polls
  communityPost,
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
    }
  }

  /// Get the subtitle/description for this upload type
  String get subtitle {
    switch (this) {
      case UploadType.video:
        return 'Record or upload long-form videos';
      case UploadType.communityPost:
        return 'Share text, images and polls';
    }
  }

  /// Get the icon for this upload type
  IconData get icon {
    switch (this) {
      case UploadType.video:
        return Icons.video_call_outlined;
      case UploadType.communityPost:
        return Icons.article_outlined;
    }
  }

  /// Get the keyboard shortcut for this upload type (web only)
  String? get keyboardShortcut {
    switch (this) {
      case UploadType.video:
        return 'V';
      case UploadType.communityPost:
        return 'C';
    }
  }

  /// Check if this upload type is currently available for use
  bool get isAvailable {
    switch (this) {
      case UploadType.video:
      case UploadType.communityPost:
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
