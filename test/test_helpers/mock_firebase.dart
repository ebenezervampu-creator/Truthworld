import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setupMockFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'mock-api-key',
        appId: 'mock-app-id',
        messagingSenderId: 'mock-sender-id',
        projectId: 'mock-project-id',
      ),
    );
  } catch (_) {
    // Ignore if already initialized or mock app exists
  }
}
