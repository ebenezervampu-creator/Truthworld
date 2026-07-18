import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';

void main() {
  group('Home sidebar visibility', () {
    test('signed-out user should only see public tabs', () {
      final items = HomeSidebarVisibility.getVisibleEntries(isAuthenticated: false);

      expect(items, isNot(contains('Subscriptions')));
      expect(items, isNot(contains('Your channel')));
      expect(items, isNot(contains('History')));
      expect(items, isNot(contains('You')));
    });
  });
}
