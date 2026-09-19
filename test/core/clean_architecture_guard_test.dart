import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clean Architecture Guard (Domain Purity & Layer Boundary Rules)', () {
    final domainDir = Directory('lib/domain');

    test('Domain layer must exist and be scanned', () {
      expect(domainDir.existsSync(), isTrue, reason: 'lib/domain directory must exist');
    });

    test('Domain layer must NEVER import cloud_firestore or Firebase SDKs', () {
      final violations = <String>[];

      for (final file in domainDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('import ') || line.startsWith('export ')) {
              if (line.contains('cloud_firestore') ||
                  line.contains('firebase_auth') ||
                  line.contains('firebase_core') ||
                  line.contains('firebase_storage')) {
                violations.add('${file.path}:${i + 1} -> $line');
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'The domain layer must remain pure Dart and never import Firebase/Firestore SDKs:\n${violations.join('\n')}',
      );
    });

    test('Domain layer must NEVER import platform I/O or storage packages (idb_shim, path_provider)', () {
      final violations = <String>[];

      for (final file in domainDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('import ') || line.startsWith('export ')) {
              if (line.contains('idb_shim') ||
                  line.contains('path_provider') ||
                  line.contains('sqflite') ||
                  line.contains('shared_preferences')) {
                violations.add('${file.path}:${i + 1} -> $line');
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Domain layer must not depend on concrete local storage or device I/O packages:\n${violations.join('\n')}',
      );
    });

    test('Domain layer must NEVER import presentation layer code', () {
      final violations = <String>[];

      for (final file in domainDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          final lines = content.split('\n');

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('import ') || line.startsWith('export ')) {
              if (line.contains('/presentation/') || line.contains('/views/') || line.contains('/widgets/')) {
                violations.add('${file.path}:${i + 1} -> $line');
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Domain layer must never import presentation layer code:\n${violations.join('\n')}',
      );
    });

    test('Domain entities must be pure Dart (no flutter/material.dart or flutter/cupertino.dart)', () {
      final entitiesDir = Directory('lib/domain/entities');
      final violations = <String>[];

      if (entitiesDir.existsSync()) {
        for (final file in entitiesDir.listSync(recursive: true)) {
          if (file is File && file.path.endsWith('.dart')) {
            final content = file.readAsStringSync();
            final lines = content.split('\n');

            for (var i = 0; i < lines.length; i++) {
              final line = lines[i].trim();
              if (line.startsWith('import ')) {
                if (line.contains('package:flutter/material.dart') ||
                    line.contains('package:flutter/cupertino.dart')) {
                  violations.add('${file.path}:${i + 1} -> $line');
                }
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Domain entities must remain framework-independent pure Dart classes:\n${violations.join('\n')}',
      );
    });
  });
}
