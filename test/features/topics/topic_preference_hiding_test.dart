import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
  });

  group('Topic Preference Hiding and Filtering Tests', () {
    late UserPreferencesService service;

    final topicA = Topic(
      id: 'topic_123',
      name: 'Artificial Intelligence',
      title: 'Artificial Intelligence',
      slug: 'artificial-intelligence',
      handle: 'T/artificial-intelligence',
      handleLowercase: 't/artificial-intelligence',
      description: 'AI and Machine Learning updates',
      category: 'Technology',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      videoCount: 5,
    );

    final topicB = Topic(
      id: 'topic_456',
      name: 'Quantum Computing',
      title: 'Quantum Computing',
      slug: 'quantum-computing',
      handle: 'T/quantum-computing',
      handleLowercase: 't/quantum-computing',
      description: 'Quantum tech and advancements',
      category: 'Science',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      videoCount: 3,
    );

    setUp(() {
      Get.reset();
      service = Get.put(UserPreferencesService());
      service.hiddenTopicIds.clear();
    });

    tearDown(Get.reset);

    test('1. Topics are visible by default', () {
      expect(service.isTopicBlocked(topicA), isFalse);
      expect(service.isTopicBlocked(topicB), isFalse);
      final filtered = service.filterTopics([topicA, topicB]);
      expect(filtered.length, equals(2));
    });

    test('2. Hiding topic removes it from filterTopics by id, slug, and canonicalKey', () async {
      await service.hideTopic(
        topicA.id,
        topicSlug: topicA.slug,
        topicName: topicA.name,
        canonicalKey: topicA.canonicalKey,
      );

      expect(service.isTopicBlocked(topicA), isTrue);
      expect(service.isTopicBlocked(topicB), isFalse);

      final filtered = service.filterTopics([topicA, topicB]);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals(topicB.id));
    });

    test('3. Hiding topic is case-insensitive', () async {
      await service.hideTopic(
        'TOPIC_123',
        topicSlug: 'ARTIFICIAL-INTELLIGENCE',
      );

      expect(service.isTopicBlocked(topicA), isTrue);
      final filtered = service.filterTopics([topicA, topicB]);
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals(topicB.id));
    });

    test('4. Unhiding topic restores it in filterTopics', () async {
      await service.hideTopic(
        topicA.id,
        topicSlug: topicA.slug,
        topicName: topicA.name,
        canonicalKey: topicA.canonicalKey,
      );
      expect(service.isTopicBlocked(topicA), isTrue);

      await service.unhideTopic(
        topicA.id,
        topicSlug: topicA.slug,
        topicName: topicA.name,
        canonicalKey: topicA.canonicalKey,
      );
      expect(service.isTopicBlocked(topicA), isFalse);

      final filtered = service.filterTopics([topicA, topicB]);
      expect(filtered.length, equals(2));
    });
  });
}
