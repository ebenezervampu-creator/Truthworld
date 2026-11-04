import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/core/widgets/google_logo.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  setUp(() {
    Get.testMode = false;
  });

  group('TruthWorld Snackbar & Toast Redesign (Image 2 & Image 3 Specifications)', () {
    testWidgets('Image 2 Specification: Sign-in snackbar renders white theme, red badge, and Google button', (tester) async {
      var signedInTriggered = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  AppSnackbar.signInRequired(
                    title: 'Sign In Required',
                    message: 'Please sign in with your Google account to post a comment.',
                    onAction: () {
                      signedInTriggered = true;
                    },
                  );
                },
                child: const Text('Trigger Sign In'),
              ),
            ),
          ),
        ),
      );

      // Trigger snackbar
      await tester.tap(find.text('Trigger Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Title and Message text
      expect(find.text('Sign In Required:'), findsOneWidget);
      expect(
        find.text('Please sign in with your Google account to post a comment.'),
        findsOneWidget,
      );

      // Verify Google Logo is present in the button
      expect(find.byType(GoogleLogo), findsOneWidget);

      // Verify "Sign In" button is present and tappable
      expect(find.text('Sign In'), findsOneWidget);

      // Verify Red Warning Icon is present
      final iconFinder = find.byIcon(Icons.warning_rounded);
      expect(iconFinder, findsOneWidget);

      // Verify Icon Color is bright red inside the soft pink/red container
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, const Color(0xFFFF1744));

      // Verify absolute white background of the snackbar container
      final snackbarMaterial = tester.widgetList<Material>(find.byType(Material)).firstWhere(
        (m) => m.color == Colors.white,
      );
      expect(snackbarMaterial.color, Colors.white);

      // Tap Sign In button and verify callback
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(signedInTriggered, isTrue);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Automatic Sign-in Detection: AppSnackbar.show with Sign In title routes to Image 2 design', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  AppSnackbar.show(
                    'Sign In Required',
                    'Please sign in to save ads.',
                  );
                },
                child: const Text('Trigger Legacy Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Legacy Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Automatically recognized as sign-in prompt
      expect(find.text('Sign In Required:'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Image 3 Specification: Standard snackbar renders absolute white theme, black icon, and outlined button', (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  AppToast.warning(
                    'Your network connection is unstable.',
                    title: 'Offline Warning',
                    actionLabel: 'Retry',
                    onAction: () {
                      actionTriggered = true;
                    },
                  );
                },
                child: const Text('Trigger Warning'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify solid black icon directly on white background
      final warningIconFinder = find.byIcon(Icons.warning_rounded);
      expect(warningIconFinder, findsOneWidget);
      final warningIcon = tester.widget<Icon>(warningIconFinder);
      expect(warningIcon.color, Colors.black);

      // Verify outlined button with black text
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify absolute white card background
      final snackbarMaterial = tester.widgetList<Material>(find.byType(Material)).firstWhere(
        (m) => m.color == Colors.white,
      );
      expect(snackbarMaterial.color, Colors.white);

      // Verify action callback
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(actionTriggered, isTrue);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Image 3 Specification: Success snackbar renders with solid black check icon', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  AppSnackbar.success('Link copied to clipboard');
                },
                child: const Text('Trigger Success'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Link copied to clipboard'), findsOneWidget);
      final checkIconFinder = find.byIcon(Icons.check_circle_rounded);
      expect(checkIconFinder, findsOneWidget);
      final checkIcon = tester.widget<Icon>(checkIconFinder);
      expect(checkIcon.color, Colors.black);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });
  });
}
