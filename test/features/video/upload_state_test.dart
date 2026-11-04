import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('UploadState Dataclass Unit Tests', () {
    test('Default instance has correct canonical defaults', () {
      const state = UploadState();

      expect(state.selectedChannel, isNull);
      expect(state.channels, isEmpty);
      expect(state.isChannelsLoading, isTrue);
      expect(state.channelsError, isEmpty);
      expect(state.todayUploadedDurationSeconds, 0);
      expect(state.remainingDailyDurationSeconds, 600);
      expect(state.isDailyLimitReached, isFalse);
      expect(state.isQuotaLoading, isFalse);
      expect(state.pickedVideo, isNull);
      expect(state.pickedImage, isNull);
      expect(state.isUploading, isFalse);
      expect(state.uploadProgress, 0.0);
      expect(state.uploadProgressPercent, '0%');
      expect(state.hasPickedVideo, isFalse);
      expect(state.hasSelectedChannel, isFalse);
      expect(state.isVideoContentApproved, isFalse);
      expect(state.isVideoContentRejected, isFalse);
      expect(state.dailyQuotaUsedRatio, 0.0);
    });

    test('copyWith updates specified fields and preserves untouched fields', () {
      const state = UploadState();
      final updated = state.copyWith(
        isUploading: true,
        uploadProgress: 0.75,
        todayUploadedDurationSeconds: 300,
        remainingDailyDurationSeconds: 300,
      );

      expect(updated.isUploading, isTrue);
      expect(updated.uploadProgress, 0.75);
      expect(updated.uploadProgressPercent, '75%');
      expect(updated.todayUploadedDurationSeconds, 300);
      expect(updated.remainingDailyDurationSeconds, 300);
      expect(updated.selectedCategory, ''); // Preserved
      expect(updated.channels, isEmpty); // Preserved
    });

    test('copyWith supports explicit null assignment for nullable fields', () {
      final sampleFile = PlatformFile(name: 'test.mp4', size: 1024);
      final initial = const UploadState().copyWith(
        pickedVideo: sampleFile,
        currentVideoId: 'video_123',
      );

      expect(initial.pickedVideo, sampleFile);
      expect(initial.currentVideoId, 'video_123');

      final nulled = initial.copyWith(
        pickedVideo: null,
        currentVideoId: null,
      );

      expect(nulled.pickedVideo, isNull);
      expect(nulled.currentVideoId, isNull);
    });

    test('resetUploads clears upload-specific state while preserving channels and topics', () {
      final dummyChannel = Channel(
        id: 'chan_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truth',
        handleLowercase: '@truth',
        description: 'test',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'user_1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      final dirtyState = UploadState(
        selectedChannel: dummyChannel,
        channels: [dummyChannel],
        isUploading: true,
        uploadProgress: 0.85,
        videoUrl: 'https://storage.googleapis.com/video.mp4',
        thumbnailUrl: 'https://storage.googleapis.com/thumb.jpg',
        currentVideoId: 'v_999',
        isScheduled: true,
      );

      final reset = dirtyState.resetUploads();

      expect(reset.isUploading, isFalse);
      expect(reset.uploadProgress, 0.0);
      expect(reset.videoUrl, isEmpty);
      expect(reset.thumbnailUrl, isEmpty);
      expect(reset.currentVideoId, isNull);
      expect(reset.isScheduled, isFalse);
      // Preserved channel selection and channels list
      expect(reset.selectedChannel, dummyChannel);
      expect(reset.channels, [dummyChannel]);
    });

    test('operator == and hashCode enforce value-object semantics', () {
      const state1 = UploadState();
      const state2 = UploadState();

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));

      final state3 = state1.copyWith(isUploading: true);
      expect(state1, isNot(equals(state3)));
    });
  });

  group('UploadController Atomic State Integration Tests', () {
    late UploadController controller;

    setUp(() {
      Get.reset();
      controller = UploadController();
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Controller initializes with canonical UploadState', () {
      expect(controller.uploadState.value, isNotNull);
      expect(controller.uploadState.value.isUploading, isFalse);
      expect(controller.isUploading.value, isFalse);
      expect(controller.uploadProgress.value, 0.0);
    });

    test('updateState emits atomic snapshot and synchronizes backward-compatible primitives', () {
      var stateEmissionCount = 0;
      controller.uploadState.listen((_) {
        stateEmissionCount++;
      });

      controller.updateState((s) => s.copyWith(
            isUploading: true,
            uploadProgress: 0.5,
            todayUploadedDurationSeconds: 150,
          ));

      expect(stateEmissionCount, 1,
          reason: 'State update must emit exactly one notification');
      expect(controller.uploadState.value.isUploading, isTrue);
      expect(controller.uploadState.value.uploadProgress, 0.5);
      expect(controller.uploadState.value.todayUploadedDurationSeconds, 150);

      // Verify backward-compatible Rx getters were synchronously updated
      expect(controller.isUploading.value, isTrue);
      expect(controller.uploadProgress.value, 0.5);
      expect(controller.todayUploadedDurationSeconds.value, 150);
    });

    test('Legacy direct mutation of Rx primitives synchronizes into uploadState', () {
      final channel = Channel(
        id: 'chan_abc',
        name: 'Verified Media',
        nameLowercase: 'verified media',
        handle: '@verified',
        handleLowercase: '@verified',
        description: 'test',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'user_456',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // Trigger legacy setter
      controller.selectedChannel.value = channel;

      expect(controller.uploadState.value.selectedChannel, channel);
    });

    test('resetUploads clears state in a single tick', () {
      controller.updateState((s) => s.copyWith(
            isUploading: true,
            uploadProgress: 0.99,
            videoUrl: 'https://test.mp4',
          ));

      controller.resetUploads();

      expect(controller.uploadState.value.isUploading, isFalse);
      expect(controller.uploadState.value.uploadProgress, 0.0);
      expect(controller.uploadState.value.videoUrl, isEmpty);
      expect(controller.isUploading.value, isFalse);
      expect(controller.uploadProgress.value, 0.0);
      expect(controller.videoUrl.value, isEmpty);
    });
  });
}
