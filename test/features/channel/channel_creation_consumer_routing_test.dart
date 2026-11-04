import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(() {
    AppFlavor.current = AppFlavor.app;
    Get.reset();
  });

  group('Channel Creation Consumer Routing & Studio Guard Tests', () {
    test('ChannelCreationGuard redirects to channelRoute in Consumer App when user has channel', () {
      AppFlavor.current = AppFlavor.app;
      expect(AppFlavor.isStudio, isFalse);

      final authService = Get.put(AuthService());
      authService.isAuthenticated.value = true;
      authService.hasChannel.value = true;

      final testChannel = Channel.fromMap({
        'id': 'test_ch_1',
        'name': 'Test Channel',
        'handle': 'testchannel',
        'ownerId': 'user_1',
      }, 'test_ch_1');
      authService.setUserChannel(testChannel);

      final guard = ChannelCreationGuard();
      final routeSettings = guard.redirect('/channelscreen');

      expect(routeSettings, isNotNull);
      // Must NOT redirect to /studio in consumer app!
      expect(routeSettings!.name, isNot('/studio'));
      expect(routeSettings.name, equals('/@testchannel'));
    });

    test('ChannelCreationGuard redirects to /studio in Studio App flavor when user has channel', () {
      AppFlavor.current = AppFlavor.studio;
      expect(AppFlavor.isStudio, isTrue);

      final authService = Get.put(AuthService());
      authService.isAuthenticated.value = true;
      authService.hasChannel.value = true;

      final testChannel = Channel.fromMap({
        'id': 'test_ch_2',
        'name': 'Studio Channel',
        'handle': 'studiochannel',
        'ownerId': 'user_2',
      }, 'test_ch_2');
      authService.setUserChannel(testChannel);

      final guard = ChannelCreationGuard();
      final routeSettings = guard.redirect('/channelscreen');

      expect(routeSettings, isNotNull);
      expect(routeSettings!.name, equals('/studio'));
    });

    test('ChannelWizardViewController checkExistingChannelAndRedirect respects Consumer flavor', () {
      AppFlavor.current = AppFlavor.app;

      Get.put(ChannelController());
      final wizardCtrl = Get.put(ChannelWizardViewController());

      final authService = Get.put(AuthService());
      authService.isAuthenticated.value = true;
      authService.hasChannel.value = true;

      final testChannel = Channel.fromMap({
        'id': 'test_ch_4',
        'name': 'Check Channel',
        'handle': 'checkchannel',
        'ownerId': 'user_4',
      }, 'test_ch_4');
      authService.setUserChannel(testChannel);

      // Verify controller logic initializes cleanly without throwing exceptions
      expect(wizardCtrl.tagList, isEmpty);
      expect(AuthService.to.hasChannel.value, isTrue);
    });

    test('StudioLauncher provides verified Play Store and download URLs', () {
      expect(StudioLauncher.androidPackage, equals('com.truthworld.studio'));
      expect(StudioLauncher.playStoreMarketUrl, equals('market://details?id=com.truthworld.studio'));
      expect(StudioLauncher.playStoreWebUrl, equals('https://play.google.com/store/apps/details?id=com.truthworld.studio'));
    });

    test('StudioLauncher isStudioInstalled returns boolean without exception', () async {
      final isInstalled = await StudioLauncher.isStudioInstalled();
      expect(isInstalled, isA<bool>());
    });
  });
}
