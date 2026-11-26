import 'package:truthworld/core/constants/ai_languages.dart';

/// Represents an available source or target language in TruthWorld Dubbing.
class DubbingLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String region;
  final bool isIndic;
  final bool isDefaultTarget;

  const DubbingLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.region,
    this.isIndic = false,
    this.isDefaultTarget = false,
  });

  /// Whether this language is active as a dubbing target in this release (single source of truth: ai_languages.dart).
  bool get isAvailableAsTarget => kDubbingLaunchTargetCodes.contains(code);

  /// Whether this language is active as a dubbing source in this release (single source of truth: ai_languages.dart).
  bool get isAvailableAsSource => kDubbingLaunchSourceCodes.contains(code);

  /// Backward-compatible alias for target availability.
  bool get isAvailable => isAvailableAsTarget;

  /// Whether this target language is not planned for near-term dubbing.
  bool get isNotPlannedAsTarget => kDubbingNotPlannedTargetCodes.contains(code);

  /// Whether this source language is not planned for near-term dubbing.
  bool get isNotPlannedAsSource => kDubbingNotPlannedSourceCodes.contains(code);

  /// ISO 3166-1 alpha-2 country code for displaying the language's representative flag.
  String get countryCode => _languageToCountryCode[code.toLowerCase()] ?? 'US';

  static const Map<String, String> _languageToCountryCode = {
    'en': 'US',
    'te': 'IN',
    'hi': 'IN',
    'mr': 'IN',
    'ta': 'IN',
    'ml': 'IN',
    'kn': 'IN',
    'bn': 'IN',
    'gu': 'IN',
    'pa': 'IN',
    'or': 'IN',
    'as': 'IN',
    'ur': 'PK',
    'sa': 'IN',
    'ne': 'NP',
    'ks': 'IN',
    'sd': 'PK',
    'es': 'ES',
    'fr': 'FR',
    'de': 'DE',
    'ja': 'JP',
    'zh': 'CN',
    'pt': 'PT',
    'it': 'IT',
    'ar': 'SA',
    'ru': 'RU',
    'ko': 'KR',
    'tr': 'TR',
    'nl': 'NL',
    'sv': 'SE',
    'id': 'ID',
    'th': 'TH',
    'vi': 'VN',
    'pl': 'PL',
    'uk': 'UA',
    'cs': 'CZ',
    'el': 'GR',
    'hu': 'HU',
    'da': 'DK',
    'fi': 'FI',
    'no': 'NO',
    'sk': 'SK',
    'bg': 'BG',
    'ca': 'ES',
    'hr': 'HR',
    'lt': 'LT',
    'sl': 'SI',
    'ro': 'RO',
    'et': 'EE',
    'lv': 'LV',
    'sr': 'RS',
    'sq': 'AL',
    'eu': 'ES',
    'be': 'BY',
    'bs': 'BA',
    'gl': 'ES',
    'ka': 'GE',
    'is': 'IS',
    'ga': 'IE',
    'mk': 'MK',
    'mt': 'MT',
    'cy': 'GB',
    'yi': 'IL',
    'tl': 'PH',
    'ms': 'MY',
    'kk': 'KZ',
    'uz': 'UZ',
    'my': 'MM',
    'km': 'KH',
    'lo': 'LA',
    'hy': 'AM',
    'mn': 'MN',
    'si': 'LK',
    'he': 'IL',
    'fa': 'IR',
    'ku': 'IQ',
    'ps': 'AF',
    'af': 'ZA',
    'az': 'AZ',
    'sw': 'KE',
    'yue': 'HK',
    'nn': 'NO',
    'xh': 'ZA',
    'zu': 'ZA',
  };

  /// Clickable/active output languages for production dubbing (single source of truth: ai_languages.dart).
  static Set<String> get activeOutputCodes => kDubbingLaunchTargetCodes;

  /// Clickable/active source language (English) (single source of truth: ai_languages.dart).
  static String get activeSourceCode => kDubbingLaunchSourceCodes.first;

  /// Supported source languages for TruthWorld Dubbing Studio.
  static List<DubbingLanguage> get availableSourceLanguages =>
      source32Languages.where((l) => l.isAvailableAsSource).toList(growable: false);

  /// Supported output/target languages for TruthWorld Dubbing Studio.
  static List<DubbingLanguage> get availableTargetLanguages =>
      supportedLanguages.where((l) => l.isAvailableAsTarget).toList(growable: false);

  /// 32 Source Languages supported by AssemblyAI Universal 3.7 Pro.
  /// English ('en') is available now; the remaining 31 languages follow as 'Available soon'.
  static const List<DubbingLanguage> source32Languages = [
    // 1. English - AVAILABLE NOW
    DubbingLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English (US/UK/IN)',
      region: 'Global',
      isDefaultTarget: true,
    ),
    // 2-12: Worldwide Popular Languages (Available soon)
    DubbingLanguage(code: 'es', name: 'Spanish', nativeName: 'Español', region: 'Spain / Latin America'),
    DubbingLanguage(code: 'fr', name: 'French', nativeName: 'Français', region: 'France / Canada'),
    DubbingLanguage(code: 'de', name: 'German', nativeName: 'Deutsch', region: 'Germany / Austria'),
    DubbingLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語', region: 'Japan'),
    DubbingLanguage(code: 'zh', name: 'Chinese (Mandarin)', nativeName: '中文 (普通话)', region: 'China / East Asia'),
    DubbingLanguage(code: 'yue', name: 'Cantonese', nativeName: '粵語', region: 'Hong Kong / Southern China'),
    DubbingLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português', region: 'Brazil / Portugal'),
    DubbingLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano', region: 'Italy'),
    DubbingLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', region: 'Middle East'),
    DubbingLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский', region: 'Eastern Europe / Central Asia'),
    DubbingLanguage(code: 'ko', name: 'Korean', nativeName: '한국어', region: 'South Korea'),
    // 13-15: Indic & South Asian Languages (Available soon)
    DubbingLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', region: 'India (National)', isIndic: true),
    DubbingLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी', region: 'India (Maharashtra)', isIndic: true),
    DubbingLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', region: 'India / Pakistan', isIndic: true),
    // 16-26: European Languages (Available soon)
    DubbingLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', region: 'Netherlands / Belgium'),
    DubbingLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', region: 'Turkey'),
    DubbingLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska', region: 'Sweden'),
    DubbingLanguage(code: 'no', name: 'Norwegian', nativeName: 'Norsk', region: 'Norway'),
    DubbingLanguage(code: 'nn', name: 'Norwegian Nynorsk', nativeName: 'Nynorsk', region: 'Norway'),
    DubbingLanguage(code: 'da', name: 'Danish', nativeName: 'Dansk', region: 'Denmark'),
    DubbingLanguage(code: 'fi', name: 'Finnish', nativeName: 'Suomi', region: 'Finland'),
    DubbingLanguage(code: 'et', name: 'Estonian', nativeName: 'Eesti', region: 'Estonia'),
    DubbingLanguage(code: 'ro', name: 'Romanian', nativeName: 'Română', region: 'Romania'),
    DubbingLanguage(code: 'ca', name: 'Catalan', nativeName: 'Català', region: 'Spain (Catalonia)'),
    DubbingLanguage(code: 'gl', name: 'Galician', nativeName: 'Galego', region: 'Spain (Galicia)'),
    // 27-29: Asian & Middle East Languages (Available soon)
    DubbingLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', region: 'Vietnam'),
    DubbingLanguage(code: 'he', name: 'Hebrew', nativeName: 'עברית', region: 'Israel'),
    DubbingLanguage(code: 'fa', name: 'Persian (Farsi)', nativeName: 'فارسی', region: 'Iran'),
    // 30-32: African Languages (Available soon)
    DubbingLanguage(code: 'af', name: 'Afrikaans', nativeName: 'Afrikaans', region: 'South Africa'),
    DubbingLanguage(code: 'xh', name: 'Xhosa', nativeName: 'isiXhosa', region: 'South Africa'),
    DubbingLanguage(code: 'zu', name: 'Zulu', nativeName: 'isiZulu', region: 'South Africa'),
  ];

  /// Comprehensive catalog of 80 supported Output / Target languages in TruthWorld Dubbing.
  /// Exactly 5 (Telugu, Hindi, Marathi, Tamil, Malayalam) are available now.
  /// Worldwide popular languages follow immediately as 'Available soon'.
  static const List<DubbingLanguage> supportedLanguages = [
    // ── The 5 Available Now Output Languages ──────────────────────────────────
    DubbingLanguage(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      region: 'India (AP / Telangana)',
      isIndic: true,
      isDefaultTarget: true,
    ),
    DubbingLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      region: 'India (National)',
      isIndic: true,
      isDefaultTarget: true,
    ),
    DubbingLanguage(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      region: 'India (Maharashtra)',
      isIndic: true,
      isDefaultTarget: true,
    ),
    DubbingLanguage(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      region: 'India / Sri Lanka',
      isIndic: true,
      isDefaultTarget: true,
    ),
    DubbingLanguage(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      region: 'India (Kerala)',
      isIndic: true,
      isDefaultTarget: true,
    ),

    // ── Worldwide Popular Languages (Available soon) ──────────────────────────
    DubbingLanguage(code: 'en', name: 'English', nativeName: 'English (US/UK/IN)', region: 'Global'),
    DubbingLanguage(code: 'es', name: 'Spanish', nativeName: 'Español', region: 'Spain / Latin America'),
    DubbingLanguage(code: 'fr', name: 'French', nativeName: 'Français', region: 'France / Canada'),
    DubbingLanguage(code: 'de', name: 'German', nativeName: 'Deutsch', region: 'Germany / Austria'),
    DubbingLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語', region: 'Japan'),
    DubbingLanguage(code: 'zh', name: 'Chinese (Mandarin)', nativeName: '中文 (普通话)', region: 'China / East Asia'),
    DubbingLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português', region: 'Brazil / Portugal'),
    DubbingLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano', region: 'Italy'),
    DubbingLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', region: 'Middle East'),
    DubbingLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский', region: 'Eastern Europe'),
    DubbingLanguage(code: 'ko', name: 'Korean', nativeName: '한국어', region: 'South Korea'),

    // ── Indic Languages (Available soon) ──────────────────────────────────────
    DubbingLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', region: 'India (Karnataka)', isIndic: true),
    DubbingLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', region: 'India / Bangladesh', isIndic: true),
    DubbingLanguage(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', region: 'India (Gujarat)', isIndic: true),
    DubbingLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', region: 'India (Punjab)', isIndic: true),
    DubbingLanguage(code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ', region: 'India (Odisha)', isIndic: true),
    DubbingLanguage(code: 'as', name: 'Assamese', nativeName: 'অসমীয়া', region: 'India (Assam)', isIndic: true),
    DubbingLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', region: 'India / Pakistan', isIndic: true),
    DubbingLanguage(code: 'sa', name: 'Sanskrit', nativeName: 'संस्कृतम्', region: 'India (Classical)', isIndic: true),
    DubbingLanguage(code: 'ne', name: 'Nepali', nativeName: 'नेपाली', region: 'Nepal / India', isIndic: true),
    DubbingLanguage(code: 'ks', name: 'Kashmiri', nativeName: 'कॉशुर', region: 'India (Kashmir)', isIndic: true),
    DubbingLanguage(code: 'sd', name: 'Sindhi', nativeName: 'سنڌي', region: 'India / Pakistan', isIndic: true),

    // ── European Languages (Available soon) ───────────────────────────────────
    DubbingLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', region: 'Turkey'),
    DubbingLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', region: 'Netherlands'),
    DubbingLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska', region: 'Sweden'),
    DubbingLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski', region: 'Poland'),
    DubbingLanguage(code: 'cs', name: 'Czech', nativeName: 'Čeština', region: 'Czech Republic'),
    DubbingLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά', region: 'Greece'),
    DubbingLanguage(code: 'hu', name: 'Hungarian', nativeName: 'Magyar', region: 'Hungary'),
    DubbingLanguage(code: 'da', name: 'Danish', nativeName: 'Dansk', region: 'Denmark'),
    DubbingLanguage(code: 'fi', name: 'Finnish', nativeName: 'Suomi', region: 'Finland'),
    DubbingLanguage(code: 'no', name: 'Norwegian', nativeName: 'Norsk', region: 'Norway'),
    DubbingLanguage(code: 'sk', name: 'Slovak', nativeName: 'Slovenčina', region: 'Slovakia'),
    DubbingLanguage(code: 'bg', name: 'Bulgarian', nativeName: 'Български', region: 'Bulgaria'),
    DubbingLanguage(code: 'ca', name: 'Catalan', nativeName: 'Català', region: 'Spain (Catalonia)'),
    DubbingLanguage(code: 'hr', name: 'Croatian', nativeName: 'Hrvatski', region: 'Croatia'),
    DubbingLanguage(code: 'lt', name: 'Lithuanian', nativeName: 'Lietuvių', region: 'Lithuania'),
    DubbingLanguage(code: 'sl', name: 'Slovenian', nativeName: 'Slovenščina', region: 'Slovenia'),
    DubbingLanguage(code: 'ro', name: 'Romanian', nativeName: 'Română', region: 'Romania'),
    DubbingLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська', region: 'Ukraine'),
    DubbingLanguage(code: 'et', name: 'Estonian', nativeName: 'Eesti', region: 'Estonia'),
    DubbingLanguage(code: 'lv', name: 'Latvian', nativeName: 'Latviešu', region: 'Latvia'),
    DubbingLanguage(code: 'sr', name: 'Serbian', nativeName: 'Српски', region: 'Serbia'),
    DubbingLanguage(code: 'sq', name: 'Albanian', nativeName: 'Shqip', region: 'Albania'),
    DubbingLanguage(code: 'eu', name: 'Basque', nativeName: 'Euskara', region: 'Spain (Basque Country)'),
    DubbingLanguage(code: 'be', name: 'Belarusian', nativeName: 'Беларуская', region: 'Belarus'),
    DubbingLanguage(code: 'bs', name: 'Bosnian', nativeName: 'Bosanski', region: 'Bosnia'),
    DubbingLanguage(code: 'gl', name: 'Galician', nativeName: 'Galego', region: 'Spain (Galicia)'),
    DubbingLanguage(code: 'ka', name: 'Georgian', nativeName: 'ქართული', region: 'Georgia'),
    DubbingLanguage(code: 'is', name: 'Icelandic', nativeName: 'Íslenska', region: 'Iceland'),
    DubbingLanguage(code: 'ga', name: 'Irish', nativeName: 'Gaeilge', region: 'Ireland'),
    DubbingLanguage(code: 'mk', name: 'Macedonian', nativeName: 'Македонски', region: 'North Macedonia'),
    DubbingLanguage(code: 'mt', name: 'Maltese', nativeName: 'Malti', region: 'Malta'),
    DubbingLanguage(code: 'cy', name: 'Welsh', nativeName: 'Cymraeg', region: 'United Kingdom (Wales)'),
    DubbingLanguage(code: 'yi', name: 'Yiddish', nativeName: 'ייִדיש', region: 'Europe / Jewish Diaspora'),

    // ── Asian & Pacific Languages (Available soon) ────────────────────────────
    DubbingLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', region: 'Indonesia'),
    DubbingLanguage(code: 'th', name: 'Thai', nativeName: 'ไทย', region: 'Thailand'),
    DubbingLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', region: 'Vietnam'),
    DubbingLanguage(code: 'tl', name: 'Tagalog', nativeName: 'Filipino', region: 'Philippines'),
    DubbingLanguage(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', region: 'Malaysia'),
    DubbingLanguage(code: 'kk', name: 'Kazakh', nativeName: 'Қазақша', region: 'Kazakhstan'),
    DubbingLanguage(code: 'uz', name: 'Uzbek', nativeName: 'Oʻzbekcha', region: 'Uzbekistan'),
    DubbingLanguage(code: 'my', name: 'Burmese', nativeName: 'မြန်မာဘာသာ', region: 'Myanmar'),
    DubbingLanguage(code: 'km', name: 'Khmer', nativeName: 'ភាសាខ្មែរ', region: 'Cambodia'),
    DubbingLanguage(code: 'lo', name: 'Lao', nativeName: 'ພາສາລາວ', region: 'Laos'),
    DubbingLanguage(code: 'hy', name: 'Armenian', nativeName: 'Հայերեն', region: 'Armenia'),
    DubbingLanguage(code: 'mn', name: 'Mongolian', nativeName: 'Монгол хэл', region: 'Mongolia'),
    DubbingLanguage(code: 'si', name: 'Sinhala', nativeName: 'සිංහල', region: 'Sri Lanka'),

    // ── Middle East & Africa (Available soon) ─────────────────────────────────
    DubbingLanguage(code: 'he', name: 'Hebrew', nativeName: 'עברית', region: 'Israel'),
    DubbingLanguage(code: 'fa', name: 'Persian', nativeName: 'فارسی', region: 'Iran'),
    DubbingLanguage(code: 'ku', name: 'Kurdish', nativeName: 'کوردی', region: 'Middle East'),
    DubbingLanguage(code: 'ps', name: 'Pashto', nativeName: 'پښتو', region: 'Afghanistan'),
    DubbingLanguage(code: 'af', name: 'Afrikaans', nativeName: 'Afrikaans', region: 'South Africa'),
    DubbingLanguage(code: 'az', name: 'Azerbaijani', nativeName: 'Azərbaycan', region: 'Azerbaijan'),
    DubbingLanguage(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili', region: 'East Africa'),
  ];

  static DubbingLanguage findByCode(String code) {
    final clean = code.trim().toLowerCase();
    return supportedLanguages.firstWhere(
      (l) => l.code.toLowerCase() == clean,
      orElse: () => source32Languages.firstWhere(
        (l) => l.code.toLowerCase() == clean,
        orElse: () => DubbingLanguage(
          code: code,
          name: code.toUpperCase(),
          nativeName: code.toUpperCase(),
          region: 'Global',
        ),
      ),
    );
  }
}
