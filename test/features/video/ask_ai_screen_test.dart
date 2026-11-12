import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/ask_ai_screen.dart';
import 'package:truthworld/routes/app_routes.dart';

import '../../test_helpers/mock_firebase.dart';

class _FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

class _MockAuthService extends GetxService implements AuthService {
  @override
  bool get isUserSignedIn => true;
  @override
  RxBool get isAuthenticated => true.obs;
  @override
  String get uid => 'user_123';
  @override
  Channel? get userChannel => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(_MockAuthService());
    Get.put<ConnectivityService>(_FakeConnectivityService());
  });

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'test_video_ask_ai',
    ownerId: 'owner_ask_ai',
    title: 'Scientific Analysis of Quantum Computing',
    description: 'Empirical verification of quantum supremacy claims.',
    videoUrl: 'https://example.com/quantum.mp4',
    thumbnailUrl: 'https://example.com/quantum.jpg',
    channelId: 'channel_quantum',
    channelName: 'Science Truth',
    category: 'Science',
    tags: const ['science', 'quantum'],
    factCheckUrl: 'https://example.com/factcheck.json',
  );

  testWidgets('AskAiScreen renders dedicated full-page AppBar and chat interface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.askAi,
        getPages: [
          GetPage(
            name: AppRoutes.askAi,
            page: () => AskAiScreen(video: testVideo),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Verify AppBar contents
    expect(find.text('Truth Intelligence AI'), findsOneWidget);
    expect(find.text('Scientific Analysis of Quantum Computing'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // Verify chat elements
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('AskAiScreen.open seamlessly opens the dedicated route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AskAiScreen.open(
                context,
                video: testVideo,
              ),
              child: const Text('Open Ask AI'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap to open
    await tester.tap(find.text('Open Ask AI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Verify AskAiScreen is displayed
    expect(find.byType(AskAiScreen), findsOneWidget);
    expect(find.text('Truth Intelligence AI'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Verify returned to original page
    expect(find.byType(AskAiScreen), findsNothing);
    expect(find.text('Open Ask AI'), findsOneWidget);
  });

  testWidgets('AskAiScreen displays claim scope when launched for a specific claim', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      GetMaterialApp(
        home: AskAiScreen(
          video: testVideo,
          scope: 'claim',
          claimIndex: 2,
          claimText: 'Quantum processors achieve 99.9% gate fidelity',
          verdict: 'Verified',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Truth AI • Claim #3'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Quantum processors achieve 99.9% gate fidelity'), findsOneWidget);
  });
}
