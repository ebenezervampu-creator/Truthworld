import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UI Contrast & Accessibility Guard (Zero White-on-White Policy)', () {
    final libDir = Directory('lib');

    bool isWhiteColor(String expr) {
      expr = expr.trim();
      if (expr.contains('brandVariant') ||
          expr.contains('bgPage') ||
          expr.contains('bgSurface') ||
          expr.contains('Colors.black') ||
          expr.contains('Colors.transparent') ||
          expr.contains('0xFF0F0F') ||
          expr.contains('0xFF2121') ||
          expr.contains('0xFF1818') ||
          expr.contains('0xFF2727') ||
          expr.contains('0xFF1616') ||
          expr.contains('0xFF2563EB') ||
          expr.contains('0xFF10B981') ||
          expr.contains('0xFFEF4444') ||
          expr.contains('error') ||
          expr.contains('red') ||
          expr.contains('Colors.grey')) {
        return false;
      }

      final alphaMatch = RegExp(r'\.(?:withValues\s*\(\s*alpha:\s*|withOpacity\s*\(\s*)([0-9.]+)').firstMatch(expr);
      if (alphaMatch != null) {
        final alpha = double.tryParse(alphaMatch.group(1) ?? '1.0') ?? 1.0;
        return alpha >= 0.6;
      }

      return expr.contains('AppColors.brand') ||
          expr.contains('Colors.white') ||
          expr.contains('0xFFFFFFFF');
    }

    String extractBalancedWidget(String text, int startIdx) {
      var depth = 0;
      var inStr = false;
      var strChar = '';
      var escape = false;

      for (var i = startIdx; i < text.length && i < startIdx + 2500; i++) {
        final c = text[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (c == r'\') {
          escape = true;
          continue;
        }
        if (inStr) {
          if (c == strChar) inStr = false;
          continue;
        }
        if (c == "'" || c == '"') {
          inStr = true;
          strChar = c;
          continue;
        }
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          depth--;
          if (depth == 0) {
            return text.substring(startIdx, i + 1);
          }
        }
      }
      return text.substring(startIdx, (startIdx + 1200).clamp(0, text.length));
    }

    test('All Dart files under lib/ must never pair white backgrounds with white text or icons', () {
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;

        final content = file.readAsStringSync();
        final path = file.path;

        // 1. Check styleFrom for white backgroundColor with white foregroundColor
        for (final m in RegExp(r'styleFrom\s*\((.*?)\)', dotAll: true).allMatches(content)) {
          final inner = m.group(1) ?? '';
          final bgMatch = RegExp(r'backgroundColor:\s*([^,\n\)]+)').firstMatch(inner);
          final fgMatch = RegExp(r'foregroundColor:\s*([^,\n\)]+)').firstMatch(inner);

          if (bgMatch != null && isWhiteColor(bgMatch.group(1)!)) {
            final fg = fgMatch?.group(1)?.trim() ?? '';
            if (fg.contains('Colors.white') || fg.contains('AppColors.textPrimary')) {
              final line = content.substring(0, m.start).split('\n').length;
              violations.add('$path:$line -> styleFrom has white backgroundColor with white foregroundColor ($fg)');
            }
          }
        }

        // 2. Check ElevatedButtons
        for (final m in RegExp(r'\bElevatedButton(?:\.icon)?\s*\(').allMatches(content)) {
          final parenStart = content.indexOf('(', m.start);
          final body = extractBalancedWidget(content, parenStart);
          final line = content.substring(0, m.start).split('\n').length;

          final bgMatch = RegExp(r'backgroundColor:\s*([^,\n\)]+)').firstMatch(body);
          final bgExpr = bgMatch != null ? bgMatch.group(1)!.trim() : 'DEFAULT_BRAND';

          var isWhiteBg = false;
          if (bgExpr == 'DEFAULT_BRAND') {
            isWhiteBg = true;
          } else if (isWhiteColor(bgExpr)) {
            isWhiteBg = true;
          }

          if (bgExpr.contains('bgSurface') ||
              bgExpr.contains('bgPage') ||
              bgExpr.contains('Colors.transparent') ||
              bgExpr.contains('0xFF2563EB') ||
              bgExpr.contains('0xFF18181B') ||
              bgExpr.contains('0xFF27272A') ||
              bgExpr.contains('0xFF272727') ||
              bgExpr.contains('0xFF10B981') ||
              bgExpr.contains('error') ||
              bgExpr.contains('red')) {
            isWhiteBg = false;
          }

          if (isWhiteBg) {
            final iconMatch = RegExp(r'icon:\s*(?:const\s+)?Icon\s*\([^)]*color:\s*(Colors\.white|AppColors\.textPrimary)[^)]*\)').firstMatch(body);
            if (iconMatch != null) {
              violations.add('$path:$line -> White icon on white/brand ElevatedButton: ${iconMatch.group(0)}');
            }

            final textMatch = RegExp(r'(?:label|child):\s*(?:const\s+)?Text\s*\([^)]*color:\s*(Colors\.white|AppColors\.textPrimary)[^)]*\)').firstMatch(body);
            if (textMatch != null) {
              violations.add('$path:$line -> White text on white/brand ElevatedButton: ${textMatch.group(0)}');
            }

            if (body.contains('AppTextStyles.buttonText') &&
                !body.contains('color: Colors.black') &&
                !body.contains('color: Colors.black87')) {
              violations.add('$path:$line -> ElevatedButton uses AppTextStyles.buttonText without overriding to black text');
            }

            final spinnerMatch = RegExp(r'CircularProgressIndicator\s*\([^)]*color:\s*Colors\.white[^)]*\)|AlwaysStoppedAnimation(?:<Color>)?\s*\(\s*Colors\.white\s*\)').firstMatch(body);
            if (spinnerMatch != null) {
              violations.add('$path:$line -> White loading indicator on white/brand ElevatedButton: ${spinnerMatch.group(0)}');
            }
          }
        }

        // 3. Check FloatingActionButton with brand/white background
        for (final m in RegExp(r'\bFloatingActionButton\s*\(').allMatches(content)) {
          final parenStart = content.indexOf('(', m.start);
          final body = extractBalancedWidget(content, parenStart);
          final line = content.substring(0, m.start).split('\n').length;

          final bgMatch = RegExp(r'backgroundColor:\s*([^,\n\)]+)').firstMatch(body);
          if (bgMatch != null && isWhiteColor(bgMatch.group(1)!)) {
            final iconMatch = RegExp(r'Icon\s*\([^)]*color:\s*(Colors\.white|AppColors\.textPrimary)[^)]*\)').firstMatch(body);
            if (iconMatch != null) {
              violations.add('$path:$line -> White icon on white FloatingActionButton: ${iconMatch.group(0)}');
            }
          }
        }

        // 4. Check dynamic theme containers (isDarkMode ? ... : Colors.white)
        for (final m in RegExp(r'color:\s*isDarkMode\s*\?\s*[^:]+:\s*(?:Colors\.white|Colors\.grey\.shade100)').allMatches(content)) {
          final chunk = content.substring(m.end, (m.end + 350).clamp(0, content.length));
          final line = content.substring(0, m.start).split('\n').length;

          final hardcodedWhiteIcon = RegExp(r'(?:const\s+)?Icon\s*\([^)]*color:\s*Colors\.white[^)]*\)').firstMatch(chunk);
          if (hardcodedWhiteIcon != null && !chunk.contains('isDarkMode ?')) {
            violations.add('$path:$line -> Dynamic container uses Colors.white in light mode with hardcoded white icon: ${hardcodedWhiteIcon.group(0)}');
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Found ${violations.length} UI contrast violations (white on white):\n${violations.join('\n')}');
      }
    });
  });
}
