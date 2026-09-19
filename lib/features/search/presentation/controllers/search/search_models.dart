import 'package:flutter/material.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Representation of a rich search suggestion in the search dropdown/overlay.
class SearchSuggestion {
  SearchSuggestion({
    required this.text,
    this.subtitle,
    this.imageUrl,
    this.isRoundImage = false,
    this.matchedResult,
    this.icon = Icons.search,
  });

  final String text;
  final String? subtitle;
  final String? imageUrl;
  final bool isRoundImage;
  final SearchResult? matchedResult;
  final IconData icon;
}

/// Representation of a realtime trending item with popularity metrics and rank movements.
class TrendingItem {
  TrendingItem({
    required this.id,
    required this.rank,
    required this.title,
    required this.category,
    required this.volume,
    this.badge = 'HOT',
    this.movement,
    this.subtitle,
    this.imageUrl,
    this.creator,
    this.duration,
  });

  final String id;
  final int rank;
  final String title;
  final String category; // 'video', 'topic', 'playlist', 'channel'
  final int volume;
  final String badge;
  final String? movement; // e.g. '▲ Up 3', '▼ Down 1', 'NEW', '🔥 HOT'
  final String? subtitle;
  final String? imageUrl;
  final String? creator;
  final String? duration;
}
