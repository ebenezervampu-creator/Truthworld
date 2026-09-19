import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';

void main() {
  group('IsolateComputeUtils Tests', () {
    test('parseJsonMapAsync handles empty and small payloads', () async {
      final emptyResult = await IsolateComputeUtils.parseJsonMapAsync('');
      expect(emptyResult, isEmpty);

      const smallJson = '{"trustScore": 85, "summary": "Verified true statement"}';
      final smallResult = await IsolateComputeUtils.parseJsonMapAsync(smallJson);
      expect(smallResult['trustScore'], equals(85));
      expect(smallResult['summary'], equals('Verified true statement'));
    });

    test('parseJsonMapAsync handles large payloads (> 2KB) in worker isolate', () async {
      // Build a large JSON payload > 2KB
      final buffer = StringBuffer('{"items":[');
      for (var i = 0; i < 100; i++) {
        buffer.write('{"id":$i,"title":"Claim #$i with detailed verification metadata","verified":true}');
        if (i < 99) buffer.write(',');
      }
      buffer.write(']}');

      final largeJson = buffer.toString();
      expect(largeJson.length, greaterThan(2048));

      final result = await IsolateComputeUtils.parseJsonMapAsync(largeJson);
      expect(result['items'], isA<List>());
      expect((result['items'] as List).length, equals(100));
      expect((result['items'] as List)[0]['id'], equals(0));
      expect((result['items'] as List)[99]['id'], equals(99));
    });

    test('parseSubtitlesAsync parses SRT content off UI thread', () async {
      const srt = '''
1
00:00:01,000 --> 00:00:03,500
Hello and welcome to TruthWorld.

2
00:00:04,000 --> 00:00:07,000
We provide AI-powered fact checking.
''';

      final segments = await IsolateComputeUtils.parseSubtitlesAsync(srt);
      expect(segments.length, equals(2));
      expect(segments[0].text, contains('Hello and welcome to TruthWorld'));
      expect(segments[0].start.inMilliseconds, equals(1000));
      expect(segments[0].end.inMilliseconds, equals(3500));
      expect(segments[1].text, contains('We provide AI-powered fact checking'));
      expect(segments[1].start.inMilliseconds, equals(4000));
      expect(segments[1].end.inMilliseconds, equals(7000));
    });

    test('parseSubtitlesAsync handles empty and invalid content gracefully', () async {
      final empty = await IsolateComputeUtils.parseSubtitlesAsync('');
      expect(empty, isEmpty);
    });
  });
}
