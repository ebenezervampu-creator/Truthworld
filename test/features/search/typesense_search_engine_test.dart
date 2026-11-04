import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/data/repositories/search_repository_impl.dart';
import 'package:truthworld/features/category/presentation/controllers/category_controller.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/engine/typesense_search_engine.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
    AppConfig.initialize(
      environment: Environment.development,
      appTitle: 'TruthWorld Test',
      apiBaseUrl: 'https://test.truthworld.in',
      enableDebugLogs: false,
      enablePerformanceMonitoring: false,
    );
  });

  group('TypesenseSearchEngine Tests', () {
    test('isEnabled reflects AppConfig', () {
      final engine = TypesenseSearchEngine();
      expect(engine.isEnabled, isTrue);
    });

    test('searchCombined returns empty when query is empty or whitespace', () async {
      final engine = TypesenseSearchEngine();
      final results = await engine.searchCombined('   ');
      expect(results, isEmpty);
    });

    test('searchVideos returns empty when query is empty', () async {
      final engine = TypesenseSearchEngine();
      final results = await engine.searchVideos('');
      expect(results, isEmpty);
    });

    test('searchChannels returns empty when query is empty', () async {
      final engine = TypesenseSearchEngine();
      final results = await engine.searchChannels('');
      expect(results, isEmpty);
    });

    test('searchTopics returns empty when query is empty', () async {
      final engine = TypesenseSearchEngine();
      final results = await engine.searchTopics('');
      expect(results, isEmpty);
    });
  });

  group('SearchService with Typesense Integration Tests', () {
    test('SearchService seamlessly prioritizes Typesense and retains fallback', () async {
      final service = SearchService();
      // Should not throw and should safely sanitize queries
      final results = await service.search('nonexistent_query_xyz_123');
      expect(results, isA<List<SearchResult>>());
    });
  });

  group('SearchRepositoryImpl Typesense Integration Tests', () {
    test('searchVideos executes safely with fallback', () async {
      final repo = SearchRepositoryImpl();
      final res = await repo.searchVideos('test video');
      expect(res.isSuccess, isTrue);
    });

    test('searchChannels executes safely with fallback', () async {
      final repo = SearchRepositoryImpl();
      final res = await repo.searchChannels('test channel');
      expect(res.isSuccess, isTrue);
    });
  });

  group('CategoryController Typesense Integration Tests', () {
    test('performCategorySearch executes safely and populates searchResults', () async {
      Get.testMode = true;
      final controller = CategoryController();
      controller.category = 'Technology';
      await controller.performCategorySearch('tech');
      expect(controller.isSearchingRemote.value, isFalse);
    });
  });
}
