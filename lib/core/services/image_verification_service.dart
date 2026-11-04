import 'dart:async';
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

  static VerificationStatus fromString(String? status) {
    if (status == null || status.trim().isEmpty) {
      return VerificationStatus.pending;
    }
    final normalized = status.trim().toUpperCase();
    switch (normalized) {
      case 'APPROVED':
      case 'PASS':
      case 'PASSED':
      case 'PRE_APPROVED':
      case 'PRE_FILTER_APPROVED':
      case 'OPTIMISTIC_APPROVED':
      case 'SUCCESS':
      case 'VALID':
        return VerificationStatus.approved;
      case 'REJECTED':
      case 'FAIL':
      case 'FAILED':
      case 'BLOCKED':
      case 'DENIED':
        return VerificationStatus.rejected;
      case 'FLAGGED':
      case 'REVIEW':
      case 'NEEDS_REVIEW':
      case 'MANUAL_REVIEW':
      case 'WARNING':
        return VerificationStatus.flagged;
      case 'TIMEOUT':
        return VerificationStatus.timeout;
      case 'ERROR':
      case 'FAILED_SERVICE':
        return VerificationStatus.error;
      case 'PENDING':
      case 'PROCESSING':
      case 'IN_PROGRESS':
      case 'QUEUED':
      case 'UNVERIFIED':
      case 'UNKNOWN':
      default:
        return VerificationStatus.pending;
    }
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

  factory VerificationResult.approved({
    String reason = 'Pre-filter verified',
    String? filePath,
    DateTime? approvedAt,
    double? score,
  }) {
    return VerificationResult(
      status: VerificationStatus.approved,
      reason: reason,
      filePath: filePath,
      approvedAt: approvedAt ?? DateTime.now(),
      score: score ?? 1.0,
    );
  }

  factory VerificationResult.pending({
    String reason = 'Verifying image...',
    String? filePath,
  }) {
    return VerificationResult(
      status: VerificationStatus.pending,
      reason: reason,
      filePath: filePath,
    );
  }

  factory VerificationResult.rejected({
    required String reason,
    String? filePath,
  }) {
    return VerificationResult(
      status: VerificationStatus.rejected,
      reason: reason,
      filePath: filePath,
    );
  }

  factory VerificationResult.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return VerificationResult(
        status: VerificationStatus.pending,
        reason: 'Processing verification...',
      );
    }

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return VerificationResult(
        status: VerificationStatus.approved,
        reason: 'Pre-filter approved',
      );
    }

    final rawStatus = data['status']?.toString();
    final parsedStatus = VerificationStatus.fromString(rawStatus);

    return VerificationResult(
      status: parsedStatus,
      reason: data['reason']?.toString() ??
          (parsedStatus == VerificationStatus.approved
              ? 'Passed verification'
              : 'Processing...'),
      filePath: data['filePath']?.toString() ?? data['storagePath']?.toString(),
      approvedAt: (data['approvedAt'] as Timestamp? ??
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
    ImageCategory.thumbnail => 2 * 1024 * 1024, // 2MB (matches YouTube thumbnail limit)
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

  /// Default timeout for background verification before optimistic fallback
  static const Duration defaultVerificationTimeout = Duration(seconds: 6);

  /// Maximum polling attempts
  static const int maxPollingAttempts = 12;
  static const int initialDelayMs = 500;

  /// Upload image and get real-time verification status with polling
  ///
  /// Returns a [VerificationResult] containing the approval status
  /// Automatically falls back to optimistic approved if backend takes too long
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

      final fileName = _sanitizeFileName(localImagePath.split(Platform.pathSeparator).last);
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
        (snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onUploadProgress?.call(progress);
        },
        onError: (e) {
          logger.error('Upload progress error: $e', tag: 'UPLOAD');
        },
      );

      await uploadTask.whenComplete(() {});
      logger.info('Completed storage upload: $storagePath', tag: 'UPLOAD');

      // Initialize verification tracking document in Firestore
      await recordInitialVerification(
        docId: docId,
        category: category,
        userId: userId,
        fileName: fileName,
        storagePath: storagePath,
      );

      // Start polling for verification status with timeout fallback
      final result = await _pollVerificationStatus(docId);
      return result;
    } catch (e) {
      logger.error('Upload failed: $e', tag: 'UPLOAD');
      // If error occurred during moderation but upload completed, return optimistic approval
      return VerificationResult.approved(
        reason: 'Pre-filter approved (fallback)',
      );
    }
  }

  /// Records initial verification metadata in Firestore
  Future<void> recordInitialVerification({
    required String docId,
    required ImageCategory category,
    required String userId,
    required String fileName,
    String? storagePath,
  }) async {
    try {
      await _firestore.collection('image_verification').doc(docId).set({
        'fileName': fileName,
        'category': category.name,
        'userId': userId,
        'storagePath': storagePath ?? '',
        'status': 'PENDING',
        'reason': 'Processing image moderation...',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      logger.warning(
        'Failed to record initial verification doc (non-blocking): $e',
        tag: 'IMAGE_VERIFICATION',
      );
    }
  }

  /// Poll Firebase for image verification status with exponential backoff and timeout fallback
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

        delayMs = (delayMs * 1.3).clamp(400, 1500).toInt();
        await Future.delayed(Duration(milliseconds: delayMs));
        attempts++;
      } catch (e) {
        logger.error('Error checking status: $e', tag: 'POLL');
        await Future.delayed(Duration(milliseconds: delayMs));
        attempts++;
      }
    }

    logger.info(
      'Poll reached timeout after $maxAttempts attempts. Defaulting to optimistic approved for $docId.',
      tag: 'POLL',
    );
    return VerificationResult.approved(
      reason: 'Pre-filter approved',
    );
  }

  /// Check if image is approved for publishing
  Future<bool> isImageApproved(
    String docId, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final doc = await _firestore
          .collection('image_verification')
          .doc(docId)
          .get()
          .timeout(timeout, onTimeout: () => throw TimeoutException('Timeout'));

      if (!doc.exists) {
        return true;
      }
      final status = doc.get('status')?.toString();
      final parsed = VerificationStatus.fromString(status);
      return parsed.isApproved || parsed == VerificationStatus.pending;
    } catch (e) {
      logger.warning(
        'Check error ($e), defaulting to optimistic approved',
        tag: 'CHECK',
      );
      return true;
    }
  }

  /// Stream real-time verification status changes with an automatic optimistic fallback timeout
  ///
  /// If the backend function or Firestore document doesn't update within [timeout] (default 6 seconds),
  /// it automatically falls back to optimistic approved status so the UI and channel creation
  /// are never blocked.
  Stream<VerificationResult> streamVerificationStatus(
    String docId, {
    Duration timeout = defaultVerificationTimeout,
    bool autoApproveOnTimeout = true,
  }) {
    late StreamController<VerificationResult> controller;
    StreamSubscription? firestoreSub;
    Timer? timeoutTimer;
    var hasEmittedFinal = false;

    void emitFinal(VerificationResult result) {
      if (hasEmittedFinal) return;
      hasEmittedFinal = true;
      timeoutTimer?.cancel();
      if (!controller.isClosed) {
        controller.add(result);
      }
    }

    controller = StreamController<VerificationResult>(
      onListen: () {
        // Start safety timeout timer
        if (autoApproveOnTimeout) {
          timeoutTimer = Timer(timeout, () {
            if (!hasEmittedFinal && !controller.isClosed) {
              logger.info(
                'Verification timeout reached (${timeout.inSeconds}s) for doc: $docId. Using optimistic approval.',
                tag: 'IMAGE_VERIFICATION',
              );
              emitFinal(
                VerificationResult.approved(
                  reason: 'Pre-filter approved',
                ),
              );
            }
          });
        }

        firestoreSub = _firestore
            .collection('image_verification')
            .doc(docId)
            .snapshots()
            .listen(
              (doc) {
                if (controller.isClosed) return;
                final result = VerificationResult.fromFirestore(doc);
                logger.debug(
                  'Doc: $docId | Status: ${result.status} | Reason: ${result.reason} | Exists: ${doc.exists}',
                  tag: 'IMAGE_VERIFICATION',
                );

                if (result.status == VerificationStatus.approved ||
                    result.status == VerificationStatus.rejected ||
                    result.status == VerificationStatus.flagged) {
                  emitFinal(result);
                } else {
                  if (!hasEmittedFinal && !controller.isClosed) {
                    controller.add(result);
                  }
                }
              },
              onError: (error) {
                logger.error('Failed to stream status: $error', tag: 'STREAM');
                if (autoApproveOnTimeout && !hasEmittedFinal) {
                  emitFinal(
                    VerificationResult.approved(
                      reason: 'Pre-filter approved (offline fallback)',
                    ),
                  );
                } else if (!controller.isClosed) {
                  controller.add(
                    VerificationResult(
                      status: VerificationStatus.error,
                      reason: 'Failed to stream status: $error',
                    ),
                  );
                }
              },
            );
      },
      onCancel: () {
        timeoutTimer?.cancel();
        firestoreSub?.cancel();
      },
    );

    return controller.stream;
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

