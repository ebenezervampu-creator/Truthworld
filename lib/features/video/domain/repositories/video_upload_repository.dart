import 'dart:typed_data';
import 'package:truthworld/core/network/result.dart';

/// Repository contract for video & thumbnail storage uploads and metadata creation.
abstract class VideoUploadRepository {
  /// Upload a video file or byte stream to remote storage.
  Future<Result<String>> uploadVideoFile({
    required String filePath,
    required String destinationPath,
    void Function(double progress)? onProgress,
  });

  /// Upload thumbnail image bytes to storage.
  Future<Result<String>> uploadThumbnailBytes({
    required Uint8List imageBytes,
    required String fileName,
  });

  /// Save video metadata document to database.
  Future<Result<String>> saveVideoMetadata(Map<String, dynamic> metadata);
}
