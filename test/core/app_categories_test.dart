import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/constants/app_categories.dart';

import 'package:truthworld/features/topics/data/models/topic_categories.dart';

void main() {
  group('AppCategories Unified 30 Categories Test', () {
    test('Has exactly 10 Fact-checking & 20 General categories', () {
      expect(AppCategories.factCheckingCategories.length, 10);
      expect(AppCategories.generalCategories.length, 20);
      expect(AppCategories.allCategories.length, 30);
    });

    test('All 30 categories are in exact defined order', () {
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
        // 20 General, Entertainment & Lifestyle
        'Music',
        'Entertainment',
        'Sports',
        'Lifestyle',
        'Travel',
        'Food',
        'Comedy',
        'Art',
        'Animation',
        'Automotive',
        'Pets & Animals',
        'DIY & How-to',
        'Nature',
        'Spirituality',
        'Kids & Family',
        'Movies',
        'TV Shows',
        'Vlogs',
        'Short Films',
        'Other',
      ];

      expect(AppCategories.allCategories, expectedCategories);
    });

    test('TopicCategoriesConfig contains exactly the 30 canonical categories (+ 1 all filter pill)', () {
      final nonAllCategories = TopicCategoriesConfig.categories.where((c) => c.id != 'all').toList();
      expect(nonAllCategories.length, 30);
      final titles = nonAllCategories.map((c) => c.title).toList();
      expect(titles, AppCategories.allCategories);
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
      expect(AppCategories.normalizeCategory('Fashion & Beauty'), 'Lifestyle');
      expect(AppCategories.normalizeCategory('Fashion'), 'Lifestyle');
      expect(AppCategories.normalizeCategory('Romance'), 'Other');
      expect(AppCategories.normalizeCategory('romantic'), 'Other');
      expect(AppCategories.normalizeCategory('Animals & Pets'), 'Pets & Animals');
      expect(AppCategories.normalizeCategory('Nature & Wildlife'), 'Nature');
      expect(AppCategories.normalizeCategory('DIY'), 'DIY & How-to');
      expect(AppCategories.normalizeCategory('Gaming'), 'Short Films');
      expect(AppCategories.normalizeCategory('shortfilms'), 'Short Films');
      expect(AppCategories.normalizeCategory('People & Blogs'), 'Vlogs');
      expect(AppCategories.normalizeCategory('people'), 'Vlogs');
      expect(AppCategories.normalizeCategory('blogs'), 'Vlogs');
      expect(AppCategories.normalizeCategory('General'), 'Other');
    });
  });
}
