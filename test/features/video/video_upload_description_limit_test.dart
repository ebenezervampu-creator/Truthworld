import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_metadata_sections.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Upload Description Box Character Limit (YouTube Parity)', () {
    const base = 'This is an authentic video description explaining the detailed educational topics. ';

    test('1. Constants match YouTube 5000 character specification', () {
      expect(ContentValidator.defaultMaxDescriptionLength, equals(5000));
      expect(UploadControllerBase.maxDescriptionLength, equals(5000));
    });

    test('2. ContentValidator validates description up to 5000 characters', () {
      final valid5000 = (base * (5000 ~/ base.length)) + base.substring(0, 5000 % base.length);
      expect(valid5000.length, equals(5000));
      final resultValid = ContentValidator.validate(valid5000, fieldName: 'Description');
      expect(resultValid.isValid, isTrue);

      final invalid5001 = '${valid5000}X';
      expect(invalid5001.length, equals(5001));
      final resultInvalid = ContentValidator.validate(invalid5001, fieldName: 'Description');
      expect(resultInvalid.isValid, isFalse);
      expect(resultInvalid.message, contains('5000'));
    });

    testWidgets('3. CreateContentDescriptionSection displays 5000 character limit and counter', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreateContentDescriptionSection(
                descriptionController: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial counter displays 0/5000
      expect(find.text('0/5000'), findsOneWidget);

      // Verify TextField max length is 5000
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, equals(5000));

      // Enter 100 characters
      controller.text = 'This is a test description for the video upload to verify YouTube character parity.'.padRight(100, '.');
      await tester.pump();
      expect(find.text('100/5000'), findsOneWidget);

      // Enter 5000 characters
      controller.text = (base * (5000 ~/ base.length)) + base.substring(0, 5000 % base.length);
      await tester.pump();
      expect(find.text('5000/5000'), findsOneWidget);
    });
  });
}
