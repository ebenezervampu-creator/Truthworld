import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';

class DiscoverChannelsController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxString selectedCategory = 'All'.obs;
  final RxString selectedFilter = 'Top Channels'.obs;
  final RxList<Channel> channels = <Channel>[].obs;
  final RxBool rxIsLoading = false.obs;

  final RxString searchQuery = ''.obs;
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  final List<String> filters = [
    'Top Channels',
    'Emerging',
    'Verified Only',
    'Most Active',
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
    loadChannels();
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
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
      Query query = _firestore
          .collection(FirestoreCollections.channels)
          .where('status', isEqualTo: 'active');

      if (selectedCategory.value != 'All') {
        query = query.where(
          'category',
          isEqualTo: selectedCategory.value.toLowerCase(),
        );
      }

      if (searchQuery.value.isNotEmpty) {
        final queryStr = searchQuery.value.toLowerCase().trim();
        query = query
            .where('nameLowercase', isGreaterThanOrEqualTo: queryStr)
            .where('nameLowercase', isLessThan: '$queryStr\uf8ff')
            .orderBy('nameLowercase');
      } else {
        // Apply Filters
        switch (selectedFilter.value) {
          case 'Top Channels':
            query = query.orderBy('subscriberCount', descending: true);
          case 'Emerging':
            query = query.orderBy('createdAt', descending: true);
          case 'Verified Only':
            query = query.where('isVerified', isEqualTo: true);
          case 'Most Active':
            query = query.orderBy('videoCount', descending: true);
        }
      }

      final snapshot = await query.limit(50).get();
      var loadedChannels = snapshot.docs
          .map(Channel.fromDocumentSnapshot)
          .toList();

      // Apply client-side sorting when search query is active
      if (searchQuery.value.isNotEmpty) {
        switch (selectedFilter.value) {
          case 'Top Channels':
            loadedChannels.sort(
              (a, b) => b.subscriberCount.compareTo(a.subscriberCount),
            );
          case 'Emerging':
            loadedChannels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case 'Verified Only':
            loadedChannels = loadedChannels.where((c) => c.isVerified).toList();
          case 'Most Active':
            loadedChannels.sort((a, b) => b.videoCount.compareTo(a.videoCount));
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
    searchController.dispose();
    super.onClose();
  }
}
