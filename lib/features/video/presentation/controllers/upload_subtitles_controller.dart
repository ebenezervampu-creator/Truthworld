import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';

/// Controller for the dedicated Subtitles Configuration & Pricing Page.
/// 100% GetX state management with granular reactivity and zero setState.
class UploadSubtitlesController extends GetxController {
  final UploadController uploadController = Get.isRegistered<UploadController>()
      ? Get.find<UploadController>()
      : Get.put(UploadController());

  // Search and Filter States
  final RxString searchQuery = ''.obs;
  final RxString selectedCategoryFilter = 'all'.obs;

  // Working copy of selected subtitle languages
  final RxSet<String> selectedLanguages = <String>{}.obs;
  final RxBool isSubtitlesEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Preload from uploadController and normalize any codes/names to canonical names
    final normalized = <String>{};
    for (final raw in uploadController.aiTranslationLanguages) {
      final match = findLanguage(raw);
      if (match != null) {
        normalized.add(match.name);
      } else if (raw.trim().isNotEmpty) {
        normalized.add(raw.trim());
      }
    }
    selectedLanguages.assignAll(normalized);
    isSubtitlesEnabled.value = uploadController.aiTranslationLanguages.isEmpty ||
        uploadController.aiGenerateSubtitles.value;
  }

  /// Find matching TranslationLanguage from any string (name, code, or nativeName)
  static TranslationLanguage? findLanguage(String identifier) {
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return null;
    return supportedLanguages.firstWhereOrNull((l) =>
        l.code.toLowerCase() == clean ||
        l.name.toLowerCase() == clean ||
        l.nativeName.toLowerCase() == clean);
  }

  /// Canonical list of selected TranslationLanguage models
  List<TranslationLanguage> get selectedLanguagesList {
    final result = <TranslationLanguage>[];
    for (final name in selectedLanguages) {
      final match = findLanguage(name);
      if (match != null) {
        if (!result.any((l) => l.code == match.code)) {
          result.add(match);
        }
      } else {
        result.add(
          TranslationLanguage(
            code: name.toLowerCase(),
            name: name,
            nativeName: name,
            category: LanguageCategory.other,
          ),
        );
      }
    }
    return result;
  }

  /// Human-readable list of display names for selected languages
  List<String> get selectedLanguageDisplayNames =>
      selectedLanguagesList.map((l) => l.name).toList();

  /// Check whether a given language is selected (matching by canonical name or code)
  bool isLanguageSelected(TranslationLanguage lang) {
    final nameLower = lang.name.toLowerCase();
    final codeLower = lang.code.toLowerCase();
    return selectedLanguages.any((s) {
      final sLower = s.trim().toLowerCase();
      return sLower == nameLower || sLower == codeLower;
    });
  }

  /// Check whether a given language is covered under Dubbing
  bool isLanguageDubbed(TranslationLanguage lang) {
    final nameLower = lang.name.toLowerCase();
    final codeLower = lang.code.toLowerCase();
    return dubbedLanguages.any((d) {
      final dLower = d.trim().toLowerCase();
      return dLower == nameLower || dLower == codeLower;
    });
  }

  // Video and Channel Information
  int get durationSeconds => uploadController.videoDurationSeconds.value;
  Channel? get channel => uploadController.selectedChannel.value;
  ChannelType get channelType =>
      (channel?.channelType == ChannelType.custom) ? ChannelType.custom : ChannelType.standard;
  bool get isCustomChannel => channelType == ChannelType.custom;
  double get walletBalance => channel != null
      ? ChannelWalletService().getSpendableBalance(channel: channel!).totalSpendableBalance
      : 0.0;

  SubtitleDurationTier get subtitleTier =>
      ChannelWalletService.getSubtitleDurationTier(durationSeconds);

  double get flatSubtitleRatePerLang =>
      ChannelWalletService.getFlatSubtitlePricePerLanguage(
        durationSeconds: durationSeconds,
        channelType: channelType,
      );

  /// Languages that are also selected for Dubbing (Subtitles are included free for dubbed languages)
  Set<String> get dubbedLanguages {
    final rawSet = uploadController.aiDubbingLanguages.toSet();
    final canonicalSet = <String>{};
    for (final raw in rawSet) {
      final match = findLanguage(raw);
      if (match != null) {
        canonicalSet.add(match.name);
      } else {
        canonicalSet.add(raw);
      }
    }
    return canonicalSet;
  }

  bool get isDubbingEnabled => uploadController.aiGenerateDubbing.value;

  /// Billable subtitle languages: excludes languages already covered under Dubbing
  List<String> get billableLanguages {
    if (!isDubbingEnabled) return selectedLanguages.toList();
    return selectedLanguages
        .where((lang) {
          final match = findLanguage(lang);
          if (match != null) {
            return !isLanguageDubbed(match);
          }
          return !dubbedLanguages.contains(lang);
        })
        .toList();
  }

  int get freeDubbedSubtitleCount =>
      selectedLanguages.length - billableLanguages.length;

  /// Total calculated subtitle cost
  double get calculatedCost => ChannelWalletService.calculateSubtitleCost(
        languageCount: billableLanguages.length,
        durationSeconds: durationSeconds,
        channelType: channelType,
        channel: channel,
      );

  bool get isInsufficientBalance =>
      selectedLanguages.isNotEmpty && calculatedCost > 0 && walletBalance < calculatedCost;

  /// Filtered list of supported languages
  List<TranslationLanguage> get filteredLanguages {
    final query = searchQuery.value.trim().toLowerCase();
    final category = selectedCategoryFilter.value;

    return supportedLanguages.where((l) {
      // 1. Category filter
      if (category != 'all') {
        if (category == 'selected') {
          if (!isLanguageSelected(l)) return false;
        } else if (category == 'popular' && l.category != LanguageCategory.global) {
          return false;
        } else if (category == 'indian' && l.category != LanguageCategory.indian) {
          return false;
        } else if (category == 'european' && !_isEuropean(l.name)) {
          return false;
        } else if (category == 'asian' && !_isAsian(l.name)) {
          return false;
        } else if (category == 'middle_eastern' && !_isMiddleEasternOrAfrican(l.name)) {
          return false;
        }
      }

      // 2. Search query filter
      if (query.isNotEmpty) {
        final matchesName = l.name.toLowerCase().contains(query);
        final matchesNative = l.nativeName.toLowerCase().contains(query);
        final matchesCode = l.code.toLowerCase().contains(query);
        return matchesName || matchesNative || matchesCode;
      }

      return true;
    }).toList();
  }

  static bool _isEuropean(String name) {
    const euroNames = {
      'Spanish', 'French', 'German', 'Italian', 'Portuguese', 'Russian', 'Turkish',
      'Dutch', 'Swedish', 'Polish', 'Czech', 'Greek', 'Hungarian', 'Danish', 'Finnish',
      'Norwegian', 'Slovak', 'Bulgarian', 'Catalan', 'Croatian', 'Lithuanian',
      'Slovenian', 'Romanian', 'Ukrainian', 'Estonian', 'Latvian', 'Serbian',
      'Albanian', 'Basque', 'Belarusian', 'Bosnian', 'Galician', 'Georgian',
      'Icelandic', 'Irish', 'Macedonian', 'Maltese', 'Welsh', 'Yiddish'
    };
    return euroNames.contains(name);
  }

  static bool _isAsian(String name) {
    const asianNames = {
      'Chinese', 'Japanese', 'Korean', 'Vietnamese', 'Thai', 'Indonesian',
      'Malay', 'Tagalog', 'Sundanese', 'Javanese', 'Khmer', 'Lao', 'Myanmar',
      'Mongolian', 'Kazakh', 'Uzbek'
    };
    return asianNames.contains(name);
  }

  static bool _isMiddleEasternOrAfrican(String name) {
    const meAfricanNames = {
      'Arabic', 'Persian', 'Hebrew', 'Turkish', 'Swahili', 'Amharic', 'Somali',
      'Hausa', 'Yoruba', 'Zulu', 'Afrikaans', 'Xhosa', 'Kurdish'
    };
    return meAfricanNames.contains(name);
  }

  // Actions
  void toggleLanguage(dynamic langOrName) {
    String canonicalName;
    var code = '';
    if (langOrName is TranslationLanguage) {
      canonicalName = langOrName.name;
      code = langOrName.code;
    } else {
      final str = langOrName.toString();
      final match = findLanguage(str);
      canonicalName = match?.name ?? str;
      code = match?.code ?? '';
    }

    final nameLower = canonicalName.trim().toLowerCase();
    final codeLower = code.trim().toLowerCase();

    final matches = selectedLanguages.where((s) {
      final sLower = s.trim().toLowerCase();
      return sLower == nameLower || (codeLower.isNotEmpty && sLower == codeLower);
    }).toList();

    if (matches.isNotEmpty) {
      matches.forEach(selectedLanguages.remove);
      if (selectedLanguages.isEmpty && selectedCategoryFilter.value == 'selected') {
        selectedCategoryFilter.value = 'all';
      }
    } else {
      selectedLanguages.add(canonicalName);
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

  void selectTopGlobal() {
    const topGlobal = [
      'English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese',
      'Hindi', 'Portuguese', 'Arabic', 'Russian'
    ];
    selectedLanguages.addAll(topGlobal);
  }

  void selectTopIndic() {
    const topIndic = [
      'Hindi', 'Bengali', 'Telugu', 'Tamil', 'Marathi', 'Gujarati',
      'Kannada', 'Malayalam', 'Punjabi', 'Urdu'
    ];
    selectedLanguages.addAll(topIndic);
  }

  void selectUNOfficial() {
    const unOfficial = [
      'Arabic', 'Chinese', 'English', 'French', 'Russian', 'Spanish'
    ];
    selectedLanguages.addAll(unOfficial);
  }

  void selectAllFiltered() {
    for (final l in filteredLanguages) {
      if (!isLanguageSelected(l)) {
        selectedLanguages.add(l.name);
      }
    }
  }

  void clearAll() {
    selectedLanguages.clear();
    if (selectedCategoryFilter.value == 'selected') {
      selectedCategoryFilter.value = 'all';
    }
  }

  void applyAndSave() {
    if (isInsufficientBalance && selectedLanguages.isNotEmpty && isSubtitlesEnabled.value) {
      AppSnackbar.warning(
        'Insufficient channel wallet balance (\$${walletBalance.toStringAsFixed(2)} available vs \$${calculatedCost.toStringAsFixed(2)} required). Please add money to your wallet to proceed with AI Subtitles for these languages.',
      );
      return;
    }

    uploadController.aiTranslationLanguages.assignAll(selectedLanguages.toList());
    uploadController.aiGenerateSubtitles.value =
        selectedLanguages.isNotEmpty && isSubtitlesEnabled.value;

    if (Get.context != null) {
      AppSnackbar.success(
        selectedLanguages.isEmpty
            ? 'Subtitles disabled.'
            : 'Subtitles configured for ${selectedLanguages.length} languages.',
      );
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    }
  }
}
