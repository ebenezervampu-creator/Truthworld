import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

/// Manages offline disk caching and persistent search history using GetStorage.
class SearchHistoryCacheManager {
  static const String cacheStorageKey = 'search_cache_persistent';
  static const String recentSearchesKey = 'search_recent_history';
  static const int defaultMaxRecentSearches = 10;

  /// Load persistent search results cache from disk
  Future<List<SearchResult>> loadPersistentCache() async {
    try {
      final cached = GetStorage().read(cacheStorageKey);
      if (cached != null && cached is String) {
        final List<dynamic> decoded = jsonDecode(cached);
        final results = decoded
            .map((item) => SearchResult.fromMap(item as Map<String, dynamic>))
            .toList();
        debugPrint('💾 [Search] Persistent cache loaded (${results.length} items)');
        return results;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchHistoryCacheManager.loadPersistentCache');
    }
    return [];
  }

  /// Save search results cache to disk for offline availability
  Future<void> savePersistentCache(List<SearchResult> results) async {
    try {
      final cacheString = jsonEncode(
        results.map((r) => r.toMap()).toList(),
        toEncodable: (nonEncodable) {
          if (nonEncodable is Timestamp) {
            return nonEncodable.toDate().toIso8601String();
          }
          if (nonEncodable is DateTime) {
            return nonEncodable.toIso8601String();
          }
          return nonEncodable.toString();
        },
      );
      debugPrint('💾 [Search] Cache saved (Size: ${cacheString.length} chars)');
      await GetStorage().write(cacheStorageKey, cacheString);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchHistoryCacheManager.savePersistentCache');
    }
  }

  /// Load recent search history queries from disk
  Future<List<String>> loadRecentSearches() async {
    try {
      final recent = GetStorage().read(recentSearchesKey) as List?;
      final list = (recent ?? []).cast<String>();
      debugPrint('📝 [Search] Recent searches loaded (${list.length} queries)');
      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchHistoryCacheManager.loadRecentSearches');
      return [];
    }
  }

  /// Save recent search history queries to disk
  Future<void> saveRecentSearches(List<String> searches) async {
    try {
      await GetStorage().write(recentSearchesKey, searches);
      debugPrint('📝 [Search] Recent searches saved (${searches.length} queries)');
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchHistoryCacheManager.saveRecentSearches');
    }
  }

  /// Add a query to the list of recent searches respecting privacy settings & deduplication
  List<String> addQueryToRecent({
    required List<String> currentList,
    required String query,
    int maxRecent = defaultMaxRecentSearches,
  }) {
    // Check if search history is paused in user settings
    if (Get.isRegistered<UserSettingsController>() &&
        UserSettingsController.to.isSearchHistoryPaused.value) {
      debugPrint('⏸️ [Search] Search history is PAUSED - not saving query');
      return currentList;
    }

    final updated = List<String>.from(currentList);

    // Remove if already exists (to avoid duplicates)
    updated.removeWhere((q) => q.toLowerCase() == query.toLowerCase());

    // Add to front
    updated.insert(0, query);

    // Keep only max items
    if (updated.length > maxRecent) {
      updated.removeRange(maxRecent, updated.length);
    }

    saveRecentSearches(updated);
    return updated;
  }

  /// Fetch user's watched video history IDs to support local filtering
  Future<Set<String>> fetchWatchedVideoIds(String userId) async {
    if (userId.isEmpty) return {};
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('watch_history')
          .limit(150)
          .get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchHistoryCacheManager.fetchWatchedVideoIds');
      return {};
    }
  }
}
