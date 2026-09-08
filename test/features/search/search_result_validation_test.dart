import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/search/data/models/search_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

// ignore: subtype_of_sealed_class
class _FakeDocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this.id, this._data);
  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;
}

void main() {
  group('SearchResult Validation Tests', () {
    test('Should reject mock/placeholder playlist with 0 videos or default title', () {
      final doc = _FakeDocSnapshot('mock_playlist_1', {
        'name': 'Playlist',
        'videoCount': 0,
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc, type: ResultType.playlist);
      expect(result.isValid, isFalse);
      expect(result.views, 0);
    });

    test('Should reject playlist with 0 videos even if title is set', () {
      final doc = _FakeDocSnapshot('empty_playlist', {
        'name': 'My Favorite Songs',
        'videoCount': 0,
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc, type: ResultType.playlist);
      expect(result.isValid, isFalse);
    });

    test('Should accept valid playlist with at least 1 video', () {
      final doc = _FakeDocSnapshot('valid_playlist', {
        'name': 'Flutter Masterclass',
        'videoCount': 5,
        'creatorName': 'Flutter Team',
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc, type: ResultType.playlist);
      expect(result.isValid, isTrue);
      expect(result.title, 'Flutter Masterclass');
      expect(result.views, 5);
      expect(result.channelName, 'Flutter Team');
    });

    test('Should reject mock/placeholder topic with 0 videos or default title', () {
      final doc = _FakeDocSnapshot('mock_topic_1', {
        'title': 'Topic',
        'slug': 'topic',
        'videoCount': 0,
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc, type: ResultType.topic);
      expect(result.isValid, isFalse);
    });

    test('Should reject topic with 0 videos even if title is valid', () {
      final doc = _FakeDocSnapshot('empty_topic', {
        'title': 'Quantum Computing',
        'slug': 'quantum-computing',
        'videoCount': 0,
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc, type: ResultType.topic);
      expect(result.isValid, isFalse);
    });

    test('Should accept valid topic with at least 1 video', () {
      final doc = _FakeDocSnapshot('valid_topic', {
        'title': 'Lets Deep Dive to Indian Market',
        'slug': 'business-in-india',
        'handle': 'T/business_in_india',
        'videoCount': 2,
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc, type: ResultType.topic);
      expect(result.isValid, isTrue);
      expect(result.title, 'Lets Deep Dive to Indian Market');
      expect(result.views, 2);
      expect(result.channelName, 'T/business_in_india');
    });

    test('Should reject video with untitled/uploading draft status', () {
      final doc = _FakeDocSnapshot('draft_video', {
        'title': 'Untitled Draft',
        'createdAt': Timestamp.now(),
      });

      final result = SearchResult.fromFirestore(doc);
      expect(result.isValid, isFalse);
    });
  });

  group('PlaylistModel Validation Tests', () {
    test('Should reject empty playlist with 0 videos', () {
      final playlist = PlaylistModel(
        id: 'p1',
        ownerId: 'u1',
        channelId: 'c1',
        name: 'Playlist',
      );

      expect(playlist.isValidPlaylist, isFalse);
    });

    test('Should accept valid public playlist with videos', () {
      final playlist = PlaylistModel(
        id: 'p2',
        ownerId: 'u1',
        channelId: 'c1',
        name: 'Best Documentaries 2026',
        videoCount: 3,
        status: 'active',
        visibility: PlaylistVisibility.public,
      );

      expect(playlist.isValidPlaylist, isTrue);
    });
  });

  group('SearchCache Hit Rate & Eviction Tests', () {
    test('Should accurately calculate hitRate on repeated queries', () {
      final cache = SearchCache();
      expect(cache.getStats()['hitRate'], equals(0.0));

      final sample = [
        SearchResult(
          id: 'v1',
          title: 'Truth in Tech',
          thumbnail: 'https://example.com/thumb.jpg',
          views: 100,
          channelName: 'Tech Channel',
          channelImage: 'https://example.com/channel.jpg',
          createdAt: Timestamp.now(),
        ),
      ];

      // Miss
      expect(cache.get('truth'), isNull);
      expect(cache.getStats()['totalRequests'], equals(1));
      expect(cache.getStats()['totalHits'], equals(0));
      expect(cache.getStats()['hitRate'], equals(0.0));

      // Put
      cache.put('truth', sample);

      // Hit
      final hit = cache.get('truth');
      expect(hit, isNotNull);
      expect(hit!.length, equals(1));
      expect(cache.getStats()['totalRequests'], equals(2));
      expect(cache.getStats()['totalHits'], equals(1));
      expect(cache.getStats()['hitRate'], equals(0.5));

      // Another hit -> 2/3 = 0.666...
      cache.get('truth');
      expect(cache.getStats()['totalRequests'], equals(3));
      expect(cache.getStats()['totalHits'], equals(2));
      expect(cache.getStats()['hitRate'], closeTo(0.666, 0.01));

      // Clear
      cache.clear();
      expect(cache.getStats()['totalRequests'], equals(0));
      expect(cache.getStats()['hitRate'], equals(0.0));
    });
  });
}
