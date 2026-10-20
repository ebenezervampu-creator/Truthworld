import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';

class CategoryController extends BaseController
    with GetTickerProviderStateMixin {
  RxString selectedGenre = 'All'.obs;
  RxString selectedSort = 'Popularity'.obs;
  RxString selectedView = 'Grid'.obs;
  RxBool isSearchVisible = false.obs;
  RxString searchQuery = ''.obs;
  RxString debouncedSearchQuery = ''.obs;
  RxList<String> genres = <String>[].obs;
  RxBool isSearching = false.obs;

  late String category;
  Timer? _searchDebounceTimer;

  // Animation controllers & animations
  late AnimationController fadeAnimationController;
  late AnimationController slideAnimationController;
  late AnimationController scaleAnimationController;
  late AnimationController heroAnimationController;

  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> heroAnimation;

  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final Map<String, List<String>> _categoryToGenres = {
    'education': [
      'All',
      'Tutorials',
      'Lectures',
      'Language Learning',
      'Math & Logic',
      'Professional Development',
      'Study Tips',
      'Career Advice',
      'Science Experiments',
      'History Lessons',
      'Exam Prep',
    ],
    'entertainment': [
      'All',
      'Movies',
      'TV Shows',
      'Comedy Skits',
      'Talk Shows',
      'Celebrity News',
      'Pop Culture',
      'Behind the Scenes',
      'Fan Theories',
      'Interviews',
    ],
    'music': [
      'All',
      'Song Covers',
      'Instrument Tutorials',
      'Music Reviews',
      'Concerts',
      'Playlists',
      'Music Production',
      'Remixes',
      'Live Sessions',
      'Artist Spotlights',
    ],
    'news': [
      'All',
      'Breaking News',
      'Politics',
      'World News',
      'Business News',
      'Tech News',
      'Health News',
      'Investigative Journalism',
      'Opinion Pieces',
      'Local News',
    ],
    'sports': [
      'All',
      'Highlights',
      'Analysis',
      'Interviews',
      'Training',
      'Extreme Sports',
      'Team Sports',
      'Player Profiles',
      'Match Previews',
      'Post-Game Reviews',
    ],
    'shortfilms': [
      'All',
      'Drama',
      'Comedy',
      'Horror',
      'Sci-Fi',
      'Experimental',
      'Thriller',
      'Festival Winners',
    ],
    'technology': [
      'All',
      'Gadget Reviews',
      'Software Tutorials',
      'AI & Tech News',
      'Coding',
      'Web Design',
      'Engineering',
      'Cybersecurity',
      'App Development',
      'Future Tech',
    ],
    'science': [
      'All',
      'Experiments',
      'Discoveries',
      'Space',
      'Biology',
      'Physics',
      'Chemistry',
      'Environment',
      'Neuroscience',
      'Quantum Mechanics',
      'Astronomy',
    ],
    'travel': [
      'All',
      'Vlogs',
      'Guides',
      'Budget Travel',
      'Luxury',
      'Adventure',
      'Cultural',
      'Food Tours',
      'Hidden Gems',
      'Solo Travel',
    ],
    'lifestyle': [
      'All',
      'Daily Routines',
      'Advice',
      'Family & Community',
      'Home & Garden',
      'Personal Development',
      'Minimalism',
      'Productivity Hacks',
      'Wellness Tips',
    ],
    'comedy': [
      'All',
      'Sketches',
      'Stand-up',
      'Pranks',
      'Parodies',
      'Satire',
      'Roasts',
      'Improv',
      'Viral Clips',
      'Reaction Videos',
    ],
    'documentary': [
      'All',
      'History',
      'Nature',
      'True Crime',
      'Biographies',
      'Social Issues',
      'Environmental',
      'Cultural',
      'War Stories',
      'Innovation',
    ],
    'movies': [
      'All',
      'Action',
      'Drama',
      'Comedy',
      'Horror',
      'Sci-Fi',
      'Reviews',
      'Trailers',
      'Behind the Scenes',
      'Film Analysis',
    ],
    'tv shows': [
      'All',
      'Drama Series',
      'Reality TV',
      'Sitcoms',
      'Documentaries',
      'Talk Shows',
      'Reviews',
      'Recaps',
      'Binge Guides',
      'Casting News',
    ],
    'vlogs': [
      'All',
      'Daily Vlogs',
      'Travel Vlogs',
      'Food Vlogs',
      'Personal Stories',
      'Family Vlogs',
      'Behind the Scenes',
      'Q&A Sessions',
      'Life Updates',
      'Creator Journeys',
    ],
    'diy & how-to': [
      'All',
      'Crafts',
      'Home Improvement',
      'Cooking Hacks',
      'Tech Fixes',
      'Decor DIY',
      'Gardening',
      'Upcycling',
      'Budget Builds',
    ],
    'business': [
      'All',
      'Entrepreneurship',
      'Leadership',
      'Startups',
      'Marketing',
      'Case Studies',
      'Corporate Strategy',
      'Small Business',
      'Ecommerce',
      'Interviews',
    ],
    'finance': [
      'All',
      'Investing',
      'Personal Finance',
      'Stock Market',
      'Crypto & Blockchain',
      'Real Estate',
      'Economics',
      'Budgeting',
      'Wealth Building',
      'Financial News',
    ],
    'health': [
      'All',
      'Nutrition',
      'Mental Health',
      'Public Health',
      'Medical Science',
      'Holistic Wellness',
      'Preventative Care',
      'Sleep & Recovery',
      'Healthcare News',
      'Healthy Habits',
    ],
    'fitness': [
      'All',
      'Workouts',
      'Strength Training',
      'Cardio & HIIT',
      'Yoga & Flexibility',
      'Bodybuilding',
      'Home Workouts',
      'Athletic Conditioning',
      'Calisthenics',
      'Exercise Science',
    ],
    'food': [
      'All',
      'Recipes',
      'Baking',
      'Meal Prep',
      'Reviews',
      'Culinary Travel',
      'Vegan Dishes',
      'Desserts',
      'Street Food',
    ],
    'art': [
      'All',
      'Drawing',
      'Painting',
      'Digital Art',
      'Graphic Design',
      'Sculpture',
      'Photography',
      'Interior Design',
      'Product Design',
    ],
    'pets & animals': [
      'All',
      'Pet Care',
      'Training',
      'Funny Videos',
      'Rescue Stories',
      'Wildlife',
      'Exotic Pets',
      'Animal Behavior',
    ],
    'nature': [
      'All',
      'Documentaries',
      'Adventures',
      'Conservation',
      'Photography',
      'Wilderness',
      'Hiking Guides',
      'Eco Tourism',
    ],
    'health & fitness': [
      'All',
      'Workouts',
      'Yoga',
      'Nutrition',
      'Mental Health',
      'Weight Loss',
      'Cardio Routines',
      'Strength Training',
      'Recovery Tips',
    ],
    'food & cooking': [
      'All',
      'Recipes',
      'Baking',
      'Meal Prep',
      'Reviews',
      'Culinary Travel',
      'Vegan Dishes',
      'Desserts',
      'Street Food',
    ],
    'business & finance': [
      'All',
      'Entrepreneurship',
      'Investing',
      'Money Management',
      'Marketing',
      'Case Studies',
      'Startups',
      'Crypto',
      'Real Estate',
    ],
    'animation': [
      'All',
      '2D Animation',
      '3D Animation',
      'Stop Motion',
      'Character Design',
      'Short Films',
      'Storyboarding',
      'Voice Acting',
      'Animation Tutorials',
    ],
    'short films': [
      'All',
      'Drama',
      'Comedy',
      'Horror',
      'Sci-Fi',
      'Experimental',
      'Thriller',
      'Festival Winners',
    ],
    'history': [
      'All',
      'Ancient History',
      'Modern History',
      'Biographies',
      'Wars',
      'Cultures',
      'Archaeology',
      'Historical Mysteries',
      'Timelines',
    ],
    'art & design': [
      'All',
      'Drawing',
      'Painting',
      'Digital Art',
      'Graphic Design',
      'Sculpture',
      'Photography',
      'Interior Design',
      'Product Design',
    ],
    'automotive': [
      'All',
      'Car Reviews',
      'Mods',
      'Racing',
      'Maintenance',
      'Classic Cars',
      'Electric Vehicles',
      'Auto Shows',
      'Driving Tips',
    ],
    'animals & pets': [
      'All',
      'Pet Care',
      'Training',
      'Funny Videos',
      'Rescue Stories',
      'Wildlife',
      'Exotic Pets',
      'Animal Behavior',
    ],
    'spirituality': [
      'All',
      'Meditation',
      'Yoga Philosophy',
      'Astrology',
      'Religious Teachings',
      'Self-Reflection',
      'Tarot Readings',
      'Energy Healing',
    ],
    'nature & wildlife': [
      'All',
      'Documentaries',
      'Adventures',
      'Conservation',
      'Photography',
      'Animals',
      'Hiking Guides',
      'Eco Tourism',
    ],
    'kids & family': [
      'All',
      'Stories',
      'Educational',
      'Crafts',
      'Toys',
      'Family Vlogs',
      'Parenting Tips',
      'Holiday Activities',
      'Bedtime Routines',
    ],
    'other': [
      'All',
      'General',
      'Miscellaneous',
      'Community',
      'Mixed',
    ],
  };

  List<String> _getGenresForCategory(String cat) {
    final lower = cat.toLowerCase().trim();
    if (_categoryToGenres.containsKey(lower)) {
      return _categoryToGenres[lower]!;
    }
    final normalized = AppCategories.normalizeCategory(cat).toLowerCase();
    if (_categoryToGenres.containsKey(normalized)) {
      return _categoryToGenres[normalized]!;
    }
    for (final entry in _categoryToGenres.entries) {
      if (entry.key.contains(lower) || lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return ['All'];
  }

  String get sortField {
    switch (selectedSort.value) {
      case 'Popularity':
      case 'Views':
        return 'views';
      case 'Release Date':
        return 'uploadedAt';
      case 'Title':
        return 'title';
      case 'Trending':
        return 'views'; // Fallback
      default:
        return 'views';
    }
  }

  Stream<QuerySnapshot> get featuredStream {
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'Public');
    if (selectedGenre.value != 'All') {
      query = query.where('genre', isEqualTo: selectedGenre.value);
    }
    return query.orderBy('views', descending: true).limit(6).snapshots();
  }

  Stream<QuerySnapshot> get newReleasesStream {
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'Public');
    if (selectedGenre.value != 'All') {
      query = query.where('genre', isEqualTo: selectedGenre.value);
    }
    return query.orderBy('uploadedAt', descending: true).limit(12).snapshots();
  }

  Stream<QuerySnapshot> get topContentStream {
    Query query = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'Public');
    if (selectedGenre.value != 'All') {
      query = query.where('genre', isEqualTo: selectedGenre.value);
    }
    return query.orderBy(sortField, descending: true).limit(12).snapshots();
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is Map && args.containsKey('category')) {
      category = args['category'];
    } else {
      category = 'All';
    }
    genres.value = _getGenresForCategory(category);
    selectedGenre.value = genres[0];

    // Initialize animation controllers
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: slideAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    heroAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: heroAnimationController,
        curve: Curves.easeOutExpo,
      ),
    );

    if (Get.testMode) {
      heroAnimationController.value = 1.0;
      fadeAnimationController.value = 1.0;
      slideAnimationController.value = 1.0;
      scaleAnimationController.value = 1.0;
    } else {
      heroAnimationController.forward();
      fadeAnimationController.forward();
      slideAnimationController.forward();
      scaleAnimationController.forward();
    }

    // Setup native GetX debounce worker for search
    addWorker(
      ever<String>(searchQuery, (_) {
        isSearching.value = true;
      }),
    );
    addWorker(
      debounce<String>(
        searchQuery,
        (value) {
          debouncedSearchQuery.value = value.trim().toLowerCase();
          isSearching.value = false;
        },
        time: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void onClose() {
    fadeAnimationController.stop();
    slideAnimationController.stop();
    scaleAnimationController.stop();
    heroAnimationController.stop();
    fadeAnimationController.dispose();
    slideAnimationController.dispose();
    scaleAnimationController.dispose();
    heroAnimationController.dispose();
    searchController.dispose();
    scrollController.dispose();
    _searchDebounceTimer?.cancel();
    super.onClose();
  }

  void clearSearch() {
    searchQuery.value = '';
    debouncedSearchQuery.value = '';
  }
}
