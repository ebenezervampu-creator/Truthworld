import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Represents the current status of image verification
enum VerificationStatus {
  pending,
  approved,
  rejected,
  flagged,
  error,
  timeout;

  static VerificationStatus fromString(String status) {
    return VerificationStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == status.toUpperCase(),
      orElse: () => VerificationStatus.error,
    );
  }

  bool get isApproved => this == VerificationStatus.approved;
  bool get isRejected => this == VerificationStatus.rejected;
  bool get isPending => this == VerificationStatus.pending;
  bool get isFlagged => this == VerificationStatus.flagged;
}

/// Result of image verification containing status and reason
class VerificationResult {
  VerificationResult({
    required this.status,
    required this.reason,
    this.filePath,
    this.approvedAt,
    this.score,
  });

  factory VerificationResult.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return VerificationResult(
        status: VerificationStatus.pending,
        reason: 'Processing...',
      );
    }

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return VerificationResult(
        status: VerificationStatus.error,
        reason: 'Invalid data',
      );
    }

    return VerificationResult(
      status: VerificationStatus.fromString(
        data['status']?.toString() ?? 'ERROR',
      ),
      reason: data['reason'] ?? 'No reason provided',
      filePath: data['filePath'],
      approvedAt:
          (data['approvedAt'] as Timestamp? ??
                  data['processedAt'] as Timestamp?)
              ?.toDate(),
      score: (data['score'] as num?)?.toDouble(),
    );
  }
  final VerificationStatus status;
  final String reason;
  final String? filePath;
  final DateTime? approvedAt;
  final double? score;

  @override
  String toString() =>
      'VerificationResult(status: $status, reason: $reason, score: $score)';
}

/// Configuration for different image categories
enum ImageCategory {
  thumbnail,
  avatar,
  banner,
  community;

  String get folderName => '${name}s';

  String get displayName => switch (this) {
    ImageCategory.thumbnail => 'Thumbnail',
    ImageCategory.avatar => 'Avatar',
    ImageCategory.banner => 'Banner',
    ImageCategory.community => 'Community Post Image',
  };

  /// Maximum allowed file size in bytes
  int get maxSize => switch (this) {
    ImageCategory.thumbnail => 5 * 1024 * 1024, // 5MB
    ImageCategory.avatar => 2 * 1024 * 1024, // 2MB
    ImageCategory.banner => 5 * 1024 * 1024, // 5MB
    ImageCategory.community => 10 * 1024 * 1024, // 10MB
  };

  /// Typical processing priority
  String get priority => switch (this) {
    ImageCategory.thumbnail => 'HIGH',
    ImageCategory.avatar => 'HIGH',
    ImageCategory.banner => 'MEDIUM',
    ImageCategory.community => 'HIGH',
  };
}

/// Service for uploading and verifying images with Firebase
class ImageVerificationService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Maximum polling attempts (5 minutes total with exponential backoff)
  static const int maxPollingAttempts = 60;
  static const int initialDelayMs = 500;

  /// Upload image and get real-time verification status with polling
  ///
  /// Returns a [VerificationResult] containing the approval status
  /// Automatically polls Firestore until image is verified or timeout occurs
  Future<VerificationResult> uploadAndVerifyImage({
    required ImageCategory category,
    required String userId,
    required String contentId,
    required String localImagePath,
    Function(double)? onUploadProgress,
  }) async {
    try {
      // Validate file exists
      if (!File(localImagePath).existsSync()) {
        return VerificationResult(
          status: VerificationStatus.error,
          reason: 'File not found: $localImagePath',
        );
      }

      // Validate file size
      final fileSize = File(localImagePath).lengthSync();
      if (fileSize > category.maxSize) {
        return VerificationResult(
          status: VerificationStatus.error,
          reason:
              'File too large. Max: ${(category.maxSize / 1024 / 1024).toStringAsFixed(1)}MB',
        );
      }

      final fileName = _sanitizeFileName(localImagePath.split('/').last);
      final storagePath = '${category.folderName}/$userId/$contentId/$fileName';
      final docId = fileName;

      logger.info('Starting upload: $storagePath', tag: 'UPLOAD');

      // Upload to Firebase Storage
      final ref = _storage.ref(storagePath);
      final uploadTask = ref.putFile(
        File(localImagePath),
        SettableMetadata(
          contentType: _getContentType(localImagePath),
          customMetadata: {
            'category': category.name,
            'userId': userId,
            'contentId': contentId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onUploadProgress?.call(progress);
        },
        onError: (e) {
          logger.error('Upload progress error: $e', tag: 'UPLOAD');
        },
      );

      await uploadTask.whenComplete(() {});
      logger.info('Completed: $storagePath', tag: 'UPLOAD');

      // Start polling for verification status
      final result = await _pollVerificationStatus(docId);

      return result;
    } catch (e) {
      logger.error('Upload failed: $e', tag: 'UPLOAD');
      return VerificationResult(
        status: VerificationStatus.error,
        reason: 'Upload failed: $e',
      );
    }
  }

  /// Poll Firebase for image verification status with exponential backoff
  ///
  /// Implements exponential backoff starting at 500ms, up to 5 seconds
  /// Continues polling for up to 5 minutes before timing out
  Future<VerificationResult> _pollVerificationStatus(
    String docId, {
    int maxAttempts = maxPollingAttempts,
    int initialDelayMs = ImageVerificationService.initialDelayMs,
  }) async {
    var attempts = 0;
    var delayMs = initialDelayMs;

    logger.info('Starting verification status poll for: $docId', tag: 'POLL');

    while (attempts < maxAttempts) {
      try {
        final doc = await _firestore
            .collection('image_verification')
            .doc(docId)
            .get(const GetOptions(source: Source.server));

        if (doc.exists) {
          final result = VerificationResult.fromFirestore(doc);

          if (result.status != VerificationStatus.pending) {
            logger.info(
              'Status received: ${result.status} after ${attempts + 1} attempts',
              tag: 'POLL',
            );
            return result;
          }
        }

        // Exponential backoff: 500ms → 750ms → 1125ms ... max 5000ms
        delayMs = (delayMs * 1.5).clamp(500, 5000).toInt();
        await Future.delayed(Duration(milliseconds: delayMs));
        attempts++;

        if (attempts % 10 == 0) {
          logger.info(
            'Still waiting... attempt ${attempts + 1}/$maxAttempts',
            tag: 'POLL',
          );
        }
      } catch (e) {
        logger.error('Error checking status: $e', tag: 'POLL');
        await Future.delayed(Duration(milliseconds: delayMs));
        attempts++;
      }
    }

    logger.warning('Timeout after $maxAttempts attempts', tag: 'POLL');
    return VerificationResult(
      status: VerificationStatus.timeout,
      reason: 'Verification processing timeout. Please check status later.',
    );
  }

  /// Check if image is approved for publishing
  Future<bool> isImageApproved(String docId) async {
    try {
      final doc = await _firestore
          .collection('image_verification')
          .doc(docId)
          .get();

      return doc.exists &&
          doc.get('status')?.toString().toUpperCase() == 'APPROVED';
    } catch (e) {
      logger.error('Check error: $e', tag: 'CHECK');
      return false;
    }
  }

  /// Stream real-time verification status changes
  ///
  /// Useful for real-time UI updates instead of polling
  /// Example: StreamBuilder with this stream for live status updates
  Stream<VerificationResult> streamVerificationStatus(String docId) {
    return _firestore
        .collection('image_verification')
        .doc(docId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          final statusValue = data?['status'] ?? 'unknown';
          logger.debug(
            'Doc: $docId | Status: $statusValue | Exists: ${doc.exists}',
            tag: 'IMAGE_VERIFICATION',
          );
          return VerificationResult.fromFirestore(doc);
        })
        .handleError((error) {
          logger.error('Failed to stream status: $error', tag: 'STREAM');
          return VerificationResult(
            status: VerificationStatus.error,
            reason: 'Failed to stream status: $error',
          );
        });
  }

  /// Get file content type based on extension
  String _getContentType(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  /// Sanitize filename to prevent directory traversal attacks
  String _sanitizeFileName(String fileName) {
    // Remove special characters, keep only alphanumeric, dash, underscore, dot
    final sanitized = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
    return sanitized;
  }
}
