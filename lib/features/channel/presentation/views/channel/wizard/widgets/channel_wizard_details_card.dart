import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardDetailsCard extends StatefulWidget {
  final ChannelController controller;
  final RxList<String> tagList;
  final bool isDarkMode;

  const ChannelWizardDetailsCard({
    required this.controller,
    required this.tagList,
    required this.isDarkMode,
    super.key,
  });

  @override
  State<ChannelWizardDetailsCard> createState() =>
      _ChannelWizardDetailsCardState();
}

class _ChannelWizardDetailsCardState extends State<ChannelWizardDetailsCard> {
  ChannelController get controller => widget.controller;
  RxList<String> get _tagList => widget.tagList;
  bool get isDarkMode => widget.isDarkMode;

  final TextEditingController _tagInputController = TextEditingController();
  final RxString _tagSearchQuery = ''.obs;
  String get _tagQueryText => _tagSearchQuery.value;

  final RxList<Map<String, dynamic>> _liveFirestoreSuggestions =
      <Map<String, dynamic>>[].obs;
  final RxBool _isSearchingTags = false.obs;

  @override
  void dispose() {
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag(String rawTag) {
    final clean = rawTag.trim().replaceAll(',', '');
    if (clean.isEmpty) return;
    if (_tagList.length >= 5) {
      AppSnackbar.warning(
        'You can add up to 5 tags.',
      );
      return;
    }
    if (!_tagList.contains(clean)) {
      _tagList.add(clean);
      controller.tags.text = _tagList.join(', ');
    }
    _tagInputController.clear();
    _tagSearchQuery.value = '';
  }

  void _removeTag(String tag) {
    _tagList.remove(tag);
    controller.tags.text = _tagList.join(', ');
  }

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
          const SizedBox(height: 16),
          // Channel Handle
          const ChannelWizardFieldLabel('Channel Handle', isRequired: true),
          const SizedBox(height: 8),
          ChannelWizardInputField(
            controller: controller.customUrl,
            hintText: 'Enter handle',
            prefixText: '@',
            maxLength: 50,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_-]')),
            ],
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

  RxMap<String, int>? _realTagUsageMapObj;
  RxMap<String, int> get _realTagUsageMap =>
      _realTagUsageMapObj ??= <String, int>{}.obs;

  Future<void> _fetchRealMatchingTagsFromFirestore(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      _liveFirestoreSuggestions.clear();
      _isSearchingTags.value = false;
      return;
    }

    _isSearchingTags.value = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.hashtags)
          .where('tagLowercase', isGreaterThanOrEqualTo: cleanQuery)
          .where('tagLowercase', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(8)
          .get();

      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        final name = data['name'] as String? ?? doc.id;
        final count = (data['usageCount'] as num?)?.toInt() ?? 1;
        _realTagUsageMap[name] = count;
        return {
          'name': name,
          'usageCount': count,
        };
      }).toList();

      _liveFirestoreSuggestions.assignAll(results);
    } on FirebaseException catch (e, stackTrace) {
      _liveFirestoreSuggestions.clear();
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWizardDetailsCard.tagSearch.firebase',
      );
    } catch (e, stackTrace) {
      _liveFirestoreSuggestions.clear();
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWizardDetailsCard.tagSearch',
      );
    } finally {
      _isSearchingTags.value = false;
    }
  }

  String _getTagUsageCountFormatted(String tag) {
    final count = _realTagUsageMap[tag] ?? 1;
    if (count >= 1000000) {
      final val = (count / 1000000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}M';
    }
    if (count >= 1000) {
      final val = (count / 1000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}k';
    }
    return '$count';
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
        controller: _tagInputController,
        inputFormatters: [TruthworldTextInputFormatters.englishOnly],
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (val) {
          _tagSearchQuery.value = val.trim();
          _fetchRealMatchingTagsFromFirestore(val);
          if (val.contains(',')) {
            _addTag(val);
          }
        },
        onSubmitted: _addTag,
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
      final query = _tagQueryText.toLowerCase().trim();
      if (query.isEmpty) return const SizedBox.shrink();

      final currentTags = _tagList.toList();

      // ONLY use real Firestore suggestions from the database
      final realMatches = <Map<String, dynamic>>[];
      for (final item in _liveFirestoreSuggestions) {
        final name = item['name'] as String;
        if (!currentTags.contains(name)) {
          realMatches.add(item);
        }
      }

      if (_isSearchingTags.value && realMatches.isEmpty) {
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
              _addTag(_tagInputController.text);
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
                    'Add "$_tagQueryText"',
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
              final usage = _getTagUsageCountFormatted(tag);
              return InkWell(
                onTap: () => _addTag(tag),
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
      final tags = _tagList.toList();
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
                    onTap: () => _removeTag(tag),
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
              if (_tagInputController.text.trim().isNotEmpty) {
                _addTag(_tagInputController.text);
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
    'Fashion': ['Style', 'Outfits', 'Beauty', 'Makeup', 'Trends', 'Hauls'],
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
    'People & Blogs': [
      'Vlogs',
      'Daily Life',
      'Personal Stories',
      'Q&A',
      'Life Updates',
      'Behind the Scenes',
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
      'Challenge Vlogs',
      'Life Updates',
      'Day in My Life',
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

      final current = _tagList.toList();
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
              final usage = _getTagUsageCountFormatted(sTag);
              return GestureDetector(
                onTap: () => _addTag(sTag),
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

  // ========================================================================
  // CARD 3: CHANNEL TYPE
  // ========================================================================
}
