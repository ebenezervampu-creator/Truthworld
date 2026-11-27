import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_comment.dart';

/// 🏛 ClaimCommentService
///
/// Handles real-time streams, posting, voting, and deletion of
/// structured claim deliberation notes (Community Notes) in Firestore.
class ClaimCommentService {
  ClaimCommentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static final ClaimCommentService instance = ClaimCommentService();

  CollectionReference<Map<String, dynamic>> _claimCommentsRef(String videoId) {
    return _firestore.collection('videos').doc(videoId).collection('claim_comments');
  }

  /// Checks whether the current user is temporarily restricted from AI Check
  /// source submissions and Community Notes due to repeated invalid sources.
  Future<DateTime?> getAiCheckRestrictionUntil() async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return null;
    try {
      final snap = await _firestore
          .collection('user_ai_check_restrictions')
          .doc(uid)
          .get();
      if (!snap.exists) return null;
      final untilMs = snap.data()?['restrictedUntilMs'];
      if (untilMs is int && untilMs > DateTime.now().millisecondsSinceEpoch) {
        return DateTime.fromMillisecondsSinceEpoch(untilMs);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Streams community deliberation notes for a video, optionally filtered by [claimIndex].
  Stream<List<ClaimComment>> streamClaimComments({
    required String videoId,
    int? claimIndex,
  }) {
    if (videoId.isEmpty) {
      return Stream.value(const []);
    }

    Query<Map<String, dynamic>> query = _claimCommentsRef(videoId);

    if (claimIndex != null) {
      query = query.where('claimIndex', isEqualTo: claimIndex);
    }

    return query
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs
          .map(ClaimComment.fromDocumentSnapshot)
          .toList();
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    }).handleError((error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace: stackTrace,
        context: 'ClaimCommentService.streamClaimComments',
      );
      return <ClaimComment>[];
    });
  }

  /// Adds a new community deliberation note to a claim.
  Future<ClaimComment> addClaimComment({
    required String videoId,
    required int claimIndex,
    required String claimText,
    required String text,
    required String stance,
    List<String> sourceUrls = const [],
  }) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      throw Exception('You must be signed in to submit a community note.');
    }

    final restrictedUntil = await getAiCheckRestrictionUntil();
    if (restrictedUntil != null) {
      final dateLabel =
          '${restrictedUntil.year}-${restrictedUntil.month.toString().padLeft(2, '0')}-${restrictedUntil.day.toString().padLeft(2, '0')}';
      throw Exception(
        'Your AI Check and Community Notes access is temporarily restricted until $dateLabel due to repeated invalid source submissions.',
      );
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw Exception('Note text cannot be empty.');
    }
    if (trimmedText.length > 2000) {
      throw Exception('Note exceeds maximum length of 2,000 characters.');
    }

    // Sanitize source URLs
    final sanitizedSources = <String>[];
    for (final rawUrl in sourceUrls) {
      final normalized = SourceUrlSanitizer.normalizeSourceUrl(rawUrl);
      if (normalized != null && normalized.isNotEmpty) {
        sanitizedSources.add(normalized);
      }
    }

    final sanitizedText = ContentValidator.cleanProfanity(trimmedText);
    final user = AuthService.to.user;
    final userChannel = AuthService.to.userChannel;

    final userName = userChannel?.name.isNotEmpty == true
        ? userChannel!.name
        : (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : 'TruthWorld Member');

    final userProfilePicUrl = userChannel?.avatarUrl.trim().isNotEmpty == true
        ? userChannel!.avatarUrl.trim()
        : (user?.photoURL?.trim().isNotEmpty == true
            ? user!.photoURL!.trim()
            : '');

    final docRef = _claimCommentsRef(videoId).doc();
    final now = Timestamp.now();

    final newComment = ClaimComment(
      id: docRef.id,
      videoId: videoId,
      claimIndex: claimIndex,
      claimText: claimText.trim(),
      userId: uid,
      userName: userName,
      userProfilePicUrl: userProfilePicUrl,
      channelId: userChannel?.id ?? uid,
      channelName: userChannel?.name,
      text: sanitizedText,
      stance: stance.toLowerCase().trim(),
      sourceUrls: sanitizedSources,
      createdAt: now,
    );

    try {
      await docRef.set(newComment.toMap());
      return newComment;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'ClaimCommentService.addClaimComment',
      );
      throw Exception('Unable to submit note at this time. Please try again.');
    }
  }

  /// Toggles whether a note was helpful or unhelpful for the current user.
  Future<void> toggleHelpfulVote({
    required String videoId,
    required String commentId,
    required bool isHelpful,
  }) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      throw Exception('You must be signed in to rate community notes.');
    }

    final docRef = _claimCommentsRef(videoId).doc(commentId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;

        final data = snap.data() ?? {};
        final helpfulUsers = List<String>.from(data['helpfulUserIds'] ?? []);
        final unhelpfulUsers = List<String>.from(data['unhelpfulUserIds'] ?? []);

        if (isHelpful) {
          if (helpfulUsers.contains(uid)) {
            helpfulUsers.remove(uid);
          } else {
            helpfulUsers.add(uid);
            unhelpfulUsers.remove(uid);
          }
        } else {
          if (unhelpfulUsers.contains(uid)) {
            unhelpfulUsers.remove(uid);
          } else {
            unhelpfulUsers.add(uid);
            helpfulUsers.remove(uid);
          }
        }

        tx.update(docRef, {
          'helpfulUserIds': helpfulUsers,
          'unhelpfulUserIds': unhelpfulUsers,
          'helpfulCount': helpfulUsers.length,
          'unhelpfulCount': unhelpfulUsers.length,
        });
      });
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'ClaimCommentService.toggleHelpfulVote',
      );
      throw Exception('Unable to register vote. Please try again.');
    }
  }

  /// Deletes a community deliberation note.
  Future<void> deleteClaimComment({
    required String videoId,
    required String commentId,
  }) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    try {
      await _claimCommentsRef(videoId).doc(commentId).delete();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        context: 'ClaimCommentService.deleteClaimComment',
      );
      throw Exception('Unable to delete note at this time.');
    }
  }
}
