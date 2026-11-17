import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_mode_switcher.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Language-to-Country code mapping for national flags.
const Map<String, String> kLanguageToCountryCode = {
  'en': 'US',
  'zh': 'CN',
  'es': 'ES',
  'fr': 'FR',
  'de': 'DE',
  'ja': 'JP',
  'ko': 'KR',
  'pt': 'BR',
  'it': 'IT',
  'ar': 'SA',
  'ru': 'RU',
  'tr': 'TR',
  'nl': 'NL',
  'sv': 'SE',
  'pl': 'PL',
  'hi': 'IN',
  'te': 'IN',
  'ta': 'IN',
  'ml': 'IN',
  'kn': 'IN',
  'bn': 'IN',
  'mr': 'IN',
  'gu': 'IN',
  'pa': 'IN',
  'or': 'IN',
  'ur': 'PK',
  'as': 'IN',
  'ne': 'NP',
  'sd': 'PK',
  'si': 'LK',
  'id': 'ID',
  'th': 'TH',
  'vi': 'VN',
  'tl': 'PH',
  'fil': 'PH',
  'ms': 'MY',
  'my': 'MM',
  'jv': 'ID',
  'ceb': 'PH',
  'kk': 'KZ',
  'uz': 'UZ',
  'ky': 'KG',
  'fa': 'IR',
  'he': 'IL',
  'ps': 'AF',
  'az': 'AZ',
  'hy': 'AM',
  'ka': 'GE',
  'uk': 'UA',
  'el': 'GR',
  'cs': 'CZ',
  'ro': 'RO',
  'hu': 'HU',
  'da': 'DK',
  'fi': 'FI',
  'no': 'NO',
  'sk': 'SK',
  'bg': 'BG',
  'hr': 'HR',
  'sr': 'RS',
  'bs': 'BA',
  'lt': 'LT',
  'sl': 'SI',
  'et': 'EE',
  'lv': 'LV',
  'mk': 'MK',
  'be': 'BY',
  'ca': 'ES',
  'gl': 'ES',
  'is': 'IS',
  'ga': 'IE',
  'cy': 'GB',
  'lb': 'LU',
  'sw': 'KE',
  'am': 'ET',
  'ha': 'NG',
  'yo': 'NG',
  'ig': 'NG',
  'zu': 'ZA',
  'xh': 'ZA',
  'af': 'ZA',
  'so': 'SO',
  'ny': 'MW',
  'ln': 'CD',
  'km': 'KH',
  'lo': 'LA',
  'mn': 'MN',
};

const Set<String> _kIndianLangCodes = {
  'hi', 'te', 'ta', 'ml', 'kn', 'bn', 'mr', 'gu', 'pa', 'or', 'ur', 'as',
  'ne', 'sd', 'si',
};

const Set<String> _kGlobalTopLangCodes = {
  'en', 'es', 'fr', 'de', 'zh', 'ja', 'ko', 'pt', 'it', 'ar', 'ru', 'tr',
};

const Set<String> _kEuropeanLangCodes = {
  'en', 'es', 'fr', 'de', 'pt', 'it', 'nl', 'sv', 'pl', 'uk', 'ro', 'el',
  'cs', 'hu', 'da', 'fi', 'no', 'sk', 'bg', 'hr', 'sr', 'bs', 'lt', 'sl',
  'lv', 'et', 'mk', 'be', 'ca', 'gl', 'is', 'ga', 'cy', 'lb', 'ru',
};

const Set<String> _kAsianLangCodes = {
  'zh', 'ja', 'ko', 'id', 'th', 'vi', 'tl', 'fil', 'ms', 'my', 'jv', 'ceb',
  'kk', 'uz', 'ky',
};

/// Converts a 2-letter country code into an emoji flag string.
String countryCodeToEmoji(String countryCode) {
  if (countryCode.length != 2) return '\u{1F3F3}';
  final firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
  final secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCodes([firstLetter, secondLetter]);
}

/// Builds a rounded flag badge for the given ISO language code.
Widget buildLanguageFlag(
  String langCode, {
  double width = 24,
  double height = 16,
}) {
  final code = kLanguageToCountryCode[langCode.toLowerCase()] ?? 'UN';
  final flagUrl = 'https://flagcdn.com/w40/${code.toLowerCase()}.png';
  final flagEmoji = countryCodeToEmoji(code);

  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: CachedNetworkImage(
      imageUrl: flagUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: Text(
          flagEmoji,
          style: TextStyle(fontSize: height * 0.72, height: 1),
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Text(
          flagEmoji,
          style: TextStyle(fontSize: height * 0.72, height: 1),
        ),
      ),
    ),
  );
}

/// Displays an interactive multi-select bottom sheet to pick one or more target
/// languages for audio tracks (up to [DubbingOptionsState.maxBatchLanguages]).
void showLanguagePicker(BuildContext context, DubbingOptionsState state) {
  final colors = context.colors;
  final typography = context.twTypography;
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final activeCategory = 'all'.obs;
  final allLanguages = state.controller.supportedLanguages;

  List<({String code, String name})> computeFiltered() {
    final q = searchQuery.value.trim().toLowerCase();
    final cat = activeCategory.value;

    return allLanguages.where((lang) {
      final code = lang.code.toLowerCase();
      if (cat == 'selected' && !state.isLanguageSelected(code)) return false;
      if (cat == 'indian' && !_kIndianLangCodes.contains(code)) return false;
      if (cat == 'global' && !_kGlobalTopLangCodes.contains(code)) return false;
      if (cat == 'european' && !_kEuropeanLangCodes.contains(code)) return false;
      if (cat == 'asian' && !_kAsianLangCodes.contains(code)) return false;

      if (q.isEmpty) return true;
      return lang.name.toLowerCase().contains(q) || code.contains(q);
    }).toList();
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final existingTracks =
          state.controller.selectedVideo.value?.audioTracks ?? const {};

      return Material(
        color: colors.appBarSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      color: colors.textPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Target Languages',
                            style: typography.headline.copyWith(
                              fontFamily: TWTypography.brandFamily,
                              fontSize: 18,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Obx(() {
                            final count = state.selectedLangCodes.length;
                            return Text(
                              'Pick 1 or up to ${DubbingOptionsState.maxBatchLanguages} languages ($count/${DubbingOptionsState.maxBatchLanguages} selected)',
                              style: typography.bodySmall.copyWith(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Obx(() {
                      final count = state.selectedLangCodes.length;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.brand,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: typography.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.textPrimary),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: colors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          maxLength: 100,
                          buildCounter: (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) =>
                              null,
                          inputFormatters:
                              TruthworldTextInputFormatters.withLimit(100),
                          onChanged: (q) => searchQuery.value = q,
                          style: typography.body.copyWith(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search language (e.g. Telugu, Hindi, Spanish)...',
                            hintStyle: typography.body.copyWith(
                              color: colors.textTertiary,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      Obx(() {
                        if (searchQuery.value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: () {
                            searchController.clear();
                            searchQuery.value = '';
                          },
                          child: Icon(
                            Icons.cancel,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Category filter pills + quick presets
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Obx(() {
                  final current = activeCategory.value;
                  final selectedCount = state.selectedLangCodes.length;
                  final cats = <({String id, String label})>[
                    const (id: 'all', label: 'All (70+)'),
                    if (selectedCount > 0)
                      (id: 'selected', label: 'Selected ($selectedCount)'),
                    const (id: 'indian', label: 'Indian'),
                    const (id: 'global', label: 'Global'),
                    const (id: 'european', label: 'European'),
                    const (id: 'asian', label: 'Asian'),
                  ];

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ...cats.map((cat) {
                          final isActive = current == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => activeCategory.value = cat.id,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? colors.brand
                                      : colors.surfaceInput,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isActive
                                        ? colors.brand
                                        : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Text(
                                  cat.label,
                                  style: typography.label.copyWith(
                                    fontSize: 12,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isActive
                                        ? Colors.black
                                        : colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => state.selectLanguagePreset(
                              const ['te', 'hi', 'ta', 'kn', 'ml'],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                '+ Top Indian',
                                style: typography.label.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => state.selectLanguagePreset(
                            const ['es', 'fr', 'de', 'ja', 'pt'],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              '+ Top Global',
                              style: typography.label.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              const SizedBox(height: 4),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

              // Language List
              Expanded(
                child: Obx(() {
                  final list = computeFiltered();
                  // Touch selectedLangCodes to guarantee reactive updates per row
                  final selectedSnapshot = state.selectedLangCodes.toSet();

                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No languages found',
                        style: typography.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (ctx, i) => Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    itemBuilder: (ctx, i) {
                      final lang = list[i];
                      final code = lang.code.toLowerCase();
                      final isSource = state.isSourceLanguage(code);
                      final isSelected = selectedSnapshot.contains(code);
                      final hasExistingTrack =
                          (existingTracks[code] ?? '').trim().isNotEmpty;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: buildLanguageFlag(code),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                lang.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.copyWith(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSource
                                      ? colors.textDisabled
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSource) ...[
                              const SizedBox(width: 8),
                              _LanguageMetaTag(
                                label: 'ORIGINAL',
                                color: colors.textTertiary,
                              ),
                            ] else if (hasExistingTrack) ...[
                              const SizedBox(width: 8),
                              _LanguageMetaTag(
                                label: 'ADDED',
                                color: colors.success,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          code.toUpperCase(),
                          style: typography.caption.copyWith(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                        trailing: isSource
                            ? Icon(
                                Icons.lock_outline_rounded,
                                color: colors.textDisabled,
                                size: 18,
                              )
                            : Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? colors.brand
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.brand
                                        : colors.textTertiary,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                        onTap: isSource
                            ? () {
                                AppSnackbar.info(
                                  '${lang.name} is the original spoken language of this video. Use the "Change" option to switch it.',
                                );
                              }
                            : () => state.toggleLanguage(code),
                      );
                    },
                  );
                }),
              ),

              // Bottom Confirmation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final count = state.selectedLangCodes.length;
                          return Row(
                            children: [
                              Flexible(
                                child: Text(
                                  count == 0
                                      ? 'No languages selected'
                                      : '$count ${count == 1 ? 'language' : 'languages'} selected',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.title.copyWith(
                                    fontSize: 13.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: state.clearLanguages,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: typography.label.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: typography.button.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LanguageMetaTag extends StatelessWidget {
  const _LanguageMetaTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.twTypography.overline.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

/// Target Language(s) card matching the sleek single-row layout from the redesign,
/// and seamlessly expanding to removable language chips when multiple languages are selected.
class DubbingLanguageBar extends StatelessWidget {
  const DubbingLanguageBar({
    required this.state,
    super.key,
  });

  final DubbingOptionsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;

    return Obx(() {
      final selectedCodes = state.selectedLangCodes.toList();
      final isMulti = selectedCodes.length > 1;
      final singleCode =
          selectedCodes.isNotEmpty ? selectedCodes.first : '';
      final singleName = singleCode.isNotEmpty
          ? state.controller.getLanguageName(singleCode)
          : '';

      return DubbingOptionCard(
        onTap: state.allowLanguageSwitch
            ? () => showLanguagePicker(context, state)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 22,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          isMulti ? 'Target Languages' : 'Target Language',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.title.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  flex: 11,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: selectedCodes.isEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Select a language',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.body.copyWith(
                                    fontSize: 14,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              if (state.allowLanguageSwitch) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ],
                          )
                        : isMulti
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${selectedCodes.length} languages',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: typography.body.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (state.allowLanguageSwitch) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  buildLanguageFlag(
                                    singleCode,
                                    width: 22,
                                    height: 15,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      singleName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      style: typography.body.copyWith(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (state.allowLanguageSwitch) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: colors.textSecondary,
                                    ),
                                  ],
                                ],
                              ),
                  ),
                ),
              ],
            ),

            // Multi-language chips strip when 2+ languages are selected
            if (isMulti) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...selectedCodes.map((code) {
                    final name = state.controller.getLanguageName(code);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceInput,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildLanguageFlag(code, width: 18, height: 12),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.label.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (state.allowLanguageSwitch) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => state.removeLanguage(code),
                              child: Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  if (state.allowLanguageSwitch &&
                      selectedCodes.length <
                          DubbingOptionsState.maxBatchLanguages)
                    InkWell(
                      onTap: () => showLanguagePicker(context, state),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: colors.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: typography.label.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
