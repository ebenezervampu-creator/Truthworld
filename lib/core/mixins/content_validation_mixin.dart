import 'package:multi_lang_bad_words_filter/multi_lang_bad_words_filter.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:truthworld/data/models/channel.dart';

/// Result of a content validation check.
class ContentValidationResult {
  const ContentValidationResult({required this.isValid, required this.message});
  final bool isValid;
  final String message;
}

/// Shared content validation mixin for upload controllers.
///
/// Provides multi-layer profanity, spam, URL, emoji, and pattern checking
/// reusable across both video and community post upload controllers.
mixin ContentValidationMixin {
  // ── Filters ──────────────────────────────────────────────────────────────

  final ProfanityFilter profanityFilter = ProfanityFilter.filterAdditionally(
    _extraOffensiveWords,
  );
  BadWordFilter? _multiLangFilter;
  BadWordFilter get multiLangFilter =>
      _multiLangFilter ??= BadWordFilter(
        languages: ['en', 'fa', 'ar', 'tr', 'de', 'fr', 'es', 'ru'],
        includeSensitiveTopics: true,
        matchInsideWords: true,
      );

  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int maxTags = 5;

  /// Call during [onInit] to set up the filter instances.
  void initializeContentFilters() {
    _multiLangFilter = BadWordFilter(
      languages: ['en', 'fa', 'ar', 'tr', 'de', 'fr', 'es', 'ru'],
      includeSensitiveTopics: true,
      matchInsideWords: true,
    );
  }

  // ── Validation API ───────────────────────────────────────────────────────

  /// Validates video count limit (max 5 videos for Standard Channel),
  /// video duration constraint (must be between 2 mins and 10 mins per video),
  /// and total accumulated duration (max 10 mins / 600s total across all videos for Standard Channel).
  ContentValidationResult validateChannelVideoUpload(
    Channel channel, {
    required int currentVideoCount,
    required int durationSeconds,
    int currentTotalDurationSeconds = 0,
  }) {
    if (channel.channelType == ChannelType.standard) {
      if (currentVideoCount >= 5) {
        return const ContentValidationResult(
          isValid: false,
          message:
              'Standard channels can upload a maximum of 5 videos. Upgrade to a Custom Channel to upload unlimited videos!',
        );
      }

      if (durationSeconds < 120) {
        return const ContentValidationResult(
          isValid: false,
          message:
              'Standard channel video duration cannot be less than 2 minutes (120 seconds).',
        );
      }

      if (durationSeconds > 600) {
        return const ContentValidationResult(
          isValid: false,
          message:
              'Standard channel video duration cannot exceed 10 minutes (600 seconds).',
        );
      }

      if (currentTotalDurationSeconds + durationSeconds > 600) {
        return const ContentValidationResult(
          isValid: false,
          message:
              'Standard channel total cumulative video duration cannot exceed 10 minutes (600 seconds) across all videos.',
        );
      }
    }

    return const ContentValidationResult(isValid: true, message: 'Valid');
  }

  /// Comprehensive multi-layer content validation.
  Future<ContentValidationResult> validateContent(
    String text, {
    String fieldName = 'Content',
    bool checkPhoneNumbers = false,
    int? minLength,
    int? maxLength,
  }) async {
    if (text.trim().isEmpty) {
      return ContentValidationResult(
        isValid: false,
        message: '$fieldName cannot be empty',
      );
    }

    if (minLength != null && text.length < minLength) {
      return ContentValidationResult(
        isValid: false,
        message: '$fieldName must be at least $minLength characters',
      );
    }

    if (maxLength != null && text.length > maxLength) {
      return ContentValidationResult(
        isValid: false,
        message: '$fieldName cannot exceed $maxLength characters',
      );
    }

    final normalized = text.trim();

    // LAYER 1: profanity_filter (English focus)
    if (profanityFilter.hasProfanity(normalized)) {
      return ContentValidationResult(
        isValid: false,
        message:
            'Your $fieldName contains inappropriate language. Please use respectful words.',
      );
    }

    // LAYER 2: multi_lang_bad_words_filter
    final filteredText = multiLangFilter.filterText(normalized);
    if (filteredText != normalized) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains inappropriate or offensive content.',
      );
    }

    // LAYER 3: Custom offensive words (previously safe_text)
    // Now handled by profanityFilter.filterAdditionally in constructor

    // LAYER 4: Phone numbers
    if (checkPhoneNumbers) {
      final phonePattern = RegExp(
        r'(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}',
      );
      if (phonePattern.hasMatch(normalized)) {
        return ContentValidationResult(
          isValid: false,
          message:
              'Your $fieldName contains a phone number. Please remove personal information.',
        );
      }
    }

    // LAYER 5: Prohibited patterns
    if (_hasProhibitedPatterns(normalized)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains prohibited content.',
      );
    }

    // LAYER 6: Spam / repetition
    if (_hasExcessiveRepetition(normalized)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains excessive repetition.',
      );
    }
    if (_hasSuspiciousUrls(normalized)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains suspicious links.',
      );
    }

    // LAYER 7: Inappropriate emojis
    if (_hasInappropriateEmojis(text)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains inappropriate content.',
      );
    }

    return const ContentValidationResult(isValid: true, message: 'Valid');
  }

  /// Validate tags array.
  Future<ContentValidationResult> validateTags(List<String> tags) async {
    if (tags.isEmpty) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Please add at least one tag',
      );
    }
    if (tags.length > maxTags) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Maximum $maxTags tags allowed',
      );
    }
    for (final tag in tags) {
      if (tag.trim().isEmpty) continue;
      final result = await validateContent(tag, fieldName: 'Tag');
      if (!result.isValid) {
        return ContentValidationResult(
          isValid: false,
          message: 'Tag "$tag" is invalid: ${result.message}',
        );
      }
    }
    return const ContentValidationResult(isValid: true, message: 'Valid');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static const List<String> _extraOffensiveWords = [
    'xxx',
    'nsfw',
    'porn',
    'sex',
    'nude',
    'explicit',
    'nazi',
    'terrorist',
    'racist',
    'cocaine',
    'heroin',
    'meth',
    'kill',
    'murder',
    'suicide',
  ];

  bool _hasProhibitedPatterns(String text) {
    const patterns = [
      '(pornhub|xvideos|xhamster|onlyfans|chaturbate)',
      '(click here|free money|buy now|limited offer|act now)',
      r'(bit\.ly|tinyurl|goo\.gl)',
      r'\b(18\+|21\+|adult only|mature content)\b',
    ];
    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(text)) return true;
    }
    return false;
  }

  bool _hasExcessiveRepetition(String text) =>
      RegExp(r'(.)\1{3,}').hasMatch(text);

  bool _hasSuspiciousUrls(String text) {
    const patterns = [
      r'bit\.ly',
      'tinyurl',
      'free.*download',
      'click.*here',
      r'\d+\s*(dollars?|usd|€|£)',
    ];
    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(text)) return true;
    }
    return false;
  }

  bool _hasInappropriateEmojis(String text) {
    const inappropriate = [
      '🍆',
      '🍑',
      '💦',
      '🔞',
      '💋',
      '👅',
      '💊',
      '💉',
      '🚬',
      '🔫',
      '🔪',
      '💣',
    ];
    for (final emoji in inappropriate) {
      if (text.contains(emoji)) return true;
    }
    return false;
  }
}
