import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';

void main() {
  group('SubtitleParser Tests', () {
    test('Correctly parses AssemblyAI milliseconds in the first 10 seconds without bug', () {
      final json = jsonEncode({
        'utterances': [
          {'start': 1200, 'end': 3500, 'text': 'Welcome to Truthworld!'},
          {'start': 4000, 'end': 8200, 'text': 'Today we explore media truth.'},
          {'start': 9500, 'end': 14000, 'text': 'Let us dive into the facts.'},
        ]
      });

      final segments = SubtitleParser.parse(json);
      expect(segments.length, 3);
      expect(segments[0].start, const Duration(milliseconds: 1200));
      expect(segments[0].end, const Duration(milliseconds: 3500));
      expect(segments[0].text, 'Welcome to Truthworld!');

      expect(segments[1].start, const Duration(milliseconds: 4000));
      expect(segments[1].end, const Duration(milliseconds: 8200));

      expect(segments[2].start, const Duration(milliseconds: 9500));
      expect(segments[2].end, const Duration(milliseconds: 14000));
    });

    test('Preserves exact word timestamps across long video without fast drift', () {
      final json = jsonEncode({
        'words': [
          {'start': 1200, 'end': 1500, 'text': 'At'},
          {'start': 1500, 'end': 1800, 'text': 'the'},
          {'start': 1800, 'end': 2200, 'text': 'beginning,'},
          // 58 second gap (silence/pause)
          {'start': 60000, 'end': 60400, 'text': 'One'},
          {'start': 60400, 'end': 60800, 'text': 'minute'},
          {'start': 60800, 'end': 61200, 'text': 'later.'},
          // 58 second gap
          {'start': 120000, 'end': 120400, 'text': 'Two'},
          {'start': 120400, 'end': 120800, 'text': 'minutes'},
          {'start': 120800, 'end': 121200, 'text': 'later.'},
        ]
      });

      final segments = SubtitleParser.parse(json);
      expect(segments.length, 3);

      // Cue 1 must start at 1.2s
      expect(segments[0].start, const Duration(milliseconds: 1200));
      expect(segments[0].text, 'At the beginning,');

      // Cue 2 MUST start at 60.0s (NOT drift to 5s!)
      expect(segments[1].start, const Duration(milliseconds: 60000));
      expect(segments[1].text, 'One minute later.');

      // Cue 3 MUST start at 120.0s (NOT drift to 10s!)
      expect(segments[2].start, const Duration(milliseconds: 120000));
      expect(segments[2].text, 'Two minutes later.');

      // Verify lookup at 30s is null (in silence)
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(seconds: 30)), isNull);

      // Verify lookup at 60.2s matches Cue 2
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 60200))?.text, 'One minute later.');

      // Verify lookup at 120.5s matches Cue 3
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 120500))?.text, 'Two minutes later.');
    });

    test('Splits large paragraph blocks into compact phrase cues (3-6 words, moving with video)', () {
      const longParagraph =
          "Over the last few years, millions of new retail investors have been absolutely flooding into the Indian stock market, tracking active brokerage accounts in India. By late 2023, startup Grow officially surpassed industry leader Zerodha. Crossing the 6.5 million mark, Grow surged 750% in just a couple of years, while Zeroda's customer acquisition almost entirely flattened out.";

      final json = jsonEncode({
        'utterances': [
          {'start': 0, 'end': 24000, 'text': longParagraph},
        ]
      });

      final segments = SubtitleParser.parse(json);

      // Must be split into multiple progressive cues, NOT a single 3-line wall of text
      expect(segments.length, greaterThan(8));

      // No cue should have more than 7 words
      for (final seg in segments) {
        final words = seg.text.split(RegExp(r'\s+'));
        expect(words.length, lessThanOrEqualTo(7));
      }

      // Timestamps must advance progressively
      for (var i = 0; i < segments.length - 1; i++) {
        expect(segments[i].end, lessThanOrEqualTo(segments[i + 1].end));
      }

      // First cue should start around 0ms and be short
      expect(segments[0].start, Duration.zero);
      expect(segments[0].text.contains('Over the last few years,'), true);
    });

    test('Correctly parses Whisper float seconds format throughout long video', () {
      final json = jsonEncode({
        'segments': [
          {'start': 0.5, 'end': 2.8, 'text': 'First sentence.'},
          {'start': 30.0, 'end': 34.5, 'text': 'At thirty seconds.'},
          {'start': 90.0, 'end': 95.0, 'text': 'At ninety seconds.'},
        ]
      });

      final segments = SubtitleParser.parse(json);
      expect(segments.length, 3);
      expect(segments[0].start, const Duration(milliseconds: 500));
      expect(segments[0].end, const Duration(milliseconds: 2800));

      expect(segments[1].start, const Duration(milliseconds: 30000));
      expect(segments[1].end, const Duration(milliseconds: 34500));

      expect(segments[2].start, const Duration(milliseconds: 90000));
      expect(segments[2].end, const Duration(milliseconds: 95000));
    });

    test('Correctly parses WebVTT with cue tags and HTML entities', () {
      const vtt = '''
WEBVTT

00:00.500 --> 00:03.200 align:middle line:84%
<v Host><b>Hello &amp; welcome</b> to the show!</v>

00:04.000 --> 00:07.500
<c.yellow>It&#39;s an honor to be here.</c>
''';

      final segments = SubtitleParser.parse(vtt);
      expect(segments.length, 2);
      expect(segments[0].start, const Duration(milliseconds: 500));
      expect(segments[0].end, const Duration(milliseconds: 3200));
      expect(segments[0].text, 'Hello & welcome to the show!');

      expect(segments[1].start, const Duration(milliseconds: 4000));
      expect(segments[1].end, const Duration(milliseconds: 7500));
      expect(segments[1].text, "It's an honor to be here.");
    });

    test('Correctly parses SRT format', () {
      const srt = '''
1
00:00:01,500 --> 00:00:04,200
This is line one.
This is line two.

2
00:00:05,000 --> 00:00:08,000
Second subtitle cue.
''';

      final segments = SubtitleParser.parse(srt);
      expect(segments.length, greaterThanOrEqualTo(2));
      expect(segments[0].start, const Duration(milliseconds: 1500));
      expect(segments.last.end, const Duration(milliseconds: 8000));
    });

    test('Active subtitle lookup returns a single clean cue without multi-line concatenation', () {
      final json = jsonEncode({
        'utterances': [
          {'start': 1000, 'end': 3000, 'text': 'Cue 1'},
          {'start': 3200, 'end': 5000, 'text': 'Cue 2'},
        ]
      });

      final segments = SubtitleParser.parse(json);

      // Exact inside
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 2000))?.text, 'Cue 1');

      // Inside gap tolerance (3100ms is within 100ms of Cue 1 end 3000ms)
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 3100))?.text, 'Cue 1');

      // Next cue
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 3500))?.text, 'Cue 2');

      // Outside
      expect(SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 6000)), isNull);
    });

    test('Preserves discrete Telugu SRT cues without synthetic character-ratio chopping or time drift', () {
      const teluguSrt = '''
1
00:00:10,200 --> 00:00:13,800
వివరాలు ఆ రికార్డు స్థాయి నెంబర్ల

2
00:00:14,200 --> 00:00:18,500
ఈ తేదీలను ఒక్కసారి గమనిస్తే బిడ్డింగ్

3
00:00:19,000 --> 00:00:23,400
అక్షరాల కేవలం కొద్ది రోజుల వ్యవధిలోనే
''';

      final segments = SubtitleParser.parse(teluguSrt);

      // Must NOT be chopped into pieces due to Indic multi-byte character length
      expect(segments.length, 3);

      expect(segments[0].start, const Duration(milliseconds: 10200));
      expect(segments[0].end, const Duration(milliseconds: 13800));
      expect(segments[0].text, 'వివరాలు ఆ రికార్డు స్థాయి నెంబర్ల');

      expect(segments[1].start, const Duration(milliseconds: 14200));
      expect(segments[1].end, const Duration(milliseconds: 18500));
      expect(segments[1].text, 'ఈ తేదీలను ఒక్కసారి గమనిస్తే బిడ్డింగ్');

      expect(segments[2].start, const Duration(milliseconds: 19000));
      expect(segments[2].end, const Duration(milliseconds: 23400));
      expect(segments[2].text, 'అక్షరాల కేవలం కొద్ది రోజుల వ్యవధిలోనే');

      // Exact time lookup
      expect(
        SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 12000))?.text,
        'వివరాలు ఆ రికార్డు స్థాయి నెంబర్ల',
      );
      expect(
        SubtitleParser.findActiveSubtitle(segments, const Duration(milliseconds: 16000))?.text,
        'ఈ తేదీలను ఒక్కసారి గమనిస్తే బిడ్డింగ్',
      );
    });

    test('Accurately detects RTL text for Arabic, Urdu, Hebrew across scripts', () {
      expect(SubtitleParser.isRtlText('مرحبا بكم في شبكة التحقق من الحقائق'), isTrue); // Arabic
      expect(SubtitleParser.isRtlText('یہ ایک معلوماتی ویڈیو ہے؟'), isTrue); // Urdu
      expect(SubtitleParser.isRtlText('שלום עולם'), isTrue); // Hebrew

      expect(SubtitleParser.isRtlText('Hello world'), isFalse); // English
      expect(SubtitleParser.isRtlText('వివరాలు ఆ రికార్డు స్థాయి'), isFalse); // Telugu
      expect(SubtitleParser.isRtlText('नमस्ते दुनिया।'), isFalse); // Hindi
      expect(SubtitleParser.isRtlText('欢迎来到真实世界。'), isFalse); // Chinese
    });

    test('Splits CJK ideographic text without spaces into rhythmic YouTube-style phrases', () {
      // Long Chinese unchunked transcript
      const chineseText = '在过去的几年里，数百万新的散户投资者涌入了印度股票市场，追踪活跃的经纪账户。初创公司超越了老牌行业领导者。';
      final json = jsonEncode({
        'utterances': [
          {'start': 0, 'end': 12000, 'text': chineseText},
        ]
      });

      final segments = SubtitleParser.parse(json);
      expect(segments.length, greaterThan(1));
      for (final s in segments) {
        expect(s.text.isNotEmpty, isTrue);
        expect(s.end, greaterThan(s.start));
      }
    });

    test('Correctly handles Indic danda (।) and Arabic question mark (؟) as sentence boundaries', () {
      final json = jsonEncode({
        'words': [
          {'start': 1000, 'end': 1500, 'text': 'नमस्ते'},
          {'start': 1500, 'end': 2000, 'text': 'भारत।'}, // Ends with Devanagari danda
          {'start': 2400, 'end': 2800, 'text': 'यह'},
          {'start': 2800, 'end': 3200, 'text': 'सच'},
          {'start': 3200, 'end': 3600, 'text': 'है؟'}, // Ends with Arabic question mark
        ]
      });

      final segments = SubtitleParser.parse(json);
      expect(segments.length, 2);
      expect(segments[0].text, 'नमस्ते भारत।');
      expect(segments[1].text, 'यह सच है؟');
    });
  });
}
