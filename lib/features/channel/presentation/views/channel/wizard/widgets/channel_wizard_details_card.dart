import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardDetailsCard extends StatelessWidget {
  final ChannelController controller;
  final RxList<String> tagList;
  final bool isDarkMode;
  final ChannelWizardViewController? wizardController;

  const ChannelWizardDetailsCard({
    required this.controller,
    required this.tagList,
    required this.isDarkMode,
    this.wizardController,
    super.key,
  });

  ChannelWizardViewController get _wc =>
      wizardController ?? Get.find<ChannelWizardViewController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Channel Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Channel Name
          const ChannelWizardFieldLabel('Channel Name', isRequired: true),
          const SizedBox(height: 8),
          ChannelWizardInputField(
            controller: controller.channelName,
            hintText: 'Enter channel name',
            maxLength: 100,
            suffix: Obx(() => _buildAvailabilityStatusSuffix(
              controller.channelNameAvailability.value,
            )),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Channel name is required';
              }
              if (controller.profanityFilter.hasProfanity(val.trim())) {
                return 'Please avoid offensive or profane language';
              }
              return null;
            },
          ),
          Obx(() => _buildAvailabilityStatusMessage(
            status: controller.channelNameAvailability.value,
            message: controller.channelNameAvailabilityMessage.value,
            fieldLabel: 'Channel name',
          )),
          const SizedBox(height: 16),
          // Channel Handle
          const ChannelWizardFieldLabel('Channel Handle', isRequired: true),
          const SizedBox(height: 8),
          ChannelWizardInputField(
            controller: controller.customUrl,
            hintText: 'Enter handle',
            prefixText: '@',
            maxLength: 30,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_-]')),
            ],
            suffix: Obx(() => _buildAvailabilityStatusSuffix(
              controller.customUrlAvailability.value,
            )),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Channel handle is required';
              }
              if (controller.profanityFilter.hasProfanity(val.trim())) {
                return 'Please avoid offensive or profane language';
              }
              return null;
            },
          ),
          Obx(() => _buildAvailabilityStatusMessage(
            status: controller.customUrlAvailability.value,
            message: controller.customUrlAvailabilityMessage.value,
            fieldLabel: 'Handle',
          )),
          Obx(() {
            if (controller.customUrlAvailability.value == AvailabilityStatus.taken &&
                controller.handleSuggestions.isNotEmpty) {
              return _buildHandleSuggestionsSection();
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 16),
          // Description
          const ChannelWizardFieldLabel('Description', isRequired: true),
          const SizedBox(height: 8),
          ChannelWizardInputField(
            controller: controller.description,
            hintText: 'Tell viewers about your channel...',
            maxLines: 4,
            maxLength: 5000,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Description is required';
              }
              if (controller.profanityFilter.hasProfanity(val.trim())) {
                return 'Please avoid offensive or profane language';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Tags
          const ChannelWizardFieldLabel('Tags', isRequired: false),
          const SizedBox(height: 8),
          _buildTagInputField(),
          _buildTagAutocompleteSuggestions(),
          const SizedBox(height: 12),
          _buildTagChipsWrap(),
          _buildSuggestedTagsSection(),
        ],
      ),
    );
  }

  Widget _buildTagInputField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _wc.tagInputController,
        maxLength: 30,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: TruthworldTextInputFormatters.withLimit(30),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (val) {
          _wc.tagSearchQuery.value = val.trim();
          _wc.fetchRealMatchingTagsFromFirestore(val);
          if (val.contains(',')) {
            _wc.addTag(val);
          }
        },
        onSubmitted: _wc.addTag,
        decoration: const InputDecoration(
          hintText: 'Add tags (type & press Enter or comma)',
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTagAutocompleteSuggestions() {
    return Obx(() {
      final query = _wc.tagQueryText.toLowerCase().trim();
      if (query.isEmpty) return const SizedBox.shrink();

      final currentTags = tagList.toList();

      // ONLY use real Firestore suggestions from the database
      final realMatches = <Map<String, dynamic>>[];
      for (final item in _wc.liveFirestoreSuggestions) {
        final name = item['name'] as String;
        if (!currentTags.contains(name)) {
          realMatches.add(item);
        }
      }

      if (_wc.isSearchingTags.value && realMatches.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Searching tags...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (realMatches.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: () {
              _wc.addTag(_wc.tagInputController.text);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add "${_wc.tagQueryText}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final displayList = realMatches.take(6).toList();

      return Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF27272A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Matching Tags (${displayList.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Divider(color: Color(0xFF27272A), height: 1),
            ...displayList.map((item) {
              final tag = item['name'] as String;
              final usage = _wc.getTagUsageCountFormatted(tag);
              return InkWell(
                onTap: () => _wc.addTag(tag),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tag, size: 15, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3F3F46)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.trending_up,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$usage used',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildTagChipsWrap() {
    return Obx(() {
      final tags = tagList.toList();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...tags.map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF212124),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _wc.removeTag(tag),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_wc.tagInputController.text.trim().isNotEmpty) {
                _wc.addTag(_wc.tagInputController.text);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF212124),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      );
    });
  }

  static const Map<String, List<String>> _categoryRecommendedTags = {
    'Business': [
      'Startup India',
      'Startup',
      'Entrepreneur',
      'Investing',
      'Stocks',
      'Leadership',
      'Marketing',
    ],
    'History': [
      'World History',
      'Ancient Civilizations',
      'Documentaries',
      'Biographies',
      'Archaeology',
    ],
    'News': [
      'Politics',
      'Breaking News',
      'World News',
      'Journalism',
      'Current Events',
      'Analysis',
    ],
    'Education': [
      'Tutorials',
      'Lectures',
      'Courses',
      'Self Improvement',
      'Study Tips',
    ],
    'Science': [
      'Astronomy',
      'Physics',
      'Biology',
      'Space',
      'Chemistry',
      'Research',
    ],
    'Technology': [
      'AI',
      'Coding',
      'Gadgets',
      'Software',
      'Tech Reviews',
      'Cybersecurity',
    ],
    'Finance': [
      'Cryptocurrency',
      'Wealth',
      'Real Estate',
      'Personal Finance',
      'Trading',
      'Stocks',
    ],
    'Health': [
      'Wellness',
      'Mental Health',
      'Nutrition',
      'Medicine',
      'Healthcare',
    ],
    'Documentary': [
      'Deep Dives',
      'Investigation',
      'True Stories',
      'Real Life',
      'Expose',
    ],
    'Fitness': [
      'Workout',
      'Gym',
      'Bodybuilding',
      'Yoga',
      'Crossfit',
      'Exercise',
    ],
    'Music': [
      'Covers',
      'Live Performance',
      'Beats',
      'EDM',
      'HipHop',
      'Acoustic',
      'Songwriting',
    ],
    'Entertainment': [
      'Vlogs',
      'Reactions',
      'Reviews',
      'Pop Culture',
      'Shorts',
      'Podcast',
    ],
    'Sports': [
      'Football',
      'Basketball',
      'Cricket',
      'Highlights',
      'Training',
      'Match Analysis',
    ],
    'Lifestyle': [
      'Vlogging',
      'Daily Routine',
      'Minimalism',
      'Self Care',
      'Home Decor',
    ],
    'Travel': [
      'Backpacking',
      'Guides',
      'Travel Vlogs',
      'Culture',
      'Exploration',
      'Hotels',
    ],
    'Food': [
      'Cooking',
      'Recipes',
      'Street Food',
      'Restaurant Reviews',
      'Baking',
      'Chef',
    ],
    'Comedy': ['Standup', 'Skits', 'Parody', 'Memes', 'Satire', 'Humor'],
    'Art': [
      'Drawing',
      'Digital Art',
      'Painting',
      'Design',
      'Illustration',
      'Crafting',
    ],
    'Animation': [
      '3D Animation',
      'Motion Graphics',
      'Cartoons',
      'Anime',
      'VFX',
    ],
    'Automotive': [
      'Cars',
      'Motorcycles',
      'EV',
      'Reviews',
      'Racing',
      'Supercars',
    ],
    'Pets & Animals': ['Dogs', 'Cats', 'Wildlife', 'Rescue', 'Pet Care'],
    'DIY & How-to': [
      'Life Hacks',
      'Home Improvement',
      'Woodworking',
      'Fix It',
      'Crafting',
    ],
    'Nature': [
      'Environment',
      'Wildlife',
      'Wilderness',
      'Conservation',
      'Hiking',
    ],
    'Spirituality': [
      'Meditation',
      'Mindfulness',
      'Philosophy',
      'Wisdom',
      'Faith',
    ],
    'Kids & Family': [
      'Parenting',
      'Toys',
      'Kids Songs',
      'Family Vlogs',
      'Storytime',
      'Education for Kids',
    ],
    'Movies': [
      'Film Reviews',
      'Trailers',
      'Film Analysis',
      'Behind the Scenes',
      'Ratings',
      'Cinema',
    ],
    'TV Shows': [
      'Recaps',
      'Reviews',
      'Binge Guides',
      'Series Analysis',
      'Casting News',
      'Season Reviews',
    ],
    'Vlogs': [
      'Daily Vlogs',
      'Travel Vlogs',
      'Food Vlogs',
      'Personal Stories',
      'Life Updates',
      'Day in My Life',
      'Behind the Scenes',
      'Q&A',
    ],
    'Short Films': [
      'Indie Cinema',
      'Short Film',
      'Festival Winners',
      'Drama',
      'Cinematic',
      'Narrative',
      'Directing',
    ],
    'Other': ['General', 'Miscellaneous', 'Mixed Content', 'Community'],
  };

  Widget _buildSuggestedTagsSection() {
    return Obx(() {
      final selectedCats = controller.selectedCategories;
      // Do not show recommended tags if user has not selected any channel category
      if (selectedCats.isEmpty) {
        return const SizedBox.shrink();
      }

      // Gather recommended tags based on selected categories
      final recommendedSet = <String>{};
      for (final cat in selectedCats) {
        final tags = _categoryRecommendedTags[cat];
        if (tags != null) {
          recommendedSet.addAll(tags);
        }
      }

      // Fallback if selected categories do not have explicit tags
      if (recommendedSet.isEmpty) {
        recommendedSet.addAll([
          'Podcast',
          'Vlog',
          'Tutorials',
          'Shorts',
          'Guides',
        ]);
      }

      final current = tagList.toList();
      final available = recommendedSet
          .where((s) => !current.contains(s))
          .toList();
      if (available.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Recommended Tags for ${selectedCats.join(", ")} (tap to add):',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: available.map((sTag) {
              final usage = _wc.getTagUsageCountFormatted(sTag);
              return GestureDetector(
                onTap: () => _wc.addTag(sTag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$sTag ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        usage,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  Widget _buildAvailabilityStatusSuffix(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.checking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF59E0B),
          ),
        );
      case AvailabilityStatus.available:
        return const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 16,
        );
      case AvailabilityStatus.taken:
        return const Icon(
          Icons.cancel_rounded,
          color: AppColors.error,
          size: 16,
        );
      case AvailabilityStatus.invalid:
        return const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFFF59E0B),
          size: 16,
        );
      case AvailabilityStatus.error:
        return const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 16,
        );
      case AvailabilityStatus.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAvailabilityStatusMessage({
    required AvailabilityStatus status,
    required String message,
    required String fieldLabel,
  }) {
    if (status == AvailabilityStatus.unknown || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final Color statusColor;
    final IconData statusIcon;

    switch (status) {
      case AvailabilityStatus.checking:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top_rounded;
      case AvailabilityStatus.available:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline_rounded;
      case AvailabilityStatus.taken:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
      case AvailabilityStatus.invalid:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.info_outline_rounded;
      case AvailabilityStatus.error:
        statusColor = AppColors.error;
        statusIcon = Icons.error_outline_rounded;
      case AvailabilityStatus.unknown:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandleSuggestionsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested handles:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: controller.handleSuggestions.map((suggestion) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.applyHandleSuggestion(suggestion),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '@',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          suggestion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
