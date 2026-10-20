import 'package:flutter/material.dart';
import 'package:truthworld/core/constants/app_categories.dart';

/// Single curated subtopic item within a topic category
class CuratedSubtopic {
  const CuratedSubtopic({
    required this.title,
    required this.slug,
    required this.imageUrl,
    this.videoCount = '',
  });

  final String title;
  final String slug;
  final String videoCount;
  final String imageUrl;
}

/// Category metadata model supporting responsive discovery grids and deep-dive detail views.
class TopicCategory {
  const TopicCategory({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.heroImageUrl,
    this.description = '',
    this.featuredSubtitle = '',
    this.topicCountText = '',
    this.searchHintExamples = '',
    this.icon,
    this.curatedSubtopics = const [],
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? heroImageUrl;
  final String description;
  final String featuredSubtitle;
  final String topicCountText;
  final String searchHintExamples;
  final IconData? icon;
  final List<CuratedSubtopic> curatedSubtopics;

  String get effectiveHeroImageUrl =>
      (heroImageUrl != null && heroImageUrl!.isNotEmpty)
          ? heroImageUrl!
          : imageUrl;
}

/// Master configuration of topic categories for Truthworld
class TopicCategoriesConfig {
  static const List<TopicCategory> categories = [
    TopicCategory(
      id: 'all',
      title: 'All',
      imageUrl:
          'https://images.unsplash.com/photo-1541701494587-cb58502866ab?auto=format&fit=crop&w=400&q=75',
      description: 'Discover meaningful content across all topics.',
      icon: Icons.explore_rounded,
    ),

    // ========================================================================
    // FACT-CHECKING & HIGH-CREDIBILITY CATEGORIES (10)
    // ========================================================================
    TopicCategory(
      id: 'business',
      title: 'Business',
      imageUrl:
          'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80',
      description:
          'Entrepreneurship, leadership, corporate strategies, and industry analysis.',
      searchHintExamples: '"startups", "leadership", "business model"',
      icon: Icons.business_center_rounded,
    ),
    TopicCategory(
      id: 'history',
      title: 'History',
      imageUrl:
          'https://images.unsplash.com/photo-1447069387593-a5de0862481e?auto=format&fit=crop&w=800&q=80',
      description:
          'Historical events, civilizations, archival footage, and documentary accounts.',
      searchHintExamples: '"ancient civilizations", "world war", "archives"',
      icon: Icons.history_edu_rounded,
    ),
    TopicCategory(
      id: 'news',
      title: 'News',
      imageUrl:
          'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=800&q=80',
      description:
          'Fact-checked journalism, global updates, verified reports, and current events.',
      searchHintExamples: '"global updates", "fact check", "reports"',
      icon: Icons.newspaper_rounded,
    ),
    TopicCategory(
      id: 'education',
      title: 'Education',
      imageUrl:
          'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=800&q=80',
      description:
          'Academic learning, historical archives, tutorials, and deep educational lectures.',
      searchHintExamples: '"history", "tutorials", "mathematics"',
      icon: Icons.school_rounded,
    ),
    TopicCategory(
      id: 'science',
      title: 'Science',
      imageUrl:
          'https://images.unsplash.com/photo-1507668077129-56e32842fceb?auto=format&fit=crop&w=800&q=80',
      heroImageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=85',
      featuredSubtitle: 'Discoveries, physics, astrophysics, and space.',
      description:
          'Scientific discoveries, space exploration, physics, biology, and verified facts.',
      searchHintExamples: '"quantum mechanics", "space", "astrophysics"',
      icon: Icons.science_rounded,
    ),
    TopicCategory(
      id: 'technology',
      title: 'Technology',
      imageUrl:
          'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80',
      heroImageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=85',
      featuredSubtitle: 'Innovation, AI, and the wonders of creation.',
      description:
          'Innovation, artificial intelligence, robotics, and emerging software breakthroughs.',
      searchHintExamples: '"artificial intelligence", "coding", "robotics"',
      icon: Icons.memory_rounded,
    ),
    TopicCategory(
      id: 'finance',
      title: 'Finance',
      imageUrl:
          'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=800&q=80',
      description:
          'Personal finance, sound investing, market economics, and wealth management.',
      searchHintExamples: '"investing", "economics", "personal finance"',
      icon: Icons.account_balance_rounded,
    ),
    TopicCategory(
      id: 'health',
      title: 'Health',
      imageUrl:
          'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=800&q=80',
      description:
          'Medical insights, holistic wellness, public health, and mental health.',
      searchHintExamples: '"nutrition", "preventative health", "mental wellness"',
      icon: Icons.health_and_safety_rounded,
    ),
    TopicCategory(
      id: 'documentary',
      title: 'Documentary',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80',
      description:
          'In-depth investigative stories, real-world journeys, and cultural portraits.',
      searchHintExamples: '"investigative", "real stories", "expeditions"',
      icon: Icons.movie_filter_rounded,
    ),
    TopicCategory(
      id: 'fitness',
      title: 'Fitness',
      imageUrl:
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80',
      description:
          'Strength training, workouts, athletic conditioning, and fitness motivation.',
      searchHintExamples: '"workout routines", "strength training", "calisthenics"',
      icon: Icons.fitness_center_rounded,
    ),

    // ========================================================================
    // GENERAL, ENTERTAINMENT & LIFESTYLE CATEGORIES (21)
    // ========================================================================
    TopicCategory(
      id: 'music',
      title: 'Music',
      imageUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=800&q=80',
      heroImageUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=85',
      featuredSubtitle: 'Worship, praise, and faith through music.',
      description:
          'Worship, praise, gospel, and faith-based music from creators around the world.',
      searchHintExamples: '"worship", "gospel", "piano"',
      icon: Icons.music_note_rounded,
    ),
    TopicCategory(
      id: 'entertainment',
      title: 'Entertainment',
      imageUrl:
          'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80',
      description:
          'Cinema, drama, animation, uplifting performances, and creative storytelling.',
      searchHintExamples: '"movies", "shows", "storytelling"',
      icon: Icons.theater_comedy_rounded,
    ),
    TopicCategory(
      id: 'sports',
      title: 'Sports',
      imageUrl:
          'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&w=800&q=80',
      description:
          'Athletics, football, highlights, training breakdowns, and tournament coverage.',
      searchHintExamples: '"football", "training", "highlights"',
      icon: Icons.sports_soccer_rounded,
    ),
    TopicCategory(
      id: 'lifestyle',
      title: 'Lifestyle',
      imageUrl:
          'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&w=800&q=80',
      description:
          'Daily routines, mindful living, home design, and personal development.',
      searchHintExamples: '"morning routine", "organization", "mindfulness"',
      icon: Icons.spa_rounded,
    ),
    TopicCategory(
      id: 'travel',
      title: 'Travel',
      imageUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=800&q=80',
      description:
          'Cultural expeditions, scenic destinations, travel itineraries, and world discoveries.',
      searchHintExamples: '"destinations", "road trips", "cultural tours"',
      icon: Icons.flight_takeoff_rounded,
    ),
    TopicCategory(
      id: 'food',
      title: 'Food',
      imageUrl:
          'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=800&q=80',
      description:
          'Culinary masterpieces, wholesome recipes, baking guides, and international food.',
      searchHintExamples: '"recipes", "baking", "culinary"',
      icon: Icons.restaurant_rounded,
    ),
    TopicCategory(
      id: 'comedy',
      title: 'Comedy',
      imageUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80',
      description:
          'Stand-up routines, satirical parodies, comedy sketches, and clean humor.',
      searchHintExamples: '"stand-up", "sketches", "parodies"',
      icon: Icons.sentiment_very_satisfied_rounded,
    ),
    TopicCategory(
      id: 'art',
      title: 'Art',
      imageUrl:
          'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=800&q=80',
      description:
          'Fine art, digital painting, illustration, graphic craft, and galleries.',
      searchHintExamples: '"digital painting", "sketching", "galleries"',
      icon: Icons.palette_rounded,
    ),
    TopicCategory(
      id: 'animation',
      title: 'Animation',
      imageUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=800&q=80',
      description:
          '2D & 3D animation, short films, motion graphics, and animated stories.',
      searchHintExamples: '"3d animation", "motion graphics", "character design"',
      icon: Icons.animation_rounded,
    ),
    TopicCategory(
      id: 'automotive',
      title: 'Automotive',
      imageUrl:
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80',
      description:
          'Vehicle reviews, automotive engineering, restoration, and car culture.',
      searchHintExamples: '"supercars", "classic cars", "car maintenance"',
      icon: Icons.directions_car_rounded,
    ),
    TopicCategory(
      id: 'pets_animals',
      title: 'Pets & Animals',
      imageUrl:
          'https://images.unsplash.com/photo-1450778869180-41d0601e046e?auto=format&fit=crop&w=800&q=80',
      description:
          'Pet care, domestic companions, animal training, and heartfelt moments.',
      searchHintExamples: '"dog training", "cat care", "wild animals"',
      icon: Icons.pets_rounded,
    ),
    TopicCategory(
      id: 'diy',
      title: 'DIY & How-to',
      imageUrl:
          'https://images.unsplash.com/photo-1581783342308-f792dbdd27c5?auto=format&fit=crop&w=800&q=80',
      description:
          'Handcrafted woodworking, home repairs, maker crafts, and practical guides.',
      searchHintExamples: '"woodworking", "crafts", "home repair"',
      icon: Icons.build_rounded,
    ),
    TopicCategory(
      id: 'nature',
      title: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c627a92ad1ab?auto=format&fit=crop&w=800&q=80',
      description:
          'Wilderness exploration, wildlife conservation, scenic wonders, and environmental care.',
      searchHintExamples: '"mountains", "wildlife", "conservation"',
      icon: Icons.park_rounded,
    ),
    TopicCategory(
      id: 'spirituality',
      title: 'Spirituality',
      imageUrl:
          'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?auto=format&fit=crop&w=800&q=80',
      heroImageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=85',
      featuredSubtitle: 'Inner peace, prayer, and spiritual growth.',
      description:
          'Inner peace, prayer, meditation, and transformative spiritual growth.',
      searchHintExamples: '"peace of mind", "prayer", "bible study"',
      icon: Icons.self_improvement_rounded,
    ),
    TopicCategory(
      id: 'kids_family',
      title: 'Kids & Family',
      imageUrl:
          'https://images.unsplash.com/photo-1502086223501-7ea6ecd79368?auto=format&fit=crop&w=800&q=80',
      description:
          'Wholesome family content, animated stories, and values-based learning for children.',
      searchHintExamples: '"stories", "family", "children"',
      icon: Icons.child_care_rounded,
    ),
    TopicCategory(
      id: 'movies',
      title: 'Movies',
      imageUrl:
          'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80',
      description:
          'Feature films, cinema analysis, trailer reviews, and film production.',
      searchHintExamples: '"film analysis", "cinema", "trailers"',
      icon: Icons.movie_rounded,
    ),
    TopicCategory(
      id: 'tv_shows',
      title: 'TV Shows',
      imageUrl:
          'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=800&q=80',
      description:
          'Series reviews, broadcast television, streaming drama, and episode recaps.',
      searchHintExamples: '"series recaps", "drama episodes", "streaming shows"',
      icon: Icons.tv_rounded,
    ),
    TopicCategory(
      id: 'vlogs',
      title: 'Vlogs',
      imageUrl:
          'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=800&q=80',
      description:
          'Creator day-in-the-life vlogs, unfiltered experiences, and live diaries.',
      searchHintExamples: '"daily vlogs", "day in the life", "travel vlogs"',
      icon: Icons.videocam_rounded,
    ),
    TopicCategory(
      id: 'short_films',
      title: 'Short Films',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80',
      description:
          'Creative indie cinema, narrative storytelling, festival entries, and cinematic shorts.',
      searchHintExamples: '"drama", "sketches", "festival films"',
      icon: Icons.movie_creation_rounded,
    ),
    TopicCategory(
      id: 'other',
      title: 'Other',
      imageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=800&q=80',
      description:
          'Specialized subjects, mixed media, and diverse video content.',
      searchHintExamples: '"community", "miscellaneous", "special interest"',
      icon: Icons.category_rounded,
    ),
  ];

  /// Find category matching name or id case-insensitively
  static TopicCategory getCategory(String nameOrId) {
    final clean = nameOrId.trim().toLowerCase();
    for (final cat in categories) {
      if (cat.id.toLowerCase() == clean ||
          cat.title.toLowerCase() == clean ||
          cat.title.toLowerCase().replaceAll(' ', '_') == clean ||
          cat.title.toLowerCase().replaceAll(' & ', '_') == clean) {
        return cat;
      }
    }
    // Return a default topic category with clean title
    final title = AppCategories.normalizeCategory(nameOrId);
    return TopicCategory(
      id: clean.replaceAll(' ', '_'),
      title: title.isNotEmpty ? title : 'Topic',
      imageUrl: AppCategories.getImageUrl(title),
      description: AppCategories.getDescription(title),
      icon: AppCategories.getIcon(title),
    );
  }
}
