import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_notification_options_sheet.dart';

class MockSubscriptionController extends ChannelSubscriptionController {
  bool updatePrefCalled = false;
  String? updatedOption;
  bool unsubscribeCalled = false;

  MockSubscriptionController() {
    isSubscribed.value = true;
    notificationsEnabled.value = true;
    notificationOption.value = 'personalized';
  }

  @override
  Future<void> updateNotificationPreference(
    String channelId,
    String option,
  ) async {
    updatePrefCalled = true;
    updatedOption = option;
    notificationOption.value = option;
    getNotificationOption(channelId).value = option;
    notificationsEnabled.value = option != 'none';
  }

  @override
  Future<bool> unsubscribeFromChannel(String channelId) async {
    unsubscribeCalled = true;
    isSubscribed.value = false;
    return true;
  }
}

void main() {
  group('ChannelNotificationOptionsSheet Widget Tests', () {
    late MockSubscriptionController subCtrl;

    setUp(() {
      Get.reset();
      subCtrl = MockSubscriptionController();
    });

    Widget createTestApp() {
      return GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ChannelNotificationOptionsSheet.show(
                  context: context,
                  channelId: 'test_channel_123',
                  channelName: 'Truth World Official',
                  subCtrl: subCtrl,
                );
              },
              child: const Text('Open Options'),
            ),
          ),
        ),
      );
    }

    testWidgets('shows Options title and all notification levels', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Options'), findsOneWidget);

      // Options & Subtitles
      expect(find.text('All'), findsOneWidget);
      expect(find.text("You'll get all notifications"), findsOneWidget);

      expect(find.text('Personalized'), findsOneWidget);
      expect(find.text("You'll get personalized notifications"), findsOneWidget);

      expect(find.text('None'), findsOneWidget);
      expect(find.text('Turn off all notifications'), findsOneWidget);

      expect(find.text('Unsubscribe'), findsOneWidget);

      // Personalized is selected initially with a checkmark
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping All updates notification preference to all', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(subCtrl.updatePrefCalled, isTrue);
      expect(subCtrl.updatedOption, equals('all'));
    });

    testWidgets('tapping None updates notification preference to none', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      expect(subCtrl.updatePrefCalled, isTrue);
      expect(subCtrl.updatedOption, equals('none'));
    });

    testWidgets('tapping Unsubscribe opens confirmation dialog and confirms', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unsubscribe'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Unsubscribe from Truth World Official?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Unsubscribe confirmation button
      final unsubscribeConfirmButton = find.widgetWithText(ElevatedButton, 'Unsubscribe');
      expect(unsubscribeConfirmButton, findsOneWidget);
      await tester.tap(unsubscribeConfirmButton);
      await tester.pumpAndSettle();

      expect(subCtrl.unsubscribeCalled, isTrue);
    });
  });
}
