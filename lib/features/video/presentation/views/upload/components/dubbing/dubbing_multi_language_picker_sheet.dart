import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';

/// Mapping from supported language names to their primary country for national flag display.
const Map<String, String> languageToCountryMap = {
  'English': 'United States',
  'Spanish': 'Spain',
  'French': 'France',
  'German': 'Germany',
  'Hindi': 'India',
  'Japanese': 'Japan',
  'Chinese (Mandarin)': 'China',
  'Portuguese': 'Brazil',
  'Italian': 'Italy',
  'Arabic': 'Saudi Arabia',
  'Russian': 'Russia',
  'Korean': 'South Korea',
  'Bengali': 'Bangladesh',
  'Telugu': 'India',
  'Tamil': 'India',
  'Marathi': 'India',
  'Gujarati': 'India',
  'Kannada': 'India',
  'Malayalam': 'India',
  'Punjabi': 'India',
  'Urdu': 'Pakistan',
  'Nepali': 'Nepal',
  'Turkish': 'Turkey',
  'Dutch': 'Netherlands',
  'Swedish': 'Sweden',
  'Polish': 'Poland',
  'Czech': 'Czech Republic',
  'Greek': 'Greece',
  'Hungarian': 'Hungary',
  'Danish': 'Denmark',
  'Finnish': 'Finland',
  'Norwegian': 'Norway',
  'Slovak': 'Slovakia',
  'Bulgarian': 'Bulgaria',
  'Catalan': 'Spain',
  'Croatian': 'Croatia',
  'Lithuanian': 'Lithuania',
  'Slovenian': 'Slovenia',
  'Romanian': 'Romania',
  'Ukrainian': 'Ukraine',
  'Estonian': 'Estonia',
  'Latvian': 'Latvia',
  'Serbian': 'Serbia',
  'Albanian': 'Albania',
  'Basque': 'Spain',
  'Belarusian': 'Belarus',
  'Bosnian': 'Bosnia and Herzegovina',
  'Galician': 'Spain',
  'Georgian': 'Georgia',
  'Icelandic': 'Iceland',
  'Irish': 'Ireland',
  'Macedonian': 'North Macedonia',
  'Maltese': 'Malta',
  'Welsh': 'United Kingdom',
  'Yiddish': 'Israel',
  'Indonesian': 'Indonesia',
  'Thai': 'Thailand',
  'Vietnamese': 'Vietnam',
  'Tagalog': 'Philippines',
  'Malay': 'Malaysia',
  'Kazakh': 'Kazakhstan',
  'Uzbek': 'Uzbekistan',
  'Hebrew': 'Israel',
  'Persian': 'Iran',
  'Afrikaans': 'South Africa',
  'Azerbaijani': 'Azerbaijan',
  'Somali': 'Somalia',
  'Swahili': 'Kenya',
  'Zulu': 'South Africa',
};

/// Builds the appropriate flag for a language or falls back to a clean language icon.
Widget buildLanguageFlag(String languageName, {double width = 26, double height = 18}) {
  final countryName = languageToCountryMap[languageName];
  if (countryName != null) {
    return ChannelWizardCountryCard.buildCountryFlag(
      countryName,
      width: width,
      height: height,
    );
  }
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFF27272A),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFF3F3F46), width: 0.5),
    ),
    child: const Icon(
      Icons.language,
      color: Colors.white70,
      size: 14,
    ),
  );
}

/// Displays the multi-select language sheet for Dubbing, matching the country selection
/// in channel creation with multi-selection capabilities.
void showDubbingMultiLanguagePicker({
  required BuildContext context,
  required UploadDubbingController controller,
}) {
  final searchController = TextEditingController();
  final activeSearch = ''.obs;
  final activeCategory = 'all'.obs;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Material(
        color: const Color(0xFF16171E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              // Top drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Row
              _buildPickerHeader(
                icon: Icons.translate,
                iconColor: const Color(0xFFA78BFA),
                iconBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                title: 'Select Dubbing Languages',
                selectedCount: () => controller.selectedLanguages.length,
                emptySubtitle: 'Choose 1 or more target languages',
                selectedSubtitleBuilder: (count) =>
                    '$count languages selected for AI dubbing',
                onClose: () => Navigator.pop(ctx),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101116),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF262834)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          maxLength: 100,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                          onChanged: (query) {
                            activeSearch.value = query;
                            controller.searchQuery.value = query;
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Search 70+ languages (e.g. Hindi, Spanish, French)...',
                            hintStyle: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Obx(() {
                        if (activeSearch.value.isNotEmpty) {
                          return GestureDetector(
                            onTap: () {
                              searchController.clear();
                              activeSearch.value = '';
                              controller.searchQuery.value = '';
                            },
                            child: const Icon(
                              Icons.cancel,
                              color: Color(0xFFA1A1AA),
                              size: 18,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),

              // Category Filter Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Obx(() {
                  final current = activeCategory.value;
                  final selectedCount = controller.selectedLanguages.length;
                  final categories = [
                    {'id': 'all', 'label': 'All (70+)'},
                    if (selectedCount > 0)
                      {'id': 'selected', 'label': 'Selected ($selectedCount)'},
                    {'id': 'popular', 'label': 'Popular'},
                    {'id': 'indic', 'label': 'Indic'},
                    {'id': 'european', 'label': 'European'},
                    {'id': 'asian', 'label': 'Asian & Pacific'},
                    {'id': 'middle_east_africa', 'label': 'Middle East & Africa'},
                  ];

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: categories.map((cat) {
                        final isSelected = current == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            onTap: () {
                              activeCategory.value = cat['id']!;
                              controller.selectedCategoryFilter.value = cat['id']!;
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF101116),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.white : const Color(0xFF262834),
                                ),
                              ),
                              child: Text(
                                cat['label']!,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : const Color(0xFFA1A1AA),
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ),

              // Quick Presets Row
              _buildQuickPresetsBar(
                presets: [
                  _buildPresetButton(
                    title: '+ Top 5 Global',
                    onTap: controller.selectTopGlobal,
                  ),
                  const SizedBox(width: 6),
                  _buildPresetButton(
                    title: '+ Top Indic',
                    onTap: controller.selectTopIndic,
                  ),
                  const SizedBox(width: 6),
                  _buildPresetButton(
                    title: '+ Top European',
                    onTap: controller.selectTopEuropean,
                  ),
                ],
                hasSelection: () => controller.selectedLanguages.isNotEmpty,
                onClearAll: controller.clearAll,
              ),

              const SizedBox(height: 6),
              const Divider(color: Color(0xFF242632), height: 1),

              // Languages List
              Expanded(
                child: Obx(() {
                  final list = controller.filteredLanguages;

                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No languages match your search or filter.',
                          style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: list.length,
                    separatorBuilder: (c, i) => const Divider(
                      color: Color(0xFF20222B),
                      height: 1,
                    ),
                    itemBuilder: (c, i) {
                      final lang = list[i];
                      final isSource = controller.isSourceLanguage(lang);
                      final isSelected = controller.isLanguageSelected(lang);

                      return ListTile(
                        onTap: isSource ? null : () => controller.toggleLanguage(lang),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        leading: buildLanguageFlag(lang.name),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                lang.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSource ? Colors.white38 : Colors.white,
                                ),
                              ),
                            ),
                            if (isSource) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 10, color: Colors.white38),
                                    SizedBox(width: 3),
                                    Text(
                                      'SOURCE LANGUAGE',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          lang.nativeName.isNotEmpty ? lang.nativeName : lang.code.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSource ? Colors.white24 : const Color(0xFFA1A1AA),
                          ),
                        ),
                        trailing: isSource
                            ? const Icon(Icons.lock, color: Colors.white24, size: 18)
                            : Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : const Color(0xFF3F3F46),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 15,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                      );
                    },
                  );
                }),
              ),

              // Bottom Sticky Confirmation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF101116),
                  border: Border(
                    top: BorderSide(color: Color(0xFF242632)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final count = controller.selectedLanguages.length;
                          final cost = controller.calculatedCost;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$count languages selected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (count > 0)
                                Text(
                                  'Estimated Dubbing: \$${cost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
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

/// Displays the multi-select language sheet for Subtitles, matching the country selection
/// in channel creation with multi-selection capabilities.
void showSubtitlesMultiLanguagePicker({
  required BuildContext context,
  required UploadController controller,
}) {
  final searchController = TextEditingController();
  final activeSearch = ''.obs;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Material(
        color: const Color(0xFF16171E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              // Top drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Row
              _buildPickerHeader(
                icon: Icons.subtitles,
                iconColor: const Color(0xFF60A5FA),
                iconBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.18),
                title: 'Select Subtitle Languages',
                selectedCount: () => controller.aiTranslationLanguages.length,
                emptySubtitle: '130+ languages supported via Google Cloud',
                selectedSubtitleBuilder: (count) =>
                    '$count languages selected for subtitles',
                onClose: () => Navigator.pop(ctx),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101116),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF262834)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          maxLength: 100,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                          onChanged: (query) => activeSearch.value = query,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: 'Search 130+ subtitle languages...',
                            hintStyle: TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Obx(() {
                        if (activeSearch.value.isNotEmpty) {
                          return GestureDetector(
                            onTap: () {
                              searchController.clear();
                              activeSearch.value = '';
                            },
                            child: const Icon(
                              Icons.cancel,
                              color: Color(0xFFA1A1AA),
                              size: 18,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),

              // Quick Presets Row
              _buildQuickPresetsBar(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                presets: [
                  _buildPresetButton(
                    title: '+ Top 5 Global',
                    onTap: () {
                      const topGlobal = ['English', 'Spanish', 'French', 'German', 'Chinese (Simplified)'];
                      for (final l in topGlobal) {
                        if (!controller.aiTranslationLanguages.contains(l)) {
                          controller.aiTranslationLanguages.add(l);
                        }
                      }
                      controller.aiGenerateSubtitles.value = true;
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildPresetButton(
                    title: '+ Top Indic',
                    onTap: () {
                      const topIndic = ['Hindi', 'Bengali', 'Telugu', 'Tamil', 'Marathi'];
                      for (final l in topIndic) {
                        if (!controller.aiTranslationLanguages.contains(l)) {
                          controller.aiTranslationLanguages.add(l);
                        }
                      }
                      controller.aiGenerateSubtitles.value = true;
                    },
                  ),
                ],
                hasSelection: () => controller.aiTranslationLanguages.isNotEmpty,
                onClearAll: () => controller.aiTranslationLanguages.clear(),
              ),

              const SizedBox(height: 6),
              const Divider(color: Color(0xFF242632), height: 1),

              // Subtitles Language List
              Expanded(
                child: Obx(() {
                  final q = activeSearch.value.trim().toLowerCase();
                  final allLangs = supportedLanguages.where((l) {
                    if (q.isEmpty) return true;
                    return l.name.toLowerCase().contains(q) ||
                        l.nativeName.toLowerCase().contains(q) ||
                        l.code.toLowerCase().contains(q);
                  }).toList();

                  if (allLangs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No subtitle languages match your search.',
                          style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: allLangs.length,
                    separatorBuilder: (c, i) => const Divider(
                      color: Color(0xFF20222B),
                      height: 1,
                    ),
                    itemBuilder: (c, i) {
                      final lang = allLangs[i];
                      return Obx(() {
                        final isSelected = controller.aiTranslationLanguages.any(
                          (l) => l.trim().toLowerCase() == lang.name.toLowerCase() ||
                              l.trim().toLowerCase() == lang.code.toLowerCase(),
                        );

                        return ListTile(
                          onTap: () {
                            if (isSelected) {
                              controller.aiTranslationLanguages.removeWhere(
                                (l) => l.trim().toLowerCase() == lang.name.toLowerCase() ||
                                    l.trim().toLowerCase() == lang.code.toLowerCase(),
                              );
                            } else {
                              controller.aiTranslationLanguages.add(lang.name);
                              controller.aiGenerateSubtitles.value = true;
                            }
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: buildLanguageFlag(lang.name),
                          title: Text(
                            lang.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            lang.nativeName.isNotEmpty ? lang.nativeName : lang.code.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                          trailing: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.white : const Color(0xFF3F3F46),
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Colors.black,
                                  )
                                : null,
                          ),
                        );
                      });
                    },
                  );
                }),
              ),

              // Bottom Sticky Confirmation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF101116),
                  border: Border(
                    top: BorderSide(color: Color(0xFF242632)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final count = controller.aiTranslationLanguages.length;
                          return Text(
                            '$count languages selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
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

/// Renders the header row for multi-language picker sheets with bounded text
/// lines so narrow viewports do not cause unbounded header wrapping.
Widget _buildPickerHeader({
  required IconData icon,
  required Color iconColor,
  required Color iconBackgroundColor,
  required String title,
  required int Function() selectedCount,
  required String emptySubtitle,
  required String Function(int count) selectedSubtitleBuilder,
  required VoidCallback onClose,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Obx(() {
                final count = selectedCount();
                return Text(
                  count == 0 ? emptySubtitle : selectedSubtitleBuilder(count),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                );
              }),
            ],
          ),
        ),
        Obx(() {
          final count = selectedCount();
          if (count > 0) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$count Selected',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: onClose,
        ),
      ],
    ),
  );
}

/// Renders a horizontally scrollable quick-preset bar with a pinned Clear All button
/// so narrow screens and large text scales never trigger RenderFlex overflow.
Widget _buildQuickPresetsBar({
  required List<Widget> presets,
  required bool Function() hasSelection,
  required VoidCallback onClearAll,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
}) {
  return Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: presets),
          ),
        ),
        Obx(() {
          if (!hasSelection()) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Semantics(
              button: true,
              label: 'Clear all selected languages',
              child: InkWell(
                onTap: onClearAll,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildPresetButton({
  required String title,
  required VoidCallback onTap,
}) {
  return Semantics(
    button: true,
    label: title,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1F212A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2D303E)),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
