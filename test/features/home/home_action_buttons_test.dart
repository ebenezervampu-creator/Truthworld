import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_bottom_navigation.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_featured_banner.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_barrel.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import '../../test_helpers/mock_firebase.dart';

class _MockHomeController extends GetxController implements HomeController {
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
  final RxInt sideNavSelectedIndex = 0.obs;

  @override
  final RxInt bottomNavSelectedIndex = 0.obs;

  @override
  final RxBool isLoadingAuth = false.obs;

  @override
  final RxList<String> availableCategories = <String>['All', 'Trending'].obs;

  @override
  final RxString selectedCategory = 'All'.obs;

  @override
  final ScrollController scrollController = ScrollController();

  @override
  void navigateToYourChannel() {}

  @override
  Future<void> navigateToWatchLater() async {}

  @override
  void onSideNavItemSelect(int index) {
    sideNavSelectedIndex.value = index;
  }

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

  group('Home Action Buttons Audit Tests', () {
    testWidgets('BannerFollowButton displays add icon when not followed', (
      tester,
    ) async {
      final followingCtrl = Get.put(FollowingTopicsController());
      final topic = Topic(
        id: 'topic_tech',
        name: 'Technology',
        handle: '@technology',
        handleLowercase: '@technology',
        description: 'Technology topic description',
        category: 'Technology',
        slug: 'technology',
        videoCount: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BannerFollowButton(topic: topic),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Follow'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      // Simulate followed state
      followingCtrl.followingStates['topic_tech'] = true;
      await tester.pump();

      expect(find.text('Following'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('NavRailPersonalSection highlights Watch later when selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = _MockHomeController();
      AuthService.to.isAuthenticated.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NavRailPersonalSection(
                selectedIndex: HomeController.indexWatchLater,
                isCompact: false,
                currentUser: null,
                homeController: controller,
                onSelectItem: (_) {},
                onShowSignInSnackbar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final watchLaterItem = tester.widget<NavRailItem>(
        find.widgetWithText(NavRailItem, 'Watch later'),
      );
      expect(watchLaterItem.isSelected, isTrue);
    });

    testWidgets('NavRailActionHandler handles indexDownloads cleanly', (
      tester,
    ) async {
      var selected = -1;

      NavRailActionHandler.handleNavItemTap(
        context: tester.binding.rootElement!,
        index: HomeController.indexDownloads,
        route: '/downloads',
        requiresAuth: false,
        currentUser: null,
        onSelectItem: (idx) => selected = idx,
        onShowSignInSnackbar: () {},
      );

      expect(selected, HomeController.indexDownloads);
    });

    testWidgets('HomeBottomNavigation renders anonymous account icon', (
      tester,
    ) async {
      final controller = _MockHomeController();
      AuthService.to.isAuthenticated.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigation(
              homeController: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    });
  });
}
