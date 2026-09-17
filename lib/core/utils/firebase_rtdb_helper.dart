import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/firebase_options.dart';

/// Returns a safely initialized [FirebaseDatabase] instance configured with
/// the current platform's [DefaultFirebaseOptions.databaseURL] to prevent
/// Web SDK URL parsing errors during cold boot and hot restarts.
FirebaseDatabase getSafeFirebaseDatabase() {
  try {
    final dbUrl = DefaultFirebaseOptions.currentPlatform.databaseURL;
    if (dbUrl != null && dbUrl.isNotEmpty) {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: dbUrl,
      );
    }
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'FirebaseRTDBHelper.getSafeFirebaseDatabase',
    );
  }
  return FirebaseDatabase.instance;
}
