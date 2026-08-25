// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

class FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  FakeDocumentSnapshot(this.id, this._data);
  final Map<String, dynamic> _data;
  @override
  final String id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;
}

void main() {
  group('Topic Validation & Safe Routing Tests', () {
    test('Should flag empty/corrupt topic document as invalid', () {
      final doc = FakeDocumentSnapshot('empty_topic_1', {
        'status': 'active',
        // missing slug, title, handle
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.isValidTopic, isFalse);
      expect(topic.title, isEmpty);
      expect(topic.slug, isEmpty);
      expect(topic.topicRoute, '/explore-topics');
    });

    test('Should flag mock "Featured Topic" or "Topic" as invalid', () {
      final doc = FakeDocumentSnapshot('mock_topic_2', {
        'title': 'Featured Topic',
        'slug': 'featured-topic',
        'status': 'active',
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.isValidTopic, isFalse);
    });

    test('Should flag inactive topic as invalid', () {
      final doc = FakeDocumentSnapshot('inactive_topic', {
        'title': 'Indian Stock Market',
        'slug': 'indian-stock-market',
        'status': 'archived',
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.isValidTopic, isFalse);
    });

    test('Should mark valid topic as valid and generate correct route', () {
      final doc = FakeDocumentSnapshot('valid_topic', {
        'title': 'Indian Stock Market',
        'slug': 'indian-stock-market',
        'handle': 'T/indian-stock-market',
        'handleLowercase': 't/indian-stock-market',
        'category': 'Finance',
        'status': 'active',
        'videoCount': 5,
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.isValidTopic, isTrue);
      expect(topic.routePathParameter, 'indian-stock-market');
      expect(topic.topicRoute, '/T/indian-stock-market');
    });

    test('Should fallback route cleanly without colliding with channel route when handle is malformed', () {
      final doc = FakeDocumentSnapshot('malformed_topic', {
        'title': '',
        'slug': '',
        'handle': 'T/',
        'status': 'active',
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.isValidTopic, isFalse);
      expect(topic.routePathParameter, isEmpty);
      expect(topic.topicRoute, '/explore-topics');
    });
  });
}
