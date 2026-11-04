import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/download_notification_service.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    CashfreePaymentService.enableNativeGateway = false;
    await setupMockFirebase();
  });

  group('TW-SEC-01: Intent Injection & Fallback Pinning Remediations', () {
    test('web/index.html excludes window.location.hash and strips "#", ";", and whitespace', () {
      final file = File('web/index.html');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Verify cleanPath excludes hash and strips [#;\s]
      expect(
        content.contains(r"(pathname + search).replace(/[#;\s]/g, '').replace(/^\/+/, '')"),
        isTrue,
        reason: r'web/index.html must sanitize pathname + search by stripping [#;\s] and excluding hash',
      );
      expect(
        content.contains('var fullPath = pathname + search + hash;'),
        isFalse,
        reason: 'web/index.html must not include window.location.hash in Intent URI path',
      );

      // Verify fallbackUrl is pinned to storeUrl
      expect(
        content.contains('var fallbackUrl = encodeURIComponent(storeUrl);'),
        isTrue,
        reason: 'web/index.html must pin fallbackUrl to official storeUrl',
      );
      expect(
        content.contains('var fallbackUrl = encodeURIComponent(window.location.href);'),
        isFalse,
        reason: 'web/index.html must not use window.location.href as fallbackUrl',
      );
    });

    test('deep_link_navigator.dart sanitizes clean path before constructing Intent URI', () {
      final file = File('lib/core/services/deep_link/deep_link_navigator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Verify regex stripping #, ;, whitespace and control characters
      expect(
        content.contains(r'[#;\s\x00-\x1F\x7F]'),
        isTrue,
        reason: r'deep_link_navigator.dart must sanitize path by stripping [#;\s\x00-\x1F\x7F]',
      );

      // Simulate the exact sanitization logic
      String sanitize(String currentPath) {
        return currentPath
            .replaceAll(RegExp(r'[#;\s\x00-\x1F\x7F]'), '')
            .replaceFirst(RegExp(r'^\/+'), '');
      }

      const maliciousPath = '///watch?v=123#Intent;package=com.evil.app;S.browser_fallback_url=http://attacker.com;end';
      final clean = sanitize(maliciousPath);

      expect(clean.contains('#'), isFalse);
      expect(clean.contains(';'), isFalse);
      expect(clean.contains(' '), isFalse);
      expect(clean.startsWith('/'), isFalse);
      expect(clean, equals('watch?v=123Intentpackage=com.evil.appS.browser_fallback_url=http://attacker.comend'));
    });
  });

  group('TW-SEC-02 & TW-SEC-03: Download Thumbnail Path Traversal & SSRF Defense', () {
    test('SHA-256 hashes videoId to produce safe file path', () {
      const maliciousVideoId = '../../../etc/shadow;rm -rf /';
      final safeId = sha256.convert(utf8.encode(maliciousVideoId)).toString();

      expect(safeId.length, equals(64));
      expect(safeId.contains('/'), isFalse);
      expect(safeId.contains('..'), isFalse);
      expect(safeId.contains(';'), isFalse);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(safeId), isTrue);

      final filename = 'tw_thumb_$safeId.jpg';
      final tempDir = Directory.systemTemp.path;
      final targetPath = p.canonicalize(p.join(tempDir, filename));

      expect(p.isWithin(tempDir, targetPath), isTrue);
    });

    test('isValidThumbnailUrl enforces HTTPS scheme only', () {
      expect(DownloadNotificationService.isValidThumbnailUrl('http://storage.googleapis.com/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('file:///etc/passwd'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('data:image/png;base64,abc'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('javascript:alert(1)'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl(''), isFalse);
    });

    test('isValidThumbnailUrl strictly blocks SSRF hosts (localhost, loopback, private IP ranges)', () {
      expect(DownloadNotificationService.isValidThumbnailUrl('https://localhost/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://127.0.0.1/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://10.0.2.2/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://192.168.1.1/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://169.254.169.254/latest/meta-data'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://attacker.localhost/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://evil-truthworld.in/test.jpg'), isFalse);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://truthworld.in.attacker.com/test.jpg'), isFalse);
    });

    test('isValidThumbnailUrl allows authorized first-party and CDN hosts', () {
      expect(DownloadNotificationService.isValidThumbnailUrl('https://firebasestorage.googleapis.com/v0/b/truthworld-1.appspot.com/o/thumb.jpg'), isTrue);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://storage.googleapis.com/truthworld-media/thumb.jpg'), isTrue);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://truthworld.in/thumbnails/test.jpg'), isTrue);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://www.truthworld.in/thumbnails/test.jpg'), isTrue);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://cdn.truthworld.in/thumbnails/test.jpg'), isTrue);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://lh3.googleusercontent.com/a/default-user'), isTrue);
      expect(DownloadNotificationService.isValidThumbnailUrl('https://i.ytimg.com/vi/abc/hqdefault.jpg'), isTrue);
    });
  });

  group('TW-SEC-04: Cashfree Payment Deep Link Order ID & Status Verification', () {
    test('handlePaymentResult rejects orderId mismatch when activeOrderId differs', () async {
      final service = CashfreePaymentService.to;
      service.activeOrderId.value = 'order_active_12345';
      service.isProcessing.value = true;

      // Attacker attempts to spoof completion with a mismatched order ID
      await service.handlePaymentResult(orderId: 'order_spoofed_99999', status: 'PAID');

      // Active order was not resolved or corrupted
      expect(service.activeOrderId.value, equals('order_active_12345'));
      expect(service.isProcessing.value, isTrue);

      // Clean up service state
      service.isProcessing.value = false;
      service.activeOrderId.value = '';
    });

    test('handlePaymentResult ignores empty or whitespace orderId', () async {
      final service = CashfreePaymentService.to;
      service.activeOrderId.value = 'order_active_12345';
      service.isProcessing.value = true;

      await service.handlePaymentResult(orderId: '   ', status: 'PAID');

      expect(service.activeOrderId.value, equals('order_active_12345'));
      expect(service.isProcessing.value, isTrue);

      service.isProcessing.value = false;
      service.activeOrderId.value = '';
    });
  });

  group('TW-SEC-05: Android Manifest Intent Filter Hardening', () {
    test('AndroidManifest.xml contains no unencrypted http intent-filters', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);
      final manifest = file.readAsStringSync();

      // Verify unencrypted http scheme is not in any intent-filter
      expect(
        manifest.contains('<data android:scheme="http"'),
        isFalse,
        reason: 'Unencrypted http intent-filter must be completely removed from AndroidManifest.xml',
      );
    });

    test('AndroidManifest.xml browsable custom schemes exclude administrative schemes', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);
      final manifest = file.readAsStringSync();

      // Extract MainActivity
      final mainActivityMatch = RegExp(r'<activity[^>]*android:name="\.MainActivity"[^>]*>([\s\S]*?)<\/activity>')
          .firstMatch(manifest);
      expect(mainActivityMatch, isNotNull);
      final mainActivityContent = mainActivityMatch!.group(1)!;

      // Find the custom schemes intent filter block
      final customSchemeFilterMatch = RegExp(r'<intent-filter>[\s\S]*?<data\s+android:scheme="truthworld"[\s\S]*?<\/intent-filter>')
          .firstMatch(mainActivityContent);
      expect(customSchemeFilterMatch, isNotNull);
      final customSchemeBlock = customSchemeFilterMatch!.group(0)!;

      // Ensure truthworldadmin and truthworldadvertiser are removed
      expect(customSchemeBlock.contains('truthworldadmin'), isFalse);
      expect(customSchemeBlock.contains('truthworldadvertiser'), isFalse);

      // Ensure consumer app scheme truthworld is present
      expect(customSchemeBlock.contains('<data android:scheme="truthworld" />'), isTrue);
    });
  });
}
