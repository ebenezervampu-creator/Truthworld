import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

class TestDubbingStudioController extends DubbingStudioController {
  @override
  Future<void> refreshWallet() async {}

  @override
  Future<void> loadUserChannelAndVideos() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('Truthworld Dubbing & Studio Channel Videos Integration Tests', () {
    test('Initializes with channel_videos as primary source mode', () {
      final controller = Get.put(TestDubbingStudioController());
      expect(controller.sourceInputMode.value, 'channel_videos');
      expect(controller.channelVideos.isEmpty, isTrue);
      expect(controller.selectedChannelVideo.value, isNull);
    });

    test('Filters channel videos by title and description search query', () {
      final controller = Get.put(TestDubbingStudioController());

      final video1 = Video(
        id: 'vid_1',
        title: 'Science Documentary Episode 1',
        description: 'Deep dive into astrophysics',
        videoUrl: 'https://cdn.truthworld.in/videos/vid_1.mp4',
        thumbnailUrl: '',
        ownerId: 'creator_1',
        channelId: 'chan_1',
        channelName: 'Science Hub',
        category: 'education',
        tags: const ['science'],
        language: 'en',
        uploadedAt: Timestamp.now(),
        duration: 300,
        audioTracks: {'en': 'https://cdn.truthworld.in/audio/vid_1_en.mp3'},
      );

      final video2 = Video(
        id: 'vid_2',
        title: 'Tech Review 2026',
        description: 'Newest quantum hardware tested',
        videoUrl: 'https://cdn.truthworld.in/videos/vid_2.mp4',
        thumbnailUrl: '',
        ownerId: 'creator_1',
        channelId: 'chan_1',
        channelName: 'Science Hub',
        category: 'tech',
        tags: const ['technology'],
        language: 'te',
        uploadedAt: Timestamp.now(),
        duration: 180,
        audioTracks: {'te': 'https://cdn.truthworld.in/audio/vid_2_te.mp3'},
      );

      controller.channelVideos.assignAll([video1, video2]);
      controller.applyChannelVideoFilter();
      expect(controller.filteredChannelVideos.length, 2);

      // Search by title match
      controller.searchChannelVideos('Science');
      expect(controller.filteredChannelVideos.length, 1);
      expect(controller.filteredChannelVideos.first.id, 'vid_1');

      // Search by description match
      controller.searchChannelVideos('quantum');
      expect(controller.filteredChannelVideos.length, 1);
      expect(controller.filteredChannelVideos.first.id, 'vid_2');

      // Clear search
      controller.searchChannelVideos('');
      expect(controller.filteredChannelVideos.length, 2);
    });

    test('Selecting channel video populates project metadata and audio tracks', () async {
      final controller = Get.put(TestDubbingStudioController());

      final sampleVideo = Video(
        id: 'vid_100',
        title: 'Quantum Physics Explained Simply',
        description: 'Understanding quantum mechanics for beginners',
        videoUrl: 'https://cdn.truthworld.in/videos/vid_100.mp4',
        thumbnailUrl: '',
        ownerId: 'creator_100',
        channelId: 'chan_100',
        channelName: 'Physics World',
        category: 'science',
        tags: const ['physics'],
        language: 'en',
        uploadedAt: Timestamp.now(),
        duration: 600,
        audioTracks: {
          'en': 'https://cdn.truthworld.in/audio/vid_100_en.mp3',
          'es': 'https://cdn.truthworld.in/audio/vid_100_es.mp3',
        },
      );

      await controller.selectChannelVideo(sampleVideo);

      expect(controller.selectedChannelVideo.value?.id, 'vid_100');
      expect(controller.mediaTitle.value, 'Quantum Physics Explained Simply');
      expect(controller.mediaUrl.value, 'https://cdn.truthworld.in/videos/vid_100.mp4');
      expect(controller.sourceLanguage.value, 'en');
      expect(controller.estimatedDurationSeconds.value, 600);
      expect(controller.selectedVideoAudioTracks.containsKey('en'), isTrue);
      expect(controller.selectedVideoAudioTracks.containsKey('es'), isTrue);
    });

    test('DubbingJob model serializes videoId and channelId correctly', () {
      final job = DubbingJob(
        id: 'dub_test_vid_1',
        userId: 'user_1',
        title: 'Channel Dubbing Session',
        mode: DubbingMode.dubbing,
        status: DubbingJobStatus.transcribing,
        progressPercent: 30,
        currentStepMessage: 'Processing audio tracks',
        sourceMediaUrl: 'https://cdn.truthworld.in/videos/sample.mp4',
        sourceMediaType: 'video',
        durationSeconds: 120,
        characterCount: 1800,
        sourceLanguage: 'en',
        targetLanguages: ['te', 'hi'],
        voiceCloningEnabled: true,
        twoStageReviewEnabled: false,
        publishToTruthworld: true,
        costUsd: 1.0,
        totalCharactersCharged: 3600,
        speakers: [],
        segmentsByLanguage: {},
        videoId: 'vid_channel_123',
        channelId: 'chan_creator_456',
        createdAt: DateTime.now(),
      );

      expect(job.videoId, 'vid_channel_123');
      expect(job.channelId, 'chan_creator_456');

      final map = {
        'id': 'dub_test_vid_1',
        'userId': 'user_1',
        'title': 'Channel Dubbing Session',
        'status': 'transcribing',
        'videoId': 'vid_channel_123',
        'channelId': 'chan_creator_456',
        'targetLanguages': ['te', 'hi'],
      };

      final parsed = DubbingJob.fromMap(map);
      expect(parsed.videoId, 'vid_channel_123');
      expect(parsed.channelId, 'chan_creator_456');
    });

    test('Studio Wallet spendable balance reflects channel balance correctly', () {
      final controller = Get.put(TestDubbingStudioController());

      // No channel yet
      expect(controller.studioWalletSpendableBalance, 0.0);

      // Channel with funded balance and rollover
      final channel = Channel.fromMap({
        'ownerId': 'creator_1',
        'name': 'Creator Hub',
        'handle': 'creatorhub',
        'walletBalanceUSD': 25.0,
      }, 'chan_studio_1');

      controller.userChannel.value = channel;
      expect(controller.studioWalletSpendableBalance, 25.0);
    });

    test('Purchase tier selection updates selected purchase tier correctly', () {
      final controller = Get.put(TestDubbingStudioController());

      expect(controller.selectedPurchaseTierUsd.value, 10);
      controller.selectedPurchaseTierUsd.value = 5;
      expect(controller.selectedPurchaseTierUsd.value, 5);
      controller.selectedPurchaseTierUsd.value = 50;
      expect(controller.selectedPurchaseTierUsd.value, 50);
    });

    test('Purchase with Studio Wallet checks balance and prevents overdraw', () async {
      final controller = Get.put(TestDubbingStudioController());

      // Without channel
      final resNoChan = await controller.purchaseCreditsWithStudioWallet(
        amountUsd: 10,
        credits: 20000,
      );
      expect(resNoChan, isFalse);

      // Channel with insufficient balance ($5 vs $20 requested)
      controller.userChannel.value = Channel.fromMap({
        'ownerId': 'creator_2',
        'name': 'Tech Channel',
        'handle': 'techchan',
        'walletBalanceUSD': 5.0,
      }, 'chan_studio_2');

      final resUnderfunded = await controller.purchaseCreditsWithStudioWallet(
        amountUsd: 20,
        credits: 45000,
      );
      expect(resUnderfunded, isFalse);
    });

    test('hasSufficientBalance enforces funded USD studio wallet balance unless 100% free waiver is active', () {
      final controller = Get.put(TestDubbingStudioController());

      // Personal wallet initialized with 0 credits and $0 USD channel balance
      controller.wallet.value = const DubbingWallet(userId: 'test_user', balanceCredits: 0);
      expect(controller.wallet.value?.balanceCredits, 0);

      final unfundedChannel = Channel.fromMap({
        'ownerId': 'test_user',
        'name': 'Ebenezer Vampu',
        'handle': 'ebenezervampu',
        'freeDubbingCredits': 10000,
        'walletBalanceUSD': 0.0,
      }, 'chan_ebenezer');
      controller.userChannel.value = unfundedChannel;

      expect(controller.channelFreeCredits, 10000);
      expect(controller.totalAvailableCharacters, 10000);
      expect(controller.isFreeDubbingActive, isFalse);

      controller.estimatedDurationSeconds.value = 120; // 2 mins * 2 langs * $0.30 = $1.20
      controller.estimatedCharacterCount.value = 2500;
      controller.targetLanguages.assignAll(['te', 'hi']);
      expect(controller.totalCharactersRequired, 5000);
      expect(controller.hasSufficientBalance, isFalse);

      // Once funded in USD Studio Wallet, balance is sufficient
      controller.userChannel.value = Channel.fromMap({
        'ownerId': 'test_user',
        'name': 'Ebenezer Vampu',
        'handle': 'ebenezervampu',
        'freeDubbingCredits': 10000,
        'walletBalanceUSD': 5.0,
      }, 'chan_ebenezer');
      expect(controller.hasSufficientBalance, isTrue);
    });

    test('Channel with 100% free dubbing waiver allows dubbing with 0 balance', () {
      final controller = Get.put(TestDubbingStudioController());

      // Personal wallet 0, channel 0 credits, but Super Admin granted 100% Free
      controller.wallet.value = const DubbingWallet(userId: 'test_user', balanceCredits: 0);
      final channel = Channel.fromMap({
        'ownerId': 'test_user',
        'name': 'Ebenezer Vampu',
        'handle': 'ebenezervampu',
        'dubbingDiscountType': 'free',
        'dubbingDiscountPercent': 100.0,
      }, 'chan_ebenezer');
      controller.userChannel.value = channel;

      expect(controller.isFreeDubbingActive, isTrue);
      controller.estimatedCharacterCount.value = 50000;
      controller.targetLanguages.assignAll(['te', 'hi', 'ta']); // 150,000 chars required
      expect(controller.hasSufficientBalance, isTrue);
    });
  });
}
