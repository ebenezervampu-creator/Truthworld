import 'package:flutter/material.dart';

/// Single source of truth for all content categories across TruthWorld.
///
/// Contains:
/// - 10 Fact-checking & High-credibility categories
/// - 20 General, Entertainment & Lifestyle categories
/// Total: 30 unified categories
class AppCategories {
  AppCategories._();

  // ==========================================================================
  // 1. FACT-CHECKING & HIGH-CREDIBILITY CATEGORIES (10)
  // ==========================================================================
  static const List<String> factCheckingCategories = [
    'Business',
    'History',
    'News',
    'Education',
    'Science',
    'Technology',
    'Finance',
    'Health',
    'Documentary',
    'Fitness',
  ];

  // ==========================================================================
  // 2. GENERAL, ENTERTAINMENT & LIFESTYLE CATEGORIES (20)
  // ==========================================================================
  static const List<String> generalCategories = [
    'Music',
    'Entertainment',
    'Sports',
    'Lifestyle',
    'Travel',
    'Food',
    'Comedy',
    'Art',
    'Animation',
    'Automotive',
    'Pets & Animals',
    'DIY & How-to',
    'Nature',
    'Spirituality',
    'Kids & Family',
    'Movies',
    'TV Shows',
    'Vlogs',
    'Short Films',
    'Other',
  ];

  // ==========================================================================
  // MASTER UNIFIED LIST (30 CATEGORIES)
  // ==========================================================================
  static const List<String> allCategories = [
    ...factCheckingCategories,
    ...generalCategories,
  ];

  /// Set of categories where AI credibility / fact-checking is not applicable
  static const Set<String> categoriesWithoutFactCheck = {
    'Music',
    'Entertainment',
    'Sports',
    'Lifestyle',
    'Travel',
    'Food',
    'Comedy',
    'Art',
    'Animation',
    'Automotive',
    'Pets & Animals',
    'DIY & How-to',
    'Nature',
    'Spirituality',
    'Kids & Family',
    'Movies',
    'TV Shows',
    'Vlogs',
    'Short Films',
    'Other',
  };

  /// Set of lowercase tokens for non-credibility checking
  static const Set<String> nonCredibilityTokens = {
    'music',
    'entertainment',
    'sports',
    'sport',
    'lifestyle',
    'travel',
    'food',
    'food & cooking',
    'comedy',
    'art',
    'art & design',
    'animation',
    'automotive',
    'pets & animals',
    'animals & pets',
    'pets',
    'diy & how-to',
    'diy',
    'nature',
    'nature & wildlife',
    'spirituality',
    'spiritual',
    'faith',
    'religion',
    'religious',
    'devotional',
    'theology',
    'theological',
    'prayer',
    'worship',
    'kids & family',
    'movies',
    'movie',
    'tv shows',
    'tv show',
    'vlogs',
    'vlog',
    'short films',
    'shortfilms',
    'short film',
    'other',
    'creative',
    'performance',
    'dance',
    'song',
    'songs',
  };

  /// Returns true if fact checking is relevant for the given category
  static bool isFactCheckRelevant(String category) {
    final normalized = normalizeCategory(category);
    return factCheckingCategories.contains(normalized);
  }

  /// Normalizes any legacy or combined category names into canonical 30 names
  static String normalizeCategory(String category) {
    final clean = category.trim();
    if (allCategories.contains(clean)) return clean;
    final lower = clean.toLowerCase();

    switch (lower) {
      case 'news & politics':
      case 'politics':
        return 'News';
      case 'technology & science':
      case 'tech':
      case 'ai & tech':
        return 'Technology';
      case 'business & finance':
      case 'economics':
        return 'Business';
      case 'health & wellness':
      case 'health & fitness':
        return 'Health';
      case 'food & cooking':
      case 'cooking':
        return 'Food';
      case 'art & design':
      case 'design':
        return 'Art';
      case 'fashion & beauty':
      case 'fashion':
      case 'beauty':
        return 'Lifestyle';
      case 'romance':
      case 'romantic':
        return 'Other';
      case 'animals & pets':
      case 'animals':
      case 'pets':
        return 'Pets & Animals';
      case 'nature & environment':
      case 'nature & wildlife':
      case 'environment':
        return 'Nature';
      case 'education & learning':
        return 'Education';
      case 'travel & events':
        return 'Travel';
      case 'diy':
        return 'DIY & How-to';
      case 'vlog':
      case 'vlogs':
      case 'people & blogs':
      case 'people and blogs':
      case 'people_blogs':
      case 'people':
      case 'blogs':
      case 'blog':
        return 'Vlogs';
      case 'movie':
      case 'film':
      case 'cinema':
      case 'films':
        return 'Movies';
      case 'tv show':
      case 'series':
      case 'tv':
      case 'shows':
        return 'TV Shows';
      case 'short films':
      case 'shortfilms':
      case 'short film':
      case 'gaming':
        return 'Short Films';
      case 'songs':
      case 'song':
      case 'tracks':
      case 'track':
      case 'music video':
      case 'music videos':
        return 'Music';
      case 'fitness & health':
      case 'gym':
      case 'workout':
      case 'workouts':
      case 'exercise':
        return 'Fitness';
      case 'science & tech':
        return 'Science';
      case 'finance & investment':
      case 'crypto':
      case 'investing':
      case 'stocks':
        return 'Finance';
      case 'humor':
      case 'comedy & humor':
      case 'jokes':
        return 'Comedy';
      case 'wildlife':
        return 'Nature';
      case 'crafts':
      case 'how-to':
      case 'howto':
        return 'DIY & How-to';
      case 'cars':
      case 'auto':
      case 'automobiles':
      case 'vehicles':
        return 'Automotive';
      case 'cartoons':
      case 'cartoon':
      case 'anime':
        return 'Animation';
      case 'general':
        return 'Other';
      default:
        for (final cat in allCategories) {
          if (cat.toLowerCase() == lower) return cat;
        }
        return clean.isEmpty ? 'Other' : clean;
    }
  }

  /// Icon for each category
  static IconData getIcon(String category) {
    switch (category.toLowerCase().trim()) {
      // 10 Fact-checking & High-credibility
      case 'business':
        return Icons.business_center_rounded;
      case 'history':
        return Icons.history_edu_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'technology':
        return Icons.memory_rounded;
      case 'finance':
        return Icons.account_balance_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'documentary':
        return Icons.movie_filter_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;

      // 20 General, Entertainment & Lifestyle
      case 'music':
        return Icons.music_note_rounded;
      case 'entertainment':
        return Icons.theater_comedy_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'lifestyle':
        return Icons.spa_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'comedy':
        return Icons.sentiment_very_satisfied_rounded;
      case 'art':
        return Icons.palette_rounded;
      case 'animation':
        return Icons.animation_rounded;
      case 'automotive':
        return Icons.directions_car_rounded;
      case 'pets & animals':
        return Icons.pets_rounded;
      case 'diy & how-to':
      case 'diy':
        return Icons.build_rounded;
      case 'nature':
        return Icons.park_rounded;
      case 'spirituality':
        return Icons.self_improvement_rounded;
      case 'kids & family':
        return Icons.child_care_rounded;
      case 'movies':
        return Icons.movie_rounded;
      case 'tv shows':
        return Icons.tv_rounded;
      case 'vlogs':
        return Icons.videocam_rounded;
      case 'short films':
      case 'shortfilms':
        return Icons.movie_creation_rounded;
      case 'other':
      default:
        return Icons.category_rounded;
    }
  }

  /// String icon identifier for Discover channels mapping
  static String getIconString(String category) {
    switch (category.toLowerCase().trim()) {
      case 'business':
        return 'business';
      case 'history':
        return 'history_edu';
      case 'news':
        return 'newspaper';
      case 'education':
        return 'school';
      case 'science':
        return 'science';
      case 'technology':
        return 'computer';
      case 'finance':
        return 'account_balance';
      case 'health':
        return 'favorite';
      case 'documentary':
        return 'video_label';
      case 'fitness':
        return 'fitness_center';
      case 'music':
        return 'music_note';
      case 'entertainment':
        return 'theater_comedy';
      case 'sports':
        return 'sports_soccer';
      case 'lifestyle':
        return 'home';
      case 'travel':
        return 'travel_explore';
      case 'food':
        return 'restaurant';
      case 'comedy':
        return 'sentiment_very_satisfied';
      case 'art':
        return 'palette';
      case 'animation':
        return 'animation';
      case 'automotive':
        return 'directions_car';
      case 'pets & animals':
        return 'pets';
      case 'diy & how-to':
        return 'build';
      case 'nature':
        return 'park';
      case 'spirituality':
        return 'self_improvement';
      case 'kids & family':
        return 'child_care';
      case 'movies':
        return 'movie';
      case 'tv shows':
        return 'tv';
      case 'vlogs':
        return 'videocam';
      case 'short films':
      case 'shortfilms':
        return 'movie_creation';
      case 'other':
      default:
        return 'category';
    }
  }

  /// Unsplash image URL for visual category representations
  static String getImageUrl(String category) {
    switch (category.toLowerCase().trim()) {
      // 10 Fact-checking & High-credibility
      case 'business':
        return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80';
      case 'history':
        return 'https://images.unsplash.com/photo-1447069387593-a5de0862481e?auto=format&fit=crop&w=800&q=80';
      case 'news':
        return 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=800&q=80';
      case 'education':
        return 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=800&q=80';
      case 'science':
        return 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?auto=format&fit=crop&w=800&q=80';
      case 'technology':
        return 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80';
      case 'finance':
        return 'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=800&q=80';
      case 'health':
        return 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=800&q=80';
      case 'documentary':
        return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80';
      case 'fitness':
        return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80';

      // 20 General, Entertainment & Lifestyle
      case 'music':
        return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=800&q=80';
      case 'entertainment':
        return 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80';
      case 'sports':
        return 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&w=800&q=80';
      case 'lifestyle':
        return 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&w=800&q=80';
      case 'travel':
        return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=800&q=80';
      case 'food':
      case 'food & cooking':
        return 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=800&q=80';
      case 'comedy':
        return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80';
      case 'art':
      case 'art & design':
        return 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=800&q=80';
      case 'animation':
        return 'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=800&q=80';
      case 'automotive':
        return 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80';
      case 'pets & animals':
      case 'pets':
        return 'https://images.unsplash.com/photo-1450778869180-41d0601e046e?auto=format&fit=crop&w=800&q=80';
      case 'diy & how-to':
      case 'diy':
        return 'https://images.unsplash.com/photo-1581783342308-f792dbdd27c5?auto=format&fit=crop&w=800&q=80';
      case 'nature':
      case 'nature & wildlife':
        return 'https://images.unsplash.com/photo-1441974231531-c627a92ad1ab?auto=format&fit=crop&w=800&q=80';
      case 'spirituality':
        return 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?auto=format&fit=crop&w=800&q=80';
      case 'kids & family':
        return 'https://images.unsplash.com/photo-1502086223501-7ea6ecd79368?auto=format&fit=crop&w=800&q=80';
      case 'movies':
        return 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80';
      case 'tv shows':
        return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=800&q=80';
      case 'vlogs':
        return 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=800&q=80';
      case 'short films':
      case 'shortfilms':
        return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80';
      case 'other':
      default:
        return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=800&q=80';
    }
  }

  /// Category descriptions
  static String getDescription(String category) {
    switch (category.toLowerCase().trim()) {
      // 10 Fact-checking & High-credibility
      case 'business':
        return 'Entrepreneurship, leadership, corporate strategies, and industry analysis.';
      case 'history':
        return 'Historical events, civilizations, archival footage, and documentary accounts.';
      case 'news':
        return 'Fact-checked journalism, breaking updates, verified reports, and global events.';
      case 'education':
        return 'Academic lectures, structured tutorials, lifelong learning, and deep instruction.';
      case 'science':
        return 'Scientific discoveries, physics, space exploration, biology, and research.';
      case 'technology':
        return 'AI innovations, software engineering, gadgets, robotics, and emerging tech.';
      case 'finance':
        return 'Personal finance, sound investing, market economics, and wealth management.';
      case 'health':
        return 'Medical insights, holistic wellness, public health, and mental health.';
      case 'documentary':
        return 'In-depth investigative stories, real-world journeys, and cultural portraits.';
      case 'fitness':
        return 'Workouts, strength training, athletic conditioning, and fitness motivation.';

      // 20 General, Entertainment & Lifestyle
      case 'music':
        return 'Original tracks, live acoustic sessions, music production, and performances.';
      case 'entertainment':
        return 'Pop culture discussions, creative storytelling, performances, and shows.';
      case 'sports':
        return 'Game highlights, tournament coverage, athletic skills, and sports analysis.';
      case 'lifestyle':
        return 'Daily habits, mindful living, home design, and personal development.';
      case 'travel':
        return 'Cultural expeditions, destination itineraries, and world adventures.';
      case 'food':
      case 'food & cooking':
        return 'Delicious recipes, culinary mastery, baking guides, and street food.';
      case 'comedy':
        return 'Stand-up routines, satirical parodies, comedy sketches, and humor.';
      case 'art':
      case 'art & design':
        return 'Fine art, digital painting, illustration, graphic craft, and galleries.';
      case 'animation':
        return '2D & 3D animation, short films, motion graphics, and animated stories.';
      case 'automotive':
        return 'Vehicle reviews, automotive engineering, restoration, and car culture.';
      case 'pets & animals':
      case 'pets':
        return 'Pet care, domestic companions, animal training, and heartfelt moments.';
      case 'diy & how-to':
      case 'diy':
        return 'Step-by-step builds, home repair, handcrafted woodwork, and maker guides.';
      case 'nature':
      case 'nature & wildlife':
        return 'Wilderness expeditions, scenic landscapes, conservation, and ecology.';
      case 'spirituality':
        return 'Inner peace, prayer, mindfulness meditation, and spiritual reflection.';
      case 'kids & family':
        return 'Wholesome family adventures, parenting, and values-based children content.';
      case 'movies':
        return 'Feature films, cinema analysis, trailer reviews, and film production.';
      case 'tv shows':
        return 'Series reviews, broadcast television, streaming drama, and episode recaps.';
      case 'vlogs':
        return 'Day-in-the-life chronicles, personal narratives, travel diaries, and unscripted creator journeys.';
      case 'short films':
      case 'shortfilms':
        return 'Creative indie cinema, narrative storytelling, festival entries, and cinematic shorts.';
      case 'other':
      default:
        return 'Explore top creators, verified channels, and engaging video content.';
    }
  }

  /// Category channel counts helper.
  /// Hardcoded mock counts are strictly forbidden per TruthWorld's Zero Mock Data Policy.
  /// Authentic channel counts should be fetched dynamically from Firestore.
  static String getChannelCount(String category) {
    return '';
  }
}
