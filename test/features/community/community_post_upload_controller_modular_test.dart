import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  late CommunityPostUploadController controller;

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    controller = CommunityPostUploadController();
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  group('CommunityPostUploadStateBase Tests', () {
    test('initial state is properly configured', () {
      expect(controller.hasConfirmedCopyrightDeclaration.value, isTrue);
      expect(controller.hasPoll.value, isFalse);
      expect(controller.pollType.value, PollType.yesNo);
      expect(controller.selectedCategory.value, 'General');
      expect(controller.selectedVisibility.value, 'Public');
      expect(controller.isKidFriendly.value, isFalse);
      expect(controller.isScheduled.value, isFalse);
      expect(controller.isLikeEnabled.value, isTrue);
      expect(controller.isCommentsEnabled.value, isTrue);
      expect(controller.canPublish, isFalse);
    });

    test('canPublish checks channel, poll and moderation', () {
      final channel = Channel(
        id: 'test_chan',
        name: 'Test Channel',
        nameLowercase: 'test channel',
        handle: 'test',
        handleLowercase: 'test',
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: '',
        description: '',
        subscriberCount: 10,
        videoCount: 5,
        ownerId: 'owner1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // No channel yet -> false
      expect(controller.canPublish, isFalse);

      controller.selectedChannel.value = channel;
      // Channel selected without copyright block -> true
      expect(controller.canPublish, isTrue);

      // With poll and empty question -> false
      controller.hasPoll.value = true;
      controller.pollQuestion.value = '';
      expect(controller.canPublish, isFalse);

      controller.pollQuestion.value = 'What is your opinion?';
      expect(controller.canPublish, isTrue);

      // If image rejected -> false
      controller.moderationStatuses[0] = 'REJECTED';
      expect(controller.canPublish, isFalse);
    });
  });

  group('CommunityPostPollFormMixin Tests', () {
    test(
      'togglePoll enables poll and initializes multiChoice default options',
      () {
        controller.togglePoll(true);
        expect(controller.hasPoll.value, isTrue);
        expect(controller.pollOptions.length, 3);

        controller.togglePoll(false);
        expect(controller.hasPoll.value, isFalse);
      },
    );

    test(
      'addPollOption adds options up to 5 and removePollOption enforces minimum 3',
      () {
        controller.togglePoll(true);
        expect(controller.pollOptions.length, 3);

        controller.addPollOption();
        expect(controller.pollOptions.length, 4);

        controller.addPollOption();
        expect(controller.pollOptions.length, 5);

        // Max 5
        controller.addPollOption();
        expect(controller.pollOptions.length, 5);

        // Remove down to 3
        controller.removePollOption(4);
        expect(controller.pollOptions.length, 4);

        controller.removePollOption(3);
        expect(controller.pollOptions.length, 3);

        // Cannot remove below 3
        controller.removePollOption(2);
        expect(controller.pollOptions.length, 3);
      },
    );

    test('updatePollOption updates text at index', () {
      controller.togglePoll(true);
      controller.updatePollOption(0, 'Option A');
      expect(controller.pollOptions[0], 'Option A');
    });

    test('resetForm clears all fields and draft state', () {
      controller.hasConfirmedCopyrightDeclaration.value = true;
      controller.titleCtrl.text = 'My Post Title';
      controller.descCtrl.text = 'Description here';
      controller.selectedCategory.value = 'Announcement';

      controller.resetForm();

      expect(controller.hasConfirmedCopyrightDeclaration.value, isTrue);
      expect(controller.titleCtrl.text, isEmpty);
      expect(controller.descCtrl.text, isEmpty);
      expect(controller.selectedCategory.value, 'General');
      expect(controller.currentDraft.value, isNull);
    });

    test('loadDraft populates form fields from CommunityDraft', () {
      final draft = CommunityDraft(
        id: 'draft_123',
        ownerId: 'owner_1',
        channelId: 'chan_1',
        type: 'post',
        title: 'Draft Post',
        description: 'Draft Description',
        tags: ['tag1', 'tag2'],
        category: 'Feedback',
        visibility: 'Public',
        isKidFriendly: true,
        imageUrls: ['https://example.com/img1.jpg'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      controller.loadDraft(draft);

      expect(controller.currentDraft.value?.id, 'draft_123');
      expect(controller.titleCtrl.text, 'Draft Post');
      expect(controller.descCtrl.text, 'Draft Description');
      expect(controller.selectedCategory.value, 'Feedback');
      expect(controller.isKidFriendly.value, isTrue);
      expect(controller.imageUrls, contains('https://example.com/img1.jpg'));
    });
  });

  group('CommunityPostChannelTopicMixin Tests', () {
    test('selectChannel and getChannelMetadata', () {
      final channel = Channel(
        id: 'c1',
        name: 'Truth Creator',
        nameLowercase: 'truth creator',
        handle: 'truthcreator',
        handleLowercase: 'truthcreator',
        avatarUrl: 'https://example.com/avatar.png',
        bannerUrl: '',
        description: '',
        subscriberCount: 100,
        videoCount: 10,
        ownerId: 'user1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      controller.channels.add(channel);
      controller.selectChannel(channel);
      expect(controller.selectedChannel.value?.channelId, 'c1');

      final meta = controller.getChannelMetadata('c1');
      expect(meta, isNotNull);
      expect(meta!['name'], 'Truth Creator');
      expect(meta['handle'], 'truthcreator');

      final unknownMeta = controller.getChannelMetadata('unknown_id');
      expect(unknownMeta, isNull);
    });
  });

  group('CommunityPostImagesMixin Tests', () {
    test('removeImage cleans pickedImages and imageUrls at index', () {
      controller.pickedImages.add(
        PlatformFile(name: 'test.jpg', size: 1024),
      );
      controller.imageUrls.add('https://example.com/test.jpg');
      controller.moderationStatuses[0] = 'APPROVED';

      expect(controller.pickedImages.length, 1);
      expect(controller.imageUrls.length, 1);

      controller.removeImage(0);

      expect(controller.pickedImages, isEmpty);
      expect(controller.imageUrls, isEmpty);
      expect(controller.moderationStatuses.containsKey(0), isFalse);
    });
  });
}
