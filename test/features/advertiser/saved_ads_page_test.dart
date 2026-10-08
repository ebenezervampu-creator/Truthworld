import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/advertiser/presentation/views/saved_ads_page.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.testMode = true;
    Get.put(AdService());
  });

  tearDown(Get.reset);

  group('SavedAdsPage Widget Tests', () {
    testWidgets('renders header with back button, title, and subtitle', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: SavedAdsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('Interacted Ads'), findsOneWidget);
      expect(
        find.text('Your liked and bookmarked advertiser sponsor layers'),
        findsOneWidget,
      );
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Liked'), findsOneWidget);
    });

    testWidgets('tapping back button navigates back', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Get.to(() => const SavedAdsPage()),
                child: const Text('Open Saved Ads'),
              ),
            ),
          ),
        ),
      );

      // Tap button to navigate to SavedAdsPage
      await tester.tap(find.text('Open Saved Ads'));
      await tester.pumpAndSettle();

      expect(find.byType(SavedAdsPage), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tap the back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Should be back to the first screen
      expect(find.byType(SavedAdsPage), findsNothing);
      expect(find.text('Open Saved Ads'), findsOneWidget);
    });
  });
}
