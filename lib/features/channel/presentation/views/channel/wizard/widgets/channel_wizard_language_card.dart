import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardLanguageCard extends StatelessWidget {
  const ChannelWizardLanguageCard({
    required this.controller,
    required this.isDarkMode,
    this.contentOnly = false,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;
  final bool contentOnly;

  @override
  Widget build(BuildContext context) {
    if (contentOnly) {
      return _buildLanguageContent(context, isDarkMode);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '8. Language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildLanguageContent(context, isDarkMode),
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _worldLanguagesDescending = [
    {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'speakers': '~1.5 Billion speakers',
      'rank': 1,
      'isAccepted': true,
    },
    {
      'code': 'zh',
      'name': 'Mandarin Chinese',
      'native': '中文',
      'speakers': '~1.1 Billion speakers',
      'rank': 2,
      'isAccepted': false,
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिन्दी',
      'speakers': '~610 Million speakers',
      'rank': 3,
      'isAccepted': false,
    },
    {
      'code': 'es',
      'name': 'Spanish',
      'native': 'Español',
      'speakers': '~560 Million speakers',
      'rank': 4,
      'isAccepted': false,
    },
    {
      'code': 'fr',
      'name': 'French',
      'native': 'Français',
      'speakers': '~310 Million speakers',
      'rank': 5,
      'isAccepted': false,
    },
    {
      'code': 'ar',
      'name': 'Arabic',
      'native': 'العربية',
      'speakers': '~274 Million speakers',
      'rank': 6,
      'isAccepted': false,
    },
    {
      'code': 'bn',
      'name': 'Bengali',
      'native': 'বাংলা',
      'speakers': '~273 Million speakers',
      'rank': 7,
      'isAccepted': false,
    },
    {
      'code': 'pt',
      'name': 'Portuguese',
      'native': 'Português',
      'speakers': '~264 Million speakers',
      'rank': 8,
      'isAccepted': false,
    },
    {
      'code': 'ru',
      'name': 'Russian',
      'native': 'Русский',
      'speakers': '~255 Million speakers',
      'rank': 9,
      'isAccepted': false,
    },
    {
      'code': 'ur',
      'name': 'Urdu',
      'native': 'اردو',
      'speakers': '~232 Million speakers',
      'rank': 10,
      'isAccepted': false,
    },
    {
      'code': 'id',
      'name': 'Indonesian',
      'native': 'Bahasa Indonesia',
      'speakers': '~200 Million speakers',
      'rank': 11,
      'isAccepted': false,
    },
    {
      'code': 'de',
      'name': 'German',
      'native': 'Deutsch',
      'speakers': '~134 Million speakers',
      'rank': 12,
      'isAccepted': false,
    },
    {
      'code': 'ja',
      'name': 'Japanese',
      'native': '日本語',
      'speakers': '~125 Million speakers',
      'rank': 13,
      'isAccepted': false,
    },
    {
      'code': 'pcm',
      'name': 'Nigerian Pidgin',
      'native': 'Naijá',
      'speakers': '~120 Million speakers',
      'rank': 14,
      'isAccepted': false,
    },
    {
      'code': 'mr',
      'name': 'Marathi',
      'native': 'मराठी',
      'speakers': '~99 Million speakers',
      'rank': 15,
      'isAccepted': false,
    },
    {
      'code': 'te',
      'name': 'Telugu',
      'native': 'తెలుగు',
      'speakers': '~96 Million speakers',
      'rank': 16,
      'isAccepted': false,
    },
    {
      'code': 'tr',
      'name': 'Turkish',
      'native': 'Türkçe',
      'speakers': '~88 Million speakers',
      'rank': 17,
      'isAccepted': false,
    },
    {
      'code': 'ta',
      'name': 'Tamil',
      'native': 'தமிழ்',
      'speakers': '~86 Million speakers',
      'rank': 18,
      'isAccepted': false,
    },
    {
      'code': 'yue',
      'name': 'Cantonese',
      'native': '粵語',
      'speakers': '~86 Million speakers',
      'rank': 19,
      'isAccepted': false,
    },
    {
      'code': 'vi',
      'name': 'Vietnamese',
      'native': 'Tiếng Việt',
      'speakers': '~85 Million speakers',
      'rank': 20,
      'isAccepted': false,
    },
    {
      'code': 'tl',
      'name': 'Tagalog (Filipino)',
      'native': 'Filipino',
      'speakers': '~83 Million speakers',
      'rank': 21,
      'isAccepted': false,
    },
    {
      'code': 'wuu',
      'name': 'Wu Chinese',
      'native': '吴语',
      'speakers': '~82 Million speakers',
      'rank': 22,
      'isAccepted': false,
    },
    {
      'code': 'ko',
      'name': 'Korean',
      'native': '한국어',
      'speakers': '~82 Million speakers',
      'rank': 23,
      'isAccepted': false,
    },
    {
      'code': 'fa',
      'name': 'Persian (Farsi)',
      'native': 'فارسی',
      'speakers': '~77 Million speakers',
      'rank': 24,
      'isAccepted': false,
    },
    {
      'code': 'ha',
      'name': 'Hausa',
      'native': 'Hausa',
      'speakers': '~77 Million speakers',
      'rank': 25,
      'isAccepted': false,
    },
    {
      'code': 'sw',
      'name': 'Swahili',
      'native': 'Kiswahili',
      'speakers': '~71 Million speakers',
      'rank': 26,
      'isAccepted': false,
    },
    {
      'code': 'jv',
      'name': 'Javanese',
      'native': 'Basa Jawa',
      'speakers': '~68 Million speakers',
      'rank': 27,
      'isAccepted': false,
    },
    {
      'code': 'it',
      'name': 'Italian',
      'native': 'Italiano',
      'speakers': '~68 Million speakers',
      'rank': 28,
      'isAccepted': false,
    },
    {
      'code': 'pa',
      'name': 'Punjabi',
      'native': 'ਪੰਜਾਬੀ',
      'speakers': '~66 Million speakers',
      'rank': 29,
      'isAccepted': false,
    },
    {
      'code': 'kn',
      'name': 'Kannada',
      'native': 'ಕನ್ನಡ',
      'speakers': '~64 Million speakers',
      'rank': 30,
      'isAccepted': false,
    },
    {
      'code': 'gu',
      'name': 'Gujarati',
      'native': 'ગુજરાતી',
      'speakers': '~62 Million speakers',
      'rank': 31,
      'isAccepted': false,
    },
    {
      'code': 'th',
      'name': 'Thai',
      'native': 'ไทย',
      'speakers': '~61 Million speakers',
      'rank': 32,
      'isAccepted': false,
    },
    {
      'code': 'am',
      'name': 'Amharic',
      'native': 'አማርኛ',
      'speakers': '~57 Million speakers',
      'rank': 33,
      'isAccepted': false,
    },
    {
      'code': 'bho',
      'name': 'Bhojpuri',
      'native': 'भोजपुरी',
      'speakers': '~52 Million speakers',
      'rank': 34,
      'isAccepted': false,
    },
    {
      'code': 'pl',
      'name': 'Polish',
      'native': 'Polski',
      'speakers': '~45 Million speakers',
      'rank': 35,
      'isAccepted': false,
    },
    {
      'code': 'yo',
      'name': 'Yoruba',
      'native': 'Yorùbá',
      'speakers': '~45 Million speakers',
      'rank': 36,
      'isAccepted': false,
    },
    {
      'code': 'my',
      'name': 'Burmese (Myanmar)',
      'native': 'မြန်မာ',
      'speakers': '~43 Million speakers',
      'rank': 37,
      'isAccepted': false,
    },
    {
      'code': 'ml',
      'name': 'Malayalam',
      'native': 'മലയാളം',
      'speakers': '~38 Million speakers',
      'rank': 38,
      'isAccepted': false,
    },
    {
      'code': 'or',
      'name': 'Odia',
      'native': 'ଓଡ଼ିଆ',
      'speakers': '~38 Million speakers',
      'rank': 39,
      'isAccepted': false,
    },
    {
      'code': 'mai',
      'name': 'Maithili',
      'native': 'मैथिली',
      'speakers': '~34 Million speakers',
      'rank': 40,
      'isAccepted': false,
    },
    {
      'code': 'ms',
      'name': 'Malay',
      'native': 'Bahasa Melayu',
      'speakers': '~33 Million speakers',
      'rank': 41,
      'isAccepted': false,
    },
    {
      'code': 'uk',
      'name': 'Ukrainian',
      'native': 'Українська',
      'speakers': '~33 Million speakers',
      'rank': 42,
      'isAccepted': false,
    },
    {
      'code': 'su',
      'name': 'Sundanese',
      'native': 'Basa Sunda',
      'speakers': '~32 Million speakers',
      'rank': 43,
      'isAccepted': false,
    },
    {
      'code': 'ig',
      'name': 'Igbo',
      'native': 'Igbo',
      'speakers': '~31 Million speakers',
      'rank': 44,
      'isAccepted': false,
    },
    {
      'code': 'uz',
      'name': 'Uzbek',
      'native': 'Oʻzbekcha',
      'speakers': '~30 Million speakers',
      'rank': 45,
      'isAccepted': false,
    },
    {
      'code': 'sd',
      'name': 'Sindhi',
      'native': 'سنڌي',
      'speakers': '~30 Million speakers',
      'rank': 46,
      'isAccepted': false,
    },
    {
      'code': 'ro',
      'name': 'Romanian',
      'native': 'Română',
      'speakers': '~28 Million speakers',
      'rank': 47,
      'isAccepted': false,
    },
    {
      'code': 'nl',
      'name': 'Dutch',
      'native': 'Nederlands',
      'speakers': '~25 Million speakers',
      'rank': 48,
      'isAccepted': false,
    },
    {
      'code': 'ps',
      'name': 'Pashto',
      'native': 'پښتو',
      'speakers': '~23 Million speakers',
      'rank': 49,
      'isAccepted': false,
    },
    {
      'code': 'ne',
      'name': 'Nepali',
      'native': 'नेपाली',
      'speakers': '~20 Million speakers',
      'rank': 50,
      'isAccepted': false,
    },
    {
      'code': 'si',
      'name': 'Sinhala',
      'native': 'සිංහල',
      'speakers': '~17 Million speakers',
      'rank': 51,
      'isAccepted': false,
    },
    {
      'code': 'af',
      'name': 'Afrikaans',
      'native': 'Afrikaans',
      'speakers': '~17 Million speakers',
      'rank': 52,
      'isAccepted': false,
    },
    {
      'code': 'km',
      'name': 'Khmer',
      'native': 'ខ្មែរ',
      'speakers': '~16 Million speakers',
      'rank': 53,
      'isAccepted': false,
    },
    {
      'code': 'tk',
      'name': 'Turkmen',
      'native': 'Türkmençe',
      'speakers': '~16 Million speakers',
      'rank': 54,
      'isAccepted': false,
    },
    {
      'code': 'as',
      'name': 'Assamese',
      'native': 'অসমীয়া',
      'speakers': '~15 Million speakers',
      'rank': 55,
      'isAccepted': false,
    },
    {
      'code': 'so',
      'name': 'Somali',
      'native': 'Soomaali',
      'speakers': '~15 Million speakers',
      'rank': 56,
      'isAccepted': false,
    },
    {
      'code': 'el',
      'name': 'Greek',
      'native': 'Ελληνικά',
      'speakers': '~13 Million speakers',
      'rank': 57,
      'isAccepted': false,
    },
    {
      'code': 'cs',
      'name': 'Czech',
      'native': 'Čeština',
      'speakers': '~13 Million speakers',
      'rank': 58,
      'isAccepted': false,
    },
    {
      'code': 'kk',
      'name': 'Kazakh',
      'native': 'Қазақ тілі',
      'speakers': '~13 Million speakers',
      'rank': 59,
      'isAccepted': false,
    },
    {
      'code': 'ku',
      'name': 'Kurdish',
      'native': 'Kurdî',
      'speakers': '~13 Million speakers',
      'rank': 60,
      'isAccepted': false,
    },
    {
      'code': 'hu',
      'name': 'Hungarian',
      'native': 'Magyar',
      'speakers': '~13 Million speakers',
      'rank': 61,
      'isAccepted': false,
    },
    {
      'code': 'sv',
      'name': 'Swedish',
      'native': 'Svenska',
      'speakers': '~13 Million speakers',
      'rank': 62,
      'isAccepted': false,
    },
    {
      'code': 'az',
      'name': 'Azerbaijani',
      'native': 'Azərbaycanca',
      'speakers': '~12 Million speakers',
      'rank': 63,
      'isAccepted': false,
    },
    {
      'code': 'sr',
      'name': 'Serbian',
      'native': 'Српски',
      'speakers': '~12 Million speakers',
      'rank': 64,
      'isAccepted': false,
    },
    {
      'code': 'ht',
      'name': 'Haitian Creole',
      'native': 'Kreyòl Ayisyen',
      'speakers': '~12 Million speakers',
      'rank': 65,
      'isAccepted': false,
    },
    {
      'code': 'rw',
      'name': 'Kinyarwanda',
      'native': 'Ikinyarwanda',
      'speakers': '~12 Million speakers',
      'rank': 66,
      'isAccepted': false,
    },
    {
      'code': 'be',
      'name': 'Belarusian',
      'native': 'Беларуская',
      'speakers': '~10 Million speakers',
      'rank': 67,
      'isAccepted': false,
    },
    {
      'code': 'zu',
      'name': 'Zulu',
      'native': 'isiZulu',
      'speakers': '~10 Million speakers',
      'rank': 68,
      'isAccepted': false,
    },
    {
      'code': 'ca',
      'name': 'Catalan',
      'native': 'Català',
      'speakers': '~10 Million speakers',
      'rank': 69,
      'isAccepted': false,
    },
    {
      'code': 'ug',
      'name': 'Uyghur',
      'native': 'ئۇيղۇرچە',
      'speakers': '~10 Million speakers',
      'rank': 70,
      'isAccepted': false,
    },
    {
      'code': 'bg',
      'name': 'Bulgarian',
      'native': 'Български',
      'speakers': '~9 Million speakers',
      'rank': 71,
      'isAccepted': false,
    },
    {
      'code': 'iw',
      'name': 'Hebrew',
      'native': 'עברית',
      'speakers': '~9 Million speakers',
      'rank': 72,
      'isAccepted': false,
    },
    {
      'code': 'sn',
      'name': 'Shona',
      'native': 'Chishona',
      'speakers': '~9 Million speakers',
      'rank': 73,
      'isAccepted': false,
    },
    {
      'code': 'xh',
      'name': 'Xhosa',
      'native': 'isiXhosa',
      'speakers': '~8.2 Million speakers',
      'rank': 74,
      'isAccepted': false,
    },
    {
      'code': 'tg',
      'name': 'Tajik',
      'native': 'Тоҷикӣ',
      'speakers': '~8 Million speakers',
      'rank': 75,
      'isAccepted': false,
    },
    {
      'code': 'ks',
      'name': 'Kashmiri',
      'native': 'कॉशुर',
      'speakers': '~7 Million speakers',
      'rank': 76,
      'isAccepted': false,
    },
    {
      'code': 'da',
      'name': 'Danish',
      'native': 'Dansk',
      'speakers': '~6 Million speakers',
      'rank': 77,
      'isAccepted': false,
    },
    {
      'code': 'fi',
      'name': 'Finnish',
      'native': 'Suomi',
      'speakers': '~5.5 Million speakers',
      'rank': 78,
      'isAccepted': false,
    },
    {
      'code': 'sk',
      'name': 'Slovak',
      'native': 'Slovenčina',
      'speakers': '~5.5 Million speakers',
      'rank': 79,
      'isAccepted': false,
    },
    {
      'code': 'no',
      'name': 'Norwegian',
      'native': 'Norsk',
      'speakers': '~5.3 Million speakers',
      'rank': 80,
      'isAccepted': false,
    },
    {
      'code': 'hr',
      'name': 'Croatian',
      'native': 'Hrvatski',
      'speakers': '~5 Million speakers',
      'rank': 81,
      'isAccepted': false,
    },
    {
      'code': 'ky',
      'name': 'Kyrgyz',
      'native': 'Кыргызча',
      'speakers': '~5 Million speakers',
      'rank': 82,
      'isAccepted': false,
    },
    {
      'code': 'tt',
      'name': 'Tatar',
      'native': 'Татар',
      'speakers': '~5.2 Million speakers',
      'rank': 83,
      'isAccepted': false,
    },
    {
      'code': 'ka',
      'name': 'Georgian',
      'native': 'ქართული',
      'speakers': '~4 Million speakers',
      'rank': 84,
      'isAccepted': false,
    },
    {
      'code': 'hy',
      'name': 'Armenian',
      'native': 'Հայերեն',
      'speakers': '~3 Million speakers',
      'rank': 85,
      'isAccepted': false,
    },
    {
      'code': 'mn',
      'name': 'Mongolian',
      'native': 'Монгол',
      'speakers': '~3 Million speakers',
      'rank': 86,
      'isAccepted': false,
    },
    {
      'code': 'bs',
      'name': 'Bosnian',
      'native': 'Bosanski',
      'speakers': '~3 Million speakers',
      'rank': 87,
      'isAccepted': false,
    },
    {
      'code': 'sq',
      'name': 'Albanian',
      'native': 'Shqip',
      'speakers': '~3 Million speakers',
      'rank': 88,
      'isAccepted': false,
    },
    {
      'code': 'lt',
      'name': 'Lithuanian',
      'native': 'Lietuvių',
      'speakers': '~3 Million speakers',
      'rank': 89,
      'isAccepted': false,
    },
    {
      'code': 'gl',
      'name': 'Galician',
      'native': 'Galego',
      'speakers': '~2.4 Million speakers',
      'rank': 90,
      'isAccepted': false,
    },
    {
      'code': 'sl',
      'name': 'Slovenian',
      'native': 'Slovenščina',
      'speakers': '~2.5 Million speakers',
      'rank': 91,
      'isAccepted': false,
    },
    {
      'code': 'mk',
      'name': 'Macedonian',
      'native': 'Македонски',
      'speakers': '~2 Million speakers',
      'rank': 92,
      'isAccepted': false,
    },
    {
      'code': 'lv',
      'name': 'Latvian',
      'native': 'Latviešu',
      'speakers': '~1.8 Million speakers',
      'rank': 93,
      'isAccepted': false,
    },
    {
      'code': 'ga',
      'name': 'Irish',
      'native': 'Gaeilge',
      'speakers': '~1.2 Million speakers',
      'rank': 94,
      'isAccepted': false,
    },
    {
      'code': 'et',
      'name': 'Estonian',
      'native': 'Eesti',
      'speakers': '~1.1 Million speakers',
      'rank': 95,
      'isAccepted': false,
    },
    {
      'code': 'eu',
      'name': 'Basque',
      'native': 'Euskara',
      'speakers': '~900 Thousand speakers',
      'rank': 96,
      'isAccepted': false,
    },
    {
      'code': 'cy',
      'name': 'Welsh',
      'native': 'Cymraeg',
      'speakers': '~850 Thousand speakers',
      'rank': 97,
      'isAccepted': false,
    },
    {
      'code': 'yi',
      'name': 'Yiddish',
      'native': 'ייִדיש',
      'speakers': '~600 Thousand speakers',
      'rank': 98,
      'isAccepted': false,
    },
    {
      'code': 'mt',
      'name': 'Maltese',
      'native': 'Malti',
      'speakers': '~520 Thousand speakers',
      'rank': 99,
      'isAccepted': false,
    },
    {
      'code': 'is',
      'name': 'Icelandic',
      'native': 'Íslenska',
      'speakers': '~380 Thousand speakers',
      'rank': 100,
      'isAccepted': false,
    },
    {
      'code': 'lb',
      'name': 'Luxembourgish',
      'native': 'Lëtzebuergesch',
      'speakers': '~390 Thousand speakers',
      'rank': 101,
      'isAccepted': false,
    },
    {
      'code': 'sa',
      'name': 'Sanskrit',
      'native': 'संस्कृतम्',
      'speakers': 'Classical Language',
      'rank': 102,
      'isAccepted': false,
    },
    {
      'code': 'la',
      'name': 'Latin',
      'native': 'Latina',
      'speakers': 'Classical Language',
      'rank': 103,
      'isAccepted': false,
    },
    {
      'code': 'eo',
      'name': 'Esperanto',
      'native': 'Esperanto',
      'speakers': '~1 Million speakers',
      'rank': 104,
      'isAccepted': false,
    },
  ];

  Widget _buildLanguageContent(BuildContext context, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your channel language.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 15),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Truthworld is accepting only English as of now. All other languages are invite only.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showLanguagePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.language,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'English',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '#1 Worldwide • ~1.5B Speakers (Active)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Accepted',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final searchController = TextEditingController();
    final filteredLanguages = RxList<Map<String, dynamic>>(
      _worldLanguagesDescending,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: const Color(0xFF18181B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.language,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Channel Language',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Notice banner
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221A10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD97706).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Truthworld is accepting only English as of now. All other world languages are invite-only at this stage.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Search Field
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: searchController,
                      onChanged: (query) {
                        final q = query.trim().toLowerCase();
                        if (q.isEmpty) {
                          filteredLanguages.assignAll(
                            _worldLanguagesDescending,
                          );
                        } else {
                          filteredLanguages.assignAll(
                            _worldLanguagesDescending.where((lang) {
                              final name = (lang['name']! as String)
                                  .toLowerCase();
                              final native = (lang['native']! as String)
                                  .toLowerCase();
                              final code = (lang['code']! as String)
                                  .toLowerCase();
                              return name.contains(q) ||
                                  native.contains(q) ||
                                  code.contains(q);
                            }),
                          );
                        }
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search world languages...',
                        hintStyle: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF27272A), height: 1),
                Expanded(
                  child: Obx(
                    () => filteredLanguages.isEmpty
                        ? const Center(
                            child: Text(
                              'No language found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredLanguages.length,
                            separatorBuilder: (c, i) => const Divider(
                              color: Color(0xFF27272A),
                              height: 1,
                            ),
                            itemBuilder: (c, i) {
                              final lang = filteredLanguages[i];
                              final isEnglish = lang['code'] == 'en';
                              final rank = lang['rank'];
                              final name = lang['name']! as String;
                              final native = lang['native']! as String;
                              final speakers = lang['speakers']! as String;

                              return ListTile(
                                onTap: () {
                                  if (isEnglish) {
                                    controller.language.value = 'en';
                                    Navigator.pop(ctx);
                                  } else {
                                    _showInviteOnlyLanguageDialog(
                                      context,
                                      langName: name,
                                      nativeName: native,
                                      code: lang['code']! as String,
                                      speakers: speakers,
                                      rank: rank as int,
                                    );
                                  }
                                },
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isEnglish
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : const Color(0xFF1E1E22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#$rank',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isEnglish
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isEnglish
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isEnglish
                                              ? Colors.white
                                              : const Color(0xFFD4D4D8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '($native)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  speakers,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: isEnglish
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF15803D,
                                              ).withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF22C55E,
                                                ).withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: const Text(
                                              'Accepted',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF3F3F46,
                                              ).withValues(alpha: 0.4),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF52525B,
                                                ).withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.lock_outline,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Invite Only',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInviteOnlyLanguageDialog(
    BuildContext context, {
    required String langName,
    required String nativeName,
    required String code,
    required String speakers,
    required int rank,
  }) {
    final isSubmitting = false.obs;
    final isSubmitted = false.obs;

    showDialog<void>(
      context: context,
      builder: (ctx) => Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$langName is Invite-Only',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Truthworld currently accepts channel creation only in English.\n\n$langName ($nativeName) is ranked #$rank worldwide with $speakers. You can request language support below, and our admin team will review your request.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSubmitted.value
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSubmitted.value
                            ? 'Request submitted to admin for $langName! Your channel remains set to English.'
                            : 'Your channel language will remain set to English.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!isSubmitted.value) ...[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27272A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isSubmitting.value
                    ? null
                    : () async {
                        isSubmitting.value = true;
                        try {
                          final auth = Get.isRegistered<AuthService>()
                              ? AuthService.to
                              : null;
                          final currentUser = FirebaseAuth.instance.currentUser ??
                              auth?.currentUser.value;
                          final currentUid =
                              currentUser?.uid ?? auth?.uid ?? '';
                          final email = currentUser?.email ??
                              auth?.currentUser.value?.email ??
                              '';
                          final displayName = currentUser?.displayName ??
                              auth?.currentUser.value?.displayName ??
                              '';

                          if (currentUid.isEmpty) {
                            isSubmitting.value = false;
                            AppSnackbar.info(
                              'Please sign in to request language access.',
                              title: 'Sign In Required',
                            );
                            return;
                          }

                          // Check if a pending request already exists
                          final existing = await FirebaseFirestore.instance
                              .collection(
                                FirestoreCollections.channelLanguageRequests,
                              )
                              .where('userId', isEqualTo: currentUid)
                              .where('languageCode', isEqualTo: code)
                              .where('status', isEqualTo: 'pending')
                              .limit(1)
                              .get();

                          if (existing.docs.isNotEmpty) {
                            isSubmitting.value = false;
                            AppSnackbar.info(
                              'You already have a pending invite request for $langName.',
                              title: 'Request Already Pending',
                            );
                            return;
                          }

                          // Save request to Firestore
                          await FirebaseFirestore.instance
                              .collection(
                                FirestoreCollections.channelLanguageRequests,
                              )
                              .add({
                                'userId': currentUid,
                                'userEmail': email,
                                'userName': displayName,
                                'languageName': langName,
                                'languageNative': nativeName,
                                'languageCode': code,
                                'speakers': speakers,
                                'rank': rank,
                                'channelNameDraft': controller.channelName.text
                                    .trim(),
                                'status': 'pending',
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                          isSubmitted.value = true;
                          isSubmitting.value = false;

                          AppSnackbar.success(
                            'Your request for $langName has been submitted for review.',
                          );
                        } catch (e) {
                          isSubmitting.value = false;
                          ErrorHandler.log(e);
                          AppSnackbar.error(
                            'Unable to submit request. Please try again.',
                          );
                        }
                      },
                child: isSubmitting.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Request Invite'),
              ),
            ] else ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27272A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // CARD 9: CHANNEL PLAN
  // ========================================================================
}
