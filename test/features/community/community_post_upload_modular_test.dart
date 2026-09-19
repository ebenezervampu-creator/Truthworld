import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/community_post_upload_screen.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/presentation/views/upload/community_upload_components.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('CommunityPostUpload Modular Presentation Tests', () {
    testWidgets('CommunityUploadHeader renders title, subtitle and back navigation button', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityUploadHeader(isMobile: false),
        ),
      );

      expect(find.text('Create Community Post'), findsOneWidget);
      expect(
        find.text('Share updates, thoughts, or important announcements with your community.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('CommunityUploadSectionCard renders title, subtitle and children', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityUploadSectionCard(
            title: 'Custom Section',
            subtitle: 'Section description here',
            children: [
              Text('Child Item 1'),
              Text('Child Item 2'),
            ],
          ),
        ),
      );

      expect(find.text('Custom Section'), findsOneWidget);
      expect(find.text('Section description here'), findsOneWidget);
      expect(find.text('Child Item 1'), findsOneWidget);
      expect(find.text('Child Item 2'), findsOneWidget);
    });

    testWidgets('CommunityImagePickerDropzone renders initial upload UI with Choose file button', (tester) async {
      Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityImagePickerDropzone(),
        ),
      );

      expect(find.text('Drag & drop your image here'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);
      expect(find.text('JPG, PNG, WEBP up to 10MB'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityPostVisibilitySection renders all 5 visibility options and updates controller', (tester) async {
      final controller = Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityPostVisibilitySection(),
        ),
      );

      expect(find.text('2. Visibility'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Subscribers only'), findsOneWidget);
      expect(find.text('Made for kids'), findsOneWidget);

      // Tap on Members
      await tester.tap(find.text('Members'));
      await tester.pump();

      expect(controller.selectedVisibility.value, equals('Members'));

      // Tap on Made for kids
      await tester.tap(find.text('Made for kids'));
      await tester.pump();

      expect(controller.selectedVisibility.value, equals('Made for kids'));
      expect(controller.isKidFriendly.value, isTrue);

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityPostAdditionalOptions renders toggles and mutates controller state', (tester) async {
      final controller = Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityPostAdditionalOptions(),
        ),
      );

      expect(find.text('3. Additional Options'), findsOneWidget);
      expect(find.text('Made for kids'), findsOneWidget);
      expect(find.text('Allow comments'), findsOneWidget);
      expect(find.text('Pin this post'), findsOneWidget);

      expect(controller.isPinnedPost.value, isFalse);
      // Toggle 'Pin this post'
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));

      await tester.tap(switches.at(2));
      await tester.pump();

      expect(controller.isPinnedPost.value, isTrue);

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityCopyrightDeclarationCard toggles confirmation reactive state', (tester) async {
      final controller = Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityCopyrightDeclarationCard(),
        ),
      );

      expect(find.text('Creator Copyright & Rights Declaration'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
      expect(controller.hasConfirmedCopyrightDeclaration.value, isFalse);

      // Tap to toggle confirmation
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(controller.hasConfirmedCopyrightDeclaration.value, isTrue);

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityUploadActionButtons renders save draft, schedule and publish buttons', (tester) async {
      final controller = Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        createWidgetUnderTest(
          const CommunityUploadActionButtons(),
        ),
      );

      expect(find.text('Save as draft'), findsOneWidget);
      expect(find.text('Schedule for later'), findsOneWidget);
      expect(find.text('Review & Publish'), findsOneWidget);

      // Toggle schedule switch
      final scheduleSwitch = find.byType(Switch);
      await tester.tap(scheduleSwitch);
      await tester.pump();

      expect(controller.isScheduled.value, isTrue);
      expect(find.text('Schedule & Publish'), findsOneWidget);

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityPostContentInputs renders title and description fields with counters', (tester) async {
      final controller = Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        createWidgetUnderTest(
          Form(
            key: controller.formKey,
            child: const CommunityPostContentInputs(),
          ),
        ),
      );

      expect(find.text('1. Post Content'), findsOneWidget);
      expect(find.text('0/100'), findsOneWidget);
      expect(find.text('0/2000'), findsOneWidget);

      // Enter title
      await tester.enterText(find.byType(TextFormField).first, 'Test Community Title');
      await tester.pump();

      expect(find.text('20/100'), findsOneWidget);
      expect(controller.titleCtrl.text, equals('Test Community Title'));

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityPostUploadScreen renders full responsive layout declaratively', (tester) async {
      Get.put(CommunityPostUploadController());

      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityPostUploadScreen(),
        ),
      );

      expect(find.text('Create Community Post'), findsOneWidget);
      expect(find.text('1. Post Content'), findsOneWidget);
      expect(find.text('2. Visibility'), findsOneWidget);
      expect(find.text('3. Additional Options'), findsOneWidget);
      expect(find.text('Creator Copyright & Rights Declaration'), findsOneWidget);
      expect(find.text('Review & Publish'), findsOneWidget);

      Get.delete<CommunityPostUploadController>();
    });

    testWidgets('CommunityPostUploadScreen loads draft for backward compatibility', (tester) async {
      final controller = Get.put(CommunityPostUploadController());

      final draft = CommunityDraft(
        id: 'draft_77',
        ownerId: 'owner_test',
        channelId: 'channel_test',
        type: 'post',
        title: 'Loaded Draft Title',
        description: 'Loaded Draft Description for testing',
        category: 'Discussion',
        visibility: 'Private',
        isKidFriendly: true,
        imageUrls: const ['https://example.com/draft_image.jpg'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityPostUploadScreen(draftToLoad: draft),
        ),
      );

      expect(controller.titleCtrl.text, equals('Loaded Draft Title'));
      expect(controller.descCtrl.text, equals('Loaded Draft Description for testing'));
      expect(controller.selectedCategory.value, equals('Discussion'));
      expect(controller.selectedVisibility.value, equals('Private'));
      expect(controller.isKidFriendly.value, isTrue);

      Get.delete<CommunityPostUploadController>();
    });
  });
}
