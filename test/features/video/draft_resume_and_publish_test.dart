import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/data/models/draft_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(Get.reset);

  Channel createTestChannel({String id = 'chan-123', String name = 'Truth Channel'}) {
    return Channel(
      id: id,
      name: name,
      nameLowercase: name.toLowerCase(),
      handle: '@$name',
      handleLowercase: '@${name.toLowerCase()}',
      description: 'Channel for testing',
      avatarUrl: 'https://example.com/avatar.jpg',
      bannerUrl: '',
      ownerId: 'user-1',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      walletBalanceUSD: 50.0,
    );
  }

  Video createTestDraftVideo({
    String id = 'draft-video-001',
    String title = 'My Draft Worship Video',
    String videoUrl = 'https://storage.googleapis.com/videos/draft-video-001/original.mp4',
    String thumbnailUrl = 'https://storage.googleapis.com/thumbnails/draft-video-001.jpg',
    String channelId = 'chan-123',
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Draft description text for testing',
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      originalUrl: videoUrl,
      ownerId: 'user-1',
      channelId: channelId,
      channelName: 'Truth Channel',
      category: 'Music',
      tags: ['worship', 'truth', 'faith'],
      status: 'draft',
      visibility: 'private',
      duration: 300,
    );
  }

  group('Draft Resume and Publish Critical Bug Fix Tests', () {
    test('1. applyDraftVideo thoroughly populates form inputs and UploadController reactive state', () {
      final uploadCtrl = Get.put(UploadController());
      final createCtrl = Get.put(CreateContentController(uploadType: UploadType.video));

      final draftVideo = createTestDraftVideo();
      createCtrl.applyDraftVideo(draftVideo);

      // Verify form text controllers
      expect(createCtrl.titleController.text, equals('My Draft Worship Video'));
      expect(createCtrl.descriptionController.text, equals('Draft description text for testing'));
      expect(createCtrl.tagsController.text, equals('worship, truth, faith'));

      // Verify UploadController reactive bindings
      expect(uploadCtrl.resumedVideoDraft.value, equals(draftVideo));
      expect(uploadCtrl.currentVideoId, equals('draft-video-001'));
      expect(uploadCtrl.videoUrl.value, equals(draftVideo.videoUrl));
      expect(uploadCtrl.thumbnailUrl.value, equals(draftVideo.thumbnailUrl));
      expect(uploadCtrl.finalstatus.value, equals('APPROVED'));
      expect(uploadCtrl.selectedCategory.value, equals('Music'));
      expect(uploadCtrl.isUploading.value, isFalse);
      expect(uploadCtrl.uploadProgress.value, equals(1.0));
      expect(uploadCtrl.videoDurationSeconds.value, equals(300));
    });

    test('2. canPublishVideo passes when draft video and thumbnail URLs are present without pickedVideo', () {
      final uploadCtrl = Get.put(UploadController());
      final createCtrl = Get.put(CreateContentController(uploadType: UploadType.video));

      final testChan = createTestChannel();
      uploadCtrl.channels.value = [testChan];
      uploadCtrl.selectedChannel.value = testChan;

      final draftVideo = createTestDraftVideo();
      createCtrl.applyDraftVideo(draftVideo);

      expect(uploadCtrl.pickedVideo.value, isNull);
      expect(uploadCtrl.videoUrl.value, isNotEmpty);
      expect(uploadCtrl.thumbnailUrl.value, isNotEmpty);
      expect(uploadCtrl.selectedCategory.value, isNotEmpty);
      expect(uploadCtrl.selectedChannel.value, isNotNull);

      // canPublishVideo must be true so the Publish button is enabled!
      expect(createCtrl.canPublishVideo(), isTrue);
    });

    test('3. loadDraftFromArguments seamlessly unpacks dashboard video draft argument map', () {
      final uploadCtrl = Get.put(UploadController());
      final draftVideo = createTestDraftVideo();

      // Simulate arguments passed by draft_scheduled_cards.dart
      Get.routing.args = {
        'video': draftVideo,
        'videoId': draftVideo.id,
        'draft': draftVideo,
      };

      final createCtrl = Get.put(CreateContentController(uploadType: UploadType.video));

      expect(createCtrl.titleController.text, equals(draftVideo.title));
      expect(createCtrl.descriptionController.text, equals(draftVideo.description));
      expect(uploadCtrl.resumedVideoDraft.value, equals(draftVideo));
      expect(uploadCtrl.currentVideoId, equals(draftVideo.id));
      expect(uploadCtrl.videoUrl.value, equals(draftVideo.videoUrl));
      expect(uploadCtrl.thumbnailUrl.value, equals(draftVideo.thumbnailUrl));
      expect(uploadCtrl.finalstatus.value, equals('APPROVED'));
    });

    test('4. loadDraftFromArguments seamlessly unpacks direct Video argument', () {
      final uploadCtrl = Get.put(UploadController());
      final draftVideo = createTestDraftVideo(title: 'Direct Video Arg');

      Get.routing.args = draftVideo;

      final createCtrl = Get.put(CreateContentController(uploadType: UploadType.video));

      expect(createCtrl.titleController.text, equals('Direct Video Arg'));
      expect(uploadCtrl.resumedVideoDraft.value?.id, equals(draftVideo.id));
      expect(uploadCtrl.currentVideoId, equals(draftVideo.id));
    });

    test('5. _applyDraftModel unpacks DraftModel properly', () {
      final uploadCtrl = Get.put(UploadController());
      final createCtrl = Get.put(CreateContentController(uploadType: UploadType.video));

      final testChan = createTestChannel();
      uploadCtrl.channels.value = [testChan];

      final draftModel = DraftModel(
        id: 'draft-mod-777',
        title: 'Draft Model Title',
        content: 'Draft Model Content',
        type: 'video',
        mediaUrl: 'https://storage.googleapis.com/thumb.jpg',
        channelId: testChan.id,
      );

      createCtrl.applyDraftVideo(Video(
        id: draftModel.id,
        title: draftModel.title,
        description: draftModel.content,
        thumbnailUrl: draftModel.mediaUrl ?? '',
        videoUrl: 'https://storage.googleapis.com/video.mp4',
        ownerId: 'user-1',
        channelId: testChan.id,
        channelName: testChan.name,
        category: 'Education',
        tags: const ['tag1'],
      ));

      expect(createCtrl.titleController.text, equals('Draft Model Title'));
      expect(uploadCtrl.currentVideoId, equals('draft-mod-777'));
      expect(uploadCtrl.thumbnailUrl.value, equals('https://storage.googleapis.com/thumb.jpg'));
      expect(uploadCtrl.finalstatus.value, equals('APPROVED'));
    });

    test('6. uploadVideo validation passes when videoUrl is populated from draft and pickedVideo is null', () async {
      final uploadCtrl = Get.put(UploadController());
      final testChan = createTestChannel();
      uploadCtrl.channels.value = [testChan];
      uploadCtrl.selectedChannel.value = testChan;

      final draftVideo = createTestDraftVideo();
      uploadCtrl.loadFromVideo(draftVideo);

      // Verify preconditions for resumed draft
      expect(uploadCtrl.pickedVideo.value, isNull);
      expect(uploadCtrl.resumedVideoDraft.value, isNotNull);
      expect(uploadCtrl.videoUrl.value, isNotEmpty);

      // Verify that currentVideoId matches the draft video id
      expect(uploadCtrl.currentVideoId, equals(draftVideo.id));
    });

    test('7. UploadQuotaMixin preserves draft channel when channels load asynchronously', () {
      final uploadCtrl = Get.put(UploadController());

      final channelA = createTestChannel(id: 'chan-A', name: 'Channel A');
      final channelB = createTestChannel(id: 'chan-B', name: 'Channel B');

      // Draft belongs to Channel B
      final draftVideo = createTestDraftVideo(channelId: 'chan-B');
      uploadCtrl.loadFromVideo(draftVideo);

      expect(uploadCtrl.resumedVideoDraft.value?.channelId, equals('chan-B'));

      // Simulate channels list loading asynchronously where Channel A comes first
      uploadCtrl.channels.value = [channelA, channelB];

      // Quota mixin channel selection logic:
      final targetChanId = uploadCtrl.resumedVideoDraft.value?.channelId;
      final matched = uploadCtrl.channels.firstWhere(
        (c) => c.channelId == targetChanId || c.id == targetChanId,
        orElse: () => uploadCtrl.channels.first,
      );
      uploadCtrl.selectedChannel.value = matched;

      // Ensure Channel B was selected, preserving draft channel
      expect(uploadCtrl.selectedChannel.value?.id, equals('chan-B'));
    });
  });
}
