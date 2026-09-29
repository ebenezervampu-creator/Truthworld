import 'dart:convert';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Comprehensive subtitle and transcript parser.
///
/// Features:
/// - Supports JSON (AssemblyAI, Whisper, standard transcript JSON, Firestore maps),
///   SRT, WebVTT (with cue tags and settings), and plain text fallbacks.
/// - Dynamic phrase chunking: Groups word streams with exact acoustic
///   timestamps into natural, rhythmic 3–6 word phrase segments split on punctuation,
///   commas, and speech pauses.
/// - Deterministic unit detection: Accurately distinguishes milliseconds from seconds
///   based on whole-dataset distribution to eliminate timestamp drift.
/// - Text sanitization: Strips HTML and WebVTT tags (`<v...>`, `<b>`, `<i>`, `<c...>`)
///   and unescapes common HTML entities (`&amp;`, `&#39;`, etc.).
/// - Precision single-cue lookup with gap tolerance to prevent micro-flicker and prevent multi-line accumulation.
class SubtitleParser {
  /// Parses any subtitle or transcript content string into a sorted list of [SubtitleSegment].
  static List<SubtitleSegment> parse(String content) {
    if (content.isEmpty) return [];

    var raw = content;
    if (raw.startsWith('\uFEFF')) raw = raw.substring(1);
    final trimmed = raw.trim();

    // 1. JSON Transcript / AssemblyAI / Whisper / Firestore
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final jsonSegments = _parseJson(trimmed);
        if (jsonSegments.isNotEmpty) {
          return _finalizeSegments(jsonSegments);
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'SubtitleParser.parseJson',
        );
      }
    }

    // 2. SRT / WebVTT
    final srtSegments = _parseSrtOrVtt(raw);
    if (srtSegments.isNotEmpty) {
      return _finalizeSegments(srtSegments);
    }

    // 3. Plain Text Fallback
    final fallbackSegments = _parsePlainText(raw);
    return _finalizeSegments(fallbackSegments);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // JSON Parsing (AssemblyAI, Whisper, Firestore)
  // ───────────────────────────────────────────────────────────────────────────

  static List<SubtitleSegment> _parseJson(String content) {
    final decoded = jsonDecode(content);
    final segs = <SubtitleSegment>[];

    if (decoded is List) {
      final list = decoded.whereType<Map>().toList();
      if (list.isEmpty) return [];

      // Check if top-level list is a word stream (e.g. AssemblyAI words or Whisper words)
      final hasWordKeys = list.first.containsKey('word') ||
          (list.first.containsKey('text') &&
              !list.first.containsKey('utterances') &&
              !list.first.containsKey('segments'));
      final isShortDuration = list.length > 5 &&
          _isDatasetInSeconds(list);

      if (hasWordKeys && isShortDuration) {
        final wordSegs = _buildSegmentsFromWordList(list);
        if (wordSegs.isNotEmpty) return wordSegs;
      }

      // Check if items contain nested words
      final nestedWords = <Map>[];
      for (final item in list) {
        if (item['words'] is List && (item['words'] as List).isNotEmpty) {
          nestedWords.addAll((item['words'] as List).whereType<Map>());
        }
      }
      if (nestedWords.isNotEmpty) {
        final wordSegs = _buildSegmentsFromWordList(nestedWords);
        if (wordSegs.isNotEmpty) return wordSegs;
      }

      // Otherwise parse each item as a segment/utterance
      final isSeconds = _isDatasetInSeconds(list);
      for (final item in list) {
        final seg = _segmentFromMap(item, isSecondsOverride: isSeconds);
        if (seg != null) {
          segs.addAll(_splitUtteranceIntoPhraseCues(seg.text, seg.start, seg.end));
        }
      }
      return segs;
    }

    if (decoded is Map) {
      // Priority 1: Word-level timestamps (AssemblyAI / Whisper words)
      // Produces exact, frame-perfect caption flow
      if (decoded['words'] is List && (decoded['words'] as List).isNotEmpty) {
        final wordMaps = (decoded['words'] as List).whereType<Map>().toList();
        final wordSegs = _buildSegmentsFromWordList(wordMaps);
        if (wordSegs.isNotEmpty) return wordSegs;
      }

      // Priority 2: Utterances (AssemblyAI speaker turns)
      if (decoded['utterances'] is List &&
          (decoded['utterances'] as List).isNotEmpty) {
        final utteranceList =
            (decoded['utterances'] as List).whereType<Map>().toList();

        // Check if utterances contain word-level data
        final allUtteranceWords = <Map>[];
        for (final u in utteranceList) {
          if (u['words'] is List && (u['words'] as List).isNotEmpty) {
            allUtteranceWords.addAll((u['words'] as List).whereType<Map>());
          }
        }
        if (allUtteranceWords.isNotEmpty) {
          final wordSegs = _buildSegmentsFromWordList(allUtteranceWords);
          if (wordSegs.isNotEmpty) return wordSegs;
        }

        final isSeconds = _isDatasetInSeconds(utteranceList);
        for (final u in utteranceList) {
          final uSeg = _segmentFromMap(u, isSecondsOverride: isSeconds);
          if (uSeg != null) {
            segs.addAll(_splitUtteranceIntoPhraseCues(uSeg.text, uSeg.start, uSeg.end));
          }
        }
        if (segs.isNotEmpty) return segs;
      }

      // Priority 3: Segments (Whisper or standard pipeline)
      if (decoded['segments'] is List &&
          (decoded['segments'] as List).isNotEmpty) {
        final segList =
            (decoded['segments'] as List).whereType<Map>().toList();

        final allSegmentWords = <Map>[];
        for (final s in segList) {
          if (s['words'] is List && (s['words'] as List).isNotEmpty) {
            allSegmentWords.addAll((s['words'] as List).whereType<Map>());
          }
        }
        if (allSegmentWords.isNotEmpty) {
          final wordSegs = _buildSegmentsFromWordList(allSegmentWords);
          if (wordSegs.isNotEmpty) return wordSegs;
        }

        final isSeconds = _isDatasetInSeconds(segList);
        for (final item in segList) {
          final seg = _segmentFromMap(item, isSecondsOverride: isSeconds);
          if (seg != null) {
            segs.addAll(_splitUtteranceIntoPhraseCues(seg.text, seg.start, seg.end));
          }
        }
        if (segs.isNotEmpty) return segs;
      }

      // Priority 4: Paragraphs
      if (decoded['paragraphs'] is List &&
          (decoded['paragraphs'] as List).isNotEmpty) {
        final pList = (decoded['paragraphs'] as List).whereType<Map>().toList();
        final isSeconds = _isDatasetInSeconds(pList);
        for (final item in pList) {
          final seg = _segmentFromMap(item, isSecondsOverride: isSeconds);
          if (seg != null) {
            segs.addAll(_splitUtteranceIntoPhraseCues(seg.text, seg.start, seg.end));
          }
        }
        if (segs.isNotEmpty) return segs;
      }

      // Priority 5: Fallback full text string
      final fullText = (decoded['text'] ?? decoded['transcript']) as String?;
      if (fullText != null && fullText.trim().isNotEmpty) {
        return _parsePlainText(fullText.trim());
      }
    }

    return segs;
  }

  /// Groups word-level timestamp objects into natural, rhythmic phrase captions.
  /// Start and end times are anchored to the physical acoustic word timestamps.
  static List<SubtitleSegment> _buildSegmentsFromWordList(List<Map> words) {
    if (words.isEmpty) return [];

    final isSeconds = _isDatasetInSeconds(words);
    final segs = <SubtitleSegment>[];
    final currentChunk = <Map>[];
    var currentChars = 0;

    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final wordText = cleanSubtitleText(
        (w['text'] ?? w['word'] ?? '').toString(),
      );
      if (wordText.isEmpty) continue;

      currentChunk.add(w);
      currentChars += wordText.length + 1;

      final isLastWord = i == words.length - 1;
      final nextWord = !isLastWord ? words[i + 1] : null;

      // Natural speech pause between words (e.g. >= 350ms gap)
      var isPauseBreak = false;
      var nextStartMs = 0;
      if (nextWord != null) {
        final currentEndMs = _parseTimestampToMs(
          w['end'] ?? w['endMs'] ?? w['endTime'] ?? w['end_time'],
          isSeconds: isSeconds,
        );
        nextStartMs = _parseTimestampToMs(
          nextWord['start'] ?? nextWord['startMs'] ?? nextWord['startTime'] ?? nextWord['start_time'],
          isSeconds: isSeconds,
        );
        if (nextStartMs > currentEndMs && (nextStartMs - currentEndMs) >= 350) {
          isPauseBreak = true;
        }
      }

      // Punctuation triggers
      final endsWithSentencePunctuation =
          wordText.endsWith('.') ||
          wordText.endsWith('?') ||
          wordText.endsWith('!') ||
          wordText.endsWith(';') ||
          wordText.endsWith(':');

      final endsWithClausePunctuation =
          (wordText.endsWith(',') ||
              wordText.endsWith('—') ||
              wordText.endsWith('-')) &&
          currentChunk.length >= 3;

      final isLengthExceeded = currentChunk.length >= 5 || currentChars >= 32;

      if (endsWithSentencePunctuation ||
          endsWithClausePunctuation ||
          isPauseBreak ||
          isLengthExceeded ||
          isLastWord) {
        final startMs = _parseTimestampToMs(
          currentChunk.first['start'] ??
              currentChunk.first['startMs'] ??
              currentChunk.first['startTime'] ??
              currentChunk.first['start_time'],
          isSeconds: isSeconds,
        );
        final endMs = _parseTimestampToMs(
          currentChunk.last['end'] ??
              currentChunk.last['endMs'] ??
              currentChunk.last['endTime'] ??
              currentChunk.last['end_time'],
          isSeconds: isSeconds,
        );

        var finalEndMs = endMs;
        if (finalEndMs <= startMs) {
          finalEndMs = startMs + (currentChunk.length * 320);
        } else if (nextWord != null && nextStartMs > finalEndMs) {
          // Hold caption for up to 200ms into silence for smooth reading
          final holdMs = (nextStartMs - finalEndMs).clamp(0, 200);
          finalEndMs += holdMs;
        }

        final chunkText = currentChunk
            .map((e) => cleanSubtitleText((e['text'] ?? e['word'] ?? '').toString()))
            .where((t) => t.isNotEmpty)
            .join(' ')
            .trim();

        if (chunkText.isNotEmpty) {
          segs.add(
            SubtitleSegment(
              start: Duration(milliseconds: startMs),
              end: Duration(milliseconds: finalEndMs),
              text: chunkText,
            ),
          );
        }
        currentChunk.clear();
        currentChars = 0;
      }
    }

    return segs;
  }

  /// Splits an utterance or cue into compact phrase cues strictly bounded within
  /// the utterance's own [start] and [end] time interval, preserving inter-utterance pauses.
  static List<SubtitleSegment> _splitUtteranceIntoPhraseCues(
    String text,
    Duration start,
    Duration end,
  ) {
    final cleaned = cleanSubtitleText(text);
    if (cleaned.isEmpty) return [];

    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];

    // If utterance is already compact (<= 7 words, <= 36 chars), return exact cue
    if (words.length <= 7 && cleaned.length <= 36) {
      return [SubtitleSegment(start: start, end: end, text: cleaned)];
    }

    final chunkList = <String>[];
    final current = <String>[];
    var charCount = 0;

    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      current.add(w);
      charCount += w.length + 1;

      final isLast = i == words.length - 1;
      final isPunct = w.endsWith('.') ||
          w.endsWith('?') ||
          w.endsWith('!') ||
          w.endsWith(';') ||
          w.endsWith(':');
      final isComma = (w.endsWith(',') || w.endsWith('—') || w.endsWith('-')) &&
          current.length >= 3;
      final isLen = current.length >= 5 || charCount >= 32;

      if (isPunct || isComma || isLen || isLast) {
        chunkList.add(current.join(' ').trim());
        current.clear();
        charCount = 0;
      }
    }

    if (chunkList.isEmpty) return [];
    if (chunkList.length == 1) {
      return [SubtitleSegment(start: start, end: end, text: chunkList.first)];
    }

    final totalDurationMs = end.inMilliseconds - start.inMilliseconds;
    final totalChars = chunkList.fold<int>(0, (sum, c) => sum + c.length);

    final segs = <SubtitleSegment>[];
    var curStartMs = start.inMilliseconds;

    for (var i = 0; i < chunkList.length; i++) {
      final chunk = chunkList[i];
      final ratio = (totalChars > 0)
          ? (chunk.length / totalChars)
          : (1.0 / chunkList.length);
      final durMs = (totalDurationMs * ratio).round();

      var curEndMs = (i == chunkList.length - 1)
          ? end.inMilliseconds
          : (curStartMs + durMs);

      if (curEndMs <= curStartMs) {
        curEndMs = curStartMs + 1000;
      }

      segs.add(
        SubtitleSegment(
          start: Duration(milliseconds: curStartMs),
          end: Duration(milliseconds: curEndMs),
          text: chunk,
        ),
      );

      curStartMs = curEndMs;
    }

    return segs;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SRT & WebVTT Parsing
  // ───────────────────────────────────────────────────────────────────────────

  static List<SubtitleSegment> _parseSrtOrVtt(String content) {
    final segs = <SubtitleSegment>[];
    var normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    if (normalized.startsWith('WEBVTT')) {
      normalized = normalized
          .replaceFirst(RegExp(r'^WEBVTT[^\n]*\n*'), '')
          .trim();
    }

    // Split cues by double newlines or cue number blocks
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty) continue;

      var timeLineIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('-->')) {
          timeLineIndex = i;
          break;
        }
      }

      if (timeLineIndex == -1) continue;

      final timeLine = lines[timeLineIndex];
      final arrowParts = timeLine.split('-->');
      if (arrowParts.length != 2) continue;

      final startTimeStr = arrowParts[0].trim();
      // Remove any WebVTT cue settings like "align:start position:50% line:90%"
      final endTimeRaw = arrowParts[1].trim();
      final endTimeStr = endTimeRaw.split(RegExp(r'\s+'))[0];

      final start = parseTimeDuration(startTimeStr);
      final end = parseTimeDuration(endTimeStr);

      final textLines = lines.sublist(timeLineIndex + 1);
      final rawText = textLines.join(' ').trim();
      final cleanedText = cleanSubtitleText(rawText);

      if (cleanedText.isNotEmpty && end > start) {
        segs.addAll(_splitUtteranceIntoPhraseCues(cleanedText, start, end));
      }
    }

    return segs;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Plain Text Fallback
  // ───────────────────────────────────────────────────────────────────────────

  static List<SubtitleSegment> _parsePlainText(String raw) {
    final clean = cleanSubtitleText(raw);
    if (clean.isEmpty) return [];

    final totalWords = clean.split(RegExp(r'\s+')).length;
    // Standard speaking rate ~450ms per word (~130 words per minute)
    final totalDurationMs = totalWords * 450;

    return _splitUtteranceIntoPhraseCues(
      clean,
      Duration.zero,
      Duration(milliseconds: totalDurationMs),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Subtitle Lookup & Synchronization
  // ───────────────────────────────────────────────────────────────────────────

  /// Finds the currently active subtitle at [position], with support for:
  /// - Exact range matching `start <= position <= end`
  /// - Micro-gap tolerance (defaults to 150ms) to prevent flicker during fast speech
  /// - Returns a single clean, compact phrase cue
  static SubtitleSegment? findActiveSubtitle(
    List<SubtitleSegment> segments,
    Duration position, {
    Duration gapTolerance = const Duration(milliseconds: 150),
  }) {
    if (segments.isEmpty) return null;

    final posMs = position.inMilliseconds;
    final tolMs = gapTolerance.inMilliseconds;

    // 1. Exact match lookup
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final startMs = s.start.inMilliseconds;
      final endMs = s.end.inMilliseconds;

      if (posMs >= startMs && posMs <= endMs) {
        return s;
      }
    }

    // 2. Micro-gap tolerance lookup (smooth playback between words/cues)
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final endMs = s.end.inMilliseconds;
      final nextStartMs = (i + 1 < segments.length)
          ? segments[i + 1].start.inMilliseconds
          : null;

      if (posMs > endMs && (posMs - endMs) <= tolMs) {
        if (nextStartMs == null || posMs < nextStartMs) {
          return s;
        }
      }
    }

    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Sanitization & Time Formatting Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Cleans and sanitizes subtitle text by stripping HTML tags, WebVTT cue tags,
  /// and decoding common HTML entities.
  static String cleanSubtitleText(String input) {
    if (input.isEmpty) return '';

    var text = input;

    // 1. Strip WebVTT voice/class tags: <v John Doe>, </v>, <c.yellow>, </c>, <00:00:01.000>
    text = text.replaceAll(RegExp(r'<\/?v[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<\/?c[^>]*>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<\d{2}:\d{2}[^>]*>', caseSensitive: false), '');

    // 2. Strip HTML formatting tags: <b>, </b>, <i>, </i>, <u>, </u>, <font...>, </font>
    text = text.replaceAll(RegExp('<[^>]+>'), '');

    // 3. Decode HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ');

    // 4. Clean whitespace
    text = text.replaceAll(RegExp('[ \t]+'), ' ').replaceAll('\n', ' ').trim();

    return text;
  }

  /// Parses a time string (e.g. `00:01:23.456`, `01:23.456`, `00:01:23,456`, `12.5s`) into a [Duration].
  static Duration parseTimeDuration(String timeStr) {
    final clean = timeStr.trim().split(RegExp(r'\s+'))[0].replaceAll(',', '.');
    if (clean.isEmpty) return Duration.zero;

    // Handle "12.5s" or "300ms"
    if (clean.endsWith('ms')) {
      final ms = double.tryParse(clean.replaceAll('ms', '')) ?? 0.0;
      return Duration(milliseconds: ms.round());
    }
    if (clean.endsWith('s')) {
      final s = double.tryParse(clean.replaceAll('s', '')) ?? 0.0;
      return Duration(milliseconds: (s * 1000).round());
    }

    final parts = clean.split(':');
    if (parts.isEmpty) return Duration.zero;

    var h = 0;
    var m = 0;
    var sSec = '0';

    if (parts.length >= 3) {
      h = int.tryParse(parts[0]) ?? 0;
      m = int.tryParse(parts[1]) ?? 0;
      sSec = parts[2];
    } else if (parts.length == 2) {
      m = int.tryParse(parts[0]) ?? 0;
      sSec = parts[1];
    } else if (parts.length == 1) {
      sSec = parts[0];
    }

    final sParts = sSec.split('.');
    final s = int.tryParse(sParts[0]) ?? 0;
    var ms = 0;
    if (sParts.length > 1) {
      final msStr = sParts[1].padRight(3, '0').substring(0, 3);
      ms = int.tryParse(msStr) ?? 0;
    }

    return Duration(hours: h, minutes: m, seconds: s, milliseconds: ms);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal Helpers
  // ───────────────────────────────────────────────────────────────────────────

  static SubtitleSegment? _segmentFromMap(Map item, {required bool isSecondsOverride}) {
    final startVal = item['start'] ??
        item['startMs'] ??
        item['startTime'] ??
        item['startTimeMs'] ??
        item['start_time'] ??
        item['tStartMs'];
    final endVal = item['end'] ??
        item['endMs'] ??
        item['endTime'] ??
        item['endTimeMs'] ??
        item['end_time'];
    final text = cleanSubtitleText(
      (item['text'] ??
              item['sentence'] ??
              item['content'] ??
              item['transcript'] ??
              item['word'] ??
              '')
          .toString(),
    );

    if (text.isEmpty) return null;

    final startMs = _parseTimestampToMs(startVal, isSeconds: isSecondsOverride);
    var endMs = _parseTimestampToMs(endVal, isSeconds: isSecondsOverride);

    // Support timedtext / dDurationMs
    if (endVal == null && item.containsKey('dDurationMs')) {
      final dur = _parseTimestampToMs(item['dDurationMs'], isSeconds: false);
      endMs = startMs + dur;
    }

    if (endMs <= startMs) {
      final wordCount = text.split(RegExp(r'\s+')).length;
      endMs = startMs + (wordCount * 350).clamp(1200, 10000);
    }

    return SubtitleSegment(
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
      text: text,
    );
  }

  static int _parseTimestampToMs(dynamic value, {required bool isSeconds}) {
    if (value == null) return 0;
    if (value is num) {
      if (isSeconds) {
        return (value * 1000).round();
      }
      return value.round();
    }
    final str = value.toString().trim();
    if (str.contains(':') || str.endsWith('s') || str.endsWith('ms')) {
      return parseTimeDuration(str).inMilliseconds;
    }
    final numVal = double.tryParse(str) ?? 0.0;
    if (isSeconds) {
      return (numVal * 1000).round();
    }
    return numVal.round();
  }

  /// Evaluates the entire dataset to determine if timestamps are in seconds or milliseconds.
  static bool _isDatasetInSeconds(Iterable<Map> items) {
    if (items.isEmpty) return false;

    // 1. If key explicitly says 'Ms', it is milliseconds
    final first = items.first;
    if (first.containsKey('startMs') ||
        first.containsKey('startTimeMs') ||
        first.containsKey('tStartMs') ||
        first.containsKey('endMs') ||
        first.containsKey('endTimeMs')) {
      return false;
    }

    var totalDuration = 0.0;
    var durationCount = 0;
    var maxVal = 0.0;

    for (final item in items) {
      final startRaw = item['start'] ??
          item['startTime'] ??
          item['start_time'] ??
          item['startMs'] ??
          item['tStartMs'];
      final endRaw = item['end'] ??
          item['endTime'] ??
          item['end_time'] ??
          item['endMs'];

      final s = (startRaw is num)
          ? startRaw.toDouble()
          : (double.tryParse(startRaw?.toString() ?? '') ?? 0.0);
      final e = (endRaw is num)
          ? endRaw.toDouble()
          : (double.tryParse(endRaw?.toString() ?? '') ?? 0.0);

      if (s > maxVal) maxVal = s;
      if (e > maxVal) maxVal = e;

      if (e > s) {
        totalDuration += e - s;
        durationCount++;
      }
    }

    // If maximum timestamp exceeds 86400 (24 hours in seconds), it is guaranteed milliseconds
    if (maxVal > 86400) {
      return false;
    }

    // 2. Duration-based speech acoustic check:
    // Natural human speech words/phrases take 0.15s to 6.0s in seconds,
    // or 150ms to 6000ms in milliseconds.
    if (durationCount > 0) {
      final avgDuration = totalDuration / durationCount;
      // An average duration of 20 or more is physically milliseconds (no word/phrase averages 20+ seconds)
      return avgDuration < 20.0;
    }

    // Fallback: If max timestamp is under 600, consider it seconds
    return maxVal < 600.0;
  }

  static List<SubtitleSegment> _finalizeSegments(List<SubtitleSegment> raw) {
    if (raw.isEmpty) return [];

    final valid = raw.where((s) => s.text.isNotEmpty && s.end > s.start).toList();
    valid.sort((a, b) => a.start.compareTo(b.start));

    final deduplicated = <SubtitleSegment>[];
    for (final s in valid) {
      if (deduplicated.isEmpty) {
        deduplicated.add(s);
        continue;
      }
      final prev = deduplicated.last;
      if (prev.start == s.start && prev.text == s.text) {
        continue;
      }
      deduplicated.add(s);
    }

    return deduplicated;
  }
}
