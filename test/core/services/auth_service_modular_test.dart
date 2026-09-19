import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import '../../test_helpers/mock_firebase.dart';

Channel _createTestChannel({
  String id = 'ch_1',
  String name = 'Channel Name',
  String handle = 'chhandle',
  String ownerId = 'usr_1',
  String avatarUrl = 'https://example.com/avatar.png',
  String description = 'Channel Description',
}) => Channel(
  id: id,
  name: name,
  nameLowercase: name.toLowerCase(),
  handle: handle,
  handleLowercase: handle.toLowerCase(),
  description: description,
  avatarUrl: avatarUrl,
  bannerUrl: '',
  ownerId: ownerId,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
);

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

  setUp(Get.reset);
  tearDown(Get.reset);

  group('AuthPremiumManager Tests', () {
    late AuthPremiumManager premiumManager;

    setUp(() {
      premiumManager = AuthPremiumManager();
    });

    test('isTrialExpired computes correctly based on expiresAt', () {
      expect(premiumManager.isTrialExpired, isFalse);

      final past = DateTime.now().millisecondsSinceEpoch - 10000;
      premiumManager.premiumExpiresAt.value = past;
      expect(premiumManager.isTrialExpired, isTrue);

      final future = DateTime.now().millisecondsSinceEpoch + 100000;
      premiumManager.premiumExpiresAt.value = future;
      expect(premiumManager.isTrialExpired, isFalse);
    });

    test('tier getters match plan IDs accurately', () {
      premiumManager.isPremiumUser.value = true;

      premiumManager.premiumPlanId.value = 'audio_monthly';
      expect(premiumManager.isAudioPremiumOnly, isTrue);
      expect(premiumManager.hasFullPremium, isFalse);
      expect(premiumManager.hasFactCheckPremium, isFalse);

      premiumManager.premiumPlanId.value = 'creator_pro';
      expect(premiumManager.isAudioPremiumOnly, isFalse);
      expect(premiumManager.hasFullPremium, isTrue);
      expect(premiumManager.hasFactCheckPremium, isFalse);

      premiumManager.premiumPlanId.value = '4k_factchecked_monthly';
      expect(premiumManager.hasFactCheckPremium, isTrue);

      premiumManager.premiumPlanId.value = 'factcheck_monthly';
      expect(premiumManager.hasFactCheckPremium, isTrue);
    });

    test('formatted date and remaining time getters format accurately', () {
      expect(premiumManager.formattedStartedDate, equals('N/A'));
      expect(premiumManager.formattedExpiresDate, equals('N/A'));
      expect(premiumManager.formattedRemainingTime, equals('N/A'));

      final start = DateTime(2026, 9, 1, 10, 30).millisecondsSinceEpoch;
      final exp = DateTime.now().add(const Duration(days: 5, hours: 3)).millisecondsSinceEpoch;

      premiumManager.premiumStartedAt.value = start;
      premiumManager.premiumExpiresAt.value = exp;

      expect(premiumManager.formattedStartedDate, contains('2026'));
      expect(premiumManager.formattedExpiresDate, contains('2026'));
      expect(premiumManager.formattedRemainingTime, contains('5 days'));
    });

    test('updateFromUserData updates observables and handles expiration', () {
      var refreshed = false;
      final futureExp = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;

      premiumManager.updateFromUserData({
        'isPremium': true,
        'premiumPlanId': 'standard_monthly',
        'premiumStartedAt': 123456789,
        'premiumExpiresAt': futureExp,
      }, onTokenRefresh: () async {
        refreshed = true;
        return 'token';
      });

      expect(premiumManager.isPremiumUser.value, isTrue);
      expect(premiumManager.premiumPlanId.value, equals('standard_monthly'));
      expect(premiumManager.premiumStartedAt.value, equals(123456789));
      expect(refreshed, isTrue);
    });
  });

  group('AuthChannelManager Tests', () {
    late AuthChannelManager channelManager;

    setUp(() {
      channelManager = AuthChannelManager();
    });

    tearDown(() {
      channelManager.dispose();
    });

    test('setUserChannel updates hasChannel and userChannel observables', () {
      expect(channelManager.hasChannel.value, isFalse);
      expect(channelManager.userChannel, isNull);

      final channel = _createTestChannel(
        id: 'ch_100',
        name: 'Truth Channel',
        handle: 'truthchannel',
      );

      channelManager.setUserChannel(channel);
      expect(channelManager.hasChannel.value, isTrue);
      expect(channelManager.userChannel?.id, equals('ch_100'));

      channelManager.clearUserChannel();
      expect(channelManager.hasChannel.value, isFalse);
      expect(channelManager.userChannel, isNull);
    });
  });

  group('AuthProfileManager Tests', () {
    late AuthProfileManager profileManager;

    setUp(() {
      profileManager = AuthProfileManager();
    });

    tearDown(() {
      profileManager.dispose();
    });

    test('getActiveDisplayName falls back according to hierarchy', () {
      // 1. None set -> 'User'
      expect(profileManager.getActiveDisplayName(), equals('User'));

      // 2. Channel set -> Channel name
      final channel = _createTestChannel();
      expect(
        profileManager.getActiveDisplayName(
          userChannel: channel,
          hasChannel: true,
        ),
        equals('Channel Name'),
      );

      // 3. User display name takes priority
      profileManager.userDisplayName.value = 'Custom Display Name';
      expect(
        profileManager.getActiveDisplayName(
          userChannel: channel,
          hasChannel: true,
        ),
        equals('Custom Display Name'),
      );
    });

    test('getActiveHandle formats with leading @ symbol', () {
      expect(profileManager.getActiveHandle(), equals('@user'));

      final channel = _createTestChannel(handle: 'mychannel');
      expect(
        profileManager.getActiveHandle(
          userChannel: channel,
          hasChannel: true,
        ),
        equals('@mychannel'),
      );

      profileManager.userHandle.value = 'truthpilot';
      expect(profileManager.getActiveHandle(), equals('@truthpilot'));

      profileManager.userHandle.value = '@alreadypointed';
      expect(profileManager.getActiveHandle(), equals('@alreadypointed'));
    });

    test('clearProfile clears all profile observables', () {
      profileManager.userDisplayName.value = 'John Doe';
      profileManager.userAge.value = 35;
      profileManager.userGender.value = 'Male';
      profileManager.needsOnboarding.value = true;

      profileManager.clearProfile();

      expect(profileManager.userDisplayName.value, isNull);
      expect(profileManager.userAge.value, isNull);
      expect(profileManager.userGender.value, isNull);
      expect(profileManager.needsOnboarding.value, isFalse);
    });
  });

  group('AuthService Coordinator Tests', () {
    late AuthService authService;

    setUp(() {
      Get.testMode = true;
      authService = Get.put<AuthService>(AuthService());
    });

    tearDown(() {
      authService.onClose();
    });

    test('singleton accessor and sub-managers exist and initialize cleanly', () {
      expect(AuthService.to, equals(authService));
      expect(authService.premiumManager, isNotNull);
      expect(authService.channelManager, isNotNull);
      expect(authService.profileManager, isNotNull);
      expect(authService.firestoreSync, isNotNull);
      expect(authService.googleProvider, isNotNull);
    });

    test('coordinator delegates profile, channel, and premium properties', () {
      authService.userAgeGroup.value = '25–34';
      expect(authService.profileManager.userAgeGroup.value, equals('25–34'));

      authService.userGender.value = 'Female';
      expect(authService.profileManager.userGender.value, equals('Female'));

      final channel = _createTestChannel(
        id: 'ch_coord',
        name: 'Coordinator Channel',
        handle: 'coord',
        ownerId: 'usr_c',
      );

      authService.setUserChannel(channel);
      expect(authService.hasChannel.value, isTrue);
      expect(authService.userChannel?.id, equals('ch_coord'));
      expect(authService.activeDisplayName, equals('Coordinator Channel'));
      expect(authService.activeHandle, equals('@coord'));

      authService.clearUserChannel();
      expect(authService.hasChannel.value, isFalse);
    });

    test('unauthenticated user returns empty uid and false isAuthenticated', () {
      expect(authService.isAuthenticated.value, isFalse);
      expect(authService.isUserSignedIn, isFalse);
      expect(authService.uid, isEmpty);
    });
  });
}
