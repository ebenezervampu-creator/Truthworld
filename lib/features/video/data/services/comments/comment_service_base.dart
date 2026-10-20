import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Base abstract class for comment services providing Firestore,
/// Cloud Functions, and standardized collection paths.
abstract class CommentServiceBase {
  CommentServiceBase({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _functionsOverride = functions,
        _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  final FirebaseAuth? _authOverride;

  /// Firestore instance (supports injection for testing)
  FirebaseFirestore get firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Backend Cloud Functions instance (configured for asia-south1)
  FirebaseFunctions get functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Auth instance (supports injection for testing)
  FirebaseAuth get auth => _authOverride ?? FirebaseAuth.instance;

  /// Proactively refresh the Firebase Auth ID token so Callable Cloud Functions
  /// have a valid and non-stale authentication context.
  Future<void> ensureAuthFreshness() async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        await currentUser.getIdToken();
      }
    } catch (_) {}
  }

  // Standard Firestore Collection paths
  static const String videosPath = 'videos';
  static const String commentsPath = 'comments';
  static const String repliesPath = 'replies';
  static const String reportsPath = 'reports';

  // Instance accessors for mixin convenience
  String get videosCollection => videosPath;
  String get commentsCollection => commentsPath;
  String get repliesCollection => repliesPath;
  String get reportsCollection => reportsPath;
}
