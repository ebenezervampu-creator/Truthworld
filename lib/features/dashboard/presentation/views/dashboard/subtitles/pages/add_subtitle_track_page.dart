import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated, full-screen responsive page for adding and provisioning subtitle tracks
class AddSubtitleTrackPage extends StatelessWidget {
  const AddSubtitleTrackPage({
    required this.controller,
    required this.isDarkMode,
    this.initialLanguage,
    this.initialCreationMode,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;
  final String? initialLanguage;
  final String? initialCreationMode;

  @override
  Widget build(BuildContext context) {
    final video = controller.selectedVideo.value;
    final surfaceColor =
        isDarkMode ? AppColors.bgSurface : AppColors.bgSurface;
    const bgColor = AppColors.bgPage;
    final textColor =
        isDarkMode ? AppColors.textPrimary : AppColors.textPrimary;
    final textSecondaryColor =
        isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : AppColors.bgSurface;

    // Reactive state for the page (Zero setState policy)
    final creationMode = (initialCreationMode ?? 'manual').obs; // 'manual' | 'duplicate' | 'upload'
    final initialLangObj = initialLanguage != null
        ? supportedLanguages.firstWhereOrNull((l) => l.code == normalizeLanguageCode(initialLanguage!))
        : null;
    final selectedLanguage = Rxn<TranslationLanguage>(initialLangObj);
    final availableTracksWithSubs = controller.availableLanguagesWithSubtitles;
    final defaultSourceLang = availableTracksWithSubs.isNotEmpty
        ? (availableTracksWithSubs.contains('en') ? 'en' : availableTracksWithSubs.first)
        : (controller.availableLanguages.isNotEmpty ? controller.availableLanguages.first : '');
    final duplicateFromLang = defaultSourceLang.obs;
    final titleController = TextEditingController(text: initialLangObj?.name ?? '');
    final titleError = RxnString();
    final pickedFile = Rxn<PlatformFile>();
    final searchQuery = ''.obs;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Get.back<void>(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Subtitle Track',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (video != null)
              Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final isTablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 900;
            final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  children: [
                    // Video Mini-Header Card
                    if (video != null)
                      _buildVideoHeaderCard(
                        video: video,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    const SizedBox(height: 20),

                    // Section 1: Choose Method (Cards)
                    _buildSectionTitle(
                      title: '1. Select Creation Method',
                      subtitle:
                          'Choose how you want to author this subtitle track',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildCreationModeSelector(
                      creationMode: creationMode,
                      controller: controller,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Method Specific Configuration
                    Obx(() {
                      if (creationMode.value == 'duplicate') {
                        return _buildDuplicateSettings(
                          duplicateFromLang: duplicateFromLang,
                          controller: controller,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          textSecondaryColor: textSecondaryColor,
                        );
                      } else if (creationMode.value == 'upload') {
                        return _buildUploadFileSection(
                          pickedFile: pickedFile,
                          controller: controller,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          textSecondaryColor: textSecondaryColor,
                        );
                      }
                      return const SizedBox.shrink();
                    }),

                    // Section 3: Target Language Selection
                    _buildSectionTitle(
                      title: '2. Target Language',
                      subtitle:
                          'Select the language for this subtitle translation',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildLanguagePicker(
                      selectedLanguage: selectedLanguage,
                      searchQuery: searchQuery,
                      controller: controller,
                      titleController: titleController,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Section 4: Custom Track Label / Title
                    _buildSectionTitle(
                      title: '3. Track Title (Optional)',
                      subtitle:
                          'Customize how this subtitle track appears to viewers',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildTitleInputField(
                      titleController: titleController,
                      titleError: titleError,
                      controller: controller,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons Bar
                    _buildActionButtons(
                      creationMode: creationMode,
                      selectedLanguage: selectedLanguage,
                      duplicateFromLang: duplicateFromLang,
                      pickedFile: pickedFile,
                      titleController: titleController,
                      titleError: titleError,
                      controller: controller,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // VIDEO CONTEXT HEADER CARD
  // ===========================================================================
  Widget _buildVideoHeaderCard({
    required Video video,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              width: 80,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                width: 80,
                height: 48,
                color: Colors.black26,
                child: const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Duration: ${video.duration}',
                      style: TextStyle(fontSize: 12, color: textSecondaryColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${controller.availableLanguages.length} Active Tracks',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================
  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textSecondaryColor),
        ),
      ],
    );
  }

  // ===========================================================================
  // CREATION MODE SELECTOR
  // ===========================================================================
  Widget _buildCreationModeSelector({
    required RxString creationMode,
    required SubtitlesController controller,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    final hasExistingCues = controller.currentCues.isNotEmpty ||
        controller.hasAnyPublishedSubtitles;

    return Obx(() {
      final current = creationMode.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final items = [
            const _ModeOption(
              key: 'manual',
              title: 'Blank Track',
              subtitle: 'Start with an empty timeline and write cues manually.',
              icon: Icons.edit_note_rounded,
            ),
            _ModeOption(
              key: 'duplicate',
              title: 'Copy Timings',
              subtitle: hasExistingCues
                  ? 'Clone cue intervals from an active track for translation.'
                  : 'Requires existing track with defined cue intervals.',
              icon: Icons.copy_all_rounded,
              disabled: !hasExistingCues,
            ),
            const _ModeOption(
              key: 'upload',
              title: 'Upload File',
              subtitle: 'Import existing .srt, .vtt, .txt, or .json file.',
              icon: Icons.upload_file_rounded,
            ),
          ];

          if (isNarrow) {
            return Column(
              children: items
                  .map(
                    (opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildModeCard(
                        option: opt,
                        isSelected: current == opt.key,
                        onTap: () {
                          if (!opt.disabled) creationMode.value = opt.key;
                        },
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            children: items
                .map(
                  (opt) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildModeCard(
                        option: opt,
                        isSelected: current == opt.key,
                        onTap: () {
                          if (!opt.disabled) creationMode.value = opt.key;
                        },
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
    });
  }

  Widget _buildModeCard({
    required _ModeOption option,
    required bool isSelected,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: option.disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.12)
              : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (option.disabled
                    ? borderColor.withValues(alpha: 0.4)
                    : borderColor),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  option.icon,
                  size: 22,
                  color: option.disabled
                      ? AppColors.textDisabled
                      : (isSelected ? AppColors.brand : Colors.white),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              option.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: option.disabled ? AppColors.textDisabled : textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: option.disabled
                    ? AppColors.textDisabled
                    : textSecondaryColor,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DUPLICATE FROM EXISTING TRACK SECTION
  // ===========================================================================
  Widget _buildDuplicateSettings({
    required RxString duplicateFromLang,
    required SubtitlesController controller,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Source Track to Copy Timings From',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final availableTracks = controller.availableLanguagesWithSubtitles.isNotEmpty
                ? controller.availableLanguagesWithSubtitles
                : controller.availableLanguages;
            final currentSelected = duplicateFromLang.value.isNotEmpty && availableTracks.contains(duplicateFromLang.value)
                ? duplicateFromLang.value
                : (availableTracks.isNotEmpty ? availableTracks.first : null);

            return DropdownButtonFormField<String>(
              value: currentSelected,
              dropdownColor: surfaceColor,
              items: availableTracks.map((code) {
                final hasPublished = controller.hasPublishedSubtitles(code);
                return DropdownMenuItem<String>(
                  value: code,
                  child: Text(
                    '${controller.getLanguageName(code)} ($code)${hasPublished ? " • Available" : ""}',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) duplicateFromLang.value = val;
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // UPLOAD FILE SECTION
  // ===========================================================================
  Widget _buildUploadFileSection({
    required Rxn<PlatformFile> pickedFile,
    required SubtitlesController controller,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.file_upload_outlined,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Subtitle File (.vtt, .srt, .txt, .json)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final file = pickedFile.value;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    file != null
                        ? Icons.description_rounded
                        : Icons.cloud_upload_outlined,
                    size: 28,
                    color: file != null ? AppColors.brand : Colors.white60,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file != null ? file.name : 'No file chosen yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: file != null ? textColor : textSecondaryColor,
                          ),
                        ),
                        if (file != null)
                          Text(
                            'Size: ${(file.size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondaryColor,
                            ),
                          )
                        else
                          Text(
                            'Supported: SubRip (.srt), WebVTT (.vtt), Timed JSON',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondaryColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['vtt', 'srt', 'txt', 'json'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          pickedFile.value = result.files.first;
                        }
                      } catch (e) {
                        ErrorHandler.log(e, tag: 'AddSubtitleTrackPage');
                        controller.showError(
                          'Unable to select file. Please try again.',
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.folder_open_rounded,
                      size: 15,
                      color: Colors.black,
                    ),
                    label: Text(
                      file != null ? 'Change' : 'Browse',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TARGET LANGUAGE PICKER (SEARCH + POPULAR CHIPS + LIST)
  // ===========================================================================
  Widget _buildLanguagePicker({
    required Rxn<TranslationLanguage> selectedLanguage,
    required RxString searchQuery,
    required SubtitlesController controller,
    required TextEditingController titleController,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    final popularCodes = [
      'en',
      'es',
      'hi',
      'te',
      'ta',
      'fr',
      'de',
      'ja',
      'ar',
      'pt',
      'ru',
      'zh',
      'ko',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search 130+ languages (e.g., Telugu, Spanish)...',
                hintStyle: TextStyle(fontSize: 13, color: textSecondaryColor),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white60,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onChanged: (q) => searchQuery.value = q.trim().toLowerCase(),
            ),
          ),
          const SizedBox(height: 12),

          // Popular Language Quick-Select Chips
          Text(
            'Popular Languages',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: popularCodes.map((code) {
              final lang = supportedLanguages.firstWhereOrNull(
                (l) => l.code == code,
              );
              if (lang == null) return const SizedBox.shrink();

              final isAlreadyAdded =
                  controller.hasPublishedSubtitles(code);

              return Obx(() {
                final isSelected = selectedLanguage.value?.code == code;

                return ChoiceChip(
                  label: Text('${lang.name} (${lang.nativeName})'),
                  selected: isSelected,
                  onSelected: isAlreadyAdded
                      ? null
                      : (sel) {
                          if (sel) {
                            selectedLanguage.value = lang;
                            if (titleController.text.trim().isEmpty) {
                              titleController.text = lang.name;
                            }
                          }
                        },
                  selectedColor: AppColors.brand,
                  backgroundColor: AppColors.bgPage,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isAlreadyAdded
                        ? AppColors.textDisabled
                        : (isSelected ? Colors.black : textColor),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.brand
                        : (isAlreadyAdded
                            ? Colors.transparent
                            : borderColor),
                  ),
                );
              });
            }).toList(),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),

          // Scrollable Language List
          Obx(() {
            final query = searchQuery.value;
            final filtered = supportedLanguages.where((l) {
              if (query.isEmpty) return true;
              return l.name.toLowerCase().contains(query) ||
                  l.nativeName.toLowerCase().contains(query) ||
                  l.code.toLowerCase().contains(query);
            }).toList();

            return Material(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No languages match "$query"',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondaryColor,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: borderColor),
                        itemBuilder: (context, index) {
                          final lang = filtered[index];
                          final isAlreadyAdded =
                              controller.hasPublishedSubtitles(lang.code);

                          return Obx(() {
                            final isSelected =
                                selectedLanguage.value?.code == lang.code;

                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                enabled: !isAlreadyAdded,
                                tileColor: isSelected
                                    ? AppColors.brand.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.brand
                                        : surfaceColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    lang.code.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.black : textColor,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  lang.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isAlreadyAdded
                                        ? AppColors.textDisabled
                                        : (isSelected
                                            ? AppColors.brand
                                            : textColor),
                                  ),
                                ),
                                subtitle: Text(
                                  lang.nativeName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isAlreadyAdded
                                        ? AppColors.textDisabled
                                        : textSecondaryColor,
                                  ),
                                ),
                                trailing: isAlreadyAdded
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Added',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textDisabled,
                                          ),
                                        ),
                                      )
                                    : (isSelected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                            color: AppColors.brand,
                                          )
                                        : const Icon(
                                            Icons.radio_button_unchecked_rounded,
                                            size: 18,
                                            color: Colors.white38,
                                          )),
                                onTap: () {
                                  selectedLanguage.value = lang;
                                  if (titleController.text.trim().isEmpty) {
                                    titleController.text = lang.name;
                                  }
                                },
                              ),
                            );
                          });
                        },
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TITLE INPUT FIELD
  // ===========================================================================
  Widget _buildTitleInputField({
    required TextEditingController titleController,
    required RxnString titleError,
    required SubtitlesController controller,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Obx(() {
        return TextFormField(
          controller: titleController,
          maxLength: 100,
          buildCounter: (
            context, {
            required currentLength,
            required isFocused,
            maxLength,
          }) =>
              null,
          inputFormatters:
              TruthworldTextInputFormatters.internationalWithLimit(100),
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            labelText: 'Subtitle Track Display Title',
            hintText: 'e.g., Spanish (Latin America) or English (CC)',
            errorText: titleError.value,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          onChanged: (val) {
            if (val.trim().isNotEmpty &&
                controller.profanityFilter.hasProfanity(val)) {
              titleError.value = 'Title contains inappropriate language.';
            } else {
              titleError.value = null;
            }
          },
        );
      }),
    );
  }

  // ===========================================================================
  // ACTION BUTTONS (CANCEL / CREATE)
  // ===========================================================================
  Widget _buildActionButtons({
    required RxString creationMode,
    required Rxn<TranslationLanguage> selectedLanguage,
    required RxString duplicateFromLang,
    required Rxn<PlatformFile> pickedFile,
    required TextEditingController titleController,
    required RxnString titleError,
    required SubtitlesController controller,
  }) {
    return Obx(() {
      final isUploading = controller.isUploadingFile.value;

      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: isUploading ? null : () => Get.back<void>(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isUploading
                  ? null
                  : () async {
                      final lang = selectedLanguage.value;
                      if (lang == null) {
                        controller.showError('Please select a target language.');
                        return;
                      }

                      final title = titleController.text.trim().isNotEmpty
                          ? titleController.text.trim()
                          : lang.name;

                      final check = await controller.validateContent(
                        title,
                        fieldName: 'Track Title',
                      );
                      if (!check.isValid) {
                        titleError.value = check.message;
                        controller.showError(check.message);
                        return;
                      }

                      if (creationMode.value == 'upload') {
                        final file = pickedFile.value;
                        if (file == null) {
                          controller.showError('Please select a subtitle file.');
                          return;
                        }

                        await controller.uploadSubtitleTrack(
                          languageCode: lang.code,
                          title: title,
                          file: file,
                        );
                        Get.back<void>();
                      } else if (creationMode.value == 'duplicate') {
                        controller.addLanguageTrack(
                          lang.code,
                          copyFromLanguage: duplicateFromLang.value,
                        );
                        Get.back<void>();
                      } else {
                        controller.addLanguageTrack(lang.code);
                        Get.back<void>();
                      }
                    },
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
              label: Text(
                isUploading ? 'Uploading...' : 'Create Subtitle Track',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _ModeOption {
  const _ModeOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.disabled = false,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool disabled;
}
