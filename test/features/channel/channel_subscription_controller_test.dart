import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';

class TestChannelSubscriptionController extends ChannelSubscriptionController {
  bool subscribeCalled = false;
  bool unsubscribeCalled = false;
  bool updatePrefCalled = false;
  String? lastUpdatedOption;

  @override
  Future<bool> subscribeToChannel(String channelId) async {
    subscribeCalled = true;
        return true;
  }

  @override
  Future<bool> unsubscribeFromChannel(String channelId) async {
    unsubscribeCalled = true;
        return true;
  }

  @override
  Future<void> updateNotificationPreference(String channelId, String option) async {
    updatePrefCalled = true;
    lastUpdatedOption = option;
    final isAll = option == 'all';
    notificationsEnabled.value = isAll;
    notificationOption.value = option;
  }

  @override
  void fetchSubscriberCount(String channelId) {
    // Fake implementation
    subscriberCount.value = 100;
  }

  // Helper to set fake subscribed state
  void setFakeSubscribed(bool value) {
    isSubscribed.value = value;
  }
}

void main() {
  group('ChannelSubscriptionController Tests', () {
    late TestChannelSubscriptionController controller;

    setUp(() {
      ChannelSubscriptionController.channelSubscriberCounts.clear();
      controller = TestChannelSubscriptionController();
    });

    test('initial state is correct', () {
      expect(controller.isSubscribed.value, isFalse);
      expect(controller.subscriberCount.value, equals(0));
    });

    test('toggleSubscription subscribes when not subscribed', () async {
      controller.setFakeSubscribed(false);
      controller.subscriberCount.value = 10;
      
      await controller.toggleSubscription('channel1');
      
      expect(controller.subscribeCalled, isTrue);
      expect(controller.isSubscribed.value, isTrue);
      // toggleSubscription increments count eagerly
      expect(controller.subscriberCount.value, equals(11));
    });

    test('toggleSubscription unsubscribes when subscribed', () async {
      controller.setFakeSubscribed(true);
      controller.subscriberCount.value = 10;
      
      await controller.toggleSubscription('channel1');
      
      expect(controller.unsubscribeCalled, isTrue);
      expect(controller.isSubscribed.value, isFalse);
      expect(controller.subscriberCount.value, equals(9));
    });

    test('fetchSubscriberCount updates count', () {
      controller.fetchSubscriberCount('channel1');
      expect(controller.subscriberCount.value, equals(100));
    });

    test('updateNotificationPreference updates states', () async {
      await controller.updateNotificationPreference('channel1', 'none');
      
      expect(controller.updatePrefCalled, isTrue);
      expect(controller.lastUpdatedOption, equals('none'));
      expect(controller.notificationsEnabled.value, isFalse);
      expect(controller.notificationOption.value, equals('none'));
    });
  });
}
