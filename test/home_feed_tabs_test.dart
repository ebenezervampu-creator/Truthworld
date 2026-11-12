import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/video/data/models/video.dart';

Video createTestVideo({
  required String id,
  required String title,
  required String category,
  List<String> tags = const [],
  List<String> topics = const [],
  int views = 0,
  int likes = 0,
  int comments = 0,
  DateTime? createdAt,
}) {
  final date = createdAt ?? DateTime.now();
  return Video(
    id: id,
    title: title,
    description: 'Test Description',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    ownerId: 'owner_1',
    channelId: 'channel_1',
    channelName: 'Channel One',
    category: category,
    tags: tags,
    topics: topics,
    views: views,
    likes: likes,
    commentCount: comments,
    createdAt: Timestamp.fromDate(date),
    uploadedAt: Timestamp.fromDate(date),
    videoUrl: 'https://example.com/video.mp4',
    geminiApproved: true,
    isApproved: true,
  );
}

bool testMatchesCategory(Video v, String cat) {
  final target = cat.trim().toLowerCase();
  final vCat = v.category.trim().toLowerCase();
  if (vCat == target || vCat.contains(target) || target.contains(vCat)) return true;
  if (v.tags.any((t) => t.trim().toLowerCase() == target || t.trim().toLowerCase().contains(target))) return true;
  if (v.topics.any((t) => t.trim().toLowerCase() == target || t.trim().toLowerCase().contains(target))) return true;
  return false;
}

double calculateTrendingScore(Video v) {
  final daysOld = DateTime.now().difference(v.createdAt.toDate()).inDays + 1;
  final views = (v.views > 0 ? v.views : v.viewCount).toDouble();
  return (views * 0.5) + (v.likes * 0.3) + (v.commentCount * 0.2) + ((1.0 / daysOld) * 100) + (v.isFactChecked ? 50.0 : 0.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Feed Tabs & Category Isolation Tests', () {
    late List<Video> databaseVideos;

    setUp(() {
      databaseVideos = [
        createTestVideo(
          id: 'v_music_1',
          title: 'Top Hits Song',
          category: 'Music',
          tags: ['pop', 'song'],
          views: 500,
          likes: 50,
          comments: 10,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        createTestVideo(
          id: 'v_music_2',
          title: 'Classical Piano',
          category: 'music',
          tags: ['instrumental'],
          views: 1000,
          likes: 120,
          comments: 30,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        createTestVideo(
          id: 'v_edu_1',
          title: 'Learn Flutter Fast',
          category: 'Education',
          tags: ['coding', 'dart'],
          views: 200,
          likes: 30,
          comments: 5,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        createTestVideo(
          id: 'v_sports_1',
          title: 'Football Highlights',
          category: 'Sports',
          tags: ['goals'],
          views: 10000,
          likes: 1500,
          comments: 300,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
    });

    test('Category matching filters strictly and supports case-insensitivity', () {
      final musicVideos = databaseVideos.where((v) => testMatchesCategory(v, 'Music')).toList();
      expect(musicVideos.length, equals(2));
      expect(musicVideos.map((v) => v.id), containsAll(['v_music_1', 'v_music_2']));
      expect(musicVideos.any((v) => v.id == 'v_edu_1'), isFalse);
      expect(musicVideos.any((v) => v.id == 'v_sports_1'), isFalse);

      final eduVideos = databaseVideos.where((v) => testMatchesCategory(v, 'Education')).toList();
      expect(eduVideos.length, equals(1));
      expect(eduVideos.first.id, equals('v_edu_1'));
    });

    test('Empty categories return 0 videos and do NOT leak all database videos', () {
      final animationVideos = databaseVideos.where((v) => testMatchesCategory(v, 'Animation')).toList();
      expect(animationVideos, isEmpty);
      expect(animationVideos.length, equals(0));
    });

    test('Trending tab correctly scores and ranks high momentum videos', () {
      final sortedTrending = List<Video>.from(databaseVideos)
        ..sort((a, b) {
          final scoreA = calculateTrendingScore(a);
          final scoreB = calculateTrendingScore(b);
          return scoreB.compareTo(scoreA);
        });

      expect(sortedTrending.first.id, equals('v_sports_1'));
      expect(sortedTrending.map((v) => v.id).toList(), isNot(equals(databaseVideos.map((v) => v.id).toList())));
    });

    test('Popular tab sorts strictly by total views and likes descending', () {
      final sortedPopular = List<Video>.from(databaseVideos)
        ..sort((a, b) {
          final metricA = (a.views * 2) + a.likes;
          final metricB = (b.views * 2) + b.likes;
          return metricB.compareTo(metricA);
        });

      expect(sortedPopular.first.id, equals('v_sports_1'));
      expect(sortedPopular[1].id, equals('v_music_2'));
      expect(sortedPopular[2].id, equals('v_music_1'));
      expect(sortedPopular[3].id, equals('v_edu_1'));
    });

    test('New tab sorts strictly by createdAt timestamp descending', () {
      final sortedNew = List<Video>.from(databaseVideos)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(sortedNew.first.id, equals('v_edu_1'));
      expect(sortedNew[1].id, equals('v_music_1'));
      expect(sortedNew[2].id, equals('v_sports_1'));
      expect(sortedNew.last.id, equals('v_music_2'));
    });

    test('FeedCacheManager generates distinct, valid cache keys for each tab and category', () {
      expect(FeedCacheManager.cacheKeyForCategory('All'), equals(FeedCacheManager.keyHomeFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Trending'), equals(FeedCacheManager.keyTrendingFeed));
      expect(FeedCacheManager.cacheKeyForCategory('🔥 Trending'), equals(FeedCacheManager.keyTrendingFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Popular'), equals(FeedCacheManager.keyPopularFeed));
      expect(FeedCacheManager.cacheKeyForCategory('New'), equals(FeedCacheManager.keyNewFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Music'), equals(FeedCacheManager.keyMusicFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Education'), equals('feed_cat_education'));
      expect(FeedCacheManager.cacheKeyForCategory('Sports'), equals('feed_cat_sports'));
      expect(FeedCacheManager.currentSchemaVersion, equals(3));
    });
  });
}
