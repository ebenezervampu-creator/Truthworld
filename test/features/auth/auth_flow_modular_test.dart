import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('AuthFlow Modular & Lifecycle Tests', () {
    test('1. AuthService initializes in unauthenticated state by default', () {
      final auth = AuthService();
      expect(auth.isAuthenticated.value, isFalse);
      expect(auth.isUserSignedIn, isFalse);
      expect(auth.uid, isEmpty);
      expect(auth.user, isNull);
      expect(auth.hasChannel.value, isFalse);
      expect(auth.userChannel, isNull);
    });

    test('2. Channel manager updates reactive properties when channel assigned', () {
      final auth = AuthService();
      final testChannel = Channel(
        id: 'ch_test_101',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: 'truthchannel',
        handleLowercase: 'truthchannel',
        avatarUrl: 'https://example.com/avatar.png',
        bannerUrl: '',
        ownerId: 'user_101',
        description: 'Verified Channel',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      auth.channelManager.setUserChannel(testChannel);

      expect(auth.hasChannel.value, isTrue);
      expect(auth.userChannel, isNotNull);
      expect(auth.userChannel?.id, equals('ch_test_101'));
      expect(auth.userChannel?.name, equals('Truth Channel'));

      auth.channelManager.clearUserChannel();
      expect(auth.hasChannel.value, isFalse);
      expect(auth.userChannel, isNull);
    });

    test('3. Premium manager reflects honest subscription status without charm pricing', () {
      final auth = AuthService();
      final premium = auth.premiumManager;

      expect(premium.isPremiumUser.value, isFalse);
      expect(premium.premiumPlanId.value, isNull);

      premium.isPremiumUser.value = true;
      premium.premiumPlanId.value = 'creator_pro';

      expect(auth.premiumManager.isPremiumUser.value, isTrue);
      expect(auth.premiumManager.hasFullPremium, isTrue);
    });

    test('4. Profile manager safely tracks public profile metadata', () {
      final auth = AuthService();
      final profile = auth.profileManager;

      expect(profile.userDisplayName.value, isNull);
      profile.userDisplayName.value = 'Investigative Creator';
      profile.userPhotoUrl.value = 'https://example.com/profile.png';

      expect(profile.userDisplayName.value, equals('Investigative Creator'));
      expect(profile.userPhotoUrl.value, equals('https://example.com/profile.png'));
      expect(
        profile.getActiveDisplayName(),
        equals('Investigative Creator'),
      );
    });
  });
}
