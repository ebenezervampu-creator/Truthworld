import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = false;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(() async {
    Get.testMode = true;
    Get.reset();
  });

  group('TrashRestoreController dialog dismissal & storage cleanup tests', () {
    testWidgets(
      'confirmPermanentDelete closes cleanly even when a GetX snackbar is open',
      (tester) async {
        final controller = TrashRestoreController(channelId: 'chan-1');
        final item = <String, dynamic>{
          'id': 'vid-1',
          'type': 'Video',
          'title': 'Test Video',
        };

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => Get.snackbar(
                        'Deleted',
                        'Success',
                        duration: const Duration(milliseconds: 400),
                      ),
                      child: const Text('Show Snackbar'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          controller.confirmPermanentDelete(ctx, item),
                      child: const Text('Open Confirm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Open a GetX snackbar so Get.isSnackbarOpen == true
        await tester.tap(find.text('Show Snackbar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(Get.isSnackbarOpen, isTrue);

        // Open the confirmation dialog
        await tester.tap(find.text('Open Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('Delete Permanently?'), findsOneWidget);

        // Tap Cancel; with Get.back() this previously only closed the snackbar and left the dialog open
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Delete Permanently?'), findsNothing);

        // Let the GetX snackbar timer finish cleanly before test teardown
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'confirmEmptyTrash closes cleanly even when a GetX snackbar is open',
      (tester) async {
        final controller = TrashRestoreController(channelId: 'chan-1');
        controller.trashItems.assignAll([
          <String, dynamic>{
            'id': 'vid-1',
            'type': 'Video',
            'title': 'Test Video',
          },
        ]);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => Get.snackbar(
                        'Deleted',
                        'Success',
                        duration: const Duration(milliseconds: 400),
                      ),
                      child: const Text('Show Snackbar'),
                    ),
                    ElevatedButton(
                      onPressed: () => controller.confirmEmptyTrash(ctx),
                      child: const Text('Open Empty Confirm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Snackbar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(Get.isSnackbarOpen, isTrue);

        await tester.tap(find.text('Open Empty Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('Empty Trash?'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Empty Trash?'), findsNothing);

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      },
    );

    test(
      'safeDeleteStorageUrl ignores firebase_storage object-not-found without reporting a crash',
      () async {
        const channelName =
            'dev.flutter.pigeon.firebase_storage_platform_interface.FirebaseStorageHostApi.referenceDelete';
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

        var mockErrorCode = 'object-not-found';
        messenger.setMockMessageHandler(
          channelName,
          (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
            mockErrorCode,
            'No object exists at the desired reference.',
            null,
          ]),
        );
        addTearDown(() => messenger.setMockMessageHandler(channelName, null));

        final capturedLogs = <String>[];
        final prevDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message != null) {
            capturedLogs.add(message);
          }
        };
        addTearDown(() => debugPrint = prevDebugPrint);

        // 1. object-not-found should be silently absorbed (no error log)
        await VideoManagementController.safeDeleteStorageUrl(
          'videos/vid-already-deleted/original.mp4',
        );
        expect(
          capturedLogs.where((log) => log.contains('safeDeleteStorageUrl')),
          isEmpty,
        );

        // 2. Non-object-not-found storage errors should still be logged
        mockErrorCode = 'unauthorized';
        await VideoManagementController.safeDeleteStorageUrl(
          'videos/vid-forbidden/original.mp4',
        );
        expect(
          capturedLogs.where(
            (log) =>
                log.contains('safeDeleteStorageUrl') &&
                log.contains('STORAGE_UNAUTHORIZED'),
          ),
          hasLength(1),
        );
      },
    );
  });
}
