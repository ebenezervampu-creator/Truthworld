import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience/audience_components.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createHarness(Widget child, {bool isDarkMode = true}) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('AudiencePage Modular Components Tests', () {
    testWidgets('buildAudienceLiveSubscriberBanner renders live subscriber information', (tester) async {
      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildAudienceLiveSubscriberBanner(
              context: ctx,
              channelId: 'ch_test_1',
              isDarkMode: true,
              surfaceColor: const Color(0xFF1E293B),
              borderColor: const Color(0xFF334155),
              textColor: Colors.white,
              subtitleColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('Live Subscribers of channel'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('See live count'), findsOneWidget);
    });

    testWidgets('buildAudienceSummaryCardsMatrix renders metric tiles correctly', (tester) async {
      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));
      ctrl.totalViews.value = 50000;
      ctrl.returningViewers.value = 25000;
      ctrl.totalUniqueViewers.value = 35000;

      await tester.pumpWidget(
        createHarness(
          Obx(
            () => buildAudienceSummaryCardsMatrix(
              controller: ctrl,
              isDarkMode: true,
              surfaceColor: const Color(0xFF1E293B),
              borderColor: const Color(0xFF334155),
              textColor: Colors.white,
              subtitleColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('Returning Viewers'), findsOneWidget);
      expect(find.text('Unique Viewers'), findsOneWidget);
      expect(find.text('Subscribers (+/-)'), findsOneWidget);
      expect(find.text('Not Subscribed Views'), findsOneWidget);
      expect(find.text('Total View Reach'), findsOneWidget);
    });

    testWidgets('buildAudienceSubscribersWatchShareCard renders subscription share', (tester) async {
      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));
      ctrl.totalViews.value = 1000;
      ctrl.subscriberViews.value = 400;
      ctrl.nonSubscriberViews.value = 600;

      await tester.pumpWidget(
        createHarness(
          Obx(
            () => buildAudienceSubscribersWatchShareCard(
              controller: ctrl,
              isDarkMode: true,
              surfaceColor: const Color(0xFF1E293B),
              borderColor: const Color(0xFF334155),
              textColor: Colors.white,
              subtitleColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('Watch Time from Subscribers'), findsOneWidget);
      expect(find.text('Subscribed'), findsOneWidget);
      expect(find.text('Not subscribed'), findsOneWidget);
    });

    testWidgets('buildAudienceAgeDemographicsCard renders age brackets', (tester) async {
      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));
      ctrl.ageDistribution.value = {
        '18–24 years': 35.0,
        '25–34 years': 45.0,
      };

      await tester.pumpWidget(
        createHarness(
          Obx(
            () => buildAudienceAgeDemographicsCard(
              controller: ctrl,
              surfaceColor: const Color(0xFF1E293B),
              borderColor: const Color(0xFF334155),
              textColor: Colors.white,
              subtitleColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('Viewer Age Groups'), findsOneWidget);
      expect(find.text('18–24 years'), findsOneWidget);
      expect(find.text('25–34 years'), findsOneWidget);
    });

    testWidgets('buildAudienceGenderDemographicsCard renders gender segments', (tester) async {
      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));

      await tester.pumpWidget(
        createHarness(
          Obx(
            () => buildAudienceGenderDemographicsCard(
              controller: ctrl,
              isDarkMode: true,
              surfaceColor: const Color(0xFF1E293B),
              borderColor: const Color(0xFF334155),
              textColor: Colors.white,
              subtitleColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('Viewer Gender Distribution'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('User specified / Other'), findsOneWidget);
    });

    testWidgets('buildAudienceViewerLoyaltyAndSettingCard renders loyalty & urban/rural stats', (tester) async {
      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));
      ctrl.returningViewers.value = 1000;
      ctrl.totalUniqueViewers.value = 2000;

      await tester.pumpWidget(
        createHarness(
          Obx(
            () => buildAudienceViewerLoyaltyAndSettingCard(
              controller: ctrl,
              isDarkMode: true,
              surfaceColor: const Color(0xFF1E293B),
              borderColor: const Color(0xFF334155),
              textColor: Colors.white,
              subtitleColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text('Audience Loyalty & Reach Setting'), findsOneWidget);
      expect(find.text('New Viewers vs Returning Viewers'), findsOneWidget);
      expect(find.text('Urban vs Rural Reach'), findsOneWidget);
    });

    testWidgets('buildAudienceSearchBar and country card render geographic filters', (tester) async {
      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));
      final countryItem = CountryAudienceItem(
        countryCode: 'IN',
        countryName: 'India',
        viewers: 50000,
        subscribers: 12000,
        viewerPercentage: 65.0,
        subscriberPercentage: 60.0,
      );

      await tester.pumpWidget(
        createHarness(
          Column(
            children: [
              buildAudienceSearchBar(
                controller: ctrl,
                surfaceColor: const Color(0xFF1E293B),
                borderColor: const Color(0xFF334155),
                textColor: Colors.white,
                subtitleColor: Colors.grey,
              ),
              buildAudienceCountryCard(
                item: countryItem,
                isDarkMode: true,
                surfaceColor: const Color(0xFF1E293B),
                borderColor: const Color(0xFF334155),
                textColor: Colors.white,
                subtitleColor: Colors.grey,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('India'), findsOneWidget);
      expect(find.text('IN'), findsOneWidget);
      expect(find.text('Country Viewers'), findsOneWidget);
      expect(find.text('Mapped Subscribers'), findsOneWidget);
    });

    testWidgets('AudiencePage coordinator renders successfully', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ctrl = Get.put(AudienceController(initialChannelId: 'ch_test_1'));
      ctrl.rxState.value = ViewState.idle;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const AudiencePage(
            channelId: 'ch_test_1',
            isDarkMode: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AudiencePage), findsOneWidget);
      expect(find.text('Audience Geography & Insights'), findsOneWidget);
    });
  });
}
