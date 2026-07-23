import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class SearchPageController extends BaseController {
  final RxString searchQuery = ''.obs;
  final RxList<Video> searchResults = <Video>[].obs;
  final RxBool isSearching = false.obs;
  final RxList<String> searchHistory = <String>[].obs;
  
  // Hover states for various UI elements (mapped by item ID)
  final RxMap<String, bool> hoverStates = <String, bool>{}.obs;

  void updateSearchQuery(String query) {
    searchQuery.value = query;
    if (query.trim().length > 2) {
      performSearch(query);
    } else {
      searchResults.clear();
    }
  }

  Future<void> performSearch(String query) async {
    try {
      setViewState(ViewState.loading);
      isSearching.value = true;
      
      // Basic search logic using Firestore
      // For high scale, this should ideally be an Algolia or ElasticSearch service
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('visibility', isEqualTo: 'Public')
          .where('status', isEqualTo: 'published')
          .orderBy('title')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();

      searchResults.assignAll(snapshot.docs.map(Video.fromDocumentSnapshot).toList());
      setViewState(ViewState.success);
    } catch (e) {
      handleError(e);
    } finally {
      isSearching.value = false;
    }
  }

  void setHoverState(String id, bool isHovered) {
    hoverStates[id] = isHovered;
  }

  bool isHovered(String id) => hoverStates[id] ?? false;

  void addToHistory(String query) {
    if (query.isEmpty) return;
    if (!searchHistory.contains(query)) {
      searchHistory.insert(0, query);
      if (searchHistory.length > 10) searchHistory.removeLast();
    }
  }

  void clearHistory() {
    searchHistory.clear();
  }
}





