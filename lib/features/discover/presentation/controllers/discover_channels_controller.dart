import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';

class DiscoverChannelsController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxString selectedCategory = 'All'.obs;
  final RxString selectedLanguage = 'All Languages'.obs;
  final RxString selectedTopic = 'All Topics'.obs;
  final RxString selectedFilter = 'Top Channels'.obs;
  final RxList<Channel> channels = <Channel>[].obs;
  final RxBool rxIsLoading = false.obs;

  // Subscription state tracking
  final RxSet<String> subscribedChannelIds = <String>{}.obs;
  final RxMap<String, int> channelSubscriberCounts = <String, int>{}.obs;

  final RxString searchQuery = ''.obs;
  TextEditingController _searchController = TextEditingController();
  bool _isDisposed = false;

  TextEditingController get searchController {
    if (_isDisposed) {
      _searchController = TextEditingController(text: searchQuery.value);
      _isDisposed = false;
    }
    return _searchController;
  }

  Timer? _debounce;

  final List<String> filters = [
    'Top Channels',
    'Emerging',
    'Verified Only',
    'Most Active',
  ];

  final List<String> languages = [
    'All Languages',
    'Telugu',
    'English',
    'Hindi',
    'Tamil',
    'Kannada',
    'Malayalam',
    'Spanish',
    'French',
    'German',
  ];

  final List<Map<String, String>> nicheTopics = [
    {'name': 'All Topics', 'tag': ''},
    {'name': 'Science & Space', 'tag': 'science'},
    {'name': 'Atheism & Rationalism', 'tag': 'atheist'},
    {'name': 'Philosophy & Mind', 'tag': 'philosophy'},
    {'name': 'AI & Robotics', 'tag': 'ai'},
    {'name': 'Deep Research & Facts', 'tag': 'research'},
    {'name': 'Geopolitics & World', 'tag': 'geopolitics'},
    {'name': 'Economics & Markets', 'tag': 'economics'},
    {'name': 'History & Ancient', 'tag': 'history'},
    {'name': 'Health & Fitness', 'tag': 'health'},
  ];

  final List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': 'All'},
    {'name': 'Education', 'icon': 'school'},
    {'name': 'Entertainment', 'icon': 'theater_comedy'},
    {'name': 'Music', 'icon': 'music_note'},
    {'name': 'News', 'icon': 'newspaper'},
    {'name': 'Sports', 'icon': 'sports_soccer'},
    {'name': 'Technology', 'icon': 'computer'},
    {'name': 'Science', 'icon': 'science'},
    {'name': 'Travel', 'icon': 'travel_explore'},
    {'name': 'Lifestyle', 'icon': 'home'},
    {'name': 'Comedy', 'icon': 'sentiment_very_satisfied'},
    {'name': 'Documentary', 'icon': 'video_label'},
    {'name': 'Movies', 'icon': 'movie'},
    {'name': 'TV Shows', 'icon': 'tv'},
    {'name': 'Vlogs', 'icon': 'videocam'},
    {'name': 'DIY & How-to', 'icon': 'build'},
    {'name': 'Health & Fitness', 'icon': 'fitness_center'},
    {'name': 'Fashion', 'icon': 'brush'},
    {'name': 'Food & Cooking', 'icon': 'restaurant'},
    {'name': 'Business & Finance', 'icon': 'business'},
  ];

  @override
  void onInit() {
    super.onInit();
    fetchUserSubscriptions();
    loadChannels();
  }

  /// Fetch user's current subscriptions from Firestore
  Future<void> fetchUserSubscriptions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: user.uid)
          .get();

      final ids = snapshot.docs
          .map((doc) => doc.data()['channelId'] as String?)
          .whereType<String>()
          .toSet();

      subscribedChannelIds.assignAll(ids);
    } catch (e) {
      Get.log('Error fetching subscriptions: $e');
    }
  }

  bool isSubscribed(String channelId) {
    return subscribedChannelIds.contains(channelId);
  }

  int getSubscriberCount(Channel channel) {
    return channelSubscriberCounts[channel.channelId] ?? channel.subscriberCount;
  }

  /// Toggle subscription with optimistic UI update and Firestore sync
  Future<void> toggleSubscription(Channel channel) async {
    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar(
        'Authentication Required',
        'Please log in to subscribe to channels.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.withValues(alpha: 0.2),
        colorText: Colors.white,
      );
      return;
    }

    final channelId = channel.channelId;
    final currentlySubscribed = isSubscribed(channelId);
    final currentCount = getSubscriberCount(channel);

    // Optimistic UI updates
    if (currentlySubscribed) {
      subscribedChannelIds.remove(channelId);
      channelSubscriberCounts[channelId] = (currentCount - 1).clamp(0, 999999999);
    } else {
      subscribedChannelIds.add(channelId);
      channelSubscriberCounts[channelId] = currentCount + 1;
    }

    // Try delegating to ChannelSubscriptionController if available
    if (Get.isRegistered<ChannelSubscriptionController>()) {
      final subController = Get.find<ChannelSubscriptionController>();
      if (currentlySubscribed) {
        await subController.unsubscribeFromChannel(channelId);
      } else {
        await subController.subscribeToChannel(channelId);
      }
      return;
    }

    // Direct Firestore transaction fallback
    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection('subscriptions').doc(subDocId);
    final channelRef = _firestore.collection(FirestoreCollections.channels).doc(channelId);

    try {
      if (currentlySubscribed) {
        await _firestore.runTransaction((tx) async {
          final doc = await tx.get(subRef);
          if (doc.exists) {
            tx.delete(subRef);
            tx.update(channelRef, {'subscriberCount': FieldValue.increment(-1)});
          }
        });
        Get.snackbar(
          'Unsubscribed',
          'You unsubscribed from ${channel.name}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
        );
      } else {
        await _firestore.runTransaction((tx) async {
          tx.set(subRef, {
            'userId': user.uid,
            'channelId': channelId,
            'subscribedAt': FieldValue.serverTimestamp(),
            'notificationsEnabled': true,
          });
          tx.update(channelRef, {
            'subscriberCount': FieldValue.increment(1),
          });
        });
        Get.snackbar(
          'Subscribed',
          'Subscribed to ${channel.name}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withValues(alpha: 0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      // Revert optimistic state on error
      if (currentlySubscribed) {
        subscribedChannelIds.add(channelId);
        channelSubscriberCounts[channelId] = currentCount;
      } else {
        subscribedChannelIds.remove(channelId);
        channelSubscriberCounts[channelId] = currentCount;
      }
      Get.snackbar(
        'Error',
        'Could not update subscription: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
    loadChannels();
  }

  void selectLanguage(String language) {
    selectedLanguage.value = language;
    loadChannels();
  }

  void selectTopic(String topicName) {
    selectedTopic.value = topicName;
    loadChannels();
  }

  void selectFilter(String filter) {
    selectedFilter.value = filter;
    loadChannels();
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), loadChannels);
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    loadChannels();
  }

  Future<void> loadChannels() async {
    rxIsLoading.value = true;
    try {
      final query = _firestore
          .collection(FirestoreCollections.channels)
          .where('status', isEqualTo: 'active');

      final snapshot = await query.limit(150).get();
      var loadedChannels = snapshot.docs
          .map(Channel.fromDocumentSnapshot)
          .toList();

      // 1. Smart Intent & Conversational Query Detection (e.g., "a channels which do business case studys")
      final rawQuery = searchQuery.value.toLowerCase().trim();
      String? detectedLangInQuery;
      String? detectedCatInQuery;
      List<String>? detectedTopicTerms;
      final textSearchTerms = <String>[];

      final langMap = {
        'telugu': ['telugu', 'te'],
        'english': ['english', 'en'],
        'hindi': ['hindi', 'hi'],
        'tamil': ['tamil', 'ta'],
        'kannada': ['kannada', 'kn'],
        'malayalam': ['malayalam', 'ml'],
        'spanish': ['spanish', 'es'],
        'french': ['french', 'fr'],
        'german': ['german', 'de'],
      };

      final catMap = {
        'music': 'music',
        'news': 'news',
        'sports': 'sports',
        'comedy': 'comedy',
        'tech': 'technology',
        'technology': 'technology',
        'education': 'education',
        'movies': 'movies',
        'movie': 'movies',
        'tv': 'tv shows',
        'vlogs': 'vlogs',
        'vlog': 'vlogs',
        'entertainment': 'entertainment',
        'science': 'science',
        'travel': 'travel',
        'lifestyle': 'lifestyle',
        'diy': 'diy & how-to',
        'fitness': 'health & fitness',
        'health': 'health & fitness',
        'fashion': 'fashion',
        'food': 'food & cooking',
        'cooking': 'food & cooking',
        'business': 'business & finance',
        'finance': 'business & finance',
        'gaming': 'gaming',
      };

      final nicheTopicMap = {
        'case study': ['case study', 'case studies', 'business', 'analysis', 'breakdown', 'company', 'strategy', 'finance'],
        'case studies': ['case study', 'case studies', 'business', 'analysis', 'breakdown', 'company', 'strategy', 'finance'],
        'atheist': ['atheist', 'atheism', 'rationalism', 'secular', 'freethought', 'agnostic', 'philosophy'],
        'atheism': ['atheist', 'atheism', 'rationalism', 'secular', 'freethought', 'agnostic', 'philosophy'],
        'rationalism': ['atheist', 'atheism', 'rationalism', 'secular', 'freethought', 'agnostic'],
        'secular': ['atheist', 'atheism', 'rationalism', 'secular', 'freethought', 'agnostic'],
        'science': ['science', 'physics', 'astronomy', 'biology', 'space', 'cosmos', 'experiment', 'stem'],
        'space': ['science', 'physics', 'astronomy', 'biology', 'space', 'cosmos'],
        'physics': ['science', 'physics', 'astronomy', 'space'],
        'philosophy': ['philosophy', 'philosophical', 'ethics', 'logic', 'mind', 'atheist'],
        'ai': ['ai', 'artificial intelligence', 'machine learning', 'tech', 'robotics'],
        'robotics': ['ai', 'artificial intelligence', 'machine learning', 'tech', 'robotics'],
        'research': ['research', 'fact-check', 'investigation', 'truth', 'journalism', 'case study'],
        'investigation': ['research', 'fact-check', 'investigation', 'truth', 'journalism', 'case study'],
        'geopolitics': ['geopolitics', 'politics', 'diplomacy', 'international', 'world'],
        'economics': ['economics', 'finance', 'crypto', 'markets', 'stocks', 'business', 'case study'],
        'history': ['history', 'ancient', 'historical', 'archeology'],
        'health': ['health', 'fitness', 'nutrition', 'medicine', 'biohacking', 'longevity'],
      };

      if (rawQuery.isNotEmpty) {
        const fillerWords = {
          'a',
          'an',
          'the',
          'channel',
          'channels',
          'video',
          'videos',
          'content',
          'show',
          'shows',
          'which',
          'that',
          'do',
          'does',
          'doing',
          'make',
          'makes',
          'making',
          'who',
          'about',
          'in',
          'for',
          'on',
          'with',
          'is',
          'are',
          'top',
          'best',
          'find',
          'get',
          'look',
          'looking',
          'like',
          'etc'
        };

        // Check for compound phrase "case study" or "case studies" or "case studys"
        if (rawQuery.contains('case study') || rawQuery.contains('case studies') || rawQuery.contains('case studys')) {
          detectedTopicTerms = nicheTopicMap['case study'];
          detectedCatInQuery = 'business & finance';
        }

        final words = rawQuery
            .split(RegExp(r'\s+'))
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList();

        for (final word in words) {
          if (fillerWords.contains(word)) continue;

          // Normalize basic plural typos like 'studys' -> 'study'
          var normWord = word;
          if (normWord.endsWith('studys')) {
            normWord = 'study';
          } else if (normWord.endsWith('studies')) {
            normWord = 'study';
          } else if (normWord.endsWith('es') && normWord.length > 4) {
            normWord = normWord.substring(0, normWord.length - 2);
          } else if (normWord.endsWith('s') && !normWord.endsWith('ss') && normWord.length > 3) {
            normWord = normWord.substring(0, normWord.length - 1);
          }

          if (langMap.containsKey(normWord) && detectedLangInQuery == null) {
            detectedLangInQuery = normWord;
          } else if (nicheTopicMap.containsKey(normWord) && detectedTopicTerms == null) {
            detectedTopicTerms = nicheTopicMap[normWord];
          } else if (catMap.containsKey(normWord) && detectedCatInQuery == null) {
            detectedCatInQuery = catMap[normWord];
          } else {
            textSearchTerms.add(normWord);
          }
        }
      }

      // 2. Niche Topic Filter (UI Chip Selection or Query Detection)
      var effectiveTopicTerms = detectedTopicTerms;
      if (selectedTopic.value != 'All Topics') {
        final topicItem = nicheTopics.firstWhere(
          (t) => t['name'] == selectedTopic.value,
          orElse: () => {'name': '', 'tag': ''},
        );
        final tag = topicItem['tag'] ?? '';
        if (tag.isNotEmpty && nicheTopicMap.containsKey(tag)) {
          effectiveTopicTerms = nicheTopicMap[tag];
        }
      }

      if (effectiveTopicTerms != null && effectiveTopicTerms.isNotEmpty) {
        loadedChannels = loadedChannels.where((c) {
          final cName = c.name.toLowerCase();
          final cDesc = c.description.toLowerCase();
          final cHandle = c.handle.toLowerCase();
          final cCat = c.category.toLowerCase();
          final cCats = c.categories.map((e) => e.toLowerCase()).toList();

          return effectiveTopicTerms!.any((term) =>
              cName.contains(term) ||
              cDesc.contains(term) ||
              cHandle.contains(term) ||
              cCat.contains(term) ||
              cCats.any((cat) => cat.contains(term)));
        }).toList();
      }

      // 3. Language Filter (UI Chip Selection or Query Detection)
      final effectiveLang = selectedLanguage.value != 'All Languages'
          ? selectedLanguage.value.toLowerCase().trim()
          : (detectedLangInQuery ?? '');

      if (effectiveLang.isNotEmpty) {
        loadedChannels = loadedChannels.where((c) {
          final cLang = c.language.toLowerCase().trim();
          final cName = c.name.toLowerCase();
          final cDesc = c.description.toLowerCase();

          var matchesLangCode = false;
          if (effectiveLang == 'telugu' || effectiveLang == 'te') {
            matchesLangCode = cLang == 'te' || cLang == 'telugu';
          } else if (effectiveLang == 'english' || effectiveLang == 'en') {
            matchesLangCode = cLang == 'en' || cLang == 'english';
          } else if (effectiveLang == 'hindi' || effectiveLang == 'hi') {
            matchesLangCode = cLang == 'hi' || cLang == 'hindi';
          } else if (effectiveLang == 'tamil' || effectiveLang == 'ta') {
            matchesLangCode = cLang == 'ta' || cLang == 'tamil';
          } else if (effectiveLang == 'kannada' || effectiveLang == 'kn') {
            matchesLangCode = cLang == 'kn' || cLang == 'kannada';
          } else if (effectiveLang == 'malayalam' || effectiveLang == 'ml') {
            matchesLangCode = cLang == 'ml' || cLang == 'malayalam';
          } else {
            matchesLangCode = cLang.contains(effectiveLang);
          }

          return matchesLangCode ||
              cName.contains(effectiveLang) ||
              cDesc.contains(effectiveLang);
        }).toList();
      }

      // 4. Category Filter (UI Card/Chip Selection or Query Detection)
      final effectiveCat = selectedCategory.value != 'All'
          ? selectedCategory.value.toLowerCase().trim()
          : (detectedCatInQuery ?? '');

      if (effectiveCat.isNotEmpty) {
        loadedChannels = loadedChannels.where((c) {
          final mainCategory = c.category.toLowerCase().trim();
          final categoryList = c.categories.map((e) => e.toLowerCase().trim()).toList();
          return mainCategory == effectiveCat ||
              mainCategory.contains(effectiveCat) ||
              categoryList.contains(effectiveCat) ||
              c.name.toLowerCase().contains(effectiveCat) ||
              c.description.toLowerCase().contains(effectiveCat);
        }).toList();
      }

      // 5. Keyword Text Search (if remaining words exist)
      if (textSearchTerms.isNotEmpty) {
        loadedChannels = loadedChannels.where((c) {
          final name = c.name.toLowerCase();
          final handle = c.handle.toLowerCase();
          final desc = c.description.toLowerCase();
          return textSearchTerms.every((term) =>
              name.contains(term) || handle.contains(term) || desc.contains(term));
        }).toList();
      }

      // 6. Apply Sub-Filters (Top Channels, Emerging, Verified Only, Most Active)
      switch (selectedFilter.value) {
        case 'Top Channels':
          loadedChannels.sort((a, b) => getSubscriberCount(b).compareTo(getSubscriberCount(a)));
        case 'Emerging':
          loadedChannels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        case 'Verified Only':
          loadedChannels = loadedChannels.where((c) => c.isVerified).toList();
        case 'Most Active':
          loadedChannels.sort((a, b) => b.videoCount.compareTo(a.videoCount));
      }

      // Initialize subscriber count map
      for (final ch in loadedChannels) {
        if (!channelSubscriberCounts.containsKey(ch.channelId)) {
          channelSubscriberCounts[ch.channelId] = ch.subscriberCount;
        }
      }

      channels.value = loadedChannels;
    } catch (e) {
      Get.log('Error loading channels: $e');
    } finally {
      rxIsLoading.value = false;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _searchController.dispose();
    _isDisposed = true;
    super.onClose();
  }
}
