import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo renders Image.asset with correct asset path',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(size: 40),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final Image imageWidget = tester.widget(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final AssetImage assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, equals('assets/app_logo.png'));
    expect(imageWidget.width, equals(40));
    expect(imageWidget.height, equals(40));
  });

  testWidgets('AppLogo renders with showText', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(
            size: 32,
            showText: true,
            text: 'Truthworld Premium',
          ),
        ),
      ),
    );

    expect(find.text('Truthworld Premium'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('AppLogo handles onTap', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppLogo(
            size: 32,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppLogo));
    expect(tapped, isTrue);
  });
}
