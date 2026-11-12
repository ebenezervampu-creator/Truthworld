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

/// State and logic coordinator for AI Dubbing & Direct Audio Track options.
/// Follows 100% GetX reactive architecture, Zero setState, and supports multi-language selection.
class DubbingOptionsState {
  static const int maxBatchLanguages = 5;

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
    } else {
      selectedDubbingTier.value = 'audio_track';
      selectedMediaMode.value = 'audio';
      voiceType.value = 'cloned';
    }

    final normalizedInitial = initialLangCode.trim().toLowerCase();
    final effectiveInitial = normalizedInitial.isNotEmpty ? normalizedInitial : 'te';
    selectedLangCode.value = effectiveInitial;
    selectedLangCodes.assignAll([effectiveInitial]);
    activeDirectLangCode.value = effectiveInitial;
    loadChannelBalance();
  }

  final AudioTracksController controller;
  final String initialLangCode;
  final bool allowLanguageSwitch;
  final String? initialTierId;
  final String initialMediaType;

  // Reactive states (Zero setState policy)
  final RxString selectedLangCode = 'te'.obs;
  final RxList<String> selectedLangCodes = <String>[].obs;
  final RxString activeDirectLangCode = 'te'.obs;
  final RxInt selectedTab = 0.obs; // 0: AI Dubbing, 1: Direct Audio Track
  final RxString selectedDubbingTier = 'audio_track'.obs;
  final RxString selectedMediaMode = 'audio'.obs; // 'audio'
  final RxString voiceType = 'cloned'.obs; // 'standard' | 'cloned'
  final RxBool enableDiarization = false.obs;
  final RxString priorityMode = 'accuracy'.obs;
  final RxString selectedVoiceGender = 'auto'.obs; // 'auto' | 'male' | 'female'
  final RxBool isGenerating = false.obs;
  final Rx<PlatformFile?> selectedDirectFile = Rx<PlatformFile?>(null);
  final RxMap<String, PlatformFile> directFilesByLang =
      <String, PlatformFile>{}.obs;
  final RxBool isUploadingDirect = false.obs;
  final Rx<SpendableBalance?> spendableBalance = Rx<SpendableBalance?>(null);
  final Rx<Channel?> currentChannel = Rx<Channel?>(null);

  String get videoBaseLang =>
      (controller.selectedVideo.value?.language ?? '').trim().toLowerCase();

  bool isSourceLanguage(String code) {
    final clean = code.trim().toLowerCase();
    return videoBaseLang.isNotEmpty && clean == videoBaseLang;
  }

  bool isLanguageSelected(String code) {
    final clean = code.trim().toLowerCase();
    return selectedLangCodes.contains(clean);
  }

  void _syncPrimaryLanguage() {
    if (selectedLangCodes.isNotEmpty) {
      selectedLangCode.value = selectedLangCodes.first;
      if (!selectedLangCodes.contains(activeDirectLangCode.value)) {
        activeDirectLangCode.value = selectedLangCodes.first;
      }
    } else {
      selectedLangCode.value = '';
      activeDirectLangCode.value = '';
    }
    selectedDirectFile.value = directFilesByLang[activeDirectLangCode.value];
  }

  void toggleLanguage(String code) {
    if (!allowLanguageSwitch) return;
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty || isSourceLanguage(clean)) return;

    if (selectedLangCodes.contains(clean)) {
      selectedLangCodes.remove(clean);
      directFilesByLang.remove(clean);
    } else {
      if (selectedLangCodes.length >= maxBatchLanguages) {
        AppSnackbar.warning(
          'You can select up to $maxBatchLanguages languages per batch.',
          title: 'Batch Limit Reached',
        );
        return;
      }
      selectedLangCodes.add(clean);
    }
    _syncPrimaryLanguage();
  }

  void selectSingleLanguage(String code) {
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty) return;
    selectedLangCodes.assignAll([clean]);
    _syncPrimaryLanguage();
  }

  void removeLanguage(String code) {
    if (!allowLanguageSwitch) return;
    final clean = code.trim().toLowerCase();
    selectedLangCodes.remove(clean);
    directFilesByLang.remove(clean);
    _syncPrimaryLanguage();
  }

  void clearLanguages() {
    if (!allowLanguageSwitch) return;
    selectedLangCodes.clear();
    directFilesByLang.clear();
    _syncPrimaryLanguage();
  }

  void selectLanguagePreset(List<String> candidateCodes) {
    if (!allowLanguageSwitch) return;
    for (final raw in candidateCodes) {
      final clean = raw.trim().toLowerCase();
      if (clean.isEmpty || isSourceLanguage(clean)) continue;
      if (selectedLangCodes.contains(clean)) continue;
      if (selectedLangCodes.length >= maxBatchLanguages) break;
      selectedLangCodes.add(clean);
    }
    _syncPrimaryLanguage();
  }

  int get billableLanguageCount {
    final nonBase = selectedLangCodes
        .where((c) => c.isNotEmpty && !isSourceLanguage(c))
        .length;
    return nonBase;
  }

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

  Future<void> pickDirectAudioFile([String? targetLangCode]) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final lang = (targetLangCode ?? activeDirectLangCode.value).trim().toLowerCase();
      if (lang.isNotEmpty) {
        directFilesByLang[lang] = file;
        activeDirectLangCode.value = lang;
      }
      selectedDirectFile.value = file;
    }
  }

  void removeDirectFileForLanguage(String langCode) {
    final clean = langCode.trim().toLowerCase();
    directFilesByLang.remove(clean);
    if (activeDirectLangCode.value == clean) {
      selectedDirectFile.value = null;
    }
  }

  Future<void> handleGenerateAiDubbing(BuildContext context) async {
    final targetCodes = selectedLangCodes
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty && !isSourceLanguage(c))
        .toList();

    if (targetCodes.isEmpty) {
      AppSnackbar.warning(
        'Please select at least one target language to generate audio tracks.',
        title: 'Select Language',
      );
      return;
    }

    final video = controller.selectedVideo.value;
    final durationSeconds = (video != null && video.durationSeconds > 0)
        ? video.durationSeconds
        : (video?.durationValue.inSeconds ?? 0);
    final chan = currentChannel.value;
    final requiredCost = ChannelWalletService.calculateProductionTierCost(
      tierId: selectedDubbingTier.value,
      languageCount: targetCodes.length,
      durationSeconds: durationSeconds,
      channel: chan,
    );
    final bal = spendableBalance.value?.totalSpendableBalance ?? 0.0;

    if (requiredCost > 0 && spendableBalance.value != null && bal < requiredCost) {
      if (chan == null) {
        AppSnackbar.error(
          'Unable to verify channel. Please select a valid channel to proceed.',
        );
        return;
      }
      isGenerating.value = true;
      try {
        final paymentOk = await ChannelWalletService().payForDubbingWithCashfree(
          channel: chan,
          amountUSD: requiredCost,
          languageCode: targetCodes.first,
          targetLanguages: targetCodes,
          videoId: video?.id ?? '',
          dubbingTier: selectedDubbingTier.value,
        );
        if (!paymentOk) {
          AppSnackbar.error(
            'Direct payment was not completed. Please try again.',
          );
          return;
        }
        final isVoiceCloned = voiceType.value == 'cloned';
        final success = await controller.triggerAIDubbingForLanguages(
          langCodes: targetCodes,
          dubbingTier: selectedDubbingTier.value,
          voiceType: isVoiceCloned ? 'cloned' : 'standard',
          enableDiarization: enableDiarization.value,
          priorityMode: priorityMode.value,
          voiceGender: selectedVoiceGender.value,
          isDirectlyPaid: true,
        );
        if (success) {
          controller.setActiveTab('tracks');
          Get.back<void>();
        }
      } finally {
        isGenerating.value = false;
      }
      return;
    }

    isGenerating.value = true;
    try {
      final isVoiceCloned = voiceType.value == 'cloned';
      final success = await controller.triggerAIDubbingForLanguages(
        langCodes: targetCodes,
        dubbingTier: selectedDubbingTier.value,
        voiceType: isVoiceCloned ? 'cloned' : 'standard',
        enableDiarization: enableDiarization.value,
        priorityMode: priorityMode.value,
        voiceGender: selectedVoiceGender.value,
      );
      if (success) {
        controller.setActiveTab('tracks');
        Get.back<void>();
      }
    } finally {
      isGenerating.value = false;
    }
  }

  Future<void> handleUploadDirectTrack(BuildContext context) async {
    final entries = <MapEntry<String, PlatformFile>>[];
    if (directFilesByLang.isNotEmpty) {
      for (final code in selectedLangCodes) {
        final file = directFilesByLang[code];
        if (file != null) {
          entries.add(MapEntry(code, file));
        }
      }
      // Also include any entry attached directly if selectedLangCodes had single mismatch
      if (entries.isEmpty && directFilesByLang.isNotEmpty) {
        entries.addAll(directFilesByLang.entries);
      }
    } else if (selectedDirectFile.value != null) {
      final fallbackLang = activeDirectLangCode.value.isNotEmpty
          ? activeDirectLangCode.value
          : selectedLangCode.value;
      if (fallbackLang.isNotEmpty) {
        entries.add(MapEntry(fallbackLang, selectedDirectFile.value!));
      }
    }

    if (entries.isEmpty) {
      AppSnackbar.warning(
        'Please select at least one audio file to upload.',
        title: 'Audio File Required',
      );
      return;
    }

    isUploadingDirect.value = true;
    try {
      var allSucceeded = true;
      for (final entry in entries) {
        final ok = await controller.uploadSingleAudioDubForLanguage(
          langCode: entry.key,
          file: entry.value,
        );
        if (!ok) {
          allSucceeded = false;
        } else {
          directFilesByLang.remove(entry.key);
        }
      }
      if (allSucceeded) {
        selectedDirectFile.value = null;
        controller.setActiveTab('tracks');
        Get.back<void>();
      }
    } finally {
      isUploadingDirect.value = false;
    }
  }
}
