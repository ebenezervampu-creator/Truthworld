import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/algorithm/vector_math_util.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Global service managing the "Flip Coin" (The Other Side) state across surfaces.
///
/// When flipped:
/// - Home feed shows content opposite to user's interests
/// - Topics page shows contrarian/alternative perspective topics
/// - Video screen shows videos representing the OPPOSITE perspective of the currently playing video
///   (e.g., War/Conflict → Peace/Diplomacy/Humanitarian views)
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
  ///      'advantages of x' -> 'disadvantages of x',
  ///      'pro' -> 'anti'
  String flipSearchQuery(String query) {
    if (query.trim().isEmpty) return query;

    final trimmed = query.trim();
    final lower = trimmed.toLowerCase();

    // 1. Direct specific key phrase rules
    if (lower == 'risks of ai' || lower == 'risk of ai') {
      return 'breakthroughs and benefits of ai';
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
      RegExp(r'\brisks of\b', caseSensitive: false):
          'breakthroughs and benefits of',
      RegExp(r'\bbenefits of\b', caseSensitive: false): 'risks and harms of',
      RegExp(r'\bdangers of\b', caseSensitive: false):
          'breakthroughs and opportunities of',
      RegExp(r'\bopportunities of\b', caseSensitive: false):
          'dangers and risks of',
      RegExp(r'\badvantages of\b', caseSensitive: false):
          'disadvantages of',
      RegExp(r'\bdisadvantages of\b', caseSensitive: false):
          'advantages of',
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
  // 3-DIMENSIONAL CONTRAST ARCHITECTURE
  // 1. Counterpart Actors & Affected Stakeholders (e.g. Conflict ↔ Diplomacy/UN)
  // 2. Conceptual Contrasts (e.g. War ↔ Peace, Attack ↔ Ceasefire)
  // 3. Opposing Claims & Stances (e.g. Military Necessity ↔ Civilian Protection)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dimension 1: Geopolitical counterpart actors, affected parties & institutional stakeholders
  static const Map<String, List<String>> counterpartActors = {
    // Middle East & Levant
    'israel': ['iran', 'palestine', 'lebanon', 'gaza', 'middle east', 'un', 'yemen', 'syria'],
    'iran': ['israel', 'us', 'usa', 'america', 'gulf states', 'saudi', 'west', 'un'],
    'palestine': ['israel', 'un', 'egypt', 'jordan', 'diplomacy', 'international court'],
    'gaza': ['israel', 'un', 'egypt', 'humanitarian', 'red cross'],
    'lebanon': ['israel', 'un', 'france', 'arab league'],
    'netanyahu': ['pezeshkian', 'khamenei', 'opposition', 'diplomats', 'un'],
    'pezeshkian': ['netanyahu', 'israel', 'us', 'west', 'diplomats', 'un'],
    'khamenei': ['netanyahu', 'israel', 'us', 'west'],

    // Eastern Europe & Eurasia
    'russia': ['ukraine', 'nato', 'eu', 'us', 'europe', 'un', 'baltics'],
    'ukraine': ['russia', 'nato', 'eu', 'un', 'global south'],
    'putin': ['zelensky', 'ukraine', 'nato', 'west', 'un'],
    'zelensky': ['putin', 'russia', 'global south', 'un'],

    // Asia-Pacific & Americas
    'china': ['taiwan', 'us', 'india', 'japan', 'philippines', 'west', 'asean'],
    'taiwan': ['china', 'us', 'pacific', 'japan'],
    'us': ['china', 'russia', 'iran', 'global south', 'eu', 'un'],
    'america': ['china', 'russia', 'iran', 'europe', 'global south'],
    'india': ['global south', 'un', 'diplomacy', 'asean', 'non-aligned'],
    'pakistan': ['diplomacy', 'un', 'central asia', 'saarc'],
    'nato': ['russia', 'neutrality', 'peace treaty'],
    'eu': ['brexit', 'national sovereignty', 'russia'],

    // Politics, Governance & Societal Stakeholders
    'government': ['opposition', 'citizens', 'civil society', 'protest', 'independent judiciary'],
    'president': ['opposition', 'counterpart', 'foreign leader', 'critic', 'diplomat'],
    'democrat': ['republican', 'conservative', 'independent', 'libertarian'],
    'republican': ['democrat', 'liberal', 'progressive', 'independent'],
    'big tech': ['open source', 'antitrust', 'regulators', 'consumers', 'privacy advocates'],
    'corporation': ['workers', 'labor union', 'consumers', 'environmentalists', 'regulators'],
  };

  /// Dimension 2: Conceptual contrasts & foundational antinomies
  static const Map<String, List<String>> conceptualContrasts = {
    'war': ['peace', 'ceasefire', 'diplomacy', 'de-escalation', 'negotiation', 'treaty', 'reconciliation', 'mediation'],
    'conflict': ['peace', 'ceasefire', 'diplomacy', 'mediation', 'conflict resolution'],
    'attack': ['defense', 'ceasefire', 'protection', 'de-escalation', 'humanitarian corridor'],
    'offensive': ['defense', 'de-escalation', 'ceasefire', 'containment'],
    'military': ['diplomacy', 'peacekeepers', 'humanitarian', 'civilian aid', 'international law'],
    'army': ['diplomacy', 'peacekeepers', 'humanitarian', 'civilian aid'],
    'acceleration': ['safety', 'precaution', 'ethics', 'sustainability', 'regulation'],
    'growth': ['conservation', 'sustainability', 'steady state', 'circular economy'],
    'centralization': ['decentralization', 'federation', 'local governance', 'user sovereignty'],
    'capitalism': ['socialism', 'cooperative', 'public sector', 'commons', 'regulation'],
    'free market': ['public goods', 'social welfare', 'antitrust', 'state planning'],
    'socialism': ['capitalism', 'free market', 'privatization', 'individual enterprise'],
    'surveillance': ['privacy', 'encryption', 'data sovereignty', 'confidentiality'],
    'automation': ['human workforce', 'craftsmanship', 'labor dignity', 'human touch'],
    'speculation': ['passive indexing', 'long term value', 'bogleheads', 'fiduciary'],
    'trading': ['long term investing', 'index funds', 'value investing', 'buy and hold'],
    'ai': ['safety', 'ethics', 'risks', 'regulation', 'humanities', 'human workforce'],
    'crypto': ['regulation', 'traditional finance', 'central banks', 'gold'],
    'bitcoin': ['central banks', 'gold', 'regulation', 'fiat currency'],
    'climate': ['economy', 'energy security', 'industry', 'nuclear energy'],
    'renewable energy': ['nuclear power', 'grid reliability', 'fossil fuels', 'energy transition'],
    'nuclear': ['renewables', 'solar', 'wind', 'radiation safety'],
    'vegan': ['carnivore', 'balanced nutrition', 'regenerative agriculture'],
    'carnivore': ['plant-based', 'vegan', 'mediterranean diet'],
    'pharmaceutical': ['holistic medicine', 'natural health', 'lifestyle medicine'],
    'vaccine': ['natural immunity', 'immunology', 'medical autonomy'],
    'medicine': ['preventative wellness', 'nutrition', 'holistic'],
  };

  /// Dimension 3: Opposing claims, framing & debate arguments
  static const Map<String, List<String>> opposingClaims = {
    'military necessity': ['civilian protection', 'international law', 'humanitarian crisis', 'proportionality', 'war crimes'],
    'security first': ['root cause political resolution', 'diplomatic normalization', 'human rights', 'reconciliation'],
    'ai inevitability': ['human oversight', 'algorithmic accountability', 'ethical alignment', 'safety bounds'],
    'market efficiency': ['market failure', 'wealth disparity', 'environmental externalities', 'consumer exploitation'],
    'tech solutionism': ['social roots', 'human centered design', 'nature balance', 'philosophical inquiry'],
    'active trading beats market': ['efficient market hypothesis', 'passive indexing', 'low fee investing'],
  };

  /// Combined map for backward compatibility and general keyword indexing
  static Map<String, List<String>> get oppositePairs {
    final merged = <String, List<String>>{};
    counterpartActors.forEach((k, v) => merged[k] = List.from(v));
    conceptualContrasts.forEach((k, v) {
      merged.putIfAbsent(k, () => []).addAll(v);
    });
    opposingClaims.forEach((k, v) {
      merged.putIfAbsent(k, () => []).addAll(v);
    });
    return merged;
  }

  /// Checks if a keyword or phrase matches text on exact word boundaries
  static bool _matchesTokenOrPhrase(String text, String term) {
    final termLower = term.toLowerCase().trim();
    if (termLower.isEmpty) return false;
    final textLower = text.toLowerCase();

    if (termLower.contains(' ')) {
      return textLower.contains(termLower);
    }
    final regex = RegExp(r'\b' + RegExp.escape(termLower) + r'\b');
    return regex.hasMatch(textLower);
  }

  /// Get contrasting search terms/topics for a video
  List<String> getOppositeKeywords(Video video) {
    final titleLower = video.title.toLowerCase();
    final descriptionLower = video.description.toLowerCase();
    final topicsLower = video.topics.map((t) => t.toLowerCase()).toList();
    final tagsLower = video.tags.map((t) => t.toLowerCase()).toList();
    final combined = '$titleLower $descriptionLower ${topicsLower.join(" ")} ${tagsLower.join(" ")}';

    final opposites = <String>{};

    oppositePairs.forEach((key, valList) {
      if (_matchesTokenOrPhrase(combined, key)) {
        opposites.addAll(valList);
      }
    });

    return opposites.toList();
  }

  /// Get all opposite keywords for a user's interest profile
  List<String> getOppositeKeywordsForProfile(UserInterestProfile profile) {
    final searchTerms = <String>{};

    // User's top topics
    for (final topic in profile.top5Topics) {
      final clean = topic.replaceFirst('topic:', '').toLowerCase();
      searchTerms.add(clean);
    }
    for (final slug in profile.followedTopicSlugs) {
      searchTerms.add(slug.toLowerCase());
    }

    // User's dominant category & top categories
    if (profile.dominantCategory != null) {
      searchTerms.add(profile.dominantCategory!.toLowerCase());
    }
    for (final cat in profile.top3Categories) {
      searchTerms.add(cat.toLowerCase());
    }

    // User's recent search queries
    for (final q in profile.recentSearchQueries.take(5)) {
      searchTerms.add(q.toLowerCase());
    }

    final opposites = <String>{};
    for (final term in searchTerms) {
      oppositePairs.forEach((key, valList) {
        if (_matchesTokenOrPhrase(term, key) || _matchesTokenOrPhrase(key, term)) {
          opposites.addAll(valList);
        }
      });
    }

    return opposites.toList();
  }

  /// Calculate how strongly a candidate video represents the OPPOSITE side to a user's interest profile.
  /// Returns a score > 0.0 if the video qualifies as an opposite-side video.
  /// Returns 0.0 if the video is on the user's SAME side (disqualified).
  double calculateUserContrastScore(Video candidateVideo, UserInterestProfile? profile) {
    // Disqualification 0: User's own video (creator is the user themselves)
    if (profile != null && profile.userId.isNotEmpty && profile.userId == candidateVideo.ownerId) {
      return 0.0;
    }
    if (Get.isRegistered<AuthService>()) {
      final auth = Get.find<AuthService>();
      if (auth.user?.uid != null && auth.user!.uid.isNotEmpty && auth.user!.uid == candidateVideo.ownerId) {
        return 0.0;
      }
      if (auth.userChannel != null && auth.userChannel!.channelId == candidateVideo.channelId) {
        return 0.0;
      }
    }

    // Disqualification 1: Subscribed channel is user's established comfort side
    if (profile != null && profile.subscribedChannelIds.contains(candidateVideo.channelId)) {
      return 0.0;
    }

    // Disqualification 2: Negative feedback on candidate
    if (profile != null &&
        (profile.notInterestedVideoIds.contains(candidateVideo.id) ||
            profile.blockedChannelIds.contains(candidateVideo.channelId) ||
            profile.recentlyDislikedVideoIds.contains(candidateVideo.id))) {
      return 0.0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CASE A: New user or no profile history (Cold Start)
    // ─────────────────────────────────────────────────────────────────────────
    if (profile == null || profile.isNewUser || profile.categoryAffinities.isEmpty) {
      var coldStartContrast = 0.0;

      // 1. Coin Battle debate pairs / stances
      if (candidateVideo.coinBattlePairVideoId != null && candidateVideo.coinBattlePairVideoId!.isNotEmpty) {
        coldStartContrast += 0.8;
      }
      if (candidateVideo.coinBattleStance != null && candidateVideo.coinBattleStance!.isNotEmpty) {
        coldStartContrast += 0.6;
      }

      // 2. Contrarian / opposite keywords present
      final candidateText =
          '${candidateVideo.title} ${candidateVideo.description} ${candidateVideo.topics.join(" ")} ${candidateVideo.tags.join(" ")}'
              .toLowerCase();
      var contrarianMatches = 0;
      for (final list in oppositePairs.values) {
        for (final kw in list) {
          if (_matchesTokenOrPhrase(candidateText, kw)) {
            contrarianMatches++;
            break;
          }
        }
      }
      if (contrarianMatches > 0) {
        coldStartContrast += (0.4 * contrarianMatches).clamp(0.0, 1.0);
      }

      // 3. High credibility / fact-checked boost
      if (candidateVideo.isFactChecked || candidateVideo.hasAiCredibility) {
        coldStartContrast += 0.2;
      }

      // Cold start requires at least one genuine counter-signal (pair, stance, or contrarian keyword)
      final hasContrarianSignal = (candidateVideo.coinBattlePairVideoId != null && candidateVideo.coinBattlePairVideoId!.isNotEmpty) ||
          (candidateVideo.coinBattleStance != null && candidateVideo.coinBattleStance!.isNotEmpty) ||
          contrarianMatches > 0;

      if (!hasContrarianSignal) {
        return 0.0; // DISQUALIFIED: regular videos without debate/contrarian content are NOT opposite
      }

      return coldStartContrast >= 0.4 ? coldStartContrast : 0.0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CASE B: User with established interest profile
    // ─────────────────────────────────────────────────────────────────────────
    var contrastScore = 0.0;
    final candidateText =
        '${candidateVideo.title} ${candidateVideo.description} ${candidateVideo.topics.join(" ")} ${candidateVideo.tags.join(" ")}'
            .toLowerCase();

    // 1. Direct Keyword Contrast Match with user's profile interests
    final profileOppositeKeywords = getOppositeKeywordsForProfile(profile);
    var keywordMatchCount = 0;
    for (final kw in profileOppositeKeywords) {
      if (_matchesTokenOrPhrase(candidateText, kw)) {
        keywordMatchCount++;
        contrastScore += 0.4;
      }
    }
    contrastScore = contrastScore.clamp(0.0, 1.2);

    // 2. Coin Battle / Opposite Stance Matching
    if (candidateVideo.coinBattlePairVideoId != null && candidateVideo.coinBattlePairVideoId!.isNotEmpty) {
      contrastScore += 0.6;
    }
    if (candidateVideo.coinBattleStance != null && candidateVideo.coinBattleStance!.isNotEmpty) {
      contrastScore += 0.4;
    }

    // 3. Category Polarity / Contrast & Unexplored Horizon Boost
    final cat = candidateVideo.category.trim();
    final catAffinity = profile.categoryAffinities[cat] ?? 0.0;

    if (cat.isNotEmpty) {
      final isTopCategory = profile.top3Categories.any((c) => c.toLowerCase() == cat.toLowerCase());

      if (profile.isUnexploredCategory(cat)) {
        // High boost for user's completely unexplored categories (The Other Side horizon)
        contrastScore += 0.6;
      } else if (isTopCategory) {
        // If it's in user's top category, it MUST have strong keyword/stance contrast to qualify!
        if (keywordMatchCount == 0 && (candidateVideo.coinBattlePairVideoId == null || candidateVideo.coinBattlePairVideoId!.isEmpty)) {
          // Pure same-side video in user's top category -> DISQUALIFY
          return 0.0;
        }
      } else if (catAffinity < 0.15) {
        // Video is from an alternative / under-explored category
        contrastScore += 0.4;
      }
    }

    // 4. Topic Affinity Inversion Check & Unexplored Topic Boost
    final topicAffinity = profile.getCombinedTopicAffinity(candidateVideo.topics.cast<String>());
    if (topicAffinity > 0.6 && keywordMatchCount == 0) {
      // Strongly aligned with user's standard topic with 0 opposing viewpoint keywords -> DISQUALIFY
      return 0.0;
    }

    // Boost if candidate contains topics that user has NOT yet explored
    var hasUnexploredTopic = false;
    for (final topic in candidateVideo.topics) {
      final slug = topic.toLowerCase().trim();
      if (!profile.exploredTopicSlugs.contains(slug) &&
          !profile.topicAffinities.containsKey('topic:$slug')) {
        hasUnexploredTopic = true;
        break;
      }
    }
    if (hasUnexploredTopic) {
      contrastScore += 0.4;
    }

    // 5. Unfamiliar / Diverse Channel Boost
    final channelWatches = profile.channelExposureCounts[candidateVideo.channelId] ?? 0;
    if (channelWatches == 0) {
      contrastScore += 0.2;
    }

    // 6. Credibility / Fact-Checked Bonus
    if (candidateVideo.isFactChecked || candidateVideo.hasAiCredibility) {
      contrastScore += 0.2;
    }

    // 7. High-Dimensional Vector Embedding Contrast (The 10/10 Modernization)
    if (candidateVideo.embedding != null && candidateVideo.embedding!.isNotEmpty) {
      final userVector = profile.computeUserTowerVector();
      if (userVector != null && userVector.isNotEmpty) {
        final vectorDistance = VectorMathUtil.cosineDistance(
          userVector,
          candidateVideo.embedding!,
        );
        if (vectorDistance >= 0.70) {
          contrastScore += (vectorDistance * 0.4).clamp(0.0, 0.6);
        }
      }
    }

    // Minimum contrast threshold to qualify as opposite-side video
    return contrastScore >= 0.3 ? contrastScore : 0.0;
  }

  /// Helper boolean to check if candidate video qualifies as opposite side for user
  bool isOppositeSideVideo(Video candidateVideo, UserInterestProfile? profile) {
    return calculateUserContrastScore(candidateVideo, profile) > 0.0;
  }

  /// Score how contrasting a candidate video is relative to the currently playing video.
  /// Returns a positive contrast score if candidate represents the opposite perspective.
  /// Returns 0.0 if candidate is on the same side or not a contrasting perspective.
  double calculateContrastScore(Video currentVideo, Video candidateVideo) {
    return evaluateVideoContrast(currentVideo, candidateVideo).contrastScore;
  }

  /// Multi-dimensional evaluation of perspective contrast between two videos
  ContrastEvaluation evaluateVideoContrast(Video currentVideo, Video candidateVideo) {
    if (currentVideo.id == candidateVideo.id) {
      return const ContrastEvaluation(
        contrastScore: 0.0,
        category: PerspectiveCategory.conceptualContrast,
        explanation: 'Same video',
      );
    }

    // Disqualification: Same creator is same side (unless explicitly an opposing coin-battle pair)
    final isSameChannel = currentVideo.channelId == candidateVideo.channelId;
    final isDirectPair = (currentVideo.coinBattlePairVideoId != null &&
            currentVideo.coinBattlePairVideoId == candidateVideo.id) ||
        (candidateVideo.coinBattlePairVideoId != null &&
            candidateVideo.coinBattlePairVideoId == currentVideo.id);

    if (isSameChannel && !isDirectPair) {
      return const ContrastEvaluation(
        contrastScore: 0.0,
        category: PerspectiveCategory.conceptualContrast,
        explanation: 'Same channel / creator',
      );
    }

    // 1. Direct Coin Battle Pair Match (Highest priority counter-video)
    if (isDirectPair) {
      return const ContrastEvaluation(
        contrastScore: 2.0,
        category: PerspectiveCategory.directCounterDebate,
        explanation: 'Direct Coin Battle Counter-Debate',
        isDirectDebatePair: true,
      );
    }

    final currentText =
        '${currentVideo.title} ${currentVideo.description} ${currentVideo.topics.join(" ")} ${currentVideo.tags.join(" ")}'
            .toLowerCase();
    final candidateText =
        '${candidateVideo.title} ${candidateVideo.description} ${candidateVideo.topics.join(" ")} ${candidateVideo.tags.join(" ")}'
            .toLowerCase();

    final matchedCounterparts = <String>[];
    final matchedConcepts = <String>[];
    final matchedClaims = <String>[];

    // Dimension 1: Counterpart Actors & Affected Stakeholders
    counterpartActors.forEach((entity, counterparts) {
      if (_matchesTokenOrPhrase(currentText, entity)) {
        for (final cp in counterparts) {
          if (_matchesTokenOrPhrase(candidateText, cp) && !matchedCounterparts.contains(cp)) {
            matchedCounterparts.add(cp);
          }
        }
      }
    });

    // Dimension 2: Conceptual Contrasts (e.g. War ↔ Peace, Attack ↔ Ceasefire)
    conceptualContrasts.forEach((concept, contrasts) {
      if (_matchesTokenOrPhrase(currentText, concept)) {
        for (final c in contrasts) {
          if (_matchesTokenOrPhrase(candidateText, c) && !matchedConcepts.contains(c)) {
            matchedConcepts.add(c);
          }
        }
      }
    });

    // Dimension 3: Opposing Claims & Stances
    opposingClaims.forEach((claim, counterClaims) {
      if (_matchesTokenOrPhrase(currentText, claim)) {
        for (final cc in counterClaims) {
          if (_matchesTokenOrPhrase(candidateText, cc) && !matchedClaims.contains(cc)) {
            matchedClaims.add(cc);
          }
        }
      }
    });

    // Check Opposing Stance
    final isOpposingStance = currentVideo.coinBattleStance != null &&
        candidateVideo.coinBattleStance != null &&
        currentVideo.coinBattleStance!.isNotEmpty &&
        candidateVideo.coinBattleStance!.isNotEmpty &&
        currentVideo.coinBattleStance != candidateVideo.coinBattleStance;

    var contrastScore = 0.0;
    if (isOpposingStance) {
      contrastScore += 1.0;
    } else if (candidateVideo.coinBattleStance != null &&
        candidateVideo.coinBattleStance!.isNotEmpty) {
      contrastScore += 0.4;
    }

    contrastScore += matchedCounterparts.length * 0.5;
    contrastScore += matchedConcepts.length * 0.5;
    contrastScore += matchedClaims.length * 0.4;

    // High-Dimensional Vector Embedding Semantic Contrast (The 10/10 Modernization)
    var semanticVectorDistance = 0.0;
    if (currentVideo.embedding != null &&
        candidateVideo.embedding != null &&
        currentVideo.embedding!.isNotEmpty &&
        candidateVideo.embedding!.isNotEmpty) {
      semanticVectorDistance = VectorMathUtil.cosineDistance(
        currentVideo.embedding!,
        candidateVideo.embedding!,
      );
      // Cosine distance >= 0.75 indicates distinct/opposing semantic angles in embedding space
      if (semanticVectorDistance >= 0.75) {
        contrastScore += (semanticVectorDistance * 0.6).clamp(0.0, 1.0);
      }
    }

    if (currentVideo.category == candidateVideo.category && !isSameChannel && contrastScore > 0) {
      contrastScore += 0.2;
    }
    if (candidateVideo.isFactChecked || candidateVideo.hasAiCredibility) {
      contrastScore += 0.2;
    }
    contrastScore = contrastScore.clamp(0.0, 2.0);

    // Determine Perspective Category & Explanation
    PerspectiveCategory category;
    String explanation;

    final isDiplomatic = matchedCounterparts.contains('un') ||
        matchedConcepts.contains('diplomacy') ||
        matchedConcepts.contains('ceasefire') ||
        matchedConcepts.contains('treaty') ||
        matchedConcepts.contains('mediation');

    if (isDiplomatic) {
      category = PerspectiveCategory.diplomaticInstitutional;
      explanation = 'Diplomatic & Ceasefire Perspective';
    } else if (matchedCounterparts.isNotEmpty) {
      category = PerspectiveCategory.counterpartActor;
      explanation = 'Counterpart Perspective: ${matchedCounterparts.take(2).join(", ")}';
    } else if (isOpposingStance || matchedClaims.isNotEmpty) {
      category = PerspectiveCategory.opposingClaim;
      explanation = isOpposingStance
          ? 'Opposing Stance: ${candidateVideo.coinBattleStance}'
          : 'Counter-Claim: ${matchedClaims.take(2).join(", ")}';
    } else if (matchedConcepts.isNotEmpty) {
      category = PerspectiveCategory.conceptualContrast;
      explanation = 'Conceptual Contrast: ${matchedConcepts.take(2).join(", ")}';
    } else if (semanticVectorDistance >= 0.75) {
      category = PerspectiveCategory.conceptualContrast;
      explanation = 'Semantic Counter-Perspective (Vector Embedding Contrast)';
    } else {
      category = PerspectiveCategory.conceptualContrast;
      explanation = 'Opposing Perspective';
    }

    final finalScore = contrastScore >= 0.4 ? contrastScore : 0.0;

    return ContrastEvaluation(
      contrastScore: finalScore,
      category: category,
      explanation: explanation,
      matchedCounterparts: matchedCounterparts,
      matchedConcepts: matchedConcepts,
      matchedClaims: matchedClaims,
      isOpposingStance: isOpposingStance,
    );
  }
}

/// Distinct perspective classifications for counter-videos
enum PerspectiveCategory {
  directCounterDebate,     // Explicit Coin Battle paired debate video
  counterpartActor,        // Counterpart leader/government or affected party (e.g. Iran, Palestine, Opposition)
  diplomaticInstitutional, // UN, international diplomacy, mediation, legal/treaty monitors
  conceptualContrast,      // Direct conceptual contrast (e.g. peace, ceasefire, safety, de-escalation)
  opposingClaim,           // Specific counter-claim (e.g. civilian protection, labor rights, privacy)
  alternativeParadigm,     // Diverse under-explored category or alternative domain paradigm
}

/// Detailed evaluation of perspective contrast between two videos
class ContrastEvaluation {
  final double contrastScore;
  final PerspectiveCategory category;
  final String explanation;
  final List<String> matchedCounterparts;
  final List<String> matchedConcepts;
  final List<String> matchedClaims;
  final bool isDirectDebatePair;
  final bool isOpposingStance;

  const ContrastEvaluation({
    required this.contrastScore,
    required this.category,
    required this.explanation,
    this.matchedCounterparts = const [],
    this.matchedConcepts = const [],
    this.matchedClaims = const [],
    this.isDirectDebatePair = false,
    this.isOpposingStance = false,
  });

  bool get qualifies => contrastScore >= 0.4;
}
