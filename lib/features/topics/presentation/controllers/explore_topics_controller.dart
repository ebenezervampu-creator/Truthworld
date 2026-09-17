

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// GetX Controller for the Topic Discovery Platform UI
class ExploreTopicsController extends BaseController {
  ExploreTopicsController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();
  final TopicRepository _repository;

  // ==========================================================================
  // OBSERVABLE STATE VARIABLES
  // ==========================================================================
  final RxList<Topic> topics = <Topic>[].obs;
  final RxList<Topic> featuredTopics = <Topic>[].obs;
  final RxList<TopicCategory> availableCategories = <TopicCategory>[].obs;
  final RxBool isLoadingCategories = false.obs;
  final RxString selectedCategory = 'all'.obs;
  final Rx<ExploreMode> exploreMode = ExploreMode.discover.obs;
  final RxString searchQuery = ''.obs;

  // AI-Assisted Interactive Search state
  final Rx<AiSearchIntent?> activeAiIntent = Rx<AiSearchIntent?>(null);
  final RxBool isAiSearching = false.obs;


  // Topic videos map: topic.id/slug -> List<Video>
  final RxMap<String, List<Video>> topicVideosMap = <String, List<Video>>{}.obs;
  final RxMap<String, bool> isLoadingVideosMap = <String, bool>{}.obs;

  final RxBool rxIsLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool rxHasMore = true.obs;
  final RxString rxErrorMessage = ''.obs;

  // Pagination cursor
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 20;

  // UI & Navigation Controllers
  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();
  late final PageController pageController;
  final RxInt currentTopicIndex = 0.obs;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================
  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    pageController.addListener(_onPageScroll);

    searchController.addListener(() {
      if (searchController.text != searchQuery.value) {
        updateSearchQuery(searchController.text);
      }
    });

    addWorker(
      ever(topics, (_) {
        if (pageController.hasClients) {
          pageController.jumpToPage(0);
          currentTopicIndex.value = 0;
        }
      }),
    );

    initialFetch();
    // GetX debounce worker replaces manual Timer — auto-disposed in BaseController.onClose()
    addWorker(
      debounce(
        searchQuery,
        (_) => loadTopics(reset: true),
        time: const Duration(milliseconds: 400),
      ),
    );
  }

  void _onPageScroll() {
    if (pageController.hasClients) {
      final page = pageController.page ?? 0.0;
      final index = page.round();
      if (currentTopicIndex.value != index) {
        currentTopicIndex.value = index;
      }
      if (page >= topics.length - 2) {
        loadMoreTopics();
      }
    }
  }

  @override
  void onClose() {
    pageController.removeListener(_onPageScroll);
    pageController.dispose();
    scrollController.dispose();
    searchController.dispose();
    super.onClose();
  }

  // ==========================================================================
  // MAIN QUERY STRATEGY
  // ==========================================================================

  /// Initialize and fetch initial feeds (both curated featured & paginated browse)
  Future<void> initialFetch() async {
    rxIsLoading.value = true;
    rxErrorMessage.value = '';

    try {
      // 1. Fetch available categories with at least 2 videos
      fetchAvailableCategories();

      // 2. Fetch Featured Curated Strips
      final rawFeatured = await _repository.fetchFeaturedTopics();
      featuredTopics.value = rawFeatured
          .where((t) => t.isValidTopic && t.videoCount > 0)
          .toList();

      // 3. Fetch paginated topics
      await loadTopics(reset: true);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ExploreTopicsController.onInit',
      );
      rxErrorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'load topic feed',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  /// Paginated fetch of topics depending on active category, mode, and search state
  Future<void> loadTopics({bool reset = false}) async {
    if (isLoadingMore.value) return;
    if (rxIsLoading.value && !reset) return;

    if (reset) {
      topics.clear();
      _lastDoc = null;
      rxHasMore.value = true;
    }

    if (!rxHasMore.value && !reset) return;

    if (reset) {
      rxIsLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      var newTopics = <Topic>[];

      // If search query is present, perform AI semantic lookup and scoring
      if (searchQuery.isNotEmpty) {
        final raw = searchQuery.value.trim();
        isAiSearching.value = true;
        final intent = await AiSearchService.instance.parseQuery(
          raw,
          scope: SearchScope.topics,
        );
        activeAiIntent.value = intent;

        final candidateMap = <String, Topic>{};

        // 1. Prefix query for direct keywords
        if (intent.cleanKeywords.isNotEmpty) {
          for (final kw in intent.cleanKeywords.take(2)) {
            final prefixResults =
                await _repository.searchTopics(kw, limit: 30);
            for (final t in prefixResults) {
              candidateMap[t.id] = t;
            }
          }
        }

        // 2. Full scan of active topics to match semantic synonyms, subdomains, categories
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .where('status', isEqualTo: 'active')
              .limit(100)
              .get();
          for (final doc in snapshot.docs) {
            final t = Topic.fromDocumentSnapshot(doc);
            if (t.isValidTopic && t.videoCount > 0) {
              candidateMap[t.id] = t;
            }
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ExploreTopicsController.aiScanActiveTopics');
        }

        // 3. Score candidates with AiSearchService.scoreTopic
        final scored = <MapEntry<Topic, double>>[];
        for (final topic in candidateMap.values) {
          final score = AiSearchService.instance.scoreTopic(topic, intent);
          if (score > 0) {
            scored.add(MapEntry(topic, score));
          }
        }

        scored.sort((a, b) => b.value.compareTo(a.value));
        newTopics = scored.map((e) => e.key).toList();

        if (intent.resultMode == SearchResultMode.ranked && newTopics.isNotEmpty) {
          final maxTrending = newTopics.fold<double>(
            1.0,
            (max, t) => t.trendingScore > max ? t.trendingScore : max,
          );
          final scoreMap = {for (final e in scored) e.key.id: e.value};
          newTopics.sort((a, b) {
            final relA = scoreMap[a.id] ?? 0.0;
            final relB = scoreMap[b.id] ?? 0.0;
            final trendA = a.trendingScore / maxTrending;
            final trendB = b.trendingScore / maxTrending;
            final rankA = (relA * 0.70) + (trendA * 30.0);
            final rankB = (relB * 0.70) + (trendB * 30.0);
            return rankB.compareTo(rankA);
          });
        }

        rxHasMore.value = false;
      } else {
        activeAiIntent.value = null;
        // Standard paginated database retrieval
        if (exploreMode.value == ExploreMode.trending) {
          newTopics = await _repository.fetchTrendingTopics(
            lastDoc: _lastDoc,
            category: selectedCategory.value,
          );
        } else if (exploreMode.value == ExploreMode.yearly) {
          // Yearly trended topics query (pull by category or lower video count fallback)
          newTopics = await _repository.fetchTopics(
            lastDoc: _lastDoc,
            category: selectedCategory.value,
          );
          // Sort or compute yearly activity boost offline
          newTopics.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
        } else {
          // ExploreMode.discover (default)
          newTopics = await _repository.fetchTopics(
            lastDoc: _lastDoc,
            category: selectedCategory.value,
          );
        }

        if (newTopics.isNotEmpty) {
          // Cache document snapshot reference for next pagination block
          final rawSnapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.topics)
              .doc(newTopics.last.id)
              .get();
          if (rawSnapshot.exists) {
            _lastDoc = rawSnapshot;
          }

          if (newTopics.length < _pageSize) {
            rxHasMore.value = false;
          }
        } else {
          rxHasMore.value = false;
        }
      }

      // Filter out any duplicates to ensure robust, unique listing
      final existingIds = topics.map((t) => t.id).toSet();
      final uniqueNewTopics = newTopics
          .where((t) => !existingIds.contains(t.id) && t.isValidTopic && t.videoCount > 0)
          .toList();
      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final isFlipped =
            Get.isRegistered<FlipCoinService>() &&
            Get.find<FlipCoinService>().isTopicsFlipped.value;
        final rankedTopics = algorithm.rankTopics(uniqueNewTopics);
        final finalTopics = isFlipped
            ? rankedTopics.reversed.toList()
            : rankedTopics;
        topics.addAll(finalTopics.isNotEmpty ? finalTopics : uniqueNewTopics);
      } else {
        topics.addAll(uniqueNewTopics);
      }

      // Fetch videos for newly added topics
      uniqueNewTopics.forEach(fetchVideosForTopic);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ExploreTopicsController.loadTopics',
      );
      rxErrorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'load topics',
      );
      if (!reset) {
        AppSnackbar.error(
          FriendlyErrorTranslator.getFriendlyMessage(
            e,
            defaultActionMessage: 'load more topics',
          ),
        );
      }
    } finally {
      rxIsLoading.value = false;
      isLoadingMore.value = false;
      isAiSearching.value = false;
    }
  }

  /// Fetch videos associated with a specific topic
  Future<void> fetchVideosForTopic(Topic topic) async {
    final key = topic.id;
    if (topicVideosMap.containsKey(key) && isLoadingVideosMap[key] != true) {
      return;
    }

    isLoadingVideosMap[key] = true;
    try {
      var videos = await _repository.getVideosByTopic(topic.slug);
      if (videos.isEmpty && topic.id != topic.slug) {
        videos = await _repository.getVideosByTopic(topic.id);
      }
      topicVideosMap[key] = videos;
      if (Get.isRegistered<UserSignalTracker>()) {
        Get.find<UserSignalTracker>().trackTopicExplored(
          topicSlug: topic.slug.isNotEmpty ? topic.slug : topic.id,
          category: topic.category,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ExploreTopicsController.fetchVideosForTopic');
      topicVideosMap[key] = [];
    } finally {
      isLoadingVideosMap[key] = false;
    }
  }

  /// Paging handler
  Future<void> loadMoreTopics() async {
    if (!isLoadingMore.value && rxHasMore.value) {
      await loadTopics();
    }
  }

  // ==========================================================================
  // CATEGORY FILTERING (AT LEAST 2 VIDEOS)
  // ==========================================================================

  String _capitalizeCategory(String cat) {
    if (cat.isEmpty) return cat;
    final trimmed = cat.trim();
    for (final c in TopicCategoriesConfig.categories) {
      if (c.title.toLowerCase() == trimmed.toLowerCase() ||
          c.id.toLowerCase() == trimmed.toLowerCase()) {
        return c.title;
      }
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Fetch category video counts and filter categories to those with at least 2 videos
  Future<void> fetchAvailableCategories() async {
    isLoadingCategories.value = true;
    try {
      final categoryCounts = <String, int>{};

      // 1. Query Firestore videos collection for broader category stats
      try {
        final videoSnapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .limit(500)
            .get();

        for (final doc in videoSnapshot.docs) {
          final data = doc.data();
          final rawCat = (data['category'] as String?)?.trim();
          if (rawCat != null &&
              rawCat.isNotEmpty &&
              rawCat.toLowerCase() != 'all') {
            final normalized = _capitalizeCategory(rawCat);
            categoryCounts[normalized] = (categoryCounts[normalized] ?? 0) + 1;
          }
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ExploreTopicsController.queryVideosForCategories',
        );
      }

      // 2. Query Firestore topics collection for topic categories and video counts
      try {
        final topicSnapshot = await FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .where('status', isEqualTo: 'active')
            .limit(300)
            .get();

        for (final doc in topicSnapshot.docs) {
          final data = doc.data();
          final status = (data['status'] as String?)?.toLowerCase();
          if (status != null && status != 'active') continue;
          final vCount = (data['videoCount'] as num?)?.toInt() ??
              (data['featuredVideoIds'] as List?)?.length ??
              0;
          if (vCount <= 0) continue;
          final rawCat = (data['category'] as String?)?.trim();
          if (rawCat != null &&
              rawCat.isNotEmpty &&
              rawCat.toLowerCase() != 'all') {
            final normalized = _capitalizeCategory(rawCat);
            categoryCounts[normalized] =
                (categoryCounts[normalized] ?? 0) + vCount;
          }
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ExploreTopicsController.queryTopicsForCategories',
        );
      }

      // 3. Count from currently loaded topics and topicVideosMap
      for (final topic in topics) {
        final cat = topic.category.trim();
        if (cat.isNotEmpty && cat.toLowerCase() != 'all') {
          final normalized = _capitalizeCategory(cat);
          final videos = topicVideosMap[topic.id];
          final count = (videos != null && videos.isNotEmpty)
              ? videos.length
              : (topic.videoCount > 0 ? topic.videoCount : 1);
          categoryCounts[normalized] =
              (categoryCounts[normalized] ?? 0) + count;
        }
      }

      // Filter to categories that have AT LEAST 2 videos
      final qualifying = <TopicCategory>[];

      for (final configCat in TopicCategoriesConfig.categories) {
        if (configCat.id.toLowerCase() == 'all') continue;
        final countByTitle = categoryCounts[configCat.title] ?? 0;
        final countById = categoryCounts[configCat.id] ?? 0;
        final maxCount = countByTitle > countById ? countByTitle : countById;
        if (maxCount >= 2) {
          qualifying.add(configCat);
        }
      }

      // Include dynamic categories not in TopicCategoriesConfig if count >= 2
      categoryCounts.forEach((catName, count) {
        if (count >= 2 && catName.toLowerCase() != 'all') {
          final alreadyAdded = qualifying.any(
            (qc) =>
                qc.title.toLowerCase() == catName.toLowerCase() ||
                qc.id.toLowerCase() == catName.toLowerCase(),
          );
          if (!alreadyAdded) {
            qualifying.add(
              TopicCategory(
                id: catName.toLowerCase().replaceAll(' ', '_'),
                title: catName,
                imageUrl:
                    'https://images.unsplash.com/photo-1541701494587-cb58502866ab?auto=format&fit=crop&w=400&q=75',
              ),
            );
          }
        }
      });

      availableCategories.assignAll(qualifying);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ExploreTopicsController.fetchAvailableCategories',
      );
    } finally {
      isLoadingCategories.value = false;
    }
  }

  // ==========================================================================
  // FILTERS & SELECTIONS
  // ==========================================================================

  /// Filter results by category selection
  void selectCategory(String category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;
    if (category != 'all' && Get.isRegistered<UserSignalTracker>()) {
      Get.find<UserSignalTracker>().trackTopicExplored(
        topicSlug: category,
        category: category,
      );
    }
    loadTopics(reset: true);
  }

  /// Switch the active explore feed mode
  void setExploreMode(ExploreMode mode) {
    if (exploreMode.value == mode) return;
    exploreMode.value = mode;
    loadTopics(reset: true);
  }

  /// Handle search query updates — 400ms GetX debounce worker fires loadTopics automatically
  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }


  /// Clear active AI topic query
  void clearAiSearch() {
    activeAiIntent.value = null;
    clearSearch();
  }

  /// Clear the active search filter
  void clearSearch() {
    activeAiIntent.value = null;
    searchQuery.value = '';
    if (searchController.text.isNotEmpty) {
      searchController.clear();
    }
    loadTopics(reset: true);
  }

  // ==========================================================================
  // DISCOVERY PRELOADING ENGINE
  // ==========================================================================

  /// Preload target topic metadata into details screen controller to bypass empty flashes
  void preloadTopicDetails(Topic topic) {
    debugPrint(
      '🚀 [TopicDiscovery] Preloading details for slug: ${topic.slug}',
    );

    // Check if the topic controller already exists in Memory or instantiate it
    if (Get.isRegistered<TopicController>()) {
      final topicController = Get.find<TopicController>();
      topicController.topic.value = topic;
    } else {
      final topicController = Get.find<TopicController>();
      topicController.topic.value = topic;
    }
  }
}

enum ExploreMode {
  discover,
  trending,
  yearly,
}
