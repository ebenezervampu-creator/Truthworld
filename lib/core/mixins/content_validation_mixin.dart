import 'package:flutter/services.dart';
import 'package:multi_lang_bad_words_filter/multi_lang_bad_words_filter.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:truthworld/data/models/channel.dart';

/// Result of a content validation check.
class ContentValidationResult {
  const ContentValidationResult({required this.isValid, required this.message});
  final bool isValid;
  final String message;
}

/// Static helper class for running multi-layer profanity and offensive content validation anywhere.
class ContentValidator {
  static final ProfanityFilter _profanityFilter =
      ProfanityFilter.filterAdditionally(_extraOffensiveWords);

  static final BadWordFilter _multiLangFilter = BadWordFilter(
    languages: ['en', 'fa', 'ar', 'tr', 'de', 'fr', 'es', 'ru'],
    includeSensitiveTopics: true,
  );

  static const int defaultMaxTitleLength = 100;
  static const int defaultMaxDescriptionLength = 5000;
  static const int defaultMaxTags = 5;

  static const List<String> _extraOffensiveWords = [
    'xxx',
    'nsfw',
    'porn',
    'porno',
    'pornography',
    'sex',
    'nude',
    'nudity',
    'explicit',
    'hentai',
    'milf',
    'erotic',
    'orgasm',
    'boobs',
    'penis',
    'vagina',
    'dildo',
    'masturbate',
    'masturbation',
    'nazi',
    'hitler',
    'terrorist',
    'terrorism',
    'racist',
    'racism',
    'jihadist',
    'white supremacist',
    'pedophile',
    'pedo',
    'rapist',
    'rape',
    'cocaine',
    'heroin',
    'meth',
    'methamphetamine',
    'fentanyl',
    'kill',
    'murder',
    'suicide',
    'slaughter',
    'genocide',
    'assassinate',
    'behead',
    'torture',
    'fuck',
    'fucking',
    'motherfucker',
    'bitch',
    'bitches',
    'asshole',
    'bastard',
    'cunt',
    'dick',
    'pussy',
    'slut',
    'whore',
    'cock',
    'blowjob',
    'handjob',
    'twat',
    'wanker',
    'chutiya',
    'madarchod',
    'behenchod',
    'bhosdike',
    'gaand',
    'harami',
    'kutta',
    'randi',
    'saala',
    'kamina',
    'lauda',
    'chodu',
    'chut',
    'mc',
    'bc',
  ];

  static const List<String> _inappropriateEmojis = [
    '🍆',
    '🍑',
    '💦',
    '🔞',
    '🖕',
    '💋',
    '👅',
    '💊',
    '💉',
    '🚬',
    '🔫',
    '🔪',
    '💣',
  ];

  static const List<String> _prohibitedDomainPatterns = [
    '(pornhub|xvideos|xhamster|onlyfans|chaturbate|redtube|youporn|brazzers|xnxx)',
    r'(click\s+here|free\s+money|buy\s+now|limited\s+offer|act\s+now|crypto\s+giveaway)',
    r'(bit\.ly|tinyurl\.com|goo\.gl|t\.co|is\.gd|buff\.ly|ow\.ly|cutt\.ly)',
    r'\b(18\+|21\+|adult\s+only|mature\s+content)\b',
  ];

  /// Normalize leetspeak, homoglyphs, zero-width characters, and repeated character runs.
  static String normalizeObfuscation(String text) {
    if (text.isEmpty) return text;

    // 1. Remove zero-width spaces and invisible formatting characters
    var s = text.replaceAll(
      RegExp(r'[\u200B-\u200D\uFEFF\u00AD\u2060\u180E]'),
      '',
    );

    // 2. Map Cyrillic / Greek homoglyphs to Latin equivalents
    const homoglyphs = {
      'а': 'a', 'А': 'A',
      'с': 'c', 'С': 'C',
      'е': 'e', 'Е': 'E',
      'о': 'o', 'О': 'O',
      'р': 'p', 'Р': 'P',
      'х': 'x', 'Х': 'X',
      'у': 'y', 'У': 'Y',
      'і': 'i', 'І': 'I',
      'ѕ': 's', 'Ѕ': 'S',
      'α': 'a', 'ο': 'o', 'ε': 'e', 'ι': 'i', 'υ': 'u',
    };

    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final char = s[i];
      buffer.write(homoglyphs[char] ?? char);
    }
    s = buffer.toString();

    // 3. Leetspeak symbol substitutions
    s = s
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('!', 'i')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])0(?=[a-zA-Z0-9])'), 'o')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])1(?=[a-zA-Z0-9])'), 'i')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])3(?=[a-zA-Z0-9])'), 'e')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])4(?=[a-zA-Z0-9])'), 'a')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])5(?=[a-zA-Z0-9])'), 's')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])7(?=[a-zA-Z0-9])'), 't')
        .replaceAll(RegExp('(?<=[a-zA-Z0-9])8(?=[a-zA-Z0-9])'), 'b');

    // 4. Remove internal punctuation separating single letters (e.g. f.u.c.k, f-u-c-k, s_h_i_t, f*c*k)
    final punctSeparated = s.replaceAllMapped(
      RegExp(r'(?<=\b[a-zA-Z])[\.\-_*\s]+(?=[a-zA-Z]\b)'),
      (match) => '',
    );
    if (punctSeparated != s) {
      s = punctSeparated;
    }

    return s;
  }

  /// Collapses repeated characters (e.g. "fuuuuck" -> "fuck", "shiiiit" -> "shit")
  static String collapseRepeatedChars(String text) {
    return text.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (match) => match.group(1)!,
    );
  }

  /// Non-English script and foreign accented character patterns.
  ///
  /// Matches any characters from foreign scripts (Arabic, Cyrillic, Devanagari/Indic,
  /// Chinese, Japanese, Korean, Greek, Hebrew, Thai, etc.) and Latin-1/Latin Extended
  /// accented letters (e.g. é, è, ê, ñ, ü, ö, ä, ß, ç, ø, å, etc.) and foreign punctuation.
  static final RegExp _nonEnglishPattern = RegExp(
    r'[\u00C0-\u024F\u0370-\u03FF\u0400-\u052F\u0590-\u05FF\u0600-\u08FF\u0900-\u0DFF\u0E00-\u0E7F\u1100-\u11FF\u2E80-\u2FD5\u3040-\u30FF\u3100-\u312F\u31A0-\u31BF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7AF\uFB50-\uFDFF\uFE70-\uFEFF¿¡]',
    unicode: true,
  );

  /// Checks whether [text] contains strictly English language characters.
  ///
  /// Returns `false` if the text contains non-English alphabets, foreign scripts,
  /// or non-English accented characters.
  static bool isEnglishOnly(String text) {
    if (text.trim().isEmpty) return true;
    return !_nonEnglishPattern.hasMatch(text);
  }

  /// Cleans and sanitizes all profanity from [text], returning the filtered version.
  ///
  /// Every profane, offensive, or inappropriate word is replaced with asterisks (`****`).
  static String cleanProfanity(String text) {
    if (text.isEmpty) return text;
    var cleaned = _multiLangFilter.filterText(text);
    cleaned = _profanityFilter.censor(cleaned);
    final allBadWords = {
      ..._profanityFilter.wordsToFilterOutList,
      ..._extraOffensiveWords,
    };
    for (final word in allBadWords) {
      if (word.trim().isEmpty) continue;
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      cleaned = cleaned.replaceAllMapped(pattern, (m) => '*' * m.group(0)!.length);
    }
    return cleaned;
  }

  /// Checks whether [text] contains any profane or offensive language across
  /// raw, normalized (anti-leetspeak/homoglyph), and collapsed representations.
  static bool hasProfanity(String text) {
    if (text.trim().isEmpty) return false;
    final raw = text.trim();
    final normalized = normalizeObfuscation(raw);
    final collapsed = collapseRepeatedChars(normalized);

    if (_profanityFilter.hasProfanity(raw) ||
        _profanityFilter.hasProfanity(normalized) ||
        _profanityFilter.hasProfanity(collapsed)) {
      return true;
    }

    if (_multiLangFilter.filterText(raw) != raw ||
        _multiLangFilter.filterText(normalized) != normalized ||
        _multiLangFilter.filterText(collapsed) != collapsed) {
      return true;
    }

    for (final word in _extraOffensiveWords) {
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(raw) || pattern.hasMatch(normalized) || pattern.hasMatch(collapsed)) {
        return true;
      }
    }

    return false;
  }

  static TextInputFormatter get englishOnlyFormatter => TruthworldTextInputFormatters.englishOnly;
  static TextInputFormatter get profanitySanitizingFormatter => TruthworldTextInputFormatters.profanityFilter;

  /// Synchronous multi-layer content validation check.
  static ContentValidationResult validate(
    String text, {
    String fieldName = 'Content',
    bool checkPhoneNumbers = false,
    bool checkEnglishOnly = true,
    int? minLength,
    int? maxLength,
  }) {
    if (text.trim().isEmpty) {
      return ContentValidationResult(
        isValid: false,
        message: '$fieldName cannot be empty',
      );
    }

    if (minLength != null && text.trim().length < minLength) {
      return ContentValidationResult(
        isValid: false,
        message: '$fieldName must be at least $minLength characters',
      );
    }

    if (maxLength != null && text.trim().length > maxLength) {
      return ContentValidationResult(
        isValid: false,
        message: '$fieldName cannot exceed $maxLength characters',
      );
    }

    final raw = text.trim();

    // LAYER 0: English Language Only Check (skippable for user names/international identity)
    if (checkEnglishOnly && !isEnglishOnly(raw)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Only English language is allowed in $fieldName.',
      );
    }

    final normalized = normalizeObfuscation(raw);
    final collapsed = collapseRepeatedChars(normalized);

    // LAYER 1: Core Profanity Filter (Raw, Normalized & Collapsed)
    if (_profanityFilter.hasProfanity(raw) ||
        _profanityFilter.hasProfanity(normalized) ||
        _profanityFilter.hasProfanity(collapsed)) {
      return ContentValidationResult(
        isValid: false,
        message:
            'Your $fieldName contains inappropriate language. Please use respectful words.',
      );
    }

    // LAYER 2: Multi-Language Bad Words Filter
    final multiFilteredRaw = _multiLangFilter.filterText(raw);
    final multiFilteredNorm = _multiLangFilter.filterText(normalized);
    final multiFilteredCol = _multiLangFilter.filterText(collapsed);

    if (multiFilteredRaw != raw ||
        multiFilteredNorm != normalized ||
        multiFilteredCol != collapsed) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains inappropriate or offensive content.',
      );
    }

    // LAYER 3: Inappropriate Emojis
    for (final emoji in _inappropriateEmojis) {
      if (text.contains(emoji)) {
        return ContentValidationResult(
          isValid: false,
          message: 'Your $fieldName contains inappropriate emojis or symbols.',
        );
      }
    }

    // LAYER 4: Phone Numbers (Optional)
    if (checkPhoneNumbers) {
      final phonePattern = RegExp(
        r'(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,4}',
      );
      if (phonePattern.hasMatch(raw)) {
        return ContentValidationResult(
          isValid: false,
          message:
              'Your $fieldName contains a phone number. Please remove personal contact details.',
        );
      }
    }

    // LAYER 5: Prohibited Patterns & Scam Phrases
    for (final pattern in _prohibitedDomainPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(raw) ||
          RegExp(pattern, caseSensitive: false).hasMatch(normalized)) {
        return ContentValidationResult(
          isValid: false,
          message: 'Your $fieldName contains prohibited links or content.',
        );
      }
    }

    // LAYER 6: Spam / Excessive Repetition
    if (RegExp(r'(.)\1{4,}').hasMatch(raw)) {
      return ContentValidationResult(
        isValid: false,
        message: 'Your $fieldName contains excessive repetition.',
      );
    }

    return const ContentValidationResult(isValid: true, message: 'Valid');
  }

  /// Validate tags array.
  static ContentValidationResult validateTags(
    List<String> tags, {
    int maxTags = defaultMaxTags,
  }) {
    final cleanTags = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (cleanTags.isEmpty) {
      return const ContentValidationResult(
        isValid: false,
        message: 'Please add at least one tag',
      );
    }
    if (cleanTags.length > maxTags) {
      return ContentValidationResult(
        isValid: false,
        message: 'Maximum $maxTags tags allowed',
      );
    }
    for (final tag in cleanTags) {
      final result = validate(tag, fieldName: 'Tag');
      if (!result.isValid) {
        return ContentValidationResult(
          isValid: false,
          message: 'Tag "$tag" is invalid: ${result.message}',
        );
      }
    }
    return const ContentValidationResult(isValid: true, message: 'Valid');
  }

  /// Create a validator suitable for [TextFormField.validator]
  static String? Function(String?) formValidator(
    String fieldName, {
    bool required = true,
    int? minLength,
    int? maxLength,
    bool checkPhoneNumbers = false,
    bool checkEnglishOnly = true,
  }) {
    return (value) {
      final text = value ?? '';
      if (!required && text.trim().isEmpty) return null;
      final result = validate(
        text,
        fieldName: fieldName,
        checkPhoneNumbers: checkPhoneNumbers,
        checkEnglishOnly: checkEnglishOnly,
        minLength: minLength,
        maxLength: maxLength,
      );
      return result.isValid ? null : result.message;
    };
  }

  /// Formats seconds into a human-readable duration string (e.g. "15m 00s", "5 min").
  static String formatDurationMinutesSeconds(int seconds) {
    if (seconds <= 0) return '0 min';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '$mins min';
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  /// Validates video upload constraints for a channel:
  /// - Standard Channels: Max 20 minutes (1,200 seconds) total daily video upload duration limit.
  ///   If a channel uploaded 15 minutes today, they have 5 minutes remaining for that day.
  ///   Single video duration cannot exceed 20 minutes (1,200 seconds) or the remaining daily quota.
  /// - Custom Channels: Unlimited daily uploads (single video supported up to 24 hours).
  static ContentValidationResult validateChannelVideoUpload(
    Channel channel, {
    required int durationSeconds,
    int dailyUploadedDurationSeconds = 0,
    int? currentTotalDurationSeconds,
    int? currentVideoCount,
  }) {
    final effectiveDailyUploaded = dailyUploadedDurationSeconds > 0
        ? dailyUploadedDurationSeconds
        : (currentTotalDurationSeconds ?? 0);

    if (channel.channelType == ChannelType.standard) {
      const maxDailySeconds = 1200; // 20 minutes

      if (durationSeconds > maxDailySeconds) {
        return const ContentValidationResult(
          isValid: false,
          message:
              'Standard channel video duration cannot exceed 20 minutes (1200 seconds). Upgrade to a Custom Channel to upload longer videos!',
        );
      }

      if (effectiveDailyUploaded >= maxDailySeconds) {
        return const ContentValidationResult(
          isValid: false,
          message:
              'Daily upload limit reached: Standard channels can upload up to 20 minutes of video per day. You have reached your 20-minute daily limit for today. You can upload again tomorrow, or upgrade to a Custom Channel for unlimited uploads!',
        );
      }

      if (effectiveDailyUploaded + durationSeconds > maxDailySeconds) {
        final remainingSeconds =
            (maxDailySeconds - effectiveDailyUploaded).clamp(0, maxDailySeconds);
        final uploadedFormatted =
            formatDurationMinutesSeconds(effectiveDailyUploaded);
        final remainingFormatted =
            formatDurationMinutesSeconds(remainingSeconds);
        final videoFormatted = formatDurationMinutesSeconds(durationSeconds);

        return ContentValidationResult(
          isValid: false,
          message:
              'Daily limit exceeded: Standard channels can upload up to 20 minutes per day. You have already uploaded $uploadedFormatted today ($remainingFormatted remaining), but this video is $videoFormatted. Upgrade to a Custom Channel for unlimited uploads!',
        );
      }
    }

    return const ContentValidationResult(isValid: true, message: 'Valid');
  }
}

/// Shared content validation mixin for upload controllers and forms.
///
/// Provides multi-layer profanity, spam, URL, emoji, and pattern checking.
mixin ContentValidationMixin {
  // ── Filters ──────────────────────────────────────────────────────────────

  ProfanityFilter get profanityFilter => ContentValidator._profanityFilter;
  BadWordFilter get multiLangFilter => ContentValidator._multiLangFilter;

  static const int maxTitleLength = ContentValidator.defaultMaxTitleLength;
  static const int maxDescriptionLength = ContentValidator.defaultMaxDescriptionLength;
  static const int maxTags = ContentValidator.defaultMaxTags;

  /// Call during [onInit] if needed (filters are lazily initialized).
  void initializeContentFilters() {
    // Initialized statically in ContentValidator
  }

  /// Formats seconds into a human-readable duration string (e.g. "15m 00s", "5 min").
  static String formatDurationMinutesSeconds(int seconds) =>
      ContentValidator.formatDurationMinutesSeconds(seconds);

  /// Validates video upload constraints for a channel:
  /// - Standard Channels: Max 20 minutes (1,200 seconds) total daily video upload duration limit.
  /// - Custom Channels: Unlimited daily uploads (single video supported up to 24 hours).
  ContentValidationResult validateChannelVideoUpload(
    Channel channel, {
    required int durationSeconds,
    int dailyUploadedDurationSeconds = 0,
    int? currentTotalDurationSeconds,
    int? currentVideoCount,
  }) {
    return ContentValidator.validateChannelVideoUpload(
      channel,
      durationSeconds: durationSeconds,
      dailyUploadedDurationSeconds: dailyUploadedDurationSeconds,
      currentTotalDurationSeconds: currentTotalDurationSeconds,
      currentVideoCount: currentVideoCount,
    );
  }

  /// Comprehensive multi-layer content validation (async).
  Future<ContentValidationResult> validateContent(
    String text, {
    String fieldName = 'Content',
    bool checkPhoneNumbers = false,
    bool checkEnglishOnly = true,
    int? minLength,
    int? maxLength,
  }) async {
    return ContentValidator.validate(
      text,
      fieldName: fieldName,
      checkPhoneNumbers: checkPhoneNumbers,
      checkEnglishOnly: checkEnglishOnly,
      minLength: minLength,
      maxLength: maxLength,
    );
  }

  /// Comprehensive multi-layer content validation (sync).
  ContentValidationResult validateContentSync(
    String text, {
    String fieldName = 'Content',
    bool checkPhoneNumbers = false,
    bool checkEnglishOnly = true,
    int? minLength,
    int? maxLength,
  }) {
    return ContentValidator.validate(
      text,
      fieldName: fieldName,
      checkPhoneNumbers: checkPhoneNumbers,
      checkEnglishOnly: checkEnglishOnly,
      minLength: minLength,
      maxLength: maxLength,
    );
  }

  /// Validate tags array.
  Future<ContentValidationResult> validateTags(
    List<String> tags, {
    int maxTags = maxTags,
  }) async {
    return ContentValidator.validateTags(tags, maxTags: maxTags);
  }

  /// Checks whether [text] contains strictly English characters.
  bool isEnglishOnly(String text) => ContentValidator.isEnglishOnly(text);

  /// Cleans and sanitizes all profanity from [text], returning the filtered version.
  String cleanProfanity(String text) => ContentValidator.cleanProfanity(text);

  /// Checks whether [text] contains any profane or offensive language.
  bool hasProfanity(String text) => ContentValidator.hasProfanity(text);

  /// Convenient access to the English-only text input formatter.
  TextInputFormatter get englishOnlyFormatter =>
      ContentValidator.englishOnlyFormatter;

  /// Convenient access to the profanity-sanitizing text input formatter.
  TextInputFormatter get profanitySanitizingFormatter =>
      ContentValidator.profanitySanitizingFormatter;
}

/// A [TextInputFormatter] that restricts input strictly to English characters.
///
/// Permits standard English Latin letters (A-Z, a-z), digits (0-9), standard whitespace,
/// and standard English punctuation / keyboard symbols. Non-English scripts and accents
/// are immediately blocked upon typing or pasting.
class EnglishOnlyTextInputFormatter extends FilteringTextInputFormatter {
  EnglishOnlyTextInputFormatter({bool allowEmojis = true})
      : super(
          RegExp(
            allowEmojis
                ? r'''[a-zA-Z0-9\s!@#\$%^&*()_+\-=\[\]{}|;':",.<>/?`~’‘“”–—…\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]'''
                : r'''[a-zA-Z0-9\s!@#\$%^&*()_+\-=\[\]{}|;':",.<>/?`~’‘“”–—…]''',
            unicode: true,
          ),
          allow: true,
        );
}

/// A [TextInputFormatter] that sanitizes and filters profanity as words are entered or pasted.
class ProfanitySanitizingTextInputFormatter extends TextInputFormatter {
  const ProfanitySanitizingTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      // Allow deletion without re-filtering
      return newValue;
    }

    final isWordBoundary = newValue.text.endsWith(' ') ||
        newValue.text.endsWith('\n') ||
        newValue.text.endsWith('.') ||
        newValue.text.endsWith(',') ||
        newValue.text.endsWith('!') ||
        newValue.text.endsWith('?') ||
        newValue.text.endsWith(';') ||
        newValue.text.endsWith(':');
    final isPasted = (newValue.text.length - oldValue.text.length) > 1;

    if (isWordBoundary || isPasted) {
      final sanitized = ContentValidator.cleanProfanity(newValue.text);
      if (sanitized != newValue.text) {
        final targetOffset = newValue.selection.end >= 0
            ? newValue.selection.end.clamp(0, sanitized.length)
            : sanitized.length;
        return TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(offset: targetOffset),
        );
      }
    }

    return newValue;
  }
}

/// Standardized text input formatters for all Truthworld text fields.
class TruthworldTextInputFormatters {
  TruthworldTextInputFormatters._();

  /// Formatter that enforces English language characters only.
  static final TextInputFormatter englishOnly = EnglishOnlyTextInputFormatter();

  /// Formatter that sanitizes profanity on word boundaries or paste.
  static const TextInputFormatter profanityFilter =
      ProfanitySanitizingTextInputFormatter();

  /// Standard formatters combination: English only and profanity sanitization.
  static List<TextInputFormatter> get standard => [
        englishOnly,
        profanityFilter,
      ];
}
