/// TruthWorld Accessibility Infrastructure
///
/// Industry-standard accessibility widgets and services following WCAG 2.1.
/// Import this barrel file to access all accessibility utilities.
///
/// ## Quick Start
///
/// Replace naked `GestureDetector` → `AccessibleTap`:
/// ```dart
/// AccessibleTap(
///   semanticLabel: 'Play video: ${video.title}',
///   onTap: () => playVideo(),
///   child: VideoThumbnail(...),
/// )
/// ```
///
/// Replace `CachedNetworkImage` → `AccessibleImage.network`:
/// ```dart
/// AccessibleImage.network(
///   url: video.thumbnailUrl,
///   semanticLabel: SemanticLabels.thumbnail(video.title),
/// )
/// ```
///
/// Announce state changes for screen readers:
/// ```dart
/// ScreenReaderService.announceLike(true);
/// ScreenReaderService.announceScreenChange('Home');
/// ```
library;

export 'accessibility_helpers.dart';
export 'accessible_image.dart';
export 'accessible_tap.dart';
export 'screen_reader_service.dart';
