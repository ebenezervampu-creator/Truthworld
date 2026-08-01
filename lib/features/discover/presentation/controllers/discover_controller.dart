import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';

class DiscoverCategoryData {
  const DiscoverCategoryData({required this.name, required this.imageUrl});
  final String name;
  final String imageUrl;
}

class DiscoverController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Realtime active channels list
  final RxList<Channel> channels = <Channel>[].obs;

  // Filtering and Search State
  final RxString selectedCategory = ''.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = true.obs;

  late final TextEditingController searchController;

  // Curated category visual data for all categories (including abstract "All")
  static const List<DiscoverCategoryData> allCategories = [
    DiscoverCategoryData(
      name: 'All',
      imageUrl:
          'https://images.unsplash.com/photo-1541701494587-cb58502866ab?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Gaming',
      imageUrl:
          'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Music',
      imageUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Entertainment',
      imageUrl:
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Education',
      imageUrl:
          'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Technology',
      imageUrl:
          'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Sports',
      imageUrl:
          'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'News',
      imageUrl:
          'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Lifestyle',
      imageUrl:
          'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Travel',
      imageUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Food',
      imageUrl:
          'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Fashion',
      imageUrl:
          'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Health',
      imageUrl:
          'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Business',
      imageUrl:
          'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Comedy',
      imageUrl:
          'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Science',
      imageUrl:
          'https://images.unsplash.com/photo-1507668077129-56e32842fceb?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Art',
      imageUrl:
          'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Documentary',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Animation',
      imageUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Automotive',
      imageUrl:
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Pets & Animals',
      imageUrl:
          'https://images.unsplash.com/photo-1450778869180-41d0601e046e?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'DIY & How-to',
      imageUrl:
          'https://images.unsplash.com/photo-1530124560676-10551fa77c2a?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Fitness',
      imageUrl:
          'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Beauty',
      imageUrl:
          'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Finance',
      imageUrl:
          'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'History',
      imageUrl:
          'https://images.unsplash.com/photo-1447069387593-a5de0862481e?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Spirituality',
      imageUrl:
          'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Kids & Family',
      imageUrl:
          'https://images.unsplash.com/photo-1536640712267-c8d024a1438c?auto=format&fit=crop&w=1200&q=90',
    ),
    DiscoverCategoryData(
      name: 'Other',
      imageUrl:
          'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?auto=format&fit=crop&w=1200&q=90',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    searchController = TextEditingController(text: searchQuery.value);
    searchController.addListener(() {
      updateSearchQuery(searchController.text);
    });
    _fetchChannels();
  }

  Future<void> _fetchChannels() async {
    isLoading.value = true;
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .where('status', isEqualTo: 'active')
          .limit(100)
          .get();

      final results = snapshot.docs.map(Channel.fromDocumentSnapshot).toList();
      // Use denormalized subscriberCount from channel doc (YouTube-standard)
      for (final channel in results) {
        if (!ChannelController.globalSubscriberCounts.containsKey(
          channel.channelId,
        )) {
          ChannelController.globalSubscriberCounts[channel.channelId] =
              channel.subscriberCount;
        }
      }
      channels.assignAll(results);
    } catch (error) {
      debugPrint('DiscoverController: Error fetching channels: $error');
    } finally {
      isLoading.value = false;
    }
  }

  /// Pull-to-refresh support
  Future<void> refreshChannels() async {
    await _fetchChannels();
  }

  // Set category filter
  void selectCategory(String category) {
    if (category.toLowerCase() == 'all') {
      selectedCategory.value = '';
    } else if (selectedCategory.value.toLowerCase() == category.toLowerCase()) {
      // Toggle off if clicked again
      selectedCategory.value = '';
    } else {
      selectedCategory.value = category;
    }
  }

  // Set search query
  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  // Clear all filters
  void clearFilters() {
    selectedCategory.value = '';
    searchController.clear();
    searchQuery.value = '';
  }

  // Get computed filtered channels
  List<Channel> get filteredChannels {
    var list = channels.toList();

    // Filter by Category
    if (selectedCategory.value.isNotEmpty) {
      final categoryFilter = selectedCategory.value.toLowerCase().trim();
      list = list.where((channel) {
        final cat = channel.category.toLowerCase().trim();
        return cat == categoryFilter || cat.contains(categoryFilter);
      }).toList();
    }

    // Filter by Search Query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase().trim();
      list = list.where((channel) {
        final name = channel.name.toLowerCase();
        final handle = channel.handle.toLowerCase();
        final desc = channel.description.toLowerCase();
        return name.contains(query) ||
            handle.contains(query) ||
            desc.contains(query);
      }).toList();
    }

    return list;
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
