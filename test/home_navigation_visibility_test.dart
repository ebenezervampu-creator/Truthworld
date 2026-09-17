import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_navigation_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'test_helpers/mock_firebase.dart';

void main() {
  group('Home sidebar visibility', () {
    test('signed-out user should only see public tabs', () {
      final items = HomeSidebarVisibility.getVisibleEntries(
        isAuthenticated: false,
      );

      expect(items, isNot(contains('Subscriptions')));
      expect(items, isNot(contains('Your channel')));
      expect(items, isNot(contains('History')));
      expect(items, isNot(contains('You')));
    });

    test('signed-in user should see Subscriptions and user tabs', () {
      final items = HomeSidebarVisibility.getVisibleEntries(
        isAuthenticated: true,
      );

      expect(items, contains('Subscriptions'));
      expect(items, contains('Your channel'));
      expect(items, contains('History'));
    });

    test('should include Advertiser Portal after Admin Portal for all users', () {
      final publicItems = HomeSidebarVisibility.getVisibleEntries(
        isAuthenticated: false,
      );
      final adminIndex = publicItems.indexOf('Admin Portal');
      final advertiserIndex = publicItems.indexOf('Advertiser Portal');

      expect(adminIndex, isNot(equals(-1)));
      expect(advertiserIndex, isNot(equals(-1)));
      expect(advertiserIndex, equals(adminIndex + 1));
    });
  });

  group('Home category tabs visibility', () {
    test('signed-out user should only see public category tabs (All, Trending, New, Popular)', () {
      final loggedOutCategories = HomeDiscoveryController.getFixedCategories(
        isAuthenticated: false,
      );

      expect(loggedOutCategories, isNot(contains('Subscriptions')));
      expect(loggedOutCategories, isNot(contains('Posts')));
      expect(loggedOutCategories, isNot(contains('Flip Coin')));
      expect(loggedOutCategories, isNot(contains('Unexplored')));
      expect(loggedOutCategories, equals(['All', 'Trending', 'New', 'Popular']));
    });

    test('signed-in user should see Subscriptions after All, and Posts after Popular', () {
      final loggedInCategories = HomeDiscoveryController.getFixedCategories(
        
      );

      expect(loggedInCategories, contains('Subscriptions'));
      expect(loggedInCategories, contains('Posts'));
      expect(loggedInCategories, contains('Unexplored'));
      expect(loggedInCategories, contains('Flip Coin'));
      expect(loggedInCategories[0], equals('All'));
      expect(loggedInCategories[1], equals('Subscriptions'));
      expect(loggedInCategories.last, equals('Posts'));
      expect(loggedInCategories, equals([
        'All',
        'Subscriptions',
        'Unexplored',
        'Trending',
        'Flip Coin',
        'New',
        'Popular',
        'Posts',
      ]));
    });

    test('Flip Coin is positioned before New and has no emoji prefix for signed-in user', () {
      final categories = HomeDiscoveryController.getFixedCategories(
        
      );

      final flipCoinIndex = categories.indexOf('Flip Coin');
      final newIndex = categories.indexOf('New');

      expect(flipCoinIndex, isNot(equals(-1)));
      expect(newIndex, isNot(equals(-1)));
      expect(flipCoinIndex, lessThan(newIndex));
      expect(categories, isNot(contains('🪙 Flip Coin')));
      expect(categories, isNot(contains('🔥 Trending')));
      expect(categories, isNot(contains('✨ New')));
      expect(categories, isNot(contains('⭐ Popular')));
    });
  });

  group('HomeNavigationController TabController safety', () {
    setUpAll(() async {
      await setupMockFirebase();
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthService>(AuthService());
    });

    tearDown(Get.reset);

    test('syncTabToCategory, onTabChanged, reinitializeTabController are safe when disposed', () {
      final nav = Get.put(HomeNavigationController());
      expect(nav.tabController, isNotNull);

      // Simulate controller disposal
      nav.onClose();

      // Ensure calling syncTabToCategory or onTabChanged after disposal does not throw
      expect(() => nav.syncTabToCategory('All'), returnsNormally);
      expect(() => nav.onTabChanged(0), returnsNormally);
      expect(nav.reinitializeTabController, returnsNormally);
    });
  });
}

