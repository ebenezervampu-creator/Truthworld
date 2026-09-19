import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/session/session_barrel.dart';

export 'package:truthworld/features/home/presentation/controllers/session/session_barrel.dart';

/// Main controller managing user interactions, video likes/dislikes, comments,
/// replies, sharing, reporting, and personal library actions.
class UserSessionController extends BaseController
    with
        SessionVideoInteractionsMixin,
        SessionContentShareMixin,
        SessionCommentInteractionsMixin,
        SessionCommentManagementMixin,
        SessionModerationLibraryMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterVideoInfo videoInfo = FlutterVideoInfo();

  FirebaseFirestore get firestore => _firestore;
  FirebaseAuth get auth => _auth;

  /// Current user authentication ID (or empty string if guest)
  String get userId => _auth.currentUser?.uid ?? '';

  /// Check if current user is authenticated and non-anonymous
  bool get isAuthenticated =>
      _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  /// Nullable user ID of active session
  String? get currentUserId => _auth.currentUser?.uid;
}
