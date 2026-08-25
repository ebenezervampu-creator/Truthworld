import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class PT {
  static const Color primary = AppColors.brand;
  static const Color bg = AppColors.bgPage;
  static const Color surface = Color(0xFF161616);
  static const Color surfaceHi = Color(0xFF222222);
  static const Color text = Color(0xFFF2F2F2);
  static const Color textDim = Color(0xFF888888);
  static const Color border = Color(0xFF2A2A2A);

  // Layout
  static const double kControlsHideMs = 3500; // YouTube uses ~3 s
  static const double kDoubleTapRippleMs = 700;
  static const double kToastDurationMs = 2000;
  static const double kHudFadeMs = 1200;
  static const double kProgressBarH = 4;
  static const double kProgressBarHover = 5;
  static const double kThumbRadius = 7;
  static const double kThumbRadiusDrag = 9;
}

// ── Text Style Cache ──────────────────────────────────────────────────────────
// Pre-build expensive GoogleFonts lookups once.
abstract class TS {
  static const body = TextStyle(
    color: PT.text,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static const bodySm = TextStyle(
    color: PT.textDim,
    fontSize: 12,
  );
  static const bold = TextStyle(
    color: PT.text,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static const title = TextStyle(
    color: PT.text,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
  static const badge = TextStyle(
    color: PT.primary,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
  static const mono = TextStyle(
    color: PT.text,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const time = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
}

// ── Subtitle / Audio / Chapter models (unchanged) ────────────────────────────
class SubtitleTrack {
  const SubtitleTrack({
    required this.label,
    required this.langCode,
    this.url = '',
    this.isDefault = false,
  });
  final String label;
  final String langCode;
  final String url;
  final bool isDefault;
}

class SubtitleSegment {
  const SubtitleSegment({
    required this.start,
    required this.end,
    required this.text,
  });
  final Duration start;
  final Duration end;
  final String text;
}

class AudioTrack {
  const AudioTrack({
    required this.label,
    required this.langCode,
    this.type = 'Original',
    this.url,
  });
  final String label;
  final String langCode;
  final String type;
  final String? url;
}

class ContentMetadata {
  const ContentMetadata({
    this.rating = 'U/A 16+',
    this.genre = '',
    this.releaseYear = '',
    this.duration = '',
    this.director = '',
    this.cast = '',
    this.advisories = const [],
  });
  final String rating;
  final String genre;
  final String releaseYear;
  final String duration;
  final String director;
  final String cast;
  final List<String> advisories;
}

class PlayerEvent {
  PlayerEvent(this.type, {this.data = const {}}) : timestamp = DateTime.now();
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

// ── Centralised timer bag — prevents all timer leaks ─────────────────────────
class TimerBag {
  final _map = <String, Timer>{};

  void set(String key, Duration delay, VoidCallback cb) {
    _map[key]?.cancel();
    _map[key] = Timer(delay, cb);
  }

  void setPeriodic(String key, Duration period, void Function(Timer) cb) {
    _map[key]?.cancel();
    _map[key] = Timer.periodic(period, cb);
  }

  void cancel(String key) {
    _map[key]?.cancel();
    _map.remove(key);
  }

  void cancelAll() {
    for (final t in _map.values) {
      t.cancel();
    }
    _map.clear();
  }
}

class MockAd {
  const MockAd({
    required this.videoUrl,
    required this.title,
    required this.description,
    required this.clickUrl,
    required this.skippable,
    required this.duration,
    this.isSponsorBumper = false,
  });
  final String videoUrl;
  final String title;
  final String description;
  final String clickUrl;
  final bool skippable;
  final Duration duration;
  final bool isSponsorBumper;
}

class LanguageRequest {
  const LanguageRequest({
    required this.id,
    required this.language,
    required this.type,
    required this.createdAt,
    this.count = 1,
  });

  factory LanguageRequest.fromMap(Map<String, dynamic> map, String id) {
    return LanguageRequest(
      id: id,
      language: (map['language'] as String?) ?? '',
      type: (map['type'] as String?) ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      count: map['count'] as int? ?? 1,
    );
  }
  final String id;
  final String language;
  final String type; // 'subtitle' or 'audio'
  final Timestamp createdAt;
  final int count;
}
