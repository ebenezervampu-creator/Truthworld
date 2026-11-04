import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClickableUrlText parsing tests', () {
    test('1. Plain text without URLs returns single TextSpan', () {
      final spans = ClickableUrlText.parseSpans('Hello world from Truthworld');
      expect(spans.length, 1);
      expect((spans[0] as TextSpan).text, 'Hello world from Truthworld');
    });

    test('2. Parses https and http URLs', () {
      final spans = ClickableUrlText.parseSpans('Visit https://truthworld.ai for truth.');
      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Visit ');
      expect((spans[1] as TextSpan).text, 'https://truthworld.ai');
      expect((spans[1] as TextSpan).recognizer, isNotNull);
      expect((spans[2] as TextSpan).text, ' for truth.');
    });

    test('3. Parses www and plain domain URLs', () {
      final spans = ClickableUrlText.parseSpans('Go to www.truthworld.in or github.com/flutter');
      final matchedTexts = spans.map((s) => (s as TextSpan).text).toList();
      expect(matchedTexts.contains('www.truthworld.in'), isTrue);
      expect(matchedTexts.contains('github.com/flutter'), isTrue);
    });

    test('4. Correctly parses markdown links [Label](URL)', () {
      final spans = ClickableUrlText.parseSpans('Check out [Truthworld](https://truthworld.ai) now!');
      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Check out ');
      expect((spans[1] as TextSpan).text, 'Truthworld');
      expect((spans[1] as TextSpan).recognizer, isNotNull);
      expect((spans[2] as TextSpan).text, ' now!');
    });

    test('5. Handles channel mentions (@handle)', () {
      final spans = ClickableUrlText.parseSpans('Follow @truthworld for updates.');
      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Follow ');
      expect((spans[1] as TextSpan).text, '@truthworld');
      expect((spans[1] as TextSpan).recognizer, isNotNull);
      expect((spans[2] as TextSpan).text, ' for updates.');
    });

    test('6. Does not parse email addresses as channel mentions', () {
      final spans = ClickableUrlText.parseSpans('Contact us at support@truthworld.ai anytime.');
      // Should treat support@truthworld.ai as a domain/URL or email, but NOT an @-mention
      final mentionSpan = spans.where((s) {
        final t = (s as TextSpan).text ?? '';
        return t == '@truthworld' || t == '@truthworld.ai';
      });
      expect(mentionSpan.isEmpty, isTrue);
    });

    test('7. Strips trailing punctuation from raw URLs', () {
      final spans = ClickableUrlText.parseSpans('Check https://google.com, and https://flutter.dev!');
      final texts = spans.map((s) => (s as TextSpan).text).toList();
      expect(texts.contains('https://google.com'), isTrue);
      expect(texts.contains(','), isTrue);
      expect(texts.contains('https://flutter.dev'), isTrue);
      expect(texts.contains('!'), isTrue);
    });

    test('8. Preserves balanced parentheses in URLs like Wikipedia', () {
      const url = 'https://en.wikipedia.org/wiki/Dart_(programming_language)';
      final spans = ClickableUrlText.parseSpans('Read $url here.');
      final texts = spans.map((s) => (s as TextSpan).text).toList();
      expect(texts.contains(url), isTrue);
    });
  });

  group('ClickableUrlText widget rendering & tap interactions', () {
    testWidgets('9. Tapping URL invokes onUrlTap callback', (tester) async {
      String? tappedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClickableUrlText(
              text: 'Visit https://truthworld.ai today!',
              onUrlTap: (url) {
                tappedUrl = url;
              },
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final rootSpan = textWidget.textSpan! as TextSpan;
      final urlSpan = rootSpan.children![1] as TextSpan;

      expect(urlSpan.text, 'https://truthworld.ai');
      expect(urlSpan.recognizer, isA<TapGestureRecognizer>());

      (urlSpan.recognizer as TapGestureRecognizer).onTap?.call();
      expect(tappedUrl, 'https://truthworld.ai');
    });

    testWidgets('10. Tapping mention invokes onMentionTap callback', (tester) async {
      String? tappedMention;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClickableUrlText(
              text: 'Subscribe to @creator on Truthworld',
              onMentionTap: (handle) {
                tappedMention = handle;
              },
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final rootSpan = textWidget.textSpan! as TextSpan;
      final mentionSpan = rootSpan.children![1] as TextSpan;

      expect(mentionSpan.text, '@creator');
      expect(mentionSpan.recognizer, isA<TapGestureRecognizer>());

      (mentionSpan.recognizer as TapGestureRecognizer).onTap?.call();
      expect(tappedMention, '@creator');
    });

    testWidgets('11. Selectable mode renders SelectionArea with Text.rich', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClickableUrlText(
              text: 'Explore https://truthworld.ai freely.',
              selectable: true,
            ),
          ),
        ),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
    });
  });
}
