import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  @override
  final String id;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;
}

void main() {
  group('Topic Timestamp Parsing Tests', () {
    test('Should parse createdAt/updatedAt correctly when they are Timestamp', () {
      final now = Timestamp.now();
      final doc = FakeDocumentSnapshot('topic_1', {
        'title': 'Test Topic',
        'slug': 'test-topic',
        'createdAt': now,
        'updatedAt': now,
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.createdAt, now.toDate());
      expect(topic.updatedAt, now.toDate());
    });

    test('Should parse createdAt/updatedAt correctly when they are int (milliseconds)', () {
      final ms = 1784343769382;
      final expectedDateTime = DateTime.fromMillisecondsSinceEpoch(ms);
      
      final doc = FakeDocumentSnapshot('topic_2', {
        'title': 'Test Topic 2',
        'slug': 'test-topic-2',
        'createdAt': ms,
        'updatedAt': ms,
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.createdAt, expectedDateTime);
      expect(topic.updatedAt, expectedDateTime);
    });

    test('Should parse createdAt/updatedAt correctly when they are int (seconds)', () {
      final seconds = 1784343769;
      final expectedDateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      
      final doc = FakeDocumentSnapshot('topic_3', {
        'title': 'Test Topic 3',
        'slug': 'test-topic-3',
        'createdAt': seconds,
        'updatedAt': seconds,
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.createdAt, expectedDateTime);
      expect(topic.updatedAt, expectedDateTime);
    });

    test('Should parse createdAt/updatedAt correctly when they are String ISO-8601', () {
      final isoStr = '2026-05-26T14:19:29.382Z';
      final expectedDateTime = DateTime.parse(isoStr);
      
      final doc = FakeDocumentSnapshot('topic_4', {
        'title': 'Test Topic 4',
        'slug': 'test-topic-4',
        'createdAt': isoStr,
        'updatedAt': isoStr,
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.createdAt, expectedDateTime);
      expect(topic.updatedAt, expectedDateTime);
    });

    test('Should fallback to current time when createdAt/updatedAt are null or missing', () {
      final doc = FakeDocumentSnapshot('topic_5', {
        'title': 'Test Topic 5',
        'slug': 'test-topic-5',
      });

      final topic = Topic.fromDocumentSnapshot(doc);
      expect(topic.createdAt, isNotNull);
      expect(topic.updatedAt, isNotNull);
      
      // Should be close to now (within 5 seconds)
      final diff = DateTime.now().difference(topic.createdAt).inSeconds.abs();
      expect(diff < 5, true);
    });
  });
}
