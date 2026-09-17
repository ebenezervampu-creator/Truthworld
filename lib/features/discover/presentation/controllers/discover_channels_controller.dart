import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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
  final RxString rxErrorMessage = ''.obs;

  // AI-Assisted Interactive Search state
  final Rx<AiSearchIntent?> activeAiIntent = Rx<AiSearchIntent?>(null);
  final RxBool isAiSearching = false.obs;
  final RxList<Channel> broadenedChannels = <Channel>[].obs;
  final RxBool isBroadenedView = false.obs;


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
    {'name': 'People & Blogs', 'icon': 'videocam'},
    {'name': 'Movies', 'icon': 'movie'},
    {'name': 'TV Shows', 'icon': 'tv'},
    {'name': 'Vlogs', 'icon': 'video_camera_front'},
    {'name': 'Kids & Family', 'icon': 'child_care'},
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
      AppSnackbar.warning(
        'Please log in to subscribe to channels.',
        title: 'Authentication Required',
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
        AppSnackbar.info(
          'You unsubscribed from ${channel.name}',
          title: 'Unsubscribed',
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
        AppSnackbar.success(
          'Subscribed to ${channel.name}',
          title: 'Subscribed',
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
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to update subscription. Please try again.',
      );
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
    if (category != 'All') {
      selectedTopic.value = 'All Topics';
      selectedLanguage.value = 'All Languages';
    }
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
    _debounce = Timer(const Duration(milliseconds: 350), loadChannels);
  }


  void broadenSearch() {
    if (broadenedChannels.isNotEmpty) {
      isBroadenedView.value = true;
      channels.assignAll(broadenedChannels);
    }
  }

  void clearAiSearch() {
    isBroadenedView.value = false;
    activeAiIntent.value = null;
    broadenedChannels.clear();
    clearSearch();
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    activeAiIntent.value = null;
    isBroadenedView.value = false;
    broadenedChannels.clear();
    loadChannels();
  }

  Future<void> loadChannels() async {
    rxIsLoading.value = true;
    try {
      final query = _firestore
          .collection(FirestoreCollections.channels)
          .where('status', isEqualTo: 'active');

      final snapshot = await query.limit(200).get();
      var loadedChannels = snapshot.docs
          .map(Channel.fromDocumentSnapshot)
          .toList();

      final rawQuery = searchQuery.value.trim();

      if (rawQuery.isNotEmpty) {
        isAiSearching.value = true;
        final intent = await AiSearchService.instance.parseQuery(
          rawQuery,
          scope: SearchScope.channels,
        );
        activeAiIntent.value = intent;

        if (intent.hasCriteria) {
          // Score and rank each channel
          final scored = <MapEntry<Channel, double>>[];
          for (final ch in loadedChannels) {
            final score = AiSearchService.instance.scoreChannel(ch, intent);
            if (score > 0) {
              scored.add(MapEntry(ch, score));
            }
          }

          // Sort by relevance score
          scored.sort((a, b) => b.value.compareTo(a.value));
          final matched = scored.map((e) => e.key).toList();

          // If language was specified and count is low (e.g. <= 2), prepare broadened fallback
          if (intent.detectedLanguage != null && intent.broadenPrompt != null) {
            final broadIntent = intent.copyWith(clearLanguage: true);
            final broadScored = <MapEntry<Channel, double>>[];
            for (final ch in loadedChannels) {
              final score =
                  AiSearchService.instance.scoreChannel(ch, broadIntent);
              if (score > 0) {
                broadScored.add(MapEntry(ch, score));
              }
            }
            broadScored.sort((a, b) => b.value.compareTo(a.value));
            broadenedChannels.assignAll(broadScored.map((e) => e.key).toList());
          } else {
            broadenedChannels.clear();
          }

          // Mode-specific sorting
          if (intent.resultMode == SearchResultMode.ranked) {
            // Decoupled multi-signal ranking:
            // 70% Semantic relevance
            // 15% Verified / Quality signals
            // 10% Engagement / Activity (catalog size)
            //  5% Audience size (popularity)
            final maxSubs = loadedChannels.fold<int>(
              1,
              (max, c) =>
                  getSubscriberCount(c) > max ? getSubscriberCount(c) : max,
            );
            final maxVideos = loadedChannels.fold<int>(
              1,
              (max, c) => c.videoCount > max ? c.videoCount : max,
            );
            final scoreMap = {for (final e in scored) e.key.id: e.value};
            matched.sort((a, b) {
              final relA = scoreMap[a.id] ?? 0.0;
              final relB = scoreMap[b.id] ?? 0.0;
              final qualityA = a.isVerified ? 1.0 : 0.0;
              final qualityB = b.isVerified ? 1.0 : 0.0;
              final activityA = (a.videoCount / maxVideos).clamp(0.0, 1.0);
              final activityB = (b.videoCount / maxVideos).clamp(0.0, 1.0);
              final audienceA =
                  (getSubscriberCount(a) / maxSubs).clamp(0.0, 1.0);
              final audienceB =
                  (getSubscriberCount(b) / maxSubs).clamp(0.0, 1.0);

              final rankA = (relA * 0.70) +
                  (qualityA * 15.0) +
                  (activityA * 10.0) +
                  (audienceA * 5.0);
              final rankB = (relB * 0.70) +
                  (qualityB * 15.0) +
                  (activityB * 10.0) +
                  (audienceB * 5.0);
              return rankB.compareTo(rankA);
            });
          } else if (intent.resultMode == SearchResultMode.trending) {
            matched.sort((a, b) => b.videoCount.compareTo(a.videoCount));
          } else if (intent.resultMode == SearchResultMode.recent) {
            matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          // Note: In exhaustive mode, all matched candidates are preserved
          // in full without audience size bias, ordered purely by match relevance.

          loadedChannels = matched;
        } else {
          // Plain keyword fallback
          final clean = rawQuery.toLowerCase();
          loadedChannels = loadedChannels.where((c) {
            return c.name.toLowerCase().contains(clean) ||
                c.handle.toLowerCase().contains(clean) ||
                c.description.toLowerCase().contains(clean);
          }).toList();
        }
      } else {
        activeAiIntent.value = null;
        isBroadenedView.value = false;
        broadenedChannels.clear();

        // 1. Topic Filter (if non-empty search)
        if (selectedTopic.value != 'All Topics') {
          final topicItem = nicheTopics.firstWhere(
            (t) => t['name'] == selectedTopic.value,
            orElse: () => {'name': '', 'tag': ''},
          );
          final tag = (topicItem['tag'] ?? '').toLowerCase();
          if (tag.isNotEmpty) {
            loadedChannels = loadedChannels.where((c) {
              return c.category.toLowerCase().contains(tag) ||
                  c.categories.any((cat) => cat.toLowerCase().contains(tag)) ||
                  c.name.toLowerCase().contains(tag) ||
                  c.description.toLowerCase().contains(tag);
            }).toList();
          }
        }

        // 2. Language Filter
        if (selectedLanguage.value != 'All Languages') {
          final lang = selectedLanguage.value.toLowerCase().trim();
          loadedChannels = loadedChannels.where((c) {
            final cLang = c.language.toLowerCase().trim();
            if (lang == 'telugu') return cLang == 'te' || cLang == 'telugu';
            if (lang == 'english') return cLang == 'en' || cLang == 'english';
            if (lang == 'hindi') return cLang == 'hi' || cLang == 'hindi';
            if (lang == 'tamil') return cLang == 'ta' || cLang == 'tamil';
            if (lang == 'kannada') return cLang == 'kn' || cLang == 'kannada';
            if (lang == 'malayalam') return cLang == 'ml' || cLang == 'malayalam';
            return cLang.contains(lang);
          }).toList();
        }

        // 3. Category Filter
        if (selectedCategory.value != 'All') {
          final cat = selectedCategory.value.toLowerCase().trim();
          final catTokens = cat
              .split(RegExp(r'[\s&/,\-]+'))
              .where((t) => t.length > 2)
              .toList();

          loadedChannels = loadedChannels.where((c) {
            final mainCat = c.category.toLowerCase().trim();
            final cats =
                c.categories.map((e) => e.toLowerCase().trim()).toList();
            final name = c.name.toLowerCase();
            final desc = c.description.toLowerCase();

            // 1. Exact match on main category or categories list
            if (mainCat == cat || cats.contains(cat)) return true;

            // 2. Substring match on main category or any category in list
            if (mainCat.isNotEmpty && mainCat != 'other') {
              if (mainCat.contains(cat) || cat.contains(mainCat)) return true;
            }
            if (cats.any((e) => e.contains(cat) || (e.isNotEmpty && cat.contains(e)))) {
              return true;
            }

            // 3. Name or description match with whole category
            if (name.contains(cat) || desc.contains(cat)) return true;

            // 4. Token match for compound categories (e.g. "Health & Fitness", "DIY & How-to")
            if (catTokens.isNotEmpty) {
              final matchesToken = catTokens.any((token) =>
                  (mainCat.isNotEmpty && mainCat != 'other' && mainCat.contains(token)) ||
                  cats.any((e) => e.contains(token)) ||
                  name.contains(token) ||
                  desc.contains(token));
              if (matchesToken) return true;
            }

            return false;
          }).toList();
        }

        // 4. Sort Filter
        switch (selectedFilter.value) {
          case 'Top Channels':
            loadedChannels.sort(
              (a, b) =>
                  getSubscriberCount(b).compareTo(getSubscriberCount(a)),
            );
          case 'Emerging':
            loadedChannels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case 'Verified Only':
            loadedChannels = loadedChannels.where((c) => c.isVerified).toList();
          case 'Most Active':
            loadedChannels.sort((a, b) => b.videoCount.compareTo(a.videoCount));
        }
      }

      // Initialize subscriber count map
      for (final ch in loadedChannels) {
        if (!channelSubscriberCounts.containsKey(ch.channelId)) {
          channelSubscriberCounts[ch.channelId] = ch.subscriberCount;
        }
      }

      channels.value = loadedChannels;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DiscoverChannelsController.loadChannels',
      );
      rxErrorMessage.value = 'Unable to load channels. Please check your connection and try again.';
    } finally {
      rxIsLoading.value = false;
      isAiSearching.value = false;
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
