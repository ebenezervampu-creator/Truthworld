import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/truthworld_splash_screen.dart';

void main() {
  group('Android Manifest Deep Linking Configuration Tests', () {
    test('AndroidManifest.xml disables default Flutter deep linking and covers all content paths', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // Verify flutter_deeplinking_enabled is explicitly set to false
      expect(
        content.contains('android:name="flutter_deeplinking_enabled"'),
        isTrue,
        reason: 'flutter_deeplinking_enabled metadata must be present',
      );
      expect(
        content.contains('android:value="false"'),
        isTrue,
        reason: 'flutter_deeplinking_enabled must be false to delegate to AppLinks',
      );

      // Verify essential content pathPrefixes exist for deep link routing
      final requiredPrefixes = [
        '/watch',
        '/v/',
        '/shorts',
        '/channel',
        '/@',
        '/playlist',
        '/topic',
        '/topics',
        '/T/',
        '/clip',
        '/clips',
        '/chapter',
        '/chapters',
        '/claim-detail',
        '/claim',
        '/claims',
        '/post',
        '/community',
      ];

      for (final prefix in requiredPrefixes) {
        expect(
          content.contains('android:pathPrefix="$prefix"'),
          isTrue,
          reason: 'AndroidManifest must cover pathPrefix: $prefix',
        );
      }
    });
  });

  group('TruthworldSplashScreen Hierarchy Stability Tests', () {
    testWidgets('Child with GlobalKey maintains element identity across splash dismiss and completion',
        (tester) async {
      TruthworldSplashScreen.reset();

      final testGlobalKey = GlobalKey();
      final childWidget = ColoredBox(
        key: testGlobalKey,
        color: Colors.blue,
        child: const Text('Root Content Widget'),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: TruthworldSplashScreen(
            duration: const Duration(milliseconds: 100),
            child: childWidget,
          ),
        ),
      );

      expect(find.text('Root Content Widget'), findsOneWidget);
      final initialElement = testGlobalKey.currentContext;
      expect(initialElement, isNotNull);

      // Trigger dismiss during mid-animation
      TruthworldSplashScreen.dismiss();
      await tester.pump(const Duration(milliseconds: 50));

      // GlobalKey element must still be mounted and identical (not deactivated/reparented)
      expect(testGlobalKey.currentContext, equals(initialElement));
      expect(find.text('Root Content Widget'), findsOneWidget);

      // Let animation settle completely
      await tester.pumpAndSettle();

      // GlobalKey element must remain mounted and valid after splash completes
      expect(testGlobalKey.currentContext, equals(initialElement));
      expect(find.text('Root Content Widget'), findsOneWidget);
    });
  });
}
