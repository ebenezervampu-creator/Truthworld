/// Authoritative repository of AI-supported languages across TruthWorld:
/// - 78 Languages for AI Audio Dubbing & Voice Cloning powered by ElevenLabs
///   (Flash v2.5 / Multilingual v2 / Eleven v3).
/// - 135+ Languages for Subtitles & Closed Captions powered by Google Cloud Translation API.
class AILanguage {
  const AILanguage({
    required this.code,
    required this.name,
    required this.native,
    required this.region, // 'Indian' or 'Global'
    this.supportsDubbing = false,
    this.supportsSubtitles = true,
  });

  final String code;
  final String name;
  final String native;
  final String region;
  final bool supportsDubbing;
  final bool supportsSubtitles;

  String get displayName => '$name ($native)';

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'native': native,
        'region': region,
        'supportsDubbing': supportsDubbing,
        'supportsSubtitles': supportsSubtitles,
      };
}

/// All 135+ languages supported by TruthWorld AI pipelines.
const List<AILanguage> kAllAILanguages = [
  // =========================================================================
  // 🇮🇳 INDIAN LANGUAGES (23 Languages - All Eighth Schedule & Major Regional)
  // =========================================================================
  AILanguage(
    code: 'te',
    name: 'Telugu',
    native: 'తెలుగు',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'hi',
    name: 'Hindi',
    native: 'हिन्दी',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ta',
    name: 'Tamil',
    native: 'தமிழ்',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'kn',
    name: 'Kannada',
    native: 'ಕನ್ನಡ',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ml',
    name: 'Malayalam',
    native: 'മലയാളം',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'bn',
    name: 'Bengali',
    native: 'বাংলা',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'mr',
    name: 'Marathi',
    native: 'मराठी',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'gu',
    name: 'Gujarati',
    native: 'ગુજરાતી',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'pa',
    name: 'Punjabi',
    native: 'ਪੰਜਾਬੀ',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'or',
    name: 'Odia',
    native: 'ଓଡ଼ିଆ',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'as',
    name: 'Assamese',
    native: 'অসমীয়া',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ur',
    name: 'Urdu',
    native: 'اردو',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ne',
    name: 'Nepali',
    native: 'नेपाली',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sd',
    name: 'Sindhi',
    native: 'سنڌي',
    region: 'Indian',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sa',
    name: 'Sanskrit',
    native: 'संस्कृतम्',
    region: 'Indian',
  ),
  AILanguage(
    code: 'ks',
    name: 'Kashmiri',
    native: 'کٲشُر',
    region: 'Indian',
  ),
  AILanguage(
    code: 'gom',
    name: 'Konkani',
    native: 'कोंकणी',
    region: 'Indian',
  ),
  AILanguage(
    code: 'mai',
    name: 'Maithili',
    native: 'मैथिली',
    region: 'Indian',
  ),
  AILanguage(
    code: 'doi',
    name: 'Dogri',
    native: 'डोगरी',
    region: 'Indian',
  ),
  AILanguage(
    code: 'mni-Mtei',
    name: 'Manipuri',
    native: 'মৈতৈলোন্',
    region: 'Indian',
  ),
  AILanguage(
    code: 'brx',
    name: 'Bodo',
    native: 'बड़ो',
    region: 'Indian',
  ),
  AILanguage(
    code: 'sat',
    name: 'Santali',
    native: 'ᱥᱟᱱᱛᱟᱲᱤ',
    region: 'Indian',
  ),
  AILanguage(
    code: 'bho',
    name: 'Bhojpuri',
    native: 'भोजपुरी',
    region: 'Indian',
  ),

  // =========================================================================
  // 🌍 GLOBAL & ELEVENLABS-SUPPORTED DUBBING LANGUAGES (64 Languages)
  // =========================================================================
  AILanguage(
    code: 'en',
    name: 'English',
    native: 'English',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'es',
    name: 'Spanish',
    native: 'Español',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'fr',
    name: 'French',
    native: 'Français',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'de',
    name: 'German',
    native: 'Deutsch',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'pt',
    name: 'Portuguese',
    native: 'Português',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ar',
    name: 'Arabic',
    native: 'العربية',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ru',
    name: 'Russian',
    native: 'Русский',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ja',
    name: 'Japanese',
    native: '日本語',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ko',
    name: 'Korean',
    native: '한국어',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'zh',
    name: 'Chinese (Mandarin)',
    native: '中文',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'it',
    name: 'Italian',
    native: 'Italiano',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'tr',
    name: 'Turkish',
    native: 'Türkçe',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'vi',
    name: 'Vietnamese',
    native: 'Tiếng Việt',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'th',
    name: 'Thai',
    native: 'ไทย',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'id',
    name: 'Indonesian',
    native: 'Bahasa Indonesia',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'nl',
    name: 'Dutch',
    native: 'Nederlands',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'pl',
    name: 'Polish',
    native: 'Polski',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sv',
    name: 'Swedish',
    native: 'Svenska',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'el',
    name: 'Greek',
    native: 'Ελληνικά',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'he',
    name: 'Hebrew',
    native: 'עברית',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'fa',
    name: 'Persian (Farsi)',
    native: 'فارسی',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'uk',
    name: 'Ukrainian',
    native: 'Українська',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'fil',
    name: 'Filipino (Tagalog)',
    native: 'Filipino',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ms',
    name: 'Malay',
    native: 'Bahasa Melayu',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'cs',
    name: 'Czech',
    native: 'Čeština',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'da',
    name: 'Danish',
    native: 'Dansk',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'fi',
    name: 'Finnish',
    native: 'Suomi',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ro',
    name: 'Romanian',
    native: 'Română',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'hu',
    name: 'Hungarian',
    native: 'Magyar',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'no',
    name: 'Norwegian',
    native: 'Norsk',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sk',
    name: 'Slovak',
    native: 'Slovenčina',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'hr',
    name: 'Croatian',
    native: 'Hrvatski',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'bg',
    name: 'Bulgarian',
    native: 'Български',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sr',
    name: 'Serbian',
    native: 'Српски',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sl',
    name: 'Slovenian',
    native: 'Slovenščina',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'lt',
    name: 'Lithuanian',
    native: 'Lietuvių',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'lv',
    name: 'Latvian',
    native: 'Latviešu',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'et',
    name: 'Estonian',
    native: 'Eesti',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'si',
    name: 'Sinhala',
    native: 'සිංහල',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sw',
    name: 'Swahili',
    native: 'Kiswahili',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'my',
    name: 'Burmese',
    native: 'မြန်မာစာ',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'kk',
    name: 'Kazakh',
    native: 'Қазақ тілі',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'uz',
    name: 'Uzbek',
    native: 'Oʻzbekcha',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'az',
    name: 'Azerbaijani',
    native: 'Azərbaycan dili',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'hy',
    name: 'Armenian',
    native: 'Հայերեն',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ka',
    name: 'Georgian',
    native: 'ქართული',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'am',
    name: 'Amharic',
    native: 'አማርኛ',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'so',
    name: 'Somali',
    native: 'Soomaaliga',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'zu',
    name: 'Zulu',
    native: 'isiZulu',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'af',
    name: 'Afrikaans',
    native: 'Afrikaans',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'sq',
    name: 'Albanian',
    native: 'Shqip',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'eu',
    name: 'Basque',
    native: 'Euskara',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'be',
    name: 'Belarusian',
    native: 'Беларуская',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'bs',
    name: 'Bosnian',
    native: 'Bosanski',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ca',
    name: 'Catalan',
    native: 'Català',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ceb',
    name: 'Cebuano',
    native: 'Sinugboanon',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ny',
    name: 'Chichewa (Nyanja)',
    native: 'Chichewa',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'gl',
    name: 'Galician',
    native: 'Galego',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ha',
    name: 'Hausa',
    native: 'Hausa',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'is',
    name: 'Icelandic',
    native: 'Íslenska',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ga',
    name: 'Irish',
    native: 'Gaeilge',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'jv',
    name: 'Javanese',
    native: 'Basa Jawa',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ky',
    name: 'Kyrgyz',
    native: 'Кыргызча',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'lb',
    name: 'Luxembourgish',
    native: 'Lëtzebuergesch',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'mk',
    name: 'Macedonian',
    native: 'Македонски',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ps',
    name: 'Pashto',
    native: 'پښتو',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'cy',
    name: 'Welsh',
    native: 'Cymraeg',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'ln',
    name: 'Lingala',
    native: 'Lingála',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'mt',
    name: 'Maltese',
    native: 'Malti',
    region: 'Global',
    supportsDubbing: true,
  ),
  AILanguage(
    code: 'la',
    name: 'Latin',
    native: 'Latina',
    region: 'Global',
    supportsDubbing: true,
  ),

  // =========================================================================
  // 🌐 ADDITIONAL GOOGLE CLOUD TRANSLATION API LANGUAGES (Subtitles Only)
  // =========================================================================
  AILanguage(
    code: 'co',
    name: 'Corsican',
    native: 'Corsu',
    region: 'Global',
  ),
  AILanguage(
    code: 'eo',
    name: 'Esperanto',
    native: 'Esperanto',
    region: 'Global',
  ),
  AILanguage(
    code: 'fy',
    name: 'Frisian',
    native: 'Frysk',
    region: 'Global',
  ),
  AILanguage(
    code: 'ht',
    name: 'Haitian Creole',
    native: 'Kreyòl Ayisyen',
    region: 'Global',
  ),
  AILanguage(
    code: 'haw',
    name: 'Hawaiian',
    native: 'ʻŌlelo Hawaiʻi',
    region: 'Global',
  ),
  AILanguage(
    code: 'hmn',
    name: 'Hmong',
    native: 'Hmoob',
    region: 'Global',
  ),
  AILanguage(
    code: 'ig',
    name: 'Igbo',
    native: 'Asụsụ Igbo',
    region: 'Global',
  ),
  AILanguage(
    code: 'km',
    name: 'Khmer',
    native: 'ភាសាខ្មែរ',
    region: 'Global',
  ),
  AILanguage(
    code: 'rw',
    name: 'Kinyarwanda',
    native: 'Ikinyarwanda',
    region: 'Global',
  ),
  AILanguage(
    code: 'ku',
    name: 'Kurdish',
    native: 'Kurdî',
    region: 'Global',
  ),
  AILanguage(
    code: 'lo',
    name: 'Lao',
    native: 'ພາສາລາວ',
    region: 'Global',
  ),
  AILanguage(
    code: 'mg',
    name: 'Malagasy',
    native: 'Malagasy',
    region: 'Global',
  ),
  AILanguage(
    code: 'mi',
    name: 'Maori',
    native: 'Te Reo Māori',
    region: 'Global',
  ),
  AILanguage(
    code: 'mn',
    name: 'Mongolian',
    native: 'Монгол хэл',
    region: 'Global',
  ),
  AILanguage(
    code: 'sm',
    name: 'Samoan',
    native: 'Gagana Sāmoa',
    region: 'Global',
  ),
  AILanguage(
    code: 'gd',
    name: 'Scots Gaelic',
    native: 'Gàidhlig',
    region: 'Global',
  ),
  AILanguage(
    code: 'st',
    name: 'Sesotho',
    native: 'Sesotho',
    region: 'Global',
  ),
  AILanguage(
    code: 'sn',
    name: 'Shona',
    native: 'chiShona',
    region: 'Global',
  ),
  AILanguage(
    code: 'su',
    name: 'Sundanese',
    native: 'Basa Sunda',
    region: 'Global',
  ),
  AILanguage(
    code: 'tg',
    name: 'Tajik',
    native: 'Тоҷикӣ',
    region: 'Global',
  ),
  AILanguage(
    code: 'tt',
    name: 'Tatar',
    native: 'Татар теле',
    region: 'Global',
  ),
  AILanguage(
    code: 'tk',
    name: 'Turkmen',
    native: 'Türkmençe',
    region: 'Global',
  ),
  AILanguage(
    code: 'ug',
    name: 'Uyghur',
    native: 'ئۇيغۇرچە',
    region: 'Global',
  ),
  AILanguage(
    code: 'xh',
    name: 'Xhosa',
    native: 'isiXhosa',
    region: 'Global',
  ),
  AILanguage(
    code: 'yi',
    name: 'Yiddish',
    native: 'ייִדיש',
    region: 'Global',
  ),
  AILanguage(
    code: 'yo',
    name: 'Yoruba',
    native: 'Èdè Yorùbá',
    region: 'Global',
  ),
  AILanguage(
    code: 'ay',
    name: 'Aymara',
    native: 'Aymar aru',
    region: 'Global',
  ),
  AILanguage(
    code: 'bm',
    name: 'Bambara',
    native: 'Bamanankan',
    region: 'Global',
  ),
  AILanguage(
    code: 'dv',
    name: 'Dhivehi',
    native: 'ދިވެހި',
    region: 'Global',
  ),
  AILanguage(
    code: 'ee',
    name: 'Ewe',
    native: 'Eʋegbe',
    region: 'Global',
  ),
  AILanguage(
    code: 'gn',
    name: 'Guarani',
    native: "Avañe'ẽ",
    region: 'Global',
  ),
  AILanguage(
    code: 'ilo',
    name: 'Ilokano',
    native: 'Ilokano',
    region: 'Global',
  ),
  AILanguage(
    code: 'kri',
    name: 'Krio',
    native: 'Krio',
    region: 'Global',
  ),
  AILanguage(
    code: 'lg',
    name: 'Luganda',
    native: 'Oluganda',
    region: 'Global',
  ),
  AILanguage(
    code: 'om',
    name: 'Oromo',
    native: 'Afaan Oromoo',
    region: 'Global',
  ),
  AILanguage(
    code: 'qu',
    name: 'Quechua',
    native: 'Runa Simi',
    region: 'Global',
  ),
  AILanguage(
    code: 'nso',
    name: 'Sepedi',
    native: 'Sesotho sa Leboa',
    region: 'Global',
  ),
  AILanguage(
    code: 'ti',
    name: 'Tigrinya',
    native: 'ትግርኛ',
    region: 'Global',
  ),
  AILanguage(
    code: 'ts',
    name: 'Tsonga',
    native: 'Xitsonga',
    region: 'Global',
  ),
  AILanguage(
    code: 'ak',
    name: 'Twi',
    native: 'Twi',
    region: 'Global',
  ),
  AILanguage(
    code: 'chr',
    name: 'Cherokee',
    native: 'ᏣᎳᎩ',
    region: 'Global',
  ),
  AILanguage(
    code: 'yue',
    name: 'Cantonese',
    native: '粵語',
    region: 'Global',
  ),
  AILanguage(
    code: 'lus',
    name: 'Mizo',
    native: 'Mizo ṭawng',
    region: 'Global',
  ),
  AILanguage(
    code: 'tn',
    name: 'Setswana',
    native: 'Setswana',
    region: 'Global',
  ),
  AILanguage(
    code: 'hil',
    name: 'Hiligaynon',
    native: 'Ilonggo',
    region: 'Global',
  ),
  AILanguage(
    code: 'war',
    name: 'Waray',
    native: 'Winaray',
    region: 'Global',
  ),
  AILanguage(
    code: 'pam',
    name: 'Kapampangan',
    native: 'Kapampangan',
    region: 'Global',
  ),
  AILanguage(
    code: 'pag',
    name: 'Pangasinan',
    native: 'Pangasinan',
    region: 'Global',
  ),
  AILanguage(
    code: 'bcl',
    name: 'Central Bikol',
    native: 'Bikol',
    region: 'Global',
  ),
  AILanguage(
    code: 'cnh',
    name: 'Hakha Chin',
    native: 'Lai holh',
    region: 'Global',
  ),
];

/// The 78 languages supported by ElevenLabs for AI voice cloning & audio dubbing.
final List<AILanguage> kElevenLabsDubbingLanguages =
    kAllAILanguages.where((l) => l.supportsDubbing).toList();

/// The 135+ languages supported by Google Cloud Translation API for subtitles & captions.
final List<AILanguage> kGoogleCloudTranslationLanguages =
    kAllAILanguages.where((l) => l.supportsSubtitles).toList();

/// Helper to lookup language metadata by ISO code.
AILanguage? getAILanguageByCode(String code) {
  final cleanCode = code.toLowerCase().trim();
  for (final lang in kAllAILanguages) {
    if (lang.code.toLowerCase() == cleanCode) return lang;
  }
  return null;
}

/// Checks if a language code supports ElevenLabs Audio Dubbing.
bool isDubbingSupported(String code) {
  final lang = getAILanguageByCode(code);
  return lang?.supportsDubbing ?? false;
}

/// Checks if a language code supports Google Cloud Translation API Subtitles.
bool isSubtitleSupported(String code) {
  final lang = getAILanguageByCode(code);
  return lang?.supportsSubtitles ?? false;
}
