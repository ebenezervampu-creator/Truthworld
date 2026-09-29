import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';

void main() {
  group('VoiceSearchState and UX Tests', () {
    test('VoiceSearchState contains all expected voice search states', () {
      expect(VoiceSearchState.values, contains(VoiceSearchState.initializing));
      expect(VoiceSearchState.values, contains(VoiceSearchState.listening));
      expect(VoiceSearchState.values, contains(VoiceSearchState.recognized));
      expect(VoiceSearchState.values, contains(VoiceSearchState.submitting));
      expect(VoiceSearchState.values, contains(VoiceSearchState.unrecognized));
      expect(VoiceSearchState.values, contains(VoiceSearchState.permissionDenied));
      expect(VoiceSearchState.values, contains(VoiceSearchState.error));
    });

    test('VoiceSearchController.sanitizeQuery removes trailing punctuation like Hike.', () {
      expect(VoiceSearchController.sanitizeQuery('Hike.'), equals('Hike'));
      expect(VoiceSearchController.sanitizeQuery('Hike!'), equals('Hike'));
      expect(VoiceSearchController.sanitizeQuery('Hike?'), equals('Hike'));
      expect(VoiceSearchController.sanitizeQuery('  hike...  '), equals('hike'));
      expect(VoiceSearchController.sanitizeQuery('Flutter Tutorial.'), equals('Flutter Tutorial'));
    });

    test('SearchService.sanitizeQuery and extractTokens handle trailing punctuation', () {
      expect(SearchService.sanitizeQuery('Hike.'), equals('hike'));
      expect(SearchService.extractTokens('Hike.'), equals(['hike']));
      expect(SearchService.extractTokens('Hike a social media platform.'), equals(['hike', 'a', 'social', 'media', 'platform']));
    });

    test('VoiceSearchDialog widget can be instantiated with callback', () {
      String? searchedQuery;
      final dialog = VoiceSearchDialog(
        onSearch: (query) {
          searchedQuery = query;
        },
      );
      expect(dialog.onSearch, isNotNull);
      dialog.onSearch('Flutter test query');
      expect(searchedQuery, equals('Flutter test query'));
    });
  });
}
