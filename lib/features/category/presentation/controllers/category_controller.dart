import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';

class CategoryController extends BaseController {
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
    'gaming': [
      'All',
      'Walkthroughs',
      'Reviews',
      'eSports',
      "Let's Plays",
      'Speedruns',
      'Mods',
      'Game Development',
      'Hardware Tips',
      'Community Challenges',
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
      'Relationships',
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
      'Romance',
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
      'Family Vlogs',
      'Challenge Vlogs',
      'Behind the Scenes',
      'Q&A Sessions',
      'Life Updates',
    ],
    'diy & how-to': [
      'All',
      'Crafts',
      'Home Improvement',
      'Cooking Hacks',
      'Tech Fixes',
      'Beauty DIY',
      'Gardening',
      'Upcycling',
      'Budget Builds',
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
    'fashion & beauty': [
      'All',
      'Makeup Tutorials',
      'Hauls',
      'Style Tips',
      'Skincare',
      'Trends',
      'Hair Styling',
      'Outfit Ideas',
      'Sustainable Fashion',
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
      'Romance',
      'Festival Winners',
    ],
    'motivation': [
      'All',
      'Speeches',
      'Success Stories',
      'Mindset',
      'Goal Setting',
      'Inspirational Quotes',
      'Overcoming Obstacles',
      'Daily Affirmations',
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
      'Fashion Design',
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
    'people & blogs': [
      'All',
      'Daily Vlogs',
      'Personal Stories',
      'Q&A Sessions',
      'Life Updates',
      'Behind the Scenes',
      'Family Vlogs',
      'Challenge Videos',
      'Opinion & Rants',
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
    return _categoryToGenres[cat.toLowerCase()] ?? ['All'];
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

    // Setup debounce listener for search
    ever(searchQuery, (value) {
      isSearching.value = true;
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        debouncedSearchQuery.value = value.trim().toLowerCase();
        isSearching.value = false;
      });
    });
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    super.onClose();
  }

  void clearSearch() {
    searchQuery.value = '';
    debouncedSearchQuery.value = '';
  }
}
