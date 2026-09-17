import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lighthouse & PageSpeed Web Optimizations Test Suite', () {
    test('web/llms.txt exists, has no UTF-8 BOM, and meets specification', () {
      final file = File('web/llms.txt');
      expect(file.existsSync(), isTrue, reason: 'web/llms.txt must exist');

      final bytes = file.readAsBytesSync();
      // Ensure no UTF-8 BOM (\xEF\xBB\xBF)
      expect(
        bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF,
        isFalse,
        reason: 'web/llms.txt must not contain a UTF-8 BOM',
      );

      final content = utf8.decode(bytes);
      expect(content.startsWith('# Truthworld'), isTrue,
          reason: 'web/llms.txt must start with H1 # Truthworld');
      expect(content.contains('> Truthworld is a high-integrity'), isTrue);
      expect(content.contains('## Core Features'), isTrue);
      expect(content.contains('https://www.truthworld.in'), isTrue);
    });

    test('web/llms-full.txt exists, has no UTF-8 BOM, and contains full context', () {
      final file = File('web/llms-full.txt');
      expect(file.existsSync(), isTrue, reason: 'web/llms-full.txt must exist');

      final bytes = file.readAsBytesSync();
      expect(
        bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF,
        isFalse,
        reason: 'web/llms-full.txt must not contain a UTF-8 BOM',
      );

      final content = utf8.decode(bytes);
      expect(content.startsWith('# Truthworld Full Documentation'), isTrue);
      expect(content.contains('## Architecture & Overview'), isTrue);
    });

    test('web/robots.txt allows AI agent crawlers to access llms files', () {
      final file = File('web/robots.txt');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('Allow: /llms.txt'), isTrue);
      expect(content.contains('Allow: /llms-full.txt'), isTrue);
    });

    test('web/index.html enforces accessible viewport scaling and font preloads', () {
      final file = File('web/index.html');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      // Accessibility: user-scalable=yes and maximum-scale=5.0
      expect(content.contains('user-scalable=yes'), isTrue);
      expect(content.contains('maximum-scale=5.0'), isTrue);

      // Dynamic MutationObserver to catch Flutter engine viewport injection
      expect(content.contains('MutationObserver'), isTrue);
      expect(content.contains('flt-viewport'), isTrue);

      // Font Preloading: asynchronous, non-render-blocking
      expect(content.contains('display=swap'), isTrue);
      expect(content.contains("onload=\"this.media='all'\""), isTrue);

      // CanvasKit WASM preload
      expect(content.contains('canvaskit.wasm'), isTrue);
      expect(content.contains('rel="preload"'), isTrue);

      // Local Cropper assets
      expect(content.contains('assets/cropper/cropper.min.css'), isTrue);
      expect(content.contains('assets/cropper/cropper.min.js'), isTrue);
    });

    test('web/flutter.js.map contains valid JSON source map format', () {
      final file = File('web/flutter.js.map');
      expect(file.existsSync(), isTrue);

      final parsed = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(parsed['version'], equals(3));
      expect(parsed['file'], equals('flutter.js'));
    });

    test('firebase.json configures rewrites and headers across all 4 hosting targets', () {
      final file = File('firebase.json');
      expect(file.existsSync(), isTrue);

      final config = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final hostingList = config['hosting'] as List<dynamic>;
      expect(hostingList.length, equals(4));

      final expectedTargets = ['web-app', 'admin-portal', 'studio-app', 'advertiser-app'];
      for (final targetName in expectedTargets) {
        final targetConfig = hostingList.firstWhere(
          (h) => h['target'] == targetName,
          orElse: () => null,
        ) as Map<String, dynamic>?;

        expect(targetConfig, isNotNull, reason: 'Target $targetName must exist in firebase.json');

        final rewrites = targetConfig!['rewrites'] as List<dynamic>;
        final rewriteSources = rewrites.map((r) => r['source']).toList();
        expect(rewriteSources.contains('/llms.txt'), isTrue,
            reason: '$targetName must have /llms.txt rewrite');
        expect(rewriteSources.contains('/llms-full.txt'), isTrue,
            reason: '$targetName must have /llms-full.txt rewrite');
        expect(rewriteSources.contains('**/*.map'), isTrue,
            reason: '$targetName must have **/*.map rewrite');

        final headers = targetConfig['headers'] as List<dynamic>;
        final headerSources = headers.map((h) => h['source']).toList();
        expect(headerSources.contains('/llms*.txt'), isTrue,
            reason: '$targetName must have /llms*.txt headers');
        expect(headerSources.contains('**/*.map'), isTrue,
            reason: '$targetName must have **/*.map headers');
      }
    });

    test('All build targets contain synchronized SEO and source map assets', () {
      final buildDirs = [
        'build/web',
        'build/web_app',
        'build/web_studio',
        'build/web_admin',
        'build/web_advertiser',
      ];
      final requiredFiles = [
        'llms.txt',
        'llms-full.txt',
        'flutter.js.map',
        'robots.txt',
      ];

      for (final dir in buildDirs) {
        final d = Directory(dir);
        if (d.existsSync()) {
          for (final f in requiredFiles) {
            final file = File('$dir/$f');
            expect(file.existsSync(), isTrue,
                reason: 'File $dir/$f must exist for deployment target');
          }
        }
      }
    });
  });
}
