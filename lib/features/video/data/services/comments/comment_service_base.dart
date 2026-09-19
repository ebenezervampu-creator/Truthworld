import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Base abstract class for comment services providing Firestore,
/// Cloud Functions, and standardized collection paths.
abstract class CommentServiceBase {
  CommentServiceBase({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestoreOverride = firestore,
        _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  /// Firestore instance (supports injection for testing)
  FirebaseFirestore get firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Backend Cloud Functions instance (configured for asia-south1)
  FirebaseFunctions get functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'asia-south1');

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
