import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo renders Image.asset with correct asset path',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(size: 40),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, equals('assets/app_logo.png'));
    expect(imageWidget.width, equals(40));
    expect(imageWidget.height, equals(40));
  });

  testWidgets('AppLogo renders with showText', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(
            showText: true,
            text: 'Truthworld Premium',
          ),
        ),
      ),
    );

    expect(find.text('Truthworld Premium'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('AppLogo handles onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppLogo(
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
