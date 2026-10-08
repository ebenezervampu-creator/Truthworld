import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/firebase_options.dart';

void main() {
  group('Truthworld Auth Domain & Google Sign-In Custom URL Tests', () {
    test('1. Web FirebaseOptions uses Truthworld authDomain instead of firebaseapp.com', () {
      expect(DefaultFirebaseOptions.web.authDomain, equals('www.truthworld.in'));
      expect(DefaultFirebaseOptions.web.authDomain, isNot(contains('firebaseapp.com')));
    });

    test('2. Windows FirebaseOptions uses Truthworld authDomain instead of firebaseapp.com', () {
      expect(DefaultFirebaseOptions.windows.authDomain, equals('www.truthworld.in'));
      expect(DefaultFirebaseOptions.windows.authDomain, isNot(contains('firebaseapp.com')));
    });

    test('3. defaultAuthDomain constant points to canonical Truthworld domain', () {
      expect(DefaultFirebaseOptions.defaultAuthDomain, equals('www.truthworld.in'));
      expect(DefaultFirebaseOptions.defaultAuthDomain, isNot(contains('firebaseapp')));
    });

    test('4. resolvedWebAuthDomain safely defaults to Truthworld domain', () {
      expect(
        DefaultFirebaseOptions.resolvedWebAuthDomain,
        anyOf(equals('www.truthworld.in'), equals('truthworld.in')),
      );
      expect(DefaultFirebaseOptions.resolvedWebAuthDomain, isNot(contains('firebaseapp.com')));
    });

    test('5. DefaultFirebaseOptions.forFlavor uses Truthworld URLs for all flavors', () {
      for (final flavor in AppFlavor.values) {
        final options = DefaultFirebaseOptions.forFlavor(flavor);
        // If the platform options define authDomain, it must not contain firebaseapp.com
        if (options.authDomain != null) {
          expect(
            options.authDomain,
            anyOf(equals('www.truthworld.in'), equals('truthworld.in')),
          );
          expect(options.authDomain, isNot(contains('firebaseapp.com')));
        }
      }
    });

    test('6. lib/firebase_options.dart contains zero instances of firebaseapp.com in authDomain', () {
      final file = File('lib/firebase_options.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, isNot(contains("authDomain: 'truthworld-1.firebaseapp.com'")));
      expect(content, contains('authDomain: defaultAuthDomain'));
    });

    test('7. admin-portal/src/firebase.js uses Truthworld custom auth domain', () {
      final file = File('admin-portal/src/firebase.js');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, isNot(contains('truthworld-1.firebaseapp.com')));
      expect(content, contains('authDomain: "www.truthworld.in"'));
    });

    test('8. web/sw.js explicitly bypasses Firebase internal reserved paths (/__/)', () {
      final file = File('web/sw.js');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains("url.pathname.startsWith('/__/')"));
    });

    test('9. firebase.json includes Truthworld domains in CSP connect-src and frame-src', () {
      final file = File('firebase.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('https://*.truthworld.in'));
      expect(content, contains('https://truthworld.in'));
    });
  });
}
