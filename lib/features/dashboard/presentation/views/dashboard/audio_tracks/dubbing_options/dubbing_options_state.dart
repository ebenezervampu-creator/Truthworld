import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';

/// State and logic coordinator for AI Voice/Video Dubbing & Direct Audio Track options.
/// Follows 100% GetX reactive architecture, Zero setState, and Clean Architecture.
class DubbingOptionsState {
  DubbingOptionsState({
    required this.controller,
    required this.initialLangCode,
    this.allowLanguageSwitch = true,
    this.initialTierId,
    this.initialMediaType = 'audio',
  }) {
    if (initialTierId != null && initialTierId!.isNotEmpty) {
      selectedDubbingTier.value = initialTierId!;
      final tier = DubbingProductionTier.fromId(initialTierId);
      selectedMediaMode.value = tier.category;
      voiceType.value = tier.isVoiceClone ? 'cloned' : 'standard';
    } else if (initialMediaType == 'video') {
      selectedDubbingTier.value = 'video_pro';
      selectedMediaMode.value = 'video';
      voiceType.value = 'cloned';
    } else {
      selectedDubbingTier.value = 'audio_starter';
      selectedMediaMode.value = 'audio';
      voiceType.value = 'standard';
    }

    final effectiveInitial = (selectedDubbingTier.value == 'audio_starter' &&
            !kChirp3HdSupportedLanguageCodes.contains(initialLangCode.toLowerCase()))
        ? 'en'
        : initialLangCode;
    selectedLangCode.value = effectiveInitial;
    loadChannelBalance();
  }

  final AudioTracksController controller;
  final String initialLangCode;
  final bool allowLanguageSwitch;
  final String? initialTierId;
  final String initialMediaType;

  // Reactive states (Zero setState policy)
  final RxString selectedLangCode = 'zh'.obs;
  final RxInt selectedTab = 0.obs; // 0: AI Dubbing, 1: Direct Audio Track
  final RxString selectedDubbingTier = 'audio_starter'.obs;
  final RxString selectedMediaMode = 'audio'.obs; // 'audio' | 'video'
  final RxString voiceType = 'standard'.obs; // 'standard' | 'cloned'
  final RxBool enableDiarization = false.obs;
  final RxString priorityMode = 'accuracy'.obs;
  final RxString selectedVoiceGender = 'auto'.obs; // 'auto' | 'male' | 'female'
  final RxBool isGenerating = false.obs;
  final Rx<PlatformFile?> selectedDirectFile = Rx<PlatformFile?>(null);
  final RxBool isUploadingDirect = false.obs;
  final Rx<SpendableBalance?> spendableBalance = Rx<SpendableBalance?>(null);
  final Rx<Channel?> currentChannel = Rx<Channel?>(null);

  Future<void> loadChannelBalance() async {
    final video = controller.selectedVideo.value;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final chanId = controller.channelId.value.isNotEmpty
        ? controller.channelId.value
        : (video?.channelId.isNotEmpty == true ? video!.channelId : user.uid);
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(chanId)
          .get();
      if (doc.exists && doc.data() != null) {
        final chan = Channel.fromMap(doc.data()!, doc.id);
        currentChannel.value = chan;
        final bal =
            await ChannelWalletService().getSpendableBalanceForChannelId(chan.id);
        spendableBalance.value = bal;
      }
    } catch (_) {}
  }

  Future<void> pickDirectAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );
    if (result != null && result.files.isNotEmpty) {
      selectedDirectFile.value = result.files.first;
    }
  }

  Future<void> handleGenerateAiDubbing(BuildContext context) async {
    final video = controller.selectedVideo.value;
    final durationSeconds = (video != null && video.durationSeconds > 0)
        ? video.durationSeconds
        : (video?.durationValue.inSeconds ?? 0);
    final chan = currentChannel.value;
    final tier = DubbingProductionTier.fromId(selectedDubbingTier.value);
    final requiredCost = ChannelWalletService.calculateProductionTierCost(
      tierId: selectedDubbingTier.value,
      languageCount: 1,
      durationSeconds: durationSeconds,
      channel: chan,
    );
    final bal = spendableBalance.value?.totalSpendableBalance ?? 0.0;
    if (requiredCost > 0 && spendableBalance.value != null && bal < requiredCost) {
      AppSnackbar.warning(
        'Insufficient channel wallet balance (\$${bal.toStringAsFixed(2)} available vs \$${requiredCost.toStringAsFixed(2)} required). Please add money to your wallet to proceed.',
      );
      if (currentChannel.value != null && context.mounted) {
        ChannelWalletTopupSheet.show(
          context,
          channel: currentChannel.value!,
          onTopupSuccess: loadChannelBalance,
        );
      }
      return;
    }

    final langCode = selectedLangCode.value;
    isGenerating.value = true;
    try {
      final isVideo = selectedMediaMode.value == 'video' || tier.isLipSync;
      final success = await controller.triggerAIDubbingForLanguage(
        langCode: langCode,
        dubbingTier: selectedDubbingTier.value,
        voiceType: tier.ttsEngine,
        enableDiarization: enableDiarization.value || tier.isCinemaGrade,
        priorityMode: priorityMode.value,
        enableLipSync: tier.isLipSync,
        isCinemaGrade: tier.isCinemaGrade,
        voiceGender: selectedVoiceGender.value,
      );
      if (success) {
        if (isVideo) {
          controller.setActiveTab('languages'); // Video tab
        } else {
          controller.setActiveTab('tracks'); // Audio tab
        }
        Get.back<void>();
      }
    } finally {
      isGenerating.value = false;
    }
  }

  Future<void> handleUploadDirectTrack(BuildContext context) async {
    final file = selectedDirectFile.value;
    if (file == null) {
      AppSnackbar.error('Please select an audio file to upload.');
      return;
    }
    final langCode = selectedLangCode.value;
    isUploadingDirect.value = true;
    try {
      final success = await controller.uploadSingleAudioDubForLanguage(
        langCode: langCode,
        file: file,
      );
      if (success) {
        controller.setActiveTab('tracks');
        Get.back<void>();
      }
    } finally {
      isUploadingDirect.value = false;
    }
  }
}
