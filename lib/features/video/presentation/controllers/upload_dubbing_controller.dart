import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';

/// Information model for a supported Dubbing Language.
class DubbingLanguageInfo {
  final String name;
  final String nativeName;
  final String code;
  final String region;

  const DubbingLanguageInfo({
    required this.name,
    required this.nativeName,
    required this.code,
    required this.region,
  });
}

/// Controller for the dedicated Dubbing Configuration & Pricing Page.
/// 100% GetX state management with granular reactivity and zero setState.
class UploadDubbingController extends GetxController {
  final UploadController uploadController = Get.isRegistered<UploadController>()
      ? Get.find<UploadController>()
      : Get.put(UploadController());

  // Search & Filter
  final RxString searchQuery = ''.obs;
  final RxString selectedCategoryFilter = 'all'.obs;

  // Working copy of selections
  final RxSet<String> selectedLanguages = <String>{}.obs;
  final RxBool isDubbingEnabled = true.obs;
  final RxString selectedDubbingTier = 'audio_track'.obs;
  final RxString voiceType = 'cloned'.obs; // Voice cloning & vocal identity
  final RxBool isDiarizationEnabled = false.obs;
  final RxBool isLipSyncEnabled = false.obs;
  final RxBool isStemIsolationEnabled = true.obs;
  final RxBool isCinemaGradeEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    final normalized = <String>{};
    for (final raw in uploadController.aiDubbingLanguages) {
      final match = findLanguage(raw);
      if (match != null) {
        normalized.add(match.name);
      } else if (raw.trim().isNotEmpty) {
        normalized.add(raw.trim());
      }
    }
    selectedLanguages.assignAll(normalized);
    isDubbingEnabled.value = uploadController.aiDubbingLanguages.isEmpty ||
        uploadController.aiGenerateDubbing.value;

    selectedDubbingTier.value = 'audio_track';
    voiceType.value = 'cloned';
    isDiarizationEnabled.value = uploadController.aiDiarizationEnabled.value;
    isLipSyncEnabled.value = false;
    isCinemaGradeEnabled.value = false;
    isStemIsolationEnabled.value = true;
  }

  DubbingProductionTier get currentProductionTier =>
      DubbingProductionTier.audioTrack;

  void selectTier(String tierId) {
    selectedDubbingTier.value = 'audio_track';
    voiceType.value = 'cloned';
    isLipSyncEnabled.value = false;
    isCinemaGradeEnabled.value = false;
    isStemIsolationEnabled.value = true;
  }

  static DubbingLanguageInfo? findLanguage(String identifier) {
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return null;
    return allDubbingLanguages.firstWhereOrNull((l) =>
        l.code.toLowerCase() == clean ||
        l.name.toLowerCase() == clean ||
        l.nativeName.toLowerCase() == clean);
  }

  bool isLanguageSelected(DubbingLanguageInfo lang) {
    final nameLower = lang.name.toLowerCase();
    final codeLower = lang.code.toLowerCase();
    return selectedLanguages.any((s) {
      final sLower = s.trim().toLowerCase();
      return sLower == nameLower || sLower == codeLower;
    });
  }

  List<DubbingLanguageInfo> get selectedLanguagesList {
    final result = <DubbingLanguageInfo>[];
    for (final name in selectedLanguages) {
      final match = findLanguage(name);
      if (match != null) {
        if (!result.any((l) => l.code == match.code)) {
          result.add(match);
        }
      } else {
        result.add(
          DubbingLanguageInfo(
            code: name.toLowerCase(),
            name: name,
            nativeName: name,
            region: 'popular',
          ),
        );
      }
    }
    return result;
  }

  List<String> get selectedLanguageDisplayNames =>
      selectedLanguagesList.map((l) => l.name).toList();

  // Video and Channel Information
  int get durationSeconds => uploadController.videoDurationSeconds.value;
  Channel? get channel => uploadController.selectedChannel.value;
  ChannelType get channelType =>
      (channel?.channelType == ChannelType.custom) ? ChannelType.custom : ChannelType.standard;
  bool get isCustomChannel => channelType == ChannelType.custom;
  double get walletBalance => channel != null
      ? ChannelWalletService().getSpendableBalance(channel: channel!).totalSpendableBalance
      : 0.0;

  DubbingDurationTier get dubbingTier =>
      ChannelWalletService.getDubbingDurationTier(durationSeconds);

  double get flatDubbingRatePerLang =>
      ChannelWalletService.getFlatRateForTier(
        tierId: selectedDubbingTier.value,
        durationSeconds: durationSeconds,
      );

  double get calculatedCost {
    final cost = ChannelWalletService.calculateProductionTierCost(
      tierId: selectedDubbingTier.value,
      languageCount: selectedLanguages.length,
      durationSeconds: durationSeconds,
      channel: channel,
    );
    return double.parse(cost.toStringAsFixed(2));
  }

  bool get isInsufficientBalance =>
      selectedLanguages.isNotEmpty && calculatedCost > 0 && walletBalance < calculatedCost;

  String get channelLanguageCode => uploadController.channelLanguageCode;
  String get channelLanguageDisplayName => uploadController.channelLanguageDisplayName;

  String? get voiceSampleName => uploadController.voiceSampleFile.value?.name;

  /// Check whether a language is the channel's native/source language
  bool isSourceLanguage(DubbingLanguageInfo lang) {
    final chanCode = channelLanguageCode.toLowerCase();
    return lang.code.toLowerCase() == chanCode ||
        lang.name.toLowerCase() == channelLanguageDisplayName.toLowerCase();
  }

  /// Master list of all 70+ supported dubbing languages
  static const List<DubbingLanguageInfo> allDubbingLanguages = [
    // Global & Popular
    DubbingLanguageInfo(name: 'English', nativeName: 'English', code: 'en', region: 'popular'),
    DubbingLanguageInfo(name: 'Spanish', nativeName: 'Español', code: 'es', region: 'popular'),
    DubbingLanguageInfo(name: 'French', nativeName: 'Français', code: 'fr', region: 'popular'),
    DubbingLanguageInfo(name: 'German', nativeName: 'Deutsch', code: 'de', region: 'popular'),
    DubbingLanguageInfo(name: 'Hindi', nativeName: 'हिन्दी', code: 'hi', region: 'popular'),
    DubbingLanguageInfo(name: 'Japanese', nativeName: '日本語', code: 'ja', region: 'popular'),
    DubbingLanguageInfo(name: 'Chinese (Mandarin)', nativeName: '中文 (普通话)', code: 'zh', region: 'popular'),
    DubbingLanguageInfo(name: 'Portuguese', nativeName: 'Português', code: 'pt', region: 'popular'),
    DubbingLanguageInfo(name: 'Italian', nativeName: 'Italiano', code: 'it', region: 'popular'),
    DubbingLanguageInfo(name: 'Arabic', nativeName: 'العربية', code: 'ar', region: 'popular'),
    DubbingLanguageInfo(name: 'Russian', nativeName: 'Русский', code: 'ru', region: 'popular'),
    DubbingLanguageInfo(name: 'Korean', nativeName: '한국어', code: 'ko', region: 'popular'),

    // Indic Languages
    DubbingLanguageInfo(name: 'Bengali', nativeName: 'বাংলা', code: 'bn', region: 'indic'),
    DubbingLanguageInfo(name: 'Telugu', nativeName: 'తెలుగు', code: 'te', region: 'indic'),
    DubbingLanguageInfo(name: 'Tamil', nativeName: 'தமிழ்', code: 'ta', region: 'indic'),
    DubbingLanguageInfo(name: 'Marathi', nativeName: 'मराठी', code: 'mr', region: 'indic'),
    DubbingLanguageInfo(name: 'Gujarati', nativeName: 'ગુજરાતી', code: 'gu', region: 'indic'),
    DubbingLanguageInfo(name: 'Kannada', nativeName: 'ಕನ್ನಡ', code: 'kn', region: 'indic'),
    DubbingLanguageInfo(name: 'Malayalam', nativeName: 'മലയാളം', code: 'ml', region: 'indic'),
    DubbingLanguageInfo(name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', code: 'pa', region: 'indic'),
    DubbingLanguageInfo(name: 'Odia', nativeName: 'ଓଡ଼ିଆ', code: 'or', region: 'indic'),
    DubbingLanguageInfo(name: 'Assamese', nativeName: 'অসমীয়া', code: 'as', region: 'indic'),
    DubbingLanguageInfo(name: 'Urdu', nativeName: 'اردو', code: 'ur', region: 'indic'),
    DubbingLanguageInfo(name: 'Nepali', nativeName: 'नेपाली', code: 'ne', region: 'indic'),
    DubbingLanguageInfo(name: 'Sanskrit', nativeName: 'संस्कृतम्', code: 'sa', region: 'indic'),
    DubbingLanguageInfo(name: 'Kashmiri', nativeName: 'कॉशुर', code: 'ks', region: 'indic'),
    DubbingLanguageInfo(name: 'Sindhi', nativeName: 'سنڌي', code: 'sd', region: 'indic'),

    // European Languages
    DubbingLanguageInfo(name: 'Turkish', nativeName: 'Türkçe', code: 'tr', region: 'european'),
    DubbingLanguageInfo(name: 'Dutch', nativeName: 'Nederlands', code: 'nl', region: 'european'),
    DubbingLanguageInfo(name: 'Swedish', nativeName: 'Svenska', code: 'sv', region: 'european'),
    DubbingLanguageInfo(name: 'Polish', nativeName: 'Polski', code: 'pl', region: 'european'),
    DubbingLanguageInfo(name: 'Czech', nativeName: 'Čeština', code: 'cs', region: 'european'),
    DubbingLanguageInfo(name: 'Greek', nativeName: 'Ελληνικά', code: 'el', region: 'european'),
    DubbingLanguageInfo(name: 'Hungarian', nativeName: 'Magyar', code: 'hu', region: 'european'),
    DubbingLanguageInfo(name: 'Danish', nativeName: 'Dansk', code: 'da', region: 'european'),
    DubbingLanguageInfo(name: 'Finnish', nativeName: 'Suomi', code: 'fi', region: 'european'),
    DubbingLanguageInfo(name: 'Norwegian', nativeName: 'Norsk', code: 'no', region: 'european'),
    DubbingLanguageInfo(name: 'Slovak', nativeName: 'Slovenčina', code: 'sk', region: 'european'),
    DubbingLanguageInfo(name: 'Bulgarian', nativeName: 'Български', code: 'bg', region: 'european'),
    DubbingLanguageInfo(name: 'Catalan', nativeName: 'Català', code: 'ca', region: 'european'),
    DubbingLanguageInfo(name: 'Croatian', nativeName: 'Hrvatski', code: 'hr', region: 'european'),
    DubbingLanguageInfo(name: 'Lithuanian', nativeName: 'Lietuvių', code: 'lt', region: 'european'),
    DubbingLanguageInfo(name: 'Slovenian', nativeName: 'Slovenščina', code: 'sl', region: 'european'),
    DubbingLanguageInfo(name: 'Romanian', nativeName: 'Română', code: 'ro', region: 'european'),
    DubbingLanguageInfo(name: 'Ukrainian', nativeName: 'Українська', code: 'uk', region: 'european'),
    DubbingLanguageInfo(name: 'Estonian', nativeName: 'Eesti', code: 'et', region: 'european'),
    DubbingLanguageInfo(name: 'Latvian', nativeName: 'Latviešu', code: 'lv', region: 'european'),
    DubbingLanguageInfo(name: 'Serbian', nativeName: 'Српски', code: 'sr', region: 'european'),
    DubbingLanguageInfo(name: 'Albanian', nativeName: 'Shqip', code: 'sq', region: 'european'),
    DubbingLanguageInfo(name: 'Basque', nativeName: 'Euskara', code: 'eu', region: 'european'),
    DubbingLanguageInfo(name: 'Belarusian', nativeName: 'Беларуская', code: 'be', region: 'european'),
    DubbingLanguageInfo(name: 'Bosnian', nativeName: 'Bosanski', code: 'bs', region: 'european'),
    DubbingLanguageInfo(name: 'Galician', nativeName: 'Galego', code: 'gl', region: 'european'),
    DubbingLanguageInfo(name: 'Georgian', nativeName: 'ქართული', code: 'ka', region: 'european'),
    DubbingLanguageInfo(name: 'Icelandic', nativeName: 'Íslenska', code: 'is', region: 'european'),
    DubbingLanguageInfo(name: 'Irish', nativeName: 'Gaeilge', code: 'ga', region: 'european'),
    DubbingLanguageInfo(name: 'Macedonian', nativeName: 'Македонски', code: 'mk', region: 'european'),
    DubbingLanguageInfo(name: 'Maltese', nativeName: 'Malti', code: 'mt', region: 'european'),
    DubbingLanguageInfo(name: 'Welsh', nativeName: 'Cymraeg', code: 'cy', region: 'european'),
    DubbingLanguageInfo(name: 'Yiddish', nativeName: 'ייִדיש', code: 'yi', region: 'european'),

    // Asian & Pacific
    DubbingLanguageInfo(name: 'Indonesian', nativeName: 'Bahasa Indonesia', code: 'id', region: 'asian'),
    DubbingLanguageInfo(name: 'Thai', nativeName: 'ไทย', code: 'th', region: 'asian'),
    DubbingLanguageInfo(name: 'Vietnamese', nativeName: 'Tiếng Việt', code: 'vi', region: 'asian'),
    DubbingLanguageInfo(name: 'Tagalog', nativeName: 'Filipino', code: 'tl', region: 'asian'),
    DubbingLanguageInfo(name: 'Malay', nativeName: 'Bahasa Melayu', code: 'ms', region: 'asian'),
    DubbingLanguageInfo(name: 'Kazakh', nativeName: 'Қазақша', code: 'kk', region: 'asian'),
    DubbingLanguageInfo(name: 'Uzbek', nativeName: 'Oʻzbekcha', code: 'uz', region: 'asian'),
    DubbingLanguageInfo(name: 'Burmese', nativeName: 'မြန်မာဘာသာ', code: 'my', region: 'asian'),
    DubbingLanguageInfo(name: 'Khmer', nativeName: 'ភាសាខ្មែរ', code: 'km', region: 'asian'),
    DubbingLanguageInfo(name: 'Lao', nativeName: 'ພາສາລາວ', code: 'lo', region: 'asian'),
    DubbingLanguageInfo(name: 'Armenian', nativeName: 'Հայերեն', code: 'hy', region: 'asian'),
    DubbingLanguageInfo(name: 'Mongolian', nativeName: 'Монгол хэл', code: 'mn', region: 'asian'),
    DubbingLanguageInfo(name: 'Sinhala', nativeName: 'සිංහල', code: 'si', region: 'asian'),

    // Middle East & Africa
    DubbingLanguageInfo(name: 'Hebrew', nativeName: 'עברית', code: 'he', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Persian', nativeName: 'فارسی', code: 'fa', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Kurdish', nativeName: 'کوردی', code: 'ku', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Pashto', nativeName: 'پښتو', code: 'ps', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Afrikaans', nativeName: 'Afrikaans', code: 'af', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Azerbaijani', nativeName: 'Azərbaycan', code: 'az', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Somali', nativeName: 'Soomaali', code: 'so', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Swahili', nativeName: 'Kiswahili', code: 'sw', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Zulu', nativeName: 'isiZulu', code: 'zu', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Xhosa', nativeName: 'isiXhosa', code: 'xh', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Amharic', nativeName: 'አማርኛ', code: 'am', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Hausa', nativeName: 'Hausa', code: 'ha', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Yoruba', nativeName: 'Yorùbá', code: 'yo', region: 'middle_east_africa'),
    DubbingLanguageInfo(name: 'Igbo', nativeName: 'Asụsụ Igbo', code: 'ig', region: 'middle_east_africa'),
  ];

  /// Filtered dubbing languages based on search and selected category
  List<DubbingLanguageInfo> get filteredLanguages {
    final query = searchQuery.value.trim().toLowerCase();
    final category = selectedCategoryFilter.value;

    return allDubbingLanguages.where((l) {
      if (category != 'all') {
        if (category == 'selected') {
          if (!isLanguageSelected(l)) return false;
        } else if (l.region != category) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        final matchesName = l.name.toLowerCase().contains(query);
        final matchesNative = l.nativeName.toLowerCase().contains(query);
        final matchesCode = l.code.toLowerCase().contains(query);
        return matchesName || matchesNative || matchesCode;
      }
      return true;
    }).toList();
  }

  void toggleLanguage(dynamic langOrInfo) {
    DubbingLanguageInfo? info;
    if (langOrInfo is DubbingLanguageInfo) {
      info = langOrInfo;
    } else {
      info = findLanguage(langOrInfo.toString());
    }

    if (info != null && isSourceLanguage(info)) {
      AppSnackbar.info(
        'This video is originally in ${info.name} (Source Channel Language). Dubbing creates audio tracks in other languages.',
      );
      return;
    }

    final targetName = (info?.name ?? langOrInfo.toString()).trim().toLowerCase();
    final targetCode = (info?.code ?? '').trim().toLowerCase();

    final matches = selectedLanguages.where((s) {
      final sLower = s.trim().toLowerCase();
      return sLower == targetName || (targetCode.isNotEmpty && sLower == targetCode);
    }).toList();

    if (matches.isNotEmpty) {
      matches.forEach(selectedLanguages.remove);
      if (selectedLanguages.isEmpty && selectedCategoryFilter.value == 'selected') {
        selectedCategoryFilter.value = 'all';
      }
    } else {
      selectedLanguages.add(info?.name ?? langOrInfo.toString());
    }
  }

  void removeLanguage(String nameOrCode) {
    final clean = nameOrCode.trim().toLowerCase();
    final match = findLanguage(nameOrCode);
    final targetName = (match?.name ?? nameOrCode).trim().toLowerCase();
    final targetCode = (match?.code ?? '').trim().toLowerCase();

    final toRemove = selectedLanguages.where((s) {
      final sLower = s.trim().toLowerCase();
      return sLower == clean ||
          sLower == targetName ||
          (targetCode.isNotEmpty && sLower == targetCode);
    }).toList();

    toRemove.forEach(selectedLanguages.remove);
    if (selectedLanguages.isEmpty && selectedCategoryFilter.value == 'selected') {
      selectedCategoryFilter.value = 'all';
    }
  }

  void clearAll() {
    selectedLanguages.clear();
    if (selectedCategoryFilter.value == 'selected') {
      selectedCategoryFilter.value = 'all';
    }
  }

  void selectTopGlobal() {
    const topGlobal = [
      'English', 'Spanish', 'French', 'German', 'Chinese (Mandarin)', 'Japanese',
      'Hindi', 'Portuguese', 'Arabic', 'Russian'
    ];
    for (final l in topGlobal) {
      final info = allDubbingLanguages.firstWhereOrNull((i) => i.name == l);
      if (info != null && !isSourceLanguage(info)) {
        selectedLanguages.add(l);
      }
    }
  }

  void selectTopIndic() {
    const topIndic = [
      'Hindi', 'Bengali', 'Telugu', 'Tamil', 'Marathi', 'Gujarati', 'Kannada', 'Malayalam'
    ];
    for (final l in topIndic) {
      final info = allDubbingLanguages.firstWhereOrNull((i) => i.name == l);
      if (info != null && !isSourceLanguage(info)) {
        selectedLanguages.add(l);
      }
    }
  }

  void selectTopEuropean() {
    const topEuro = ['Spanish', 'French', 'German', 'Italian', 'Portuguese', 'Dutch'];
    for (final l in topEuro) {
      final info = allDubbingLanguages.firstWhereOrNull((i) => i.name == l);
      if (info != null && !isSourceLanguage(info)) {
        selectedLanguages.add(l);
      }
    }
  }

  Future<void> pickVoiceSample() async {
    await uploadController.pickVoiceSample();
  }

  void applyAndSave() {
    if (isInsufficientBalance && selectedLanguages.isNotEmpty && isDubbingEnabled.value) {
      AppSnackbar.warning(
        'Insufficient channel revenue (\$${walletBalance.toStringAsFixed(2)} available vs \$${calculatedCost.toStringAsFixed(2)} required). You can pay directly to proceed with AI Audio Dubbing for these languages.',
      );
      return;
    }

    uploadController.aiDubbingLanguages.assignAll(selectedLanguages.toList());
    uploadController.aiDubbingTier.value = selectedDubbingTier.value;
    uploadController.aiCinemaGradeEnabled.value = isCinemaGradeEnabled.value;
    uploadController.aiStemIsolationEnabled.value = isStemIsolationEnabled.value;
    uploadController.aiGenerateDubbing.value =
        selectedLanguages.isNotEmpty && isDubbingEnabled.value;
    uploadController.aiTTSVoiceType.value = voiceType.value;
    uploadController.aiDiarizationEnabled.value = isDiarizationEnabled.value;
    uploadController.aiLipSyncEnabled.value = isLipSyncEnabled.value;

    // Automatically ensure dubbed languages have matching subtitles
    if (uploadController.aiGenerateDubbing.value) {
      for (final lang in selectedLanguages) {
        if (!uploadController.aiTranslationLanguages.contains(lang)) {
          uploadController.aiTranslationLanguages.add(lang);
        }
      }
      uploadController.aiGenerateSubtitles.value = true;
    }

    if (Get.context != null) {
      AppSnackbar.success(
        selectedLanguages.isEmpty
            ? 'Dubbing disabled.'
            : 'Dubbing configured for ${selectedLanguages.length} languages.',
      );
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }
}
