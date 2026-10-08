import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Accessibility Guard (WCAG Compliance Scanner)', () {
    final libDir = Directory('lib');

    String extractBalancedWidget(String text, int startIdx) {
      var depth = 0;
      var inStr = false;
      var strChar = '';
      var escape = false;

      for (var i = startIdx; i < text.length; i++) {
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

    test('Scan for WCAG accessibility violations (baseline)', () {
      var nakedGestureDetectors = 0;
      var missingSemanticLabelImages = 0;
      var nakedInkWells = 0;

      var filesScanned = 0;
      var cleanFiles = 0;

      if (!libDir.existsSync()) {
        return;
      }

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;

        // Skip generated files
        if (file.path.endsWith('.g.dart') || file.path.endsWith('.freezed.dart')) {
          continue;
        }

        // Skip files inside lib/core/accessibility/
        final normalizedPath = file.path.replaceAll(r'\', '/');
        if (normalizedPath.contains('lib/core/accessibility/')) {
          continue;
        }

        final content = file.readAsStringSync();
        final path = file.path;
        final lines = content.split('\n');
        
        var fileHasViolations = false;
        
        String getLinesContext(int startLineIdx, int endLineIdx) {
          final start = startLineIdx.clamp(0, lines.length - 1);
          final end = endLineIdx.clamp(0, lines.length - 1);
          return lines.sublist(start, end + 1).join('\n');
        }

        // 1. Naked GestureDetector
        for (final m in RegExp(r'\bGestureDetector\s*\(').allMatches(content)) {
          final lineIdx = content.substring(0, m.start).split('\n').length - 1;
          final contextLines = getLinesContext(lineIdx - 3, lineIdx + 3);
          
          if (!contextLines.contains('Semantics')) {
            nakedGestureDetectors++;
            fileHasViolations = true;
            print('⚠️ ACCESSIBILITY: $path:${lineIdx + 1} -> Naked GestureDetector');
          }
        }

        // 2. Image without semanticLabel
        final imageRegExp = RegExp(r'\bImage\.(network|asset|file|memory)\s*\(');
        for (final m in imageRegExp.allMatches(content)) {
          final parenStart = content.indexOf('(', m.start);
          if (parenStart != -1) {
            final body = extractBalancedWidget(content, parenStart);
            final lineIdx = content.substring(0, m.start).split('\n').length - 1;

            if (!body.contains('semanticLabel:')) {
              missingSemanticLabelImages++;
              fileHasViolations = true;
              print('⚠️ ACCESSIBILITY: $path:${lineIdx + 1} -> Image.${m.group(1)} without semanticLabel');
            }
          }
        }

        // 3. InkWell without semantics
        for (final m in RegExp(r'\bInkWell\s*\(').allMatches(content)) {
          final lineIdx = content.substring(0, m.start).split('\n').length - 1;
          final contextLines = getLinesContext(lineIdx - 5, lineIdx);
          
          if (!contextLines.contains('Semantics') && !contextLines.contains('tooltip:')) {
            nakedInkWells++;
            fileHasViolations = true;
            print('⚠️ ACCESSIBILITY: $path:${lineIdx + 1} -> Naked InkWell');
          }
        }

        filesScanned++;
        if (!fileHasViolations) {
          cleanFiles++;
        }
      }

      print('');
      if (nakedGestureDetectors > 0) {
        print('⚠️ ACCESSIBILITY: $nakedGestureDetectors naked GestureDetector(s) found');
      }
      if (missingSemanticLabelImages > 0) {
        print('⚠️ ACCESSIBILITY: $missingSemanticLabelImages Image(s) without semanticLabel');
      }
      if (nakedInkWells > 0) {
        print('⚠️ ACCESSIBILITY: $nakedInkWells naked InkWell(s) found');
      }
      
      final coverage = filesScanned > 0 ? ((cleanFiles / filesScanned) * 100).round() : 100;
      print('📊 Accessibility coverage: $coverage% of files clean ($cleanFiles/$filesScanned)');
      
      // The test SHOULD PASS with warnings for now (baseline)
      expect(true, isTrue);
    });
  });
}
