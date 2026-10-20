import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_details_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(() {
    if (Get.isRegistered<ChannelController>()) {
      Get.find<ChannelController>().disposeAvailabilityTimers();
    }
    Get.reset();
  });

  group('Channel Handle & Name Availability Tests', () {
    test('Handle instant validation validates empty, short, long, and invalid format (0ms, zero cost)', () {
      final controller = Get.put(ChannelController());

      // Empty handle
      controller.checkCustomUrlAvailability('');
      expect(controller.customUrlAvailability.value, AvailabilityStatus.unknown);
      expect(controller.customUrlAvailabilityMessage.value, isEmpty);

      // Short handle (< 3 chars)
      controller.checkCustomUrlAvailability('ab');
      expect(controller.customUrlAvailability.value, AvailabilityStatus.invalid);
      expect(controller.customUrlAvailabilityMessage.value, contains('at least 3 characters'));

      // Long handle (> 30 chars)
      controller.checkCustomUrlAvailability('a' * 31);
      expect(controller.customUrlAvailability.value, AvailabilityStatus.invalid);
      expect(controller.customUrlAvailabilityMessage.value, contains('cannot exceed 30 characters'));

      // Invalid characters
      controller.checkCustomUrlAvailability('invalid.handle!');
      expect(controller.customUrlAvailability.value, AvailabilityStatus.invalid);
      expect(
        controller.customUrlAvailabilityMessage.value,
        contains('letters, numbers, underscores, and hyphens'),
      );
    });

    test('Handle instant validation blocks reserved handles instantly with suggestions', () {
      final controller = Get.put(ChannelController());

      controller.checkCustomUrlAvailability('admin');
      expect(controller.customUrlAvailability.value, AvailabilityStatus.taken);
      expect(controller.customUrlAvailabilityMessage.value, contains('reserved'));
      expect(controller.handleSuggestions.isNotEmpty, isTrue);

      controller.checkCustomUrlAvailability('truthworld');
      expect(controller.customUrlAvailability.value, AvailabilityStatus.taken);
      expect(controller.customUrlAvailabilityMessage.value, contains('reserved'));
    });

    test('Channel name instant validation validates empty, short, and long lengths', () {
      final controller = Get.put(ChannelController());

      // Empty name
      controller.checkChannelNameAvailability('');
      expect(controller.channelNameAvailability.value, AvailabilityStatus.unknown);
      expect(controller.channelNameAvailabilityMessage.value, isEmpty);

      // Short name (< 3 chars)
      controller.checkChannelNameAvailability('Hi');
      expect(controller.channelNameAvailability.value, AvailabilityStatus.invalid);
      expect(controller.channelNameAvailabilityMessage.value, contains('at least 3 characters'));

      // Long name (> 100 chars)
      controller.checkChannelNameAvailability('T' * 101);
      expect(controller.channelNameAvailability.value, AvailabilityStatus.invalid);
      expect(controller.channelNameAvailabilityMessage.value, contains('cannot exceed 100 characters'));
    });

    test('applyHandleSuggestion applies handle to customUrl and checks availability', () {
      final controller = Get.put(ChannelController());

      controller.applyHandleSuggestion('truth_creator101');
      expect(controller.customUrl.text, 'truth_creator101');
      expect(
        controller.customUrlAvailability.value == AvailabilityStatus.checking ||
            controller.customUrlAvailability.value == AvailabilityStatus.available,
        isTrue,
      );
      controller.disposeAvailabilityTimers();
    });

    test('Auto-slug generates clean handle when typing channel name', () {
      final controller = Get.put(ChannelController());

      controller.channelName.text = 'Truth & Science 2026';
      expect(controller.customUrl.text, 'truth-science-2026');
      controller.disposeAvailabilityTimers();
    });

    testWidgets('ChannelWizardDetailsCard renders availability status indicators and suggestion chips', (tester) async {
      final controller = Get.put(ChannelController());
      final wizardCtrl = Get.put(ChannelWizardViewController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChannelWizardDetailsCard(
                controller: controller,
                tagList: wizardCtrl.tagList,
                isDarkMode: true,
                wizardController: wizardCtrl,
              ),
            ),
          ),
        ),
      );

      // Verify labels rendered
      expect(find.text('Channel Name'), findsOneWidget);
      expect(find.text('Channel Handle'), findsOneWidget);

      // Simulate Handle Taken
      controller.customUrlAvailability.value = AvailabilityStatus.taken;
      controller.customUrlAvailabilityMessage.value = 'Handle @tech is already taken.';
      controller.handleSuggestions.value = ['tech_official', 'tech_channel'];
      await tester.pump();

      expect(find.text('Handle @tech is already taken.'), findsOneWidget);
      expect(find.text('Suggested handles:'), findsOneWidget);
      expect(find.text('tech_official'), findsOneWidget);
      expect(find.text('tech_channel'), findsOneWidget);

      // Tap suggestion chip
      await tester.tap(find.text('tech_official'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(controller.customUrl.text, 'tech_official');

      // Simulate Handle Available
      controller.customUrlAvailability.value = AvailabilityStatus.available;
      controller.customUrlAvailabilityMessage.value = 'Handle @tech_official is available!';
      controller.handleSuggestions.clear();
      await tester.pump();

      expect(find.text('Handle @tech_official is available!'), findsOneWidget);
      expect(find.text('Suggested handles:'), findsNothing);
    });
  });
}
