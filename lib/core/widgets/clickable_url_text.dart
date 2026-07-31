import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that automatically parses text for URLs and channel handles (@handle)
/// and renders them as clickable links.
class ClickableUrlText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? urlStyle;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;
  final bool selectable;
  final Function(String url)? onUrlTap;
  final Function(String handle)? onMentionTap;

  const ClickableUrlText({
    super.key,
    required this.text,
    this.style,
    this.urlStyle,
    this.mentionStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.start,
    this.selectable = false,
    this.onUrlTap,
    this.onMentionTap,
  });

  static final RegExp _urlAndMentionRegex = RegExp(
    r'(https?:\/\/[^\s<]+|www\.[^\s<]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}(?:\/[^\s<]*)?|@[a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  /// Navigates to channel details page using handle.
  static void navigateToChannelByHandle(String rawHandle) {
    String handle = rawHandle.trim();
    while (handle.endsWith('.') ||
        handle.endsWith(',') ||
        handle.endsWith(')') ||
        handle.endsWith(']') ||
        handle.endsWith('!') ||
        handle.endsWith('?')) {
      handle = handle.substring(0, handle.length - 1);
    }
    if (!handle.startsWith('@')) {
      handle = '@$handle';
    }
    if (handle.length <= 1) return;

    Get.toNamed('/channel/$handle');
  }

  /// Launches a URL string externally.
  static Future<void> launchUrlString(String rawUrl) async {
    String url = rawUrl.trim();
    while (url.endsWith('.') ||
        url.endsWith(',') ||
        url.endsWith(')') ||
        url.endsWith(']') ||
        url.endsWith('!') ||
        url.endsWith('?')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri);
        }
      } catch (e) {
        debugPrint('[ClickableUrlText] Error launching $url: $e');
      }
    }
  }

  /// Converts raw URLs and @handle mentions in markdown text to standard markdown links.
  static String formatMarkdownLinks(String text) {
    if (text.isEmpty) return text;
    final markdownLinkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final matches = _urlAndMentionRegex.allMatches(text);
    if (matches.isEmpty) return text;

    final existingMarkdownSpans = <TextRange>[];
    for (final m in markdownLinkRegex.allMatches(text)) {
      existingMarkdownSpans.add(TextRange(start: m.start, end: m.end));
    }

    final buffer = StringBuffer();
    int lastEnd = 0;

    for (final match in matches) {
      bool insideMarkdown = existingMarkdownSpans.any(
        (range) => match.start >= range.start && match.end <= range.end,
      );
      if (insideMarkdown) continue;

      String rawMatched = match.group(0)!;

      // Check if @handle is part of an email address
      if (rawMatched.startsWith('@') && match.start > 0) {
        final prevChar = text[match.start - 1];
        if (prevChar != ' ' &&
            prevChar != '\n' &&
            prevChar != '\t' &&
            prevChar != '(' &&
            prevChar != '[' &&
            prevChar != '{' &&
            prevChar != '<') {
          continue;
        }
      }

      buffer.write(text.substring(lastEnd, match.start));
      String cleanToken = rawMatched;
      String trailingPunct = '';

      while (cleanToken.endsWith('.') ||
          cleanToken.endsWith(',') ||
          cleanToken.endsWith(')') ||
          cleanToken.endsWith(']') ||
          cleanToken.endsWith('!') ||
          cleanToken.endsWith('?')) {
        trailingPunct = cleanToken[cleanToken.length - 1] + trailingPunct;
        cleanToken = cleanToken.substring(0, cleanToken.length - 1);
      }

      if (cleanToken.isNotEmpty) {
        if (cleanToken.startsWith('@')) {
          buffer.write(
            '[$cleanToken](mention://${cleanToken.substring(1)})$trailingPunct',
          );
        } else {
          String fullTarget = cleanToken;
          if (!fullTarget.startsWith('http://') &&
              !fullTarget.startsWith('https://')) {
            fullTarget = 'https://$fullTarget';
          }
          buffer.write('[$cleanToken]($fullTarget)$trailingPunct');
        }
      } else {
        buffer.write(rawMatched);
      }
      lastEnd = match.end;
    }
    buffer.write(text.substring(lastEnd));
    return buffer.toString();
  }

  /// Parses text into a list of InlineSpan objects containing text, URL, and handle mention spans.
  static List<InlineSpan> parseSpans(
    String text, {
    TextStyle? style,
    TextStyle? urlStyle,
    TextStyle? mentionStyle,
    Function(String url)? onUrlTap,
    Function(String handle)? onMentionTap,
  }) {
    if (text.isEmpty) return [];
    final matches = _urlAndMentionRegex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    final defaultLinkStyle = (style ?? const TextStyle()).copyWith(
      color: const Color(0xFF3EA6FF),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF3EA6FF),
    );
    final effectiveUrlStyle = urlStyle ?? defaultLinkStyle;

    final defaultMentionStyle = (style ?? const TextStyle()).copyWith(
      color: const Color(0xFF3EA6FF),
      fontWeight: FontWeight.w600,
    );
    final effectiveMentionStyle = mentionStyle ?? defaultMentionStyle;

    for (final match in matches) {
      String rawMatched = match.group(0)!;

      // Check if @handle is part of an email address
      if (rawMatched.startsWith('@') && match.start > 0) {
        final prevChar = text[match.start - 1];
        if (prevChar != ' ' &&
            prevChar != '\n' &&
            prevChar != '\t' &&
            prevChar != '(' &&
            prevChar != '[' &&
            prevChar != '{' &&
            prevChar != '<') {
          continue;
        }
      }

      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: style,
          ),
        );
      }

      String cleanToken = rawMatched;
      String trailingPunct = '';

      while (cleanToken.endsWith('.') ||
          cleanToken.endsWith(',') ||
          cleanToken.endsWith(')') ||
          cleanToken.endsWith(']') ||
          cleanToken.endsWith('!') ||
          cleanToken.endsWith('?')) {
        trailingPunct = cleanToken[cleanToken.length - 1] + trailingPunct;
        cleanToken = cleanToken.substring(0, cleanToken.length - 1);
      }

      if (cleanToken.isNotEmpty) {
        final targetToken = cleanToken;
        final isMention = cleanToken.startsWith('@');

        spans.add(
          TextSpan(
            text: cleanToken,
            style: isMention ? effectiveMentionStyle : effectiveUrlStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (isMention) {
                  if (onMentionTap != null) {
                    onMentionTap(targetToken);
                  } else {
                    navigateToChannelByHandle(targetToken);
                  }
                } else {
                  if (onUrlTap != null) {
                    onUrlTap(targetToken);
                  } else {
                    launchUrlString(targetToken);
                  }
                }
              },
          ),
        );
        if (trailingPunct.isNotEmpty) {
          spans.add(TextSpan(text: trailingPunct, style: style));
        }
      } else {
        spans.add(TextSpan(text: rawMatched, style: style));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: style,
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final spans = parseSpans(
      text,
      style: style,
      urlStyle: urlStyle,
      mentionStyle: mentionStyle,
      onUrlTap: onUrlTap,
      onMentionTap: onMentionTap,
    );

    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
        maxLines: maxLines,
        textAlign: textAlign,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
