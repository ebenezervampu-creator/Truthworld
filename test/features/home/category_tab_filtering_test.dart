import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/features/home/presentation/controllers/feed_mixins/feed_mixins.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

Video _createTestVideo({
  required String id,
  required String category,
  List<String> tags = const [],
  List<String> topics = const [],
  String channelId = 'ch_1',
  String channelName = 'Channel 1',
}) {
  final now = DateTime.now();
  return Video(
    id: id,
    title: 'Test Video $id',
    description: 'Description',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    ownerId: 'owner_1',
    channelId: channelId,
    channelName: channelName,
    category: category,
    tags: tags,
    topics: topics,
    createdAt: Timestamp.fromDate(now),
    uploadedAt: Timestamp.fromDate(now),
    videoUrl: 'https://example.com/video.mp4',
    geminiApproved: true,
    isApproved: true,
  );
}

class _TestCategoryFeedController extends HomeFeedControllerBase
    with
        HomeFeedCachePersonalizationMixin,
        HomeFeedAlgorithmTabsMixin,
        HomeFeedCategoryTabsMixin,
        HomeFeedCommunityCarouselMixin,
        HomeFeedScrollMixin {
  @override
  late final AuthService authService =
      Get.isRegistered<AuthService>() ? Get.find<AuthService>() : AuthService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  late _TestCategoryFeedController ctrl;

  setUp(() {
    Get.reset();
    Get.put(UserPreferencesService());
    ctrl = _TestCategoryFeedController();
  });

  tearDown(Get.reset);

  group('Category Tab Strict Filtering Tests', () {
    test('Special tab "All" and empty string match any video', () {
      final v = _createTestVideo(id: 'v1', category: 'News');
      expect(ctrl.matchesCategory(v, 'All'), isTrue);
      expect(ctrl.matchesCategory(v, 'all'), isTrue);
      expect(ctrl.matchesCategory(v, ''), isTrue);
    });

    test('Exact category matches with case insensitivity', () {
      final vMusic = _createTestVideo(id: 'v1', category: 'Music');
      expect(ctrl.matchesCategory(vMusic, 'Music'), isTrue);
      expect(ctrl.matchesCategory(vMusic, 'music'), isTrue);
      expect(ctrl.matchesCategory(vMusic, 'MUSIC'), isTrue);
      expect(ctrl.matchesCategory(vMusic, '  music  '), isTrue);

      final vTech = _createTestVideo(id: 'v2', category: 'Technology');
      expect(ctrl.matchesCategory(vTech, 'Technology'), isTrue);
      expect(ctrl.matchesCategory(vTech, 'technology'), isTrue);
      expect(ctrl.matchesCategory(vTech, 'Music'), isFalse);
    });

    test('Canonical normalization maps compound/legacy categories correctly', () {
      final vFood = _createTestVideo(id: 'v1', category: 'Food & Cooking');
      expect(ctrl.matchesCategory(vFood, 'Food'), isTrue);

      final vCooking = _createTestVideo(id: 'v2', category: 'Cooking');
      expect(ctrl.matchesCategory(vCooking, 'Food'), isTrue);

      final vNews = _createTestVideo(id: 'v3', category: 'News & Politics');
      expect(ctrl.matchesCategory(vNews, 'News'), isTrue);

      final vTech = _createTestVideo(id: 'v4', category: 'Tech');
      expect(ctrl.matchesCategory(vTech, 'Technology'), isTrue);

      final vAnimals = _createTestVideo(id: 'v5', category: 'Animals');
      expect(ctrl.matchesCategory(vAnimals, 'Pets & Animals'), isTrue);

      final vPets = _createTestVideo(id: 'v6', category: 'Pets');
      expect(ctrl.matchesCategory(vPets, 'Pets & Animals'), isTrue);
    });

    test('Multi-word and normalized tags match appropriate category', () {
      final vSong = _createTestVideo(id: 'v1', category: 'Other', tags: ['rock music']);
      expect(ctrl.matchesCategory(vSong, 'Music'), isTrue);

      final vGym = _createTestVideo(id: 'v2', category: 'Other', tags: ['gym workout']);
      expect(ctrl.matchesCategory(vGym, 'Fitness'), isTrue);

      final vCoding = _createTestVideo(id: 'v3', category: 'Other', topics: ['flutter coding']);
      expect(ctrl.matchesCategory(vCoding, 'Technology'), isFalse); // "coding" is not tech unless normalized or word equals
      
      final vDirectTag = _createTestVideo(id: 'v4', category: 'Other', tags: ['music']);
      expect(ctrl.matchesCategory(vDirectTag, 'Music'), isTrue);
    });

    test('Zero Substring Bleed: prevents false positives from short tags or partial words', () {
      // "us" should NOT match "Music" (previously matched because 'music'.contains('us'))
      final vUS = _createTestVideo(id: 'v1', category: 'News', tags: ['us', 'politics']);
      expect(ctrl.matchesCategory(vUS, 'Music'), isFalse);

      // "in" should NOT match "Gaming" (previously matched because 'gaming'.contains('in'))
      final vIN = _createTestVideo(id: 'v2', category: 'News', tags: ['in', 'world']);
      expect(ctrl.matchesCategory(vIN, 'Gaming'), isFalse);

      // "to" should NOT match "Education" (previously matched because 'education'.contains('to'))
      final vTO = _createTestVideo(id: 'v3', category: 'News', tags: ['to', 'live']);
      expect(ctrl.matchesCategory(vTO, 'Education'), isFalse);

      // "on" should NOT match "Technology" (previously matched because 'technology'.contains('on'))
      final vON = _createTestVideo(id: 'v4', category: 'News', tags: ['on', 'today']);
      expect(ctrl.matchesCategory(vON, 'Technology'), isFalse);

      // "it" should NOT match "Fitness" (previously matched because 'fitness'.contains('it'))
      final vIT = _createTestVideo(id: 'v5', category: 'News', tags: ['it', 'breaking']);
      expect(ctrl.matchesCategory(vIT, 'Fitness'), isFalse);

      // Words containing 'art' should NOT match "Art" (smart, heart, party, start, part, cart)
      final vSmart = _createTestVideo(id: 'v6', category: 'News', tags: ['smart', 'heart', 'party', 'start', 'part', 'cart']);
      expect(ctrl.matchesCategory(vSmart, 'Art'), isFalse);

      // Actual 'art' tag DOES match "Art"
      final vArt = _createTestVideo(id: 'v7', category: 'News', tags: ['art']);
      expect(ctrl.matchesCategory(vArt, 'Art'), isTrue);
    });

    test('UserPreferencesService.isVideoBlocked detects blocked topics on videos', () {
      final userPrefs = UserPreferencesService.to;
      userPrefs.hiddenTopicIds.assignAll({'politics-2026', 'controversial_debate'});

      final vBlocked = _createTestVideo(
        id: 'v_blocked',
        category: 'News',
        topics: ['Politics 2026', 'Breaking News'],
      );
      expect(userPrefs.isVideoBlocked(vBlocked), isTrue);

      final vClean = _createTestVideo(
        id: 'v_clean',
        category: 'News',
        topics: ['Science Discoveries'],
      );
      expect(userPrefs.isVideoBlocked(vClean), isFalse);
    });
  });
}
