import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/constants/app_categories.dart';

void main() {
  group('AppCategories Unified 31 Categories Test', () {
    test('Has exactly 10 Fact-checking & 21 General categories', () {
      expect(AppCategories.factCheckingCategories.length, 10);
      expect(AppCategories.generalCategories.length, 21);
      expect(AppCategories.allCategories.length, 31);
    });

    test('All 31 categories are in exact defined order', () {
      const expectedCategories = [
        // 10 Fact-checking & High-credibility
        'Business',
        'History',
        'News',
        'Education',
        'Science',
        'Technology',
        'Finance',
        'Health',
        'Documentary',
        'Fitness',
        // 21 General, Entertainment & Lifestyle
        'Music',
        'Entertainment',
        'Sports',
        'Lifestyle',
        'Travel',
        'Food',
        'Fashion',
        'Comedy',
        'Art',
        'Animation',
        'Automotive',
        'Pets & Animals',
        'DIY & How-to',
        'Nature',
        'Spirituality',
        'People & Blogs',
        'Kids & Family',
        'Movies',
        'TV Shows',
        'Vlogs',
        'Other',
      ];

      expect(AppCategories.allCategories, expectedCategories);
    });

    test('Every category has a valid icon, image URL, and description', () {
      for (final cat in AppCategories.allCategories) {
        final icon = AppCategories.getIcon(cat);
        expect(icon, isNotNull);

        final iconStr = AppCategories.getIconString(cat);
        expect(iconStr, isNotEmpty);

        final img = AppCategories.getImageUrl(cat);
        expect(img, startsWith('https://images.unsplash.com/'));

        final desc = AppCategories.getDescription(cat);
        expect(desc, isNotEmpty);

        final channelCount = AppCategories.getChannelCount(cat);
        // Zero Mock Data Policy: Never return hardcoded mock channel counts
        expect(channelCount, isEmpty);
      }
    });

    test('Fact-checking relevance is true only for the 10 credibility categories', () {
      for (final cat in AppCategories.factCheckingCategories) {
        expect(
          AppCategories.isFactCheckRelevant(cat),
          isTrue,
          reason: '$cat should be fact-check relevant',
        );
      }

      for (final cat in AppCategories.generalCategories) {
        expect(
          AppCategories.isFactCheckRelevant(cat),
          isFalse,
          reason: '$cat should NOT be fact-check relevant',
        );
      }
    });

    test('Normalizes legacy and variant names accurately', () {
      expect(AppCategories.normalizeCategory('News & Politics'), 'News');
      expect(AppCategories.normalizeCategory('Technology & Science'), 'Technology');
      expect(AppCategories.normalizeCategory('Business & Finance'), 'Business');
      expect(AppCategories.normalizeCategory('Health & Wellness'), 'Health');
      expect(AppCategories.normalizeCategory('Food & Cooking'), 'Food');
      expect(AppCategories.normalizeCategory('Fashion & Beauty'), 'Fashion');
      expect(AppCategories.normalizeCategory('Animals & Pets'), 'Pets & Animals');
      expect(AppCategories.normalizeCategory('Nature & Wildlife'), 'Nature');
      expect(AppCategories.normalizeCategory('DIY'), 'DIY & How-to');
      expect(AppCategories.normalizeCategory('General'), 'Other');
    });
  });
}
