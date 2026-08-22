import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';

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
  });

  group('Home category tabs visibility', () {
    test('signed-out user should NOT see Subscriptions tab after All', () {
      final categories = HomeDiscoveryController.getFixedCategories(
        isAuthenticated: false,
      );

      expect(categories, isNot(contains('Subscriptions')));
      expect(categories.first, equals('All'));
      expect(categories[1], isNot(equals('Subscriptions')));
    });

    test('signed-in user should see Subscriptions tab right after All', () {
      final categories = HomeDiscoveryController.getFixedCategories(
        isAuthenticated: true,
      );

      expect(categories, contains('Subscriptions'));
      expect(categories[0], equals('All'));
      expect(categories[1], equals('Subscriptions'));
    });
  });
}

