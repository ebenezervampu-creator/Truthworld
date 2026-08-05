import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Global service managing the "Flip Coin" (The Other Side) state across surfaces.
///
/// When flipped:
/// - Home feed shows content opposite to user's interests
/// - Topics page shows contrarian/alternative perspective topics
/// - Video screen shows videos representing the OPPOSITE perspective of the currently playing video
///   (e.g., Iran President → Israel President / Opposing diplomatic views)
class FlipCoinService extends GetxService {
  static FlipCoinService get to {
    if (!Get.isRegistered<FlipCoinService>()) {
      Get.put(FlipCoinService(), permanent: true);
    }
    return Get.find<FlipCoinService>();
  }

  /// Surface flip states
  final RxBool isHomeFlipped = false.obs;
  final RxBool isTopicsFlipped = false.obs;
  final RxMap<String, bool> videoFlipStates = <String, bool>{}.obs;

  /// Counter-arguments and defense analysis flip states
  final RxBool isCommentCounterArgumentFlipped = false.obs;
  final RxBool isAnalysisDefenseFlipped = false.obs;

  /// Toggle home feed flip
  void toggleHomeFlip() {
    isHomeFlipped.toggle();
  }

  /// Toggle topics feed flip
  void toggleTopicsFlip() {
    isTopicsFlipped.toggle();
  }

  /// Toggle video screen flip for specific video
  void toggleVideoFlip(String videoId) {
    final current = videoFlipStates[videoId] ?? false;
    videoFlipStates[videoId] = !current;
  }

  /// Set video flip state explicitly for a videoId
  void setVideoFlipped(String videoId, bool flipped) {
    videoFlipStates[videoId] = flipped;
  }

  /// Check if video screen is flipped for a videoId
  bool isVideoFlipped(String videoId) {
    return videoFlipStates[videoId] ?? false;
  }

  /// Track flip coin interaction on a specified surface
  void trackFlipCoinInteraction(String surface) {
    if (Get.isRegistered<UserInterestProfileService>()) {
      UserInterestProfileService.to.onFlipCoinTapped(surface);
    }
  }

  /// Converts query to opposite/contrarian viewpoint
  /// e.g. 'risks of ai' -> 'breakthroughs and benefits of ai',
  ///      'iran president' -> 'israel presidentdiplomacy',
  ///      'pro' -> 'anti'
  String flipSearchQuery(String query) {
    if (query.trim().isEmpty) return query;

    final trimmed = query.trim();
    final lower = trimmed.toLowerCase();

    // 1. Direct specific key phrase rules
    if (lower == 'risks of ai' || lower == 'risk of ai') {
      return 'breakthroughs and benefits of ai';
    }
    if (lower == 'iran president') {
      return 'israel presidentdiplomacy';
    }
    if (lower == 'pro') {
      return 'anti';
    }
    if (lower == 'anti') {
      return 'pro';
    }

    // 2. Pattern & regex replacements
    var flipped = trimmed;

    final replacements = <RegExp, String>{
      RegExp(r'\brisks? of ai\b', caseSensitive: false):
          'breakthroughs and benefits of ai',
      RegExp(r'\biran president\b', caseSensitive: false):
          'israel presidentdiplomacy',
      RegExp(r'\brisks of\b', caseSensitive: false):
          'breakthroughs and benefits of',
      RegExp(r'\bbenefits of\b', caseSensitive: false): 'risks and harms of',
      RegExp(r'\bdangers of\b', caseSensitive: false):
          'breakthroughs and opportunities of',
      RegExp(r'\bopportunities of\b', caseSensitive: false):
          'dangers and risks of',
      RegExp(r'\bpros and cons\b', caseSensitive: false): 'cons and pros',
      RegExp(r'\bpros of\b', caseSensitive: false): 'cons of',
      RegExp(r'\bcons of\b', caseSensitive: false): 'pros of',
      RegExp(r'\bpro\b', caseSensitive: false): 'anti',
      RegExp(r'\banti\b', caseSensitive: false): 'pro',
    };

    var replacedAny = false;
    for (final entry in replacements.entries) {
      if (entry.key.hasMatch(flipped)) {
        flipped = flipped.replaceAll(entry.key, entry.value);
        replacedAny = true;
        break;
      }
    }

    if (replacedAny) return flipped;

    // 3. Fallback to oppositePairs map matching
    for (final entry in oppositePairs.entries) {
      final key = entry.key;
      final opposites = entry.value;
      if (lower.contains(key) && opposites.isNotEmpty) {
        final replacement = opposites.first;
        flipped = flipped.replaceAll(
          RegExp(r'\b' + RegExp.escape(key) + r'\b', caseSensitive: false),
          replacement,
        );
        if (flipped != trimmed) return flipped;
      }
    }

    return 'Opposing viewpoint: $trimmed';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OPPOSITE PERSPECTIVE KEYWORD PAIRS (Contrarian Mappings)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Known opposite entity/perspective pairs for context matching
  static const Map<String, List<String>> oppositePairs = {
    // Geopolitics / World Leadership
    'iran': ['israel', 'us', 'usa', 'america', 'diplomacy', 'west'],
    'israel': ['iran', 'palestine', 'lebanon', 'gaza', 'middle east'],
    'palestine': ['israel', 'diplomacy', 'un', 'peace'],
    'russia': ['ukraine', 'nato', 'eu', 'us'],
    'ukraine': ['russia', 'diplomacy', 'peace'],
    'china': ['taiwan', 'us', 'india', 'japan'],
    'taiwan': ['china', 'us', 'pacific'],
    'us': ['china', 'russia', 'iran'],
    'india': ['pakistan', 'china'],
    'pakistan': ['india'],

    // Politics & Governance
    'government': ['opposition', 'critics', 'citizens', 'protest'],
    'president': ['opposition', 'counterpart', 'foreign leader', 'critic'],
    'military': ['diplomacy', 'peace', 'activists', 'un'],
    'army': ['diplomacy', 'peacekeepers', 'humanitarian'],
    'election': ['opposition', 'voters', 'reform'],

    // Tech & Society
    'ai': ['safety', 'ethics', 'risks', 'regulation', 'humanities'],
    'crypto': ['regulation', 'traditional finance', 'central banks'],
    'climate': ['economy', 'energy', 'industry'],
  };

  /// Get contrasting search terms/topics for a video
  List<String> getOppositeKeywords(Video video) {
    final titleLower = video.title.toLowerCase();
    final descriptionLower = video.description.toLowerCase();
    final topicsLower = video.topics.map((t) => t.toLowerCase()).toList();
    final combined = '$titleLower $descriptionLower ${topicsLower.join(" ")}';

    final opposites = <String>{};

    oppositePairs.forEach((key, valList) {
      if (combined.contains(key)) {
        opposites.addAll(valList);
      }
    });

    return opposites.toList();
  }

  /// Score how contrasting a candidate video is relative to the currently playing video
  double calculateContrastScore(Video currentVideo, Video candidateVideo) {
    if (currentVideo.id == candidateVideo.id) return -1.0;

    var contrastScore = 0.0;
    final currentKeywords = getOppositeKeywords(currentVideo);
    final candidateText =
        '${candidateVideo.title} ${candidateVideo.description} ${candidateVideo.topics.join(" ")}'
            .toLowerCase();

    // 1. Direct Keyword Contrast Match
    for (final kw in currentKeywords) {
      if (candidateText.contains(kw)) {
        contrastScore += 0.5;
      }
    }

    // 2. Different Channel (Opposite Voice)
    if (currentVideo.channelId != candidateVideo.channelId) {
      contrastScore += 0.2;
    }

    // 3. Same Category or Related Topic (Relevant context, but contrasting viewpoint)
    if (currentVideo.category == candidateVideo.category) {
      contrastScore += 0.2;
    }

    return contrastScore;
  }
}
