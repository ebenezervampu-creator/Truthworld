import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  late CreateTopicController controller;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    controller = Get.put(CreateTopicController());
  });

  tearDown(Get.reset);

  Widget createHarness(Widget child) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('CreateTopicDialog Modular Components Tests', () {
    testWidgets('buildCreateTopicPageHeader renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildCreateTopicPageHeader(ctx, isDesktop: true),
          ),
        ),
      );

      expect(find.text('Create Topic'), findsOneWidget);
      expect(find.text('Build a topic to organize and curate videos around a theme.'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('buildCreateTopicProfanityAlert renders warning when error is present', (tester) async {
      await tester.pumpWidget(
        createHarness(
          buildCreateTopicProfanityAlert(controller),
        ),
      );

      expect(find.byIcon(Icons.gavel_rounded), findsNothing);

      controller.profanityError.value = 'Inappropriate term detected in topic name.';
      await tester.pump();

      expect(find.byIcon(Icons.gavel_rounded), findsOneWidget);
      expect(find.text('Inappropriate term detected in topic name.'), findsOneWidget);
    });

    testWidgets('buildSection1TopicName and buildSection2Handle render inputs', (tester) async {
      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => Column(
              children: [
                buildSection1TopicName(ctx, controller),
                buildSection2Handle(ctx, controller),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1. Topic Name'), findsOneWidget);
      expect(find.text('2. Handle'), findsOneWidget);
      expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
    });

    testWidgets('buildSection3Title, buildSection4Description, and buildSection5Tags render inputs and tag chips', (tester) async {
      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => Column(
              children: [
                buildSection3Title(ctx, controller),
                buildSection4Description(ctx, controller),
                buildSection5Tags(ctx, controller),
              ],
            ),
          ),
        ),
      );

      expect(find.text('3. Title'), findsOneWidget);
      expect(find.text('4. Description'), findsOneWidget);
      expect(find.text('5. Tags'), findsOneWidget);

      // Default tags
      expect(find.text('Space '), findsOneWidget);
      expect(find.text('Astronomy '), findsOneWidget);

      // Tap remove on first tag
      final closeIcons = find.byIcon(Icons.close_rounded);
      expect(closeIcons, findsWidgets);
      await tester.tap(closeIcons.first);
      await tester.pump();

      expect(controller.tagsList.contains('Space'), isFalse);
    });

    testWidgets('buildSection6Category and buildSection7TopicType render category and visibility options', (tester) async {
      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => Column(
              children: [
                buildSection6Category(ctx, controller, CreateTopicDialog.availableCategories),
                buildSection7TopicType(ctx, controller),
              ],
            ),
          ),
        ),
      );

      expect(find.text('6. Topic Category'), findsOneWidget);
      expect(find.text('7. Topic Type'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);

      // Switch to Private
      await tester.tap(find.text('Private'));
      await tester.pump();

      expect(controller.selectedVisibility.value, equals(TopicVisibilityType.private));
      expect(find.text('Enter Private Passcode'), findsOneWidget);
    });

    testWidgets('buildSection8AddVideos renders empty state and selected videos', (tester) async {
      final dummyVideos = [
        {'id': 'v1', 'title': 'Test Video 1', 'thumbnailUrl': 'https://example.com/1.jpg'},
        {'id': 'v2', 'title': 'Test Video 2', 'thumbnailUrl': 'https://example.com/2.jpg'},
      ];

      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildSection8AddVideos(
              ctx,
              controller,
              Future.value(dummyVideos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8. Add Videos'), findsOneWidget);
      expect(find.text('+ Select videos'), findsOneWidget);
      expect(find.text('No videos selected yet. (At least 1 video required)'), findsOneWidget);

      // Select video v1
      controller.selectedVideoIds.add('v1');
      await tester.pump();

      expect(find.text('+ Select videos (1)'), findsOneWidget);
      expect(find.text('Test Video 1'), findsOneWidget);
      expect(find.text('1 videos selected'), findsOneWidget);
    });

    testWidgets('buildSection9TopicImage renders video and custom image options', (tester) async {
      final dummyVideos = [
        {'id': 'v1', 'title': 'Test Video 1', 'thumbnailUrl': 'https://example.com/1.jpg'},
      ];

      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildSection9TopicImage(
              ctx,
              controller,
              Future.value(dummyVideos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9. Topic Image'), findsOneWidget);
      expect(find.text('Use thumbnail from selected video'), findsOneWidget);
      expect(find.text('Upload custom image'), findsOneWidget);

      // Switch to custom upload
      await tester.tap(find.text('Upload custom image'));
      await tester.pump();

      expect(controller.thumbnailSource.value, equals('custom'));
      expect(find.text('PNG, JPG or WEBP. Max 5MB.'), findsOneWidget);
    });

    testWidgets('buildCreateTopicDesktopFooterActions renders Cancel and Submit buttons', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildCreateTopicDesktopFooterActions(
              ctx,
              controller,
              (ctrl) async => submitted = true,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Topic'), findsOneWidget);

      // Fill in valid details to validate
      controller.nameController.text = 'Science Discovery';
      controller.handleController.text = 'science-discovery';
      controller.titleController.text = 'Science Discovery 2026';
      controller.selectedVideoIds.add('v1');

      await tester.tap(find.text('Create Topic'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
    });

    testWidgets('CreateTopicDialog coordinator widget renders successfully', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: CreateTopicDialog(
            isDarkMode: true,
            channelVideosFuture: Future.value([]),
            onCreateTopicSubmitted: (ctrl) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CreateTopicDialog), findsOneWidget);
      expect(find.text('Create Topic'), findsWidgets);
      expect(find.text('TRUTHWORLD'), findsOneWidget);
    });
  });
}
