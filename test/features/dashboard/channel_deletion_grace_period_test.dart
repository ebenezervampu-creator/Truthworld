import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/channel_deletion_grace_period_page.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('Channel Deletion Grace Period Model Tests', () {
    test('Calculates active 30-day grace period correctly', () {
      final now = DateTime.now();
      final scheduledAt = now.subtract(const Duration(days: 5));
      final expiresAt = scheduledAt.add(const Duration(days: 30)); // 25 days remaining

      final channel = Channel(
        id: 'del_ch_1',
        name: 'Deleted Channel Test',
        nameLowercase: 'deleted channel test',
        handle: '@deletedtest',
        handleLowercase: '@deletedtest',
        description: 'Test channel in grace period',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_123',
        status: ChannelStatus.deleted,
        deletionScheduledAt: Timestamp.fromDate(scheduledAt),
        deletionGracePeriodExpiresAt: Timestamp.fromDate(expiresAt),
        createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 100))),
        updatedAt: Timestamp.fromDate(scheduledAt),
      );

      expect(channel.isDeleted, isTrue);
      expect(channel.isPendingDeletion, isTrue);
      expect(channel.isPermanentDeletionExpired, isFalse);
      expect(channel.gracePeriodDaysRemaining, inInclusiveRange(24, 25));
      expect(channel.scheduledPermanentDeletionDate, isNotNull);
    });

    test('Identifies expired grace period after 30 days', () {
      final now = DateTime.now();
      final scheduledAt = now.subtract(const Duration(days: 35));
      final expiresAt = scheduledAt.add(const Duration(days: 30)); // 5 days past expiry

      final channel = Channel(
        id: 'del_ch_expired',
        name: 'Expired Channel Test',
        nameLowercase: 'expired channel test',
        handle: '@expiredtest',
        handleLowercase: '@expiredtest',
        description: 'Channel past 30 days',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_123',
        status: ChannelStatus.deleted,
        deletionScheduledAt: Timestamp.fromDate(scheduledAt),
        deletionGracePeriodExpiresAt: Timestamp.fromDate(expiresAt),
        createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 200))),
        updatedAt: Timestamp.fromDate(scheduledAt),
      );

      expect(channel.isDeleted, isTrue);
      expect(channel.isPendingDeletion, isFalse);
      expect(channel.isPermanentDeletionExpired, isTrue);
      expect(channel.gracePeriodDaysRemaining, 0);
    });

    test('Round-trips deletion fields via fromMap and toMap', () {
      final now = DateTime.now();
      final mapData = <String, dynamic>{
        'name': 'Serialized Channel',
        'handle': '@serialized',
        'status': 'deleted',
        'deletionScheduledAt': Timestamp.fromDate(now),
        'deletionGracePeriodExpiresAt':
            Timestamp.fromDate(now.add(const Duration(days: 30))),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final parsed = Channel.fromMap(mapData, 'serialized_doc');
      expect(parsed.status, ChannelStatus.deleted);
      expect(parsed.deletionScheduledAt, isNotNull);
      expect(parsed.deletionGracePeriodExpiresAt, isNotNull);

      final exported = parsed.toMap();
      expect(exported['deletionScheduledAt'], isNotNull);
      expect(exported['deletionGracePeriodExpiresAt'], isNotNull);
      expect(exported['status'], 'deleted');
    });
  });

  group('ChannelDeletionGracePeriodPage Widget Tests', () {
    testWidgets('Renders grace period page with countdown and restore action',
        (tester) async {
      final now = DateTime.now();
      final scheduledAt = now.subtract(const Duration(days: 2));
      final expiresAt = scheduledAt.add(const Duration(days: 30));

      final activeGraceChannel = Channel(
        id: 'ch_grace_ui',
        name: 'Grace Channel',
        nameLowercase: 'grace channel',
        handle: '@gracechannel',
        handleLowercase: '@gracechannel',
        description: 'Channel in 30 day grace period',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_123',
        status: ChannelStatus.deleted,
        deletionScheduledAt: Timestamp.fromDate(scheduledAt),
        deletionGracePeriodExpiresAt: Timestamp.fromDate(expiresAt),
        createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 50))),
        updatedAt: Timestamp.fromDate(scheduledAt),
      );

      var cancelCalled = false;
      var signOutCalled = false;

      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: ChannelDeletionGracePeriodPage(
            channel: activeGraceChannel,
            onCancelDeletion: () async {
              cancelCalled = true;
            },
            onSignOut: () {
              signOutCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & headlines
      expect(find.text('Channel Scheduled for Deletion'), findsOneWidget);
      expect(find.text('Grace Channel'), findsOneWidget);
      expect(find.text('@gracechannel'), findsOneWidget);
      expect(find.text('Pending Deletion'), findsOneWidget);
      expect(find.text('30-Day Grace Period'), findsOneWidget);

      // Verify cancel/restore button exists
      final restoreBtn = find.text('Cancel Channel Deletion');
      expect(restoreBtn, findsOneWidget);

      // Tap cancel deletion
      await tester.tap(restoreBtn);
      await tester.pump();
      expect(cancelCalled, isTrue);

      // Verify sign out
      final signOutBtn = find.text('Sign Out');
      expect(signOutBtn, findsOneWidget);
      await tester.tap(signOutBtn);
      await tester.pump();
      expect(signOutCalled, isTrue);
    });

    testWidgets('Renders expired state when 30-day grace period has passed',
        (tester) async {
      final now = DateTime.now();
      final scheduledAt = now.subtract(const Duration(days: 35));
      final expiresAt = scheduledAt.add(const Duration(days: 30));

      final expiredChannel = Channel(
        id: 'ch_expired_ui',
        name: 'Expired Channel',
        nameLowercase: 'expired channel',
        handle: '@expiredchannel',
        handleLowercase: '@expiredchannel',
        description: 'Channel past 30 days',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_123',
        status: ChannelStatus.deleted,
        deletionScheduledAt: Timestamp.fromDate(scheduledAt),
        deletionGracePeriodExpiresAt: Timestamp.fromDate(expiresAt),
        createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 80))),
        updatedAt: Timestamp.fromDate(scheduledAt),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: ChannelDeletionGracePeriodPage(
            channel: expiredChannel,
            onCancelDeletion: () async {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Channel Deletion Completed'), findsOneWidget);
      expect(find.text('Create a New Channel'), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);
    });
  });
}
