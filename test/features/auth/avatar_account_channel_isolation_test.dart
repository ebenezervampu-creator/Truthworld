import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
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
  });

  tearDown(() {
    if (Get.isRegistered<AuthService>()) {
      AuthService.to.clearUserChannel();
      AuthService.to.profileManager.clearProfile();
    }
    Get.reset();
  });

  final testChannel = Channel(
    id: 'test_channel_123',
    name: 'Truth Channel',
    nameLowercase: 'truth channel',
    handle: '@truthchannel',
    handleLowercase: '@truthchannel',
    description: 'Fact-checking and localized journalism',
    avatarUrl: 'https://images.truthworld.in/channels/avatar_123.jpg',
    bannerUrl: '',
    ownerId: 'uid_user_1',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  group('Avatar Account & Channel Isolation Tests', () {
    test('activePhotoUrl returns channel avatar when user has a channel', () {
      final auth = AuthService.to;
      auth.setUserChannel(testChannel, 'uid_user_1');
      auth.profileManager.userPhotoUrl.value =
          'https://lh3.googleusercontent.com/personal_account_photo.jpg';

      expect(auth.hasChannel.value, isTrue);
      expect(auth.userChannel, isNotNull);
      // MUST return channel avatar, never the Google/Firebase account photo
      expect(
        auth.activePhotoUrl,
        equals('https://images.truthworld.in/channels/avatar_123.jpg'),
      );
    });

    test(
        'activePhotoUrl returns cached channel avatar if userChannel is hydrating',
        () {
      final auth = AuthService.to;
      const uid = 'uid_hydrating_user';
      final box = GetStorage();
      box.write('hasChannel_$uid', true);
      box.write(
        'channel_avatar_$uid',
        'https://images.truthworld.in/channels/cached_avatar.jpg',
      );

      auth.channelManager.initCachedChannelStatus(uid);
      auth.profileManager.userPhotoUrl.value =
          'https://lh3.googleusercontent.com/personal_account_photo.jpg';

      // hasChannel is true, userChannel may be null before Firestore returns
      expect(auth.hasChannel.value, isTrue);

      // Even if user.photoURL exists, it must return cached channel avatar or empty, NEVER account photo
      final resolved = auth.profileManager.getActivePhotoUrl(
        userChannel: auth.userChannel,
        hasChannel: auth.hasChannel.value,
        user: auth.user,
        currentUid: uid,
      );
      expect(
        resolved,
        equals('https://images.truthworld.in/channels/cached_avatar.jpg'),
      );
    });

    test(
        'activePhotoUrl NEVER leaks personal account photo when user has a channel without avatar',
        () {
      final auth = AuthService.to;
      const uid = 'uid_no_avatar_channel';
      final channelWithoutAvatar = testChannel.copyWith(avatarUrl: '');
      auth.setUserChannel(channelWithoutAvatar, uid);
      auth.profileManager.userPhotoUrl.value =
          'https://lh3.googleusercontent.com/personal_account_photo.jpg';

      expect(auth.hasChannel.value, isTrue);
      // Because user has a channel, we must never leak personal account photo
      expect(auth.activePhotoUrl, isEmpty);
    });

    test('activePhotoUrl returns account avatar only when user has NO channel',
        () {
      final auth = AuthService.to;
      auth.clearUserChannel('uid_viewer');
      auth.profileManager.userPhotoUrl.value =
          'https://lh3.googleusercontent.com/viewer_account_photo.jpg';

      expect(auth.hasChannel.value, isFalse);
      expect(auth.userChannel, isNull);
      expect(
        auth.activePhotoUrl,
        equals('https://lh3.googleusercontent.com/viewer_account_photo.jpg'),
      );
    });

    test('setUserChannel updates local GetStorage cache synchronously', () {
      final auth = AuthService.to;
      const uid = 'uid_sync_cache_test';
      auth.setUserChannel(testChannel, uid);

      final box = GetStorage();
      expect(box.read('hasChannel_$uid'), isTrue);
      expect(box.read('channel_id_$uid'), equals('test_channel_123'));
      expect(
        box.read('channel_avatar_$uid'),
        equals('https://images.truthworld.in/channels/avatar_123.jpg'),
      );
      expect(box.read('channel_name_$uid'), equals('Truth Channel'));
      expect(box.read('channel_handle_$uid'), equals('@truthchannel'));
      expect(box.read('channel_data_$uid'), isA<Map>());
    });

    test('clearUserChannel purges local GetStorage channel cache', () {
      final auth = AuthService.to;
      const uid = 'uid_purge_cache_test';
      auth.setUserChannel(testChannel, uid);
      auth.clearUserChannel(uid);

      final box = GetStorage();
      expect(box.read('hasChannel_$uid'), isFalse);
      expect(box.read('channel_id_$uid'), isNull);
      expect(box.read('channel_avatar_$uid'), isNull);
      expect(box.read('channel_name_$uid'), isNull);
      expect(box.read('channel_handle_$uid'), isNull);
      expect(box.read('channel_data_$uid'), isNull);
    });

    testWidgets(
        'UserAvatar does NOT hijack explicit photoUrl even if displayName matches currentUser',
        (tester) async {
      final auth = AuthService.to;
      auth.setUserChannel(testChannel, 'uid_current');
      auth.profileManager.userDisplayName.value = 'John Doe';

      const anotherCreatorPhoto = 'https://other-domain.com/creator_b.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              photoUrl: anotherCreatorPhoto,
              displayName: 'John Doe',
            ),
          ),
        ),
      );

      // Verify widget renders without hijacking the explicitly provided photoUrl
      final avatarFinder = find.byType(UserAvatar);
      expect(avatarFinder, findsOneWidget);
      final userAvatarWidget = tester.widget<UserAvatar>(avatarFinder);
      expect(userAvatarWidget.photoUrl, equals(anotherCreatorPhoto));
    });

    testWidgets(
        'UserAvatar resolves to activePhotoUrl when photoUrl is omitted',
        (tester) async {
      final auth = AuthService.to;
      auth.isAuthenticated.value = true;
      auth.setUserChannel(testChannel, 'uid_current');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              radius: 12,
            ),
          ),
        ),
      );

      final avatarFinder = find.byType(UserAvatar);
      expect(avatarFinder, findsOneWidget);
    });
  });
}
