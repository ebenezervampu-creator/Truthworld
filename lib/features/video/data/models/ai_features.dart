/// AI feature models for the video processing pipeline.
library;

/// Text-to-Speech configuration for video processing.
class TTSConfig {
  const TTSConfig({
    this.enabled = false,
    this.voiceType = 'standard',
    this.clonedVoiceId,
  });

  factory TTSConfig.fromMap(Map<String, dynamic> data) => TTSConfig(
    enabled: data['enabled'] ?? false,
    voiceType: data['voiceType'] ?? 'standard',
    clonedVoiceId: data['clonedVoiceId'],
  );
  final bool enabled;
  final String voiceType; // "standard" | "voice_clone"
  final String? clonedVoiceId;

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'voiceType': voiceType,
    if (clonedVoiceId != null) 'clonedVoiceId': clonedVoiceId,
  };
}

/// AI feature selections for video processing pipeline.
/// Controls which features are applied during backend processing.
class AIFeatures {
  // "draft" | "published" | "processing" | "completed"

  const AIFeatures({
    this.transcript = true,
    this.genLangSubs = false,
    this.generateDubbing = false,
    this.translationLanguages = const [],
    this.tts = const TTSConfig(),
    this.factChecking = false,
    this.factCheckTier = 'standard',
    this.diarization = false,
    this.summary = false,
    this.autoChapters = false,
    this.speakerCount = 'not_sure',
    this.pipelineStage,
  });

  factory AIFeatures.fromMap(Map<String, dynamic> data) => AIFeatures(
    transcript: data['transcript'] ?? true,
    genLangSubs: data['genLangSubs'] ?? false,
    generateDubbing: data['generateDubbing'] ?? false,
    translationLanguages: List<String>.from(data['translationLanguages'] ?? []),
    tts: data['tts'] != null
        ? TTSConfig.fromMap(Map<String, dynamic>.from(data['tts'] as Map))
        : const TTSConfig(),
    factChecking: data['factChecking'] ?? false,
    factCheckTier: (data['factCheckTier'] as String?) ?? 'standard',
    diarization: data['diarization'] ?? false,
    summary: data['summary'] ?? false,
    autoChapters: data['autoChapters'] ?? false,
    speakerCount: data['speakerCount'] ?? 'not_sure',
    pipelineStage: data['pipelineStage'],
  );
  final bool transcript; // AssemblyAI
  final bool genLangSubs; // Google Cloud Translate
  final bool generateDubbing; // ElevenLabs
  final List<String> translationLanguages; // ISO 639-1 codes
  final TTSConfig tts;
  final bool factChecking; // Gemini
  final String factCheckTier; // "short" | "standard" | "full_ground"
  final bool diarization;
  final bool summary;
  final bool autoChapters; // AssemblyAI
  final String speakerCount; // "1" | "2" | "3" | "4" | "5+" | "not_sure"
  final String? pipelineStage;

  Map<String, dynamic> toMap() => {
    'transcript': transcript,
    'genLangSubs': genLangSubs,
    'generateDubbing': generateDubbing,
    'translationLanguages': translationLanguages,
    'tts': tts.toMap(),
    'factChecking': factChecking,
    'factCheckTier': factCheckTier,
    'diarization': diarization,
    'summary': summary,
    'autoChapters': autoChapters,
    'speakerCount': speakerCount,
    if (pipelineStage != null) 'pipelineStage': pipelineStage,
  };

  static const AIFeatures defaultFeatures = AIFeatures();
}

/// Language categories for UI grouping.
enum LanguageCategory { global, indian, other }

/// Supported languages for translation.
class TranslationLanguage {
  const TranslationLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.category,
  });
  final String code;
  final String name;
  final String nativeName;
  final LanguageCategory category;
}

/// All supported translation languages (Google Cloud Translation v3).
/// Includes 130+ languages categorized by region and usage.
const List<TranslationLanguage> supportedLanguages = [
  // --- GLOBAL / WIDELY USED ---
  TranslationLanguage(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Español',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'fr',
    name: 'French',
    nativeName: 'Français',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'de',
    name: 'German',
    nativeName: 'Deutsch',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'zh',
    name: 'Chinese',
    nativeName: '中文',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'ru',
    name: 'Russian',
    nativeName: 'Русский',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'pt',
    name: 'Portuguese',
    nativeName: 'Português',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'ar',
    name: 'Arabic',
    nativeName: 'العربية',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'ko',
    name: 'Korean',
    nativeName: '한국어',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'it',
    name: 'Italian',
    nativeName: 'Italiano',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'tr',
    name: 'Turkish',
    nativeName: 'Türkçe',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'vi',
    name: 'Vietnamese',
    nativeName: 'Tiếng Việt',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'th',
    name: 'Thai',
    nativeName: 'ไทย',
    category: LanguageCategory.global,
  ),
  TranslationLanguage(
    code: 'id',
    name: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
    category: LanguageCategory.global,
  ),

  // --- INDIAN LANGUAGES ---
  TranslationLanguage(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'bn',
    name: 'Bengali',
    nativeName: 'বাংলা',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'te',
    name: 'Telugu',
    nativeName: 'తెలుగు',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'ta',
    name: 'Tamil',
    nativeName: 'தமிழ்',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'mr',
    name: 'Marathi',
    nativeName: 'मराठी',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'gu',
    name: 'Gujarati',
    nativeName: 'ગુજરાતી',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'kn',
    name: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'ml',
    name: 'Malayalam',
    nativeName: 'മലയാളം',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'pa',
    name: 'Punjabi',
    nativeName: 'ਪੰਜਾਬੀ',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'or',
    name: 'Odia',
    nativeName: 'ଓଡ଼ିଆ',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'as',
    name: 'Assamese',
    nativeName: 'অસમীয়া',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'ur',
    name: 'Urdu',
    nativeName: 'اردو',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'ks',
    name: 'Kashmiri',
    nativeName: 'कॉशुर',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'sd',
    name: 'Sindhi',
    nativeName: 'سنڌي',
    category: LanguageCategory.indian,
  ),
  TranslationLanguage(
    code: 'sa',
    name: 'Sanskrit',
    nativeName: 'संस्कृतम्',
    category: LanguageCategory.indian,
  ),

  // --- OTHER LANGUAGES ---
  TranslationLanguage(
    code: 'af',
    name: 'Afrikaans',
    nativeName: 'Afrikaans',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sq',
    name: 'Albanian',
    nativeName: 'Shqip',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'am',
    name: 'Amharic',
    nativeName: 'አማርኛ',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'hy',
    name: 'Armenian',
    nativeName: 'Հայերեն',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'az',
    name: 'Azerbaijani',
    nativeName: 'Azərbaycanca',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'eu',
    name: 'Basque',
    nativeName: 'Euskara',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'be',
    name: 'Belarusian',
    nativeName: 'Беларуская',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'bs',
    name: 'Bosnian',
    nativeName: 'Bosanski',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'bg',
    name: 'Bulgarian',
    nativeName: 'Български',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ca',
    name: 'Catalan',
    nativeName: 'Català',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ceb',
    name: 'Cebuano',
    nativeName: 'Cebuano',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ny',
    name: 'Chichewa',
    nativeName: 'Chichewa',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'co',
    name: 'Corsican',
    nativeName: 'Corsu',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'hr',
    name: 'Croatian',
    nativeName: 'Hrvatski',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'cs',
    name: 'Czech',
    nativeName: 'Čeština',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'da',
    name: 'Danish',
    nativeName: 'Dansk',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'nl',
    name: 'Dutch',
    nativeName: 'Nederlands',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'eo',
    name: 'Esperanto',
    nativeName: 'Esperanto',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'et',
    name: 'Estonian',
    nativeName: 'Eesti',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'tl',
    name: 'Filipino',
    nativeName: 'Filipino',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'fi',
    name: 'Finnish',
    nativeName: 'Suomi',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'fy',
    name: 'Frisian',
    nativeName: 'Frysk',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'gl',
    name: 'Galician',
    nativeName: 'Galego',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ka',
    name: 'Georgian',
    nativeName: 'քարթուլի',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'el',
    name: 'Greek',
    nativeName: 'Ελληνικά',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ht',
    name: 'Haitian Creole',
    nativeName: 'Kreyòl Ayisyen',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ha',
    name: 'Hausa',
    nativeName: 'Hausa',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'haw',
    name: 'Hawaiian',
    nativeName: 'ʻŌlelo Hawaiʻi',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'iw',
    name: 'Hebrew',
    nativeName: 'עברית',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'hmn',
    name: 'Hmong',
    nativeName: 'Hmong',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'hu',
    name: 'Hungarian',
    nativeName: 'Magyar',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'is',
    name: 'Icelandic',
    nativeName: 'Íslenska',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ig',
    name: 'Igbo',
    nativeName: 'Igbo',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ga',
    name: 'Irish',
    nativeName: 'Gaeilge',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'jv',
    name: 'Javanese',
    nativeName: 'Basa Jawa',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'kk',
    name: 'Kazakh',
    nativeName: 'Қазақ тілі',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'km',
    name: 'Khmer',
    nativeName: 'ខ្មែរ',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'rw',
    name: 'Kinyarwanda',
    nativeName: 'Ikinyarwanda',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ku',
    name: 'Kurdish',
    nativeName: 'Kurdî',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ky',
    name: 'Kyrgyz',
    nativeName: 'Кыргызча',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'lo',
    name: 'Lao',
    nativeName: 'ລາວ',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'la',
    name: 'Latin',
    nativeName: 'Latina',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'lv',
    name: 'Latvian',
    nativeName: 'Latviešu',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'lt',
    name: 'Lithuanian',
    nativeName: 'Lietuvių',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'lb',
    name: 'Luxembourgish',
    nativeName: 'Lëtzebuergesch',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'mk',
    name: 'Macedonian',
    nativeName: 'Македонски',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'mg',
    name: 'Malagasy',
    nativeName: 'Malagasy',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ms',
    name: 'Malay',
    nativeName: 'Bahasa Melayu',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'mt',
    name: 'Maltese',
    nativeName: 'Malti',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'mi',
    name: 'Maori',
    nativeName: 'Māori',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'mn',
    name: 'Mongolian',
    nativeName: 'Монгол',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'my',
    name: 'Myanmar',
    nativeName: 'မြန်မာ',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ne',
    name: 'Nepali',
    nativeName: 'नेपाली',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'no',
    name: 'Norwegian',
    nativeName: 'Norsk',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ps',
    name: 'Pashto',
    nativeName: 'پښتو',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'fa',
    name: 'Persian',
    nativeName: 'فارسی',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'pl',
    name: 'Polish',
    nativeName: 'Polski',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ro',
    name: 'Romanian',
    nativeName: 'Română',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sm',
    name: 'Samoan',
    nativeName: 'Gagana Sāmoa',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'gd',
    name: 'Scots Gaelic',
    nativeName: 'Gàidhlig',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sr',
    name: 'Serbian',
    nativeName: 'Српски',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'st',
    name: 'Sesotho',
    nativeName: 'Sesotho',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sn',
    name: 'Shona',
    nativeName: 'Chishona',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'si',
    name: 'Sinhala',
    nativeName: 'සිංහල',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sk',
    name: 'Slovak',
    nativeName: 'Slovenčina',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sl',
    name: 'Slovenian',
    nativeName: 'Slovenščina',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'so',
    name: 'Somali',
    nativeName: 'Soomaali',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'su',
    name: 'Sundanese',
    nativeName: 'Basa Sunda',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sw',
    name: 'Swahili',
    nativeName: 'Kiswahili',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'sv',
    name: 'Swedish',
    nativeName: 'Svenska',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'tg',
    name: 'Tajik',
    nativeName: 'Тоҷикӣ',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'tt',
    name: 'Tatar',
    nativeName: 'Татар',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'tk',
    name: 'Turkmen',
    nativeName: 'Türkmençe',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'uk',
    name: 'Ukrainian',
    nativeName: 'Українська',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'ug',
    name: 'Uyghur',
    nativeName: 'ئۇيղۇرچە',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'uz',
    name: 'Uzbek',
    nativeName: 'Oʻzbekcha',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'cy',
    name: 'Welsh',
    nativeName: 'Cymraeg',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'xh',
    name: 'Xhosa',
    nativeName: 'isiXhosa',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'yi',
    name: 'Yiddish',
    nativeName: 'ייִדיש',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'yo',
    name: 'Yoruba',
    nativeName: 'Yorùbá',
    category: LanguageCategory.other,
  ),
  TranslationLanguage(
    code: 'zu',
    name: 'Zulu',
    nativeName: 'isiZulu',
    category: LanguageCategory.other,
  ),
];
