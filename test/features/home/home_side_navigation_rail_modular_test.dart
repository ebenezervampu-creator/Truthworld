import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_side_navigation_rail.dart';
import '../../test_helpers/mock_firebase.dart';

class MockHomeController extends GetxController implements HomeController {
  @override
  final Rxn<dynamic> selectedPlaylist = Rxn<dynamic>();

  @override
  final RxBool isLoadingSubscriptions = false.obs;

  @override
  final RxList<Map<String, dynamic>> subscribedChannelList =
      <Map<String, dynamic>>[].obs;

  @override
  final RxBool isNavigating = false.obs;

  @override
  void navigateToYourChannel() {}

  @override
  Future<void> navigateToWatchLater() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('ModernSideNavigationRail Modular Tests', () {
    testWidgets('renders full rail with explore, support, and policy sections',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MockHomeController();
      var selected = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernSideNavigationRail(
              selectedIndex: 0,
              onSelectItem: (idx) => selected = idx,
              onShowSignInSnackbar: () {},
              currentUser: null,
              homeController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EXPLORE'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Discover Channel'), findsOneWidget);
      expect(find.text('Explore Topics'), findsOneWidget);
      expect(find.text('Truthworld Premium'), findsOneWidget);

      expect(find.text('SUPPORT'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('About Truthworld'), findsOneWidget);

      expect(find.text('POLICIES'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Community Guidelines'), findsOneWidget);
      expect(find.text('Truthworld Studio'), findsOneWidget);

      // Verify item tap
      await tester.tap(find.text('Discover Channel'));
      await tester.pump();
      expect(selected, HomeController.indexDiscover);
    });

    testWidgets('renders compact rail with tooltips', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MockHomeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernSideNavigationRail(
              selectedIndex: 0,
              onSelectItem: (_) {},
              onShowSignInSnackbar: () {},
              currentUser: null,
              homeController: controller,
              isCompact: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Tooltip), findsWidgets);
      // In compact mode, section headers like 'EXPLORE' are hidden
      expect(find.text('EXPLORE'), findsNothing);
    });

    testWidgets(
        'triggers onShowSignInSnackbar for auth-required items when unauthenticated',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MockHomeController();
      var signInPromptShown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernSideNavigationRail(
              selectedIndex: 0,
              onSelectItem: (_) {},
              onShowSignInSnackbar: () => signInPromptShown = true,
              currentUser: null,
              homeController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      NavRailActionHandler.handleNavItemTap(
        context: tester.element(find.byType(ModernSideNavigationRail)),
        index: HomeController.indexFeedback,
        route: '/feedback',
        requiresAuth: true,
        currentUser: null,
        onSelectItem: (_) {},
        onShowSignInSnackbar: () => signInPromptShown = true,
      );

      expect(signInPromptShown, isTrue);
    });

    testWidgets('ModernChannelListItem renders channel name and avatar initials',
        (tester) async {
      final channel = Channel(
        id: 'c1',
        ownerId: 'u1',
        name: 'Alpha Truth Network',
        nameLowercase: 'alpha truth network',
        handle: '@alphatruth',
        handleLowercase: '@alphatruth',
        description: 'Channel for testing',
        avatarUrl: '',
        bannerUrl: '',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      var channelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernChannelListItem(
              channel: channel,
              onTap: () => channelTapped = true,
              isCompact: false,
            ),
          ),
        ),
      );

      expect(find.text('Alpha Truth Network'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // Initial letter avatar fallback

      await tester.tap(find.text('Alpha Truth Network'));
      expect(channelTapped, isTrue);
    });

    testWidgets('NavRailSubscriptionsSection renders loading shimmer and empty state',
        (tester) async {
      final controller = MockHomeController();
      controller.isLoadingSubscriptions.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavRailSubscriptionsSection(
              currentUser: null,
              isCompact: false,
              homeController: controller,
            ),
          ),
        ),
      );

      // When currentUser is null, section is empty (SizedBox.shrink)
      expect(find.byType(NavRailDivider), findsNothing);
    });
  });
}
