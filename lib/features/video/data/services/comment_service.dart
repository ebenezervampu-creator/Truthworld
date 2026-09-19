import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/features/video/data/services/comments/comment_service_barrel.dart';

export 'package:truthworld/features/video/data/services/comments/comment_service_barrel.dart';

/// Central CommentService coordinating CRUD, replies, interactions,
/// creator hearts, and studio queries for video comments.
class CommentService extends CommentServiceBase
    with
        CommentCrudMixin,
        ReplyCrudMixin,
        CommentInteractionsMixin,
        ReplyInteractionsMixin,
        CommentStudioQueriesMixin {
  /// Singleton factory constructor
  factory CommentService() => _instance;

  /// Internal constructor for singleton
  CommentService._internal({
    super.firestore,
    super.functions,
  });

  /// Visible for testing constructor allowing custom firestore & functions injection
  factory CommentService.custom({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) {
    return CommentService._internal(
      firestore: firestore,
      functions: functions,
    );
  }

  static final CommentService _instance = CommentService._internal();
}
