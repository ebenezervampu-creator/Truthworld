import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/animated_interaction_buttons.dart';

void main() {
  testWidgets('AnimatedSubscribeButton renders unsubscribed without overflow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedSubscribeButton(
              isSubscribed: false,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets(
      'AnimatedSubscribeButton transitions between subscribed and unsubscribed without overflow',
      (tester) async {
    final isSubscribed = false.obs;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Obx(
              () => AnimatedSubscribeButton(
                isSubscribed: isSubscribed.value,
                onPressed: () {
                  isSubscribed.value = !isSubscribed.value;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    // Tap to toggle to subscribed
    await tester.tap(find.byType(AnimatedSubscribeButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Subscribed'), findsOneWidget);

    // Tap to toggle back to unsubscribed
    await tester.tap(find.byType(AnimatedSubscribeButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Subscribe'), findsOneWidget);
  });
}
