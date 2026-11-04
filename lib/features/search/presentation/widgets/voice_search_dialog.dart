import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Distinct lifecycle states for YouTube-style voice search
enum VoiceSearchState {
  initializing,
  listening,
  recognized,
  submitting,
  unrecognized,
  permissionDenied,
  error,
}

/// Controller managing speech recognition lifecycle, permissions, sound decibels,
/// and multilingual speech recognition locales across 100+ languages.
class VoiceSearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  VoiceSearchController({required this.onSearch, required this.context});

  final Function(String) onSearch;
  final BuildContext context;

  final stt.SpeechToText speech = stt.SpeechToText();
  final GetStorage _storage = GetStorage();

  static const String kVoiceLocaleIdKey = 'voice_search_selected_locale_id';
  static const String kVoiceLocaleNameKey = 'voice_search_selected_locale_name';

  final Rx<VoiceSearchState> voiceState = VoiceSearchState.initializing.obs;
  final RxString recognizedText = ''.obs;
  final RxDouble normalizedSoundLevel = 0.0.obs;
  final RxString rxErrorMessage = ''.obs;

  // Active language selection
  final RxString activeLocaleName = 'English (United States)'.obs;
  final RxString activeLocaleId = 'en_US'.obs;
  final RxList<stt.LocaleName> availableLocales = <stt.LocaleName>[].obs;

  late final AnimationController pulsateController;
  Timer? _silenceTimer;
  Timer? _maxListenTimer;
  bool _isSubmitting = false;
  bool _isDisposed = false;

  // Curated comprehensive global and Indian languages (120+ languages)
  static final List<stt.LocaleName> fallbackLocales = [
    // --- Indian Languages (All Eighth Schedule & Regional) ---
    stt.LocaleName('te_IN', 'Telugu (India)'),
    stt.LocaleName('hi_IN', 'Hindi (India)'),
    stt.LocaleName('ta_IN', 'Tamil (India)'),
    stt.LocaleName('kn_IN', 'Kannada (India)'),
    stt.LocaleName('ml_IN', 'Malayalam (India)'),
    stt.LocaleName('bn_IN', 'Bengali (India)'),
    stt.LocaleName('mr_IN', 'Marathi (India)'),
    stt.LocaleName('gu_IN', 'Gujarati (India)'),
    stt.LocaleName('pa_IN', 'Punjabi (India)'),
    stt.LocaleName('or_IN', 'Odia (India)'),
    stt.LocaleName('as_IN', 'Assamese (India)'),
    stt.LocaleName('ur_IN', 'Urdu (India)'),
    stt.LocaleName('ur_PK', 'Urdu (Pakistan)'),
    stt.LocaleName('ne_IN', 'Nepali (India)'),
    stt.LocaleName('ne_NP', 'Nepali (Nepal)'),
    stt.LocaleName('sa_IN', 'Sanskrit (India)'),
    stt.LocaleName('sd_IN', 'Sindhi (India)'),
    stt.LocaleName('ks_IN', 'Kashmiri (India)'),
    stt.LocaleName('kok_IN', 'Konkani (India)'),
    stt.LocaleName('mai_IN', 'Maithili (India)'),
    stt.LocaleName('doi_IN', 'Dogri (India)'),
    stt.LocaleName('mni_IN', 'Manipuri (India)'),
    stt.LocaleName('brx_IN', 'Bodo (India)'),
    stt.LocaleName('sat_IN', 'Santali (India)'),
    stt.LocaleName('bho_IN', 'Bhojpuri (India)'),

    // --- English Regional Variants ---
    stt.LocaleName('en_US', 'English (United States)'),
    stt.LocaleName('en_IN', 'English (India)'),
    stt.LocaleName('en_GB', 'English (United Kingdom)'),
    stt.LocaleName('en_AU', 'English (Australia)'),
    stt.LocaleName('en_CA', 'English (Canada)'),
    stt.LocaleName('en_IE', 'English (Ireland)'),
    stt.LocaleName('en_NZ', 'English (New Zealand)'),
    stt.LocaleName('en_SG', 'English (Singapore)'),
    stt.LocaleName('en_ZA', 'English (South Africa)'),
    stt.LocaleName('en_PH', 'English (Philippines)'),

    // --- Spanish Regional Variants ---
    stt.LocaleName('es_ES', 'Spanish (Spain)'),
    stt.LocaleName('es_US', 'Spanish (United States)'),
    stt.LocaleName('es_MX', 'Spanish (Mexico)'),
    stt.LocaleName('es_AR', 'Spanish (Argentina)'),
    stt.LocaleName('es_CO', 'Spanish (Colombia)'),
    stt.LocaleName('es_CL', 'Spanish (Chile)'),

    // --- French Regional Variants ---
    stt.LocaleName('fr_FR', 'French (France)'),
    stt.LocaleName('fr_CA', 'French (Canada)'),
    stt.LocaleName('fr_BE', 'French (Belgium)'),
    stt.LocaleName('fr_CH', 'French (Switzerland)'),

    // --- German Regional Variants ---
    stt.LocaleName('de_DE', 'German (Germany)'),
    stt.LocaleName('de_AT', 'German (Austria)'),
    stt.LocaleName('de_CH', 'German (Switzerland)'),

    // --- Chinese Variants ---
    stt.LocaleName('zh_CN', 'Chinese (Simplified)'),
    stt.LocaleName('cmn_CN', 'Chinese (Simplified Han, China)'),
    stt.LocaleName('zh_TW', 'Chinese (Traditional)'),
    stt.LocaleName('cmn_TW', 'Chinese (Traditional Han, Taiwan)'),
    stt.LocaleName('zh_HK', 'Chinese (Cantonese, Hong Kong)'),

    // --- Arabic Regional Variants ---
    stt.LocaleName('ar_SA', 'Arabic (Saudi Arabia)'),
    stt.LocaleName('ar_EG', 'Arabic (Egypt)'),
    stt.LocaleName('ar_AE', 'Arabic (United Arab Emirates)'),
    stt.LocaleName('ar_DZ', 'Arabic (Algeria)'),
    stt.LocaleName('ar_IQ', 'Arabic (Iraq)'),
    stt.LocaleName('ar_MA', 'Arabic (Morocco)'),

    // --- Portuguese Regional Variants ---
    stt.LocaleName('pt_BR', 'Portuguese (Brazil)'),
    stt.LocaleName('pt_PT', 'Portuguese (Portugal)'),

    // --- Major Global Languages ---
    stt.LocaleName('ja_JP', 'Japanese (Japan)'),
    stt.LocaleName('ko_KR', 'Korean (South Korea)'),
    stt.LocaleName('ru_RU', 'Russian (Russia)'),
    stt.LocaleName('it_IT', 'Italian (Italy)'),
    stt.LocaleName('it_CH', 'Italian (Switzerland)'),
    stt.LocaleName('tr_TR', 'Turkish (Turkey)'),
    stt.LocaleName('vi_VN', 'Vietnamese (Vietnam)'),
    stt.LocaleName('th_TH', 'Thai (Thailand)'),
    stt.LocaleName('id_ID', 'Indonesian (Indonesia)'),
    stt.LocaleName('nl_NL', 'Dutch (Netherlands)'),
    stt.LocaleName('nl_BE', 'Dutch (Belgium)'),
    stt.LocaleName('pl_PL', 'Polish (Poland)'),
    stt.LocaleName('sv_SE', 'Swedish (Sweden)'),
    stt.LocaleName('el_GR', 'Greek (Greece)'),
    stt.LocaleName('he_IL', 'Hebrew (Israel)'),
    stt.LocaleName('fa_IR', 'Persian (Iran)'),
    stt.LocaleName('uk_UA', 'Ukrainian (Ukraine)'),
    stt.LocaleName('fil_PH', 'Filipino (Philippines)'),
    stt.LocaleName('ms_MY', 'Malay (Malaysia)'),
    stt.LocaleName('cs_CZ', 'Czech (Czech Republic)'),
    stt.LocaleName('da_DK', 'Danish (Denmark)'),
    stt.LocaleName('fi_FI', 'Finnish (Finland)'),
    stt.LocaleName('ro_RO', 'Romanian (Romania)'),
    stt.LocaleName('hu_HU', 'Hungarian (Hungary)'),
    stt.LocaleName('nb_NO', 'Norwegian Bokmål (Norway)'),
    stt.LocaleName('sk_SK', 'Slovak (Slovakia)'),
    stt.LocaleName('hr_HR', 'Croatian (Croatia)'),
    stt.LocaleName('bg_BG', 'Bulgarian (Bulgaria)'),
    stt.LocaleName('sr_RS', 'Serbian (Serbia)'),
    stt.LocaleName('sl_SI', 'Slovenian (Slovenia)'),
    stt.LocaleName('lt_LT', 'Lithuanian (Lithuania)'),
    stt.LocaleName('lv_LV', 'Latvian (Latvia)'),
    stt.LocaleName('et_EE', 'Estonian (Estonia)'),
    stt.LocaleName('si_LK', 'Sinhala (Sri Lanka)'),
    stt.LocaleName('sw_KE', 'Swahili (Kenya)'),
    stt.LocaleName('sw_TZ', 'Swahili (Tanzania)'),
    stt.LocaleName('my_MM', 'Burmese (Myanmar)'),
    stt.LocaleName('kk_KZ', 'Kazakh (Kazakhstan)'),
    stt.LocaleName('uz_UZ', 'Uzbek (Uzbekistan)'),
    stt.LocaleName('az_AZ', 'Azerbaijani (Azerbaijan)'),
    stt.LocaleName('hy_AM', 'Armenian (Armenia)'),
    stt.LocaleName('ka_GE', 'Georgian (Georgia)'),
    stt.LocaleName('am_ET', 'Amharic (Ethiopia)'),
    stt.LocaleName('so_SO', 'Somali (Somalia)'),
    stt.LocaleName('zu_ZA', 'Zulu (South Africa)'),
    stt.LocaleName('af_ZA', 'Afrikaans (South Africa)'),
    stt.LocaleName('sq_AL', 'Albanian (Albania)'),
    stt.LocaleName('eu_ES', 'Basque (Spain)'),
    stt.LocaleName('be_BY', 'Belarusian (Belarus)'),
    stt.LocaleName('bs_BA', 'Bosnian (Bosnia and Herzegovina)'),
    stt.LocaleName('ca_ES', 'Catalan (Spain)'),
    stt.LocaleName('gl_ES', 'Galician (Spain)'),
    stt.LocaleName('is_IS', 'Icelandic (Iceland)'),
    stt.LocaleName('ga_IE', 'Irish (Ireland)'),
    stt.LocaleName('jv_ID', 'Javanese (Indonesia)'),
    stt.LocaleName('su_ID', 'Sundanese (Indonesia)'),
    stt.LocaleName('km_KH', 'Khmer (Cambodia)'),
    stt.LocaleName('ku_TR', 'Kurdish (Turkey)'),
    stt.LocaleName('lo_LA', 'Lao (Laos)'),
    stt.LocaleName('mk_MK', 'Macedonian (North Macedonia)'),
    stt.LocaleName('mt_MT', 'Maltese (Malta)'),
    stt.LocaleName('mn_MN', 'Mongolian (Mongolia)'),
    stt.LocaleName('ps_AF', 'Pashto (Afghanistan)'),
    stt.LocaleName('cy_GB', 'Welsh (United Kingdom)'),
    stt.LocaleName('tg_TJ', 'Tajik (Tajikistan)'),
    stt.LocaleName('tt_RU', 'Tatar (Russia)'),
    stt.LocaleName('tk_TM', 'Turkmen (Turkmenistan)'),
    stt.LocaleName('ug_CN', 'Uyghur (China)'),
    stt.LocaleName('xh_ZA', 'Xhosa (South Africa)'),
    stt.LocaleName('yi_001', 'Yiddish'),
    stt.LocaleName('yo_NG', 'Yoruba (Nigeria)'),
    stt.LocaleName('ceb_PH', 'Cebuano (Philippines)'),
    stt.LocaleName('ht_HT', 'Haitian Creole (Haiti)'),
    stt.LocaleName('haw_US', 'Hawaiian (United States)'),
    stt.LocaleName('hmn_CN', 'Hmong'),
    stt.LocaleName('ig_NG', 'Igbo (Nigeria)'),
    stt.LocaleName('rw_RW', 'Kinyarwanda (Rwanda)'),
    stt.LocaleName('lb_LU', 'Luxembourgish (Luxembourg)'),
    stt.LocaleName('mg_MG', 'Malagasy (Madagascar)'),
    stt.LocaleName('mi_NZ', 'Maori (New Zealand)'),
    stt.LocaleName('sm_WS', 'Samoan (Samoa)'),
    stt.LocaleName('gd_GB', 'Scottish Gaelic (United Kingdom)'),
    stt.LocaleName('st_ZA', 'Sesotho (South Africa)'),
    stt.LocaleName('sn_ZW', 'Shona (Zimbabwe)'),
    stt.LocaleName('la_001', 'Latin'),
    stt.LocaleName('co_FR', 'Corsican (France)'),
    stt.LocaleName('fy_NL', 'Western Frisian (Netherlands)'),
    stt.LocaleName('ny_MW', 'Chichewa (Malawi)'),
    stt.LocaleName('eo_001', 'Esperanto'),
  ];

  static final Map<String, String> _nativeNames = {
    // Indian Languages
    'te_in': 'తెలుగు',
    'hi_in': 'हिन्दी',
    'ta_in': 'தமிழ்',
    'kn_in': 'ಕನ್ನಡ',
    'ml_in': 'മലയാളം',
    'bn_in': 'বাংলা',
    'mr_in': 'मराठी',
    'gu_in': 'ગુજરાતી',
    'pa_in': 'ਪੰਜਾਬੀ',
    'or_in': 'ଓଡ଼ିଆ',
    'as_in': 'অসমীয়া',
    'ur_in': 'اردو',
    'ur_pk': 'اردو',
    'ne_in': 'नेपाली',
    'ne_np': 'नेपाली',
    'sa_in': 'संस्कृतम्',
    'sd_in': 'سنڌي',
    'ks_in': 'کٲشُر',
    'kok_in': 'कोंकणी',
    'mai_in': 'मैथिली',
    'doi_in': 'डोगरी',
    'mni_in': 'মৈতৈলোন্',
    'brx_in': 'बड़ो',
    'sat_in': 'ᱥᱟᱱᱛᱟᱲᱤ',
    'bho_in': 'भोजपुरी',

    // Global Languages
    'en_us': 'English',
    'en_in': 'English (India)',
    'en_gb': 'English (UK)',
    'en_au': 'English (AU)',
    'en_ca': 'English (CA)',
    'en_ie': 'English (IE)',
    'en_nz': 'English (NZ)',
    'en_sg': 'English (SG)',
    'en_za': 'English (ZA)',
    'en_ph': 'English (PH)',
    'es_es': 'Español',
    'es_us': 'Español (EE.UU.)',
    'es_mx': 'Español (México)',
    'es_ar': 'Español (Argentina)',
    'es_co': 'Español (Colombia)',
    'es_cl': 'Español (Chile)',
    'fr_fr': 'Français',
    'fr_ca': 'Français (Canada)',
    'fr_be': 'Français (Belgique)',
    'fr_ch': 'Français (Suisse)',
    'de_de': 'Deutsch',
    'de_at': 'Deutsch (Österreich)',
    'de_ch': 'Deutsch (Schweiz)',
    'zh_cn': '中文 (简体)',
    'cmn_cn': '中文 (普通话)',
    'zh_tw': '中文 (繁體)',
    'cmn_tw': '中文 (台灣國語)',
    'zh_hk': '粵語 (香港)',
    'yue_hk': '粵語 (香港)',
    'ja_jp': '日本語',
    'ko_kr': '한국어',
    'ru_ru': 'Русский',
    'ar_sa': 'العربية',
    'ar_eg': 'العربية (مصر)',
    'ar_ae': 'العربية (الإمارات)',
    'ar_dz': 'العربية (الجزائر)',
    'ar_iq': 'العربية (العراق)',
    'ar_ma': 'العربية (المغرب)',
    'pt_br': 'Português (Brasil)',
    'pt_pt': 'Português (Portugal)',
    'it_it': 'Italiano',
    'it_ch': 'Italiano (Svizzera)',
    'tr_tr': 'Türkçe',
    'vi_vn': 'Tiếng Việt',
    'th_th': 'ไทย',
    'id_id': 'Bahasa Indonesia',
    'nl_nl': 'Nederlands',
    'nl_be': 'Nederlands (België)',
    'pl_pl': 'Polski',
    'sv_se': 'Svenska',
    'el_gr': 'Ελληνικά',
    'he_il': 'עברית',
    'fa_ir': 'فارسی',
    'uk_ua': 'Українська',
    'fil_ph': 'Filipino',
    'ms_my': 'Bahasa Melayu',
    'cs_cz': 'Čeština',
    'da_dk': 'Dansk',
    'fi_fi': 'Suomi',
    'ro_ro': 'Română',
    'hu_hu': 'Magyar',
    'nb_no': 'Norsk bokmål',
    'sk_sk': 'Slovenčina',
    'hr_hr': 'Hrvatski',
    'bg_bg': 'Български',
    'sr_rs': 'Српски',
    'sl_si': 'Slovenščina',
    'lt_lt': 'Lietuvių',
    'lv_lv': 'Latviešu',
    'et_ee': 'Eesti',
    'si_lk': 'සිංහල',
    'sw_ke': 'Kiswahili',
    'sw_tz': 'Kiswahili',
    'my_mm': 'မြန်မာ',
    'kk_kz': 'Қазақша',
    'uz_uz': 'Oʻzbekcha',
    'az_az': 'Azərbaycan',
    'hy_am': 'Հայերեն',
    'ka_ge': 'ქართული',
    'am_et': 'አማርኛ',
    'so_so': 'Soomaali',
    'zu_za': 'isiZulu',
    'af_za': 'Afrikaans',
    'sq_al': 'Shqip',
    'eu_es': 'Euskara',
    'be_by': 'Беларуская',
    'bs_ba': 'Bosanski',
    'ca_es': 'Català',
    'gl_es': 'Galego',
    'is_is': 'Íslenska',
    'ga_ie': 'Gaeilge',
    'jv_id': 'Basa Jawa',
    'km_kh': 'ភាសាខ្មែរ',
    'ku_tr': 'Kurdî',
    'lo_la': 'ພາສາລາວ',
    'mk_mk': 'Македонски',
    'mt_mt': 'Malti',
    'mn_mn': 'Монгол',
    'ps_af': 'پښتو',
    'cy_gb': 'Cymraeg',
    'su_id': 'Basa Sunda',
    'tg_tj': 'Тоҷикӣ',
    'tt_ru': 'Татарча',
    'tk_tm': 'Türkmençe',
    'ug_cn': 'ئۇيغۇرچە',
    'xh_za': 'isiXhosa',
    'yi_001': 'ייִדיש',
    'yo_ng': 'Èdè Yorùbá',
    'ceb_ph': 'Sinugboanon',
    'ht_ht': 'Kreyòl ayisyen',
    'haw_us': 'ʻŌlelo Hawaiʻi',
    'hmn_cn': 'Hmoob',
    'ig_ng': 'Asụsụ Igbo',
    'rw_rw': 'Ikinyarwanda',
    'lb_lu': 'Lëtzebuergesch',
    'mg_mg': 'Malagasy',
    'mi_nz': 'Te Reo Māori',
    'sm_ws': 'Gagana Sāmoa',
    'gd_gb': 'Gàidhlig',
    'st_za': 'Sesotho',
    'sn_zw': 'chiShona',
    'la_001': 'Latina',
    'co_fr': 'Corsu',
    'fy_nl': 'Frysk',
    'ny_mw': 'Chinyanja',
    'eo_001': 'Esperanto',
  };

  /// Retrieves the localized native name for a given locale ID
  static String getNativeName(String localeId) {
    final key = localeId.toLowerCase().replaceAll('-', '_');
    if (_nativeNames.containsKey(key)) {
      return _nativeNames[key]!;
    }
    final prefix = key.split('_').first;
    for (final entry in _nativeNames.entries) {
      if (entry.key.startsWith('${prefix}_')) {
        return entry.value;
      }
    }
    return '';
  }

  /// Merges hardware device locales with TruthWorld's 120+ language catalog.
  /// Never drops canonical languages, ensuring all required Indian and global
  /// languages remain accessible regardless of OEM hardware limits.
  static List<stt.LocaleName> buildLocalesList(List<stt.LocaleName> deviceLocales) {
    final Map<String, stt.LocaleName> map = {};

    // 1. Add all canonical supported locales
    for (final loc in fallbackLocales) {
      final key = loc.localeId.toLowerCase().replaceAll('-', '_');
      map[key] = loc;
    }

    // 2. Merge in device-reported locales (e.g. cmn_CN, regional English variants)
    for (final dev in deviceLocales) {
      final key = dev.localeId.toLowerCase().replaceAll('-', '_');
      if (!map.containsKey(key)) {
        map[key] = dev;
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // Sample prompt suggestions shown when waiting/retrying
  final List<String> suggestions = const [
    'Flutter tutorials',
    'Latest news',
    'Tech innovations',
    'Documentaries',
    'Trending topics',
  ];

  @override
  void onInit() {
    super.onInit();
    pulsateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    initAndStartListening();
  }

  @override
  void onClose() {
    _isDisposed = true;
    _cancelTimers();
    try {
      speech.stop();
      speech.cancel();
    } catch (_) {}
    pulsateController.dispose();
    super.onClose();
  }

  void _cancelTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxListenTimer?.cancel();
    _maxListenTimer = null;
  }

  /// Proactively verify & request microphone permission, then initialize STT engine
  Future<void> initAndStartListening() async {
    if (_isDisposed) return;
    voiceState.value = VoiceSearchState.initializing;
    rxErrorMessage.value = '';
    recognizedText.value = '';
    normalizedSoundLevel.value = 0.0;
    _isSubmitting = false;

    // 1. Check microphone permission (on mobile platforms)
    if (!kIsWeb) {
      final status = await Permission.microphone.status;
      if (status.isPermanentlyDenied || status.isRestricted) {
        voiceState.value = VoiceSearchState.permissionDenied;
        rxErrorMessage.value =
            'Microphone access is disabled. Please enable it in device Settings to search with your voice.';
        return;
      }

      if (!status.isGranted) {
        final reqStatus = await Permission.microphone.request();
        if (reqStatus.isPermanentlyDenied || reqStatus.isRestricted) {
          voiceState.value = VoiceSearchState.permissionDenied;
          rxErrorMessage.value =
              'Microphone access is disabled. Please enable it in device Settings to search with your voice.';
          return;
        }
        if (!reqStatus.isGranted) {
          voiceState.value = VoiceSearchState.permissionDenied;
          rxErrorMessage.value =
              'Microphone permission is required to search with your voice.';
          return;
        }
      }
    }

    // 2. Initialize STT engine
    try {
      final isAvailable = await speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );

      if (_isDisposed) return;

      if (!isAvailable) {
        voiceState.value = VoiceSearchState.error;
        rxErrorMessage.value =
            'Voice search is not available on this device right now.';
        return;
      }

      // 3. Resolve preferred locale and fetch all available device locales
      try {
        final deviceLocales = await speech.locales();
        availableLocales.assignAll(VoiceSearchController.buildLocalesList(deviceLocales));
      } catch (_) {
        availableLocales.assignAll(VoiceSearchController.buildLocalesList([]));
      }

      _resolveInitialLocale();

      // 4. Start active listening in the resolved locale
      await startListening();
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('🎙️ [VoiceSearch] Error during init: $e');
      voiceState.value = VoiceSearchState.error;
      rxErrorMessage.value = 'Failed to start voice search. Tap mic to retry.';
    }
  }

  /// Intelligently resolves initial recognition language:
  /// 1. Explicitly saved user choice from previous session
  /// 2. User profile primary language (UserLanguagesService)
  /// 3. Device system locale
  /// 4. Global fallback (English)
  void _resolveInitialLocale() {
    // 1. Check user explicitly saved preference in previous sessions
    final savedId = _storage.read(kVoiceLocaleIdKey) as String?;
    final savedName = _storage.read(kVoiceLocaleNameKey) as String?;
    if (savedId != null && savedId.isNotEmpty) {
      final match =
          availableLocales.firstWhereOrNull((l) => l.localeId == savedId);
      if (match != null) {
        activeLocaleId.value = match.localeId;
        activeLocaleName.value = match.name;
        return;
      } else if (savedName != null && savedName.isNotEmpty) {
        activeLocaleId.value = savedId;
        activeLocaleName.value = savedName;
        return;
      }
    }

    // 2. Check user's TruthWorld profile primary language
    if (Get.isRegistered<UserLanguagesService>()) {
      final userPrimary =
          UserLanguagesService.to.primaryLanguage.value.toLowerCase().trim();
      if (userPrimary.isNotEmpty) {
        final match = availableLocales.firstWhereOrNull((l) {
          final lName = l.name.toLowerCase();
          final lId = l.localeId.toLowerCase();
          return lName.contains(userPrimary) ||
              (userPrimary.length >= 2 &&
                  lId.startsWith(userPrimary.substring(0, 2)));
        });
        if (match != null) {
          activeLocaleId.value = match.localeId;
          activeLocaleName.value = match.name;
          return;
        }
      }
    }

    // 3. Match device system locale
    try {
      final devLocale = Get.deviceLocale;
      if (devLocale != null) {
        final lang = devLocale.languageCode.toLowerCase();
        final country = devLocale.countryCode?.toLowerCase() ?? '';
        final fullTag = country.isNotEmpty ? '${lang}_$country' : lang;

        // Exact match with country (e.g. en_in, hi_in, en_us)
        final exact = availableLocales.firstWhereOrNull(
          (l) => l.localeId.toLowerCase() == fullTag,
        );
        if (exact != null) {
          activeLocaleId.value = exact.localeId;
          activeLocaleName.value = exact.name;
          return;
        }

        // Language-only match (e.g. en, hi, te)
        final langMatch = availableLocales.firstWhereOrNull(
          (l) => l.localeId.toLowerCase().startsWith(lang),
        );
        if (langMatch != null) {
          activeLocaleId.value = langMatch.localeId;
          activeLocaleName.value = langMatch.name;
          return;
        }
      }
    } catch (_) {}

    // 4. Default to first available or English
    final english = availableLocales.firstWhereOrNull(
      (l) => l.localeId.toLowerCase() == 'en_us' || l.localeId.toLowerCase() == 'en_in',
    );
    if (english != null) {
      activeLocaleId.value = english.localeId;
      activeLocaleName.value = english.name;
    } else if (availableLocales.isNotEmpty) {
      activeLocaleId.value = availableLocales.first.localeId;
      activeLocaleName.value = availableLocales.first.name;
    }
  }

  /// Switch the active recognition language, persist preference, and re-listen
  void changeLocale(stt.LocaleName locale) {
    if (_isDisposed) return;
    activeLocaleId.value = locale.localeId;
    activeLocaleName.value = locale.name;

    // Persist choice across sessions ($0 external config cost)
    _storage.write(kVoiceLocaleIdKey, locale.localeId);
    _storage.write(kVoiceLocaleNameKey, locale.name);

    // If currently listening, seamlessly restart with the new language
    if (voiceState.value == VoiceSearchState.listening ||
        voiceState.value == VoiceSearchState.recognized ||
        voiceState.value == VoiceSearchState.unrecognized) {
      startListening();
    }
  }

  /// Opens the YouTube-style interactive language selector bottom sheet
  void openLanguagePicker(BuildContext context) {
    Get.bottomSheet(
      VoiceSearchLanguagePickerSheet(voiceController: this),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
    );
  }

  /// Begin actively recording audio and transcribing words
  Future<void> startListening() async {
    if (_isDisposed) return;
    _cancelTimers();
    _isSubmitting = false;
    rxErrorMessage.value = '';
    recognizedText.value = '';
    normalizedSoundLevel.value = 0.0;
    voiceState.value = VoiceSearchState.listening;

    try {
      if (speech.isListening) {
        await speech.stop();
      }

      await speech.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: _handleSoundLevel,
        localeId: activeLocaleId.value,
        listenMode: stt.ListenMode.search,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
      );

      // Max listening safety fallback timeout
      _maxListenTimer = Timer(const Duration(seconds: 20), () {
        if (_isDisposed || _isSubmitting) return;
        if (recognizedText.value.trim().isNotEmpty) {
          submitSearch(recognizedText.value);
        } else {
          stopListening(promptUnrecognized: true);
        }
      });
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('🎙️ [VoiceSearch] Exception in startListening: $e');
      voiceState.value = VoiceSearchState.error;
      rxErrorMessage.value = 'Unable to listen. Tap the microphone to retry.';
    }
  }

  /// Strips trailing/leading punctuation marks (. ? ! , ; : - _ etc.) and collapses whitespace across all languages
  static String sanitizeQuery(String text) {
    var cleaned = text.trim();
    // Strip trailing punctuation marks across all languages (including Arabic ؟, Spanish ¿, CJK 。, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'[\p{P}\p{S}\s]+$', unicode: true), '').trim();
    // Strip leading punctuation marks
    cleaned = cleaned.replaceAll(RegExp(r'^[\p{P}\p{S}\s]+', unicode: true), '').trim();
    // Collapse multiple whitespaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  /// Handles incoming streaming recognition result
  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (_isDisposed || _isSubmitting) return;

    final words = sanitizeQuery(result.recognizedWords);
    if (words.isNotEmpty) {
      recognizedText.value = words;
      voiceState.value = VoiceSearchState.recognized;

      // Reset silence debounce timer on every spoken phrase (YouTube 1:1 feel)
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(milliseconds: 950), () {
        if (_isDisposed || _isSubmitting) return;
        if (recognizedText.value.trim().isNotEmpty) {
          submitSearch(recognizedText.value);
        }
      });
    }

    if (result.finalResult && words.isNotEmpty) {
      submitSearch(words);
    }
  }

  /// Normalizes hardware decibels into a smooth 0.0 .. 1.0 curve for wave animation
  void _handleSoundLevel(double level) {
    if (_isDisposed || voiceState.value != VoiceSearchState.listening) return;

    // Standardize decibels across iOS (-60..0), Android (-2..10), and Web (0..1)
    double normalized;
    if (level < 0) {
      normalized = ((level + 60.0) / 60.0).clamp(0.0, 1.0);
    } else if (level <= 1.0) {
      normalized = level.clamp(0.0, 1.0);
    } else {
      normalized = (level / 10.0).clamp(0.0, 1.0);
    }

    // Apply exponential ease-out curve for natural visual bounce
    final eased = math.pow(normalized, 0.7).toDouble();
    normalizedSoundLevel.value = eased;
  }

  /// Handles speech engine status transitions
  void _handleStatus(String status) {
    if (_isDisposed) return;
    debugPrint('🎙️ [VoiceSearch] Engine Status: $status');

    if (status == 'listening') {
      if (voiceState.value != VoiceSearchState.recognized) {
        voiceState.value = VoiceSearchState.listening;
      }
    } else if (status == 'notListening' || status == 'done') {
      if (_isSubmitting) return;

      if (recognizedText.value.trim().isNotEmpty) {
        submitSearch(recognizedText.value);
      } else if (voiceState.value == VoiceSearchState.listening) {
        voiceState.value = VoiceSearchState.unrecognized;
      }
    }
  }

  /// Handles speech recognition engine errors gracefully
  void _handleError(SpeechRecognitionError error) {
    if (_isDisposed) return;
    debugPrint(
        '🎙️ [VoiceSearch] Recognition Error: ${error.errorMsg} (permanent: ${error.permanent})');

    if (_isSubmitting) return;

    if (recognizedText.value.trim().isNotEmpty) {
      submitSearch(recognizedText.value);
      return;
    }

    if (error.errorMsg == 'error_permission') {
      voiceState.value = VoiceSearchState.permissionDenied;
      rxErrorMessage.value =
          'Microphone permission is required. Please grant permission to search by voice.';
    } else if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      voiceState.value = VoiceSearchState.unrecognized;
    } else {
      voiceState.value = VoiceSearchState.error;
      rxErrorMessage.value =
          "Didn't catch that. Tap the microphone to try again.";
    }
  }

  /// Stop listening manually
  Future<void> stopListening({bool promptUnrecognized = false}) async {
    _cancelTimers();
    try {
      await speech.stop();
    } catch (_) {}

    if (_isDisposed) return;
    normalizedSoundLevel.value = 0.0;

    if (recognizedText.value.trim().isNotEmpty) {
      submitSearch(recognizedText.value);
    } else if (promptUnrecognized) {
      voiceState.value = VoiceSearchState.unrecognized;
    }
  }

  /// Submit finalized query to search page and close modal
  void submitSearch(String query) {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.isEmpty || _isSubmitting || _isDisposed) return;

    _isSubmitting = true;
    _cancelTimers();
    voiceState.value = VoiceSearchState.submitting;

    try {
      speech.stop();
    } catch (_) {}

    // Short tactile pause before dismissing
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isDisposed) return;
      onSearch(cleanQuery);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Toggle or retry listening on tapping the center mic button
  void onMicButtonTapped() {
    if (voiceState.value == VoiceSearchState.listening ||
        voiceState.value == VoiceSearchState.recognized) {
      if (recognizedText.value.trim().isNotEmpty) {
        submitSearch(recognizedText.value);
      } else {
        stopListening(promptUnrecognized: true);
      }
    } else if (voiceState.value == VoiceSearchState.permissionDenied) {
      openAppSettings();
    } else {
      startListening();
    }
  }
}

/// Controller managing language filter and selection within the picker bottom sheet
class VoiceSearchLanguagePickerController extends GetxController {
  VoiceSearchLanguagePickerController({required this.voiceController});

  final VoiceSearchController voiceController;
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  List<stt.LocaleName> get filteredLocales {
    final query = searchQuery.value.trim().toLowerCase();
    final all = voiceController.availableLocales;
    if (query.isEmpty) {
      final activeId = voiceController.activeLocaleId.value.toLowerCase();
      final selected = all.firstWhereOrNull(
        (l) => l.localeId.toLowerCase() == activeId,
      );
      if (selected != null) {
        final rest = all.where((l) => l.localeId.toLowerCase() != activeId).toList();
        return [selected, ...rest];
      }
      return all;
    }
    return all.where((l) {
      final nameMatches = l.name.toLowerCase().contains(query);
      final idMatches = l.localeId.toLowerCase().contains(query);
      final native = VoiceSearchController.getNativeName(l.localeId).toLowerCase();
      final nativeMatches = native.isNotEmpty && native.contains(query);
      return nameMatches || idMatches || nativeMatches;
    }).toList();
  }
}

/// YouTube-style Multilingual Language Picker Bottom Sheet
class VoiceSearchLanguagePickerSheet extends StatelessWidget {
  const VoiceSearchLanguagePickerSheet({
    required this.voiceController,
    super.key,
  });

  final VoiceSearchController voiceController;

  static String _buildSubtitle(stt.LocaleName item) {
    final native = VoiceSearchController.getNativeName(item.localeId);
    if (native.isNotEmpty && !item.name.contains(native)) {
      return '${item.localeId} • $native';
    }
    return item.localeId;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VoiceSearchLanguagePickerController>(
      init: VoiceSearchLanguagePickerController(
          voiceController: voiceController),
      dispose: (_) {
        if (Get.isRegistered<VoiceSearchLanguagePickerController>()) {
          Get.delete<VoiceSearchLanguagePickerController>();
        }
      },
      builder: (pickerController) {
        final screenHeight = MediaQuery.of(context).size.height;

        return Container(
          height: screenHeight * 0.72,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Top Drag Handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select spoken language',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: Get.back,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Instant Language Search Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: pickerController.searchController,
                          onChanged: (val) =>
                              pickerController.searchQuery.value = val,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Search languages (e.g. Spanish, Hindi)...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Obx(() {
                        if (pickerController.searchQuery.value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: () {
                            pickerController.searchController.clear();
                            pickerController.searchQuery.value = '';
                          },
                        );
                      }),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),

              // Multilingual Locales List
              Expanded(
                child: Obx(() {
                  final list = pickerController.filteredLocales;
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching languages found',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Colors.white10,
                      height: 1,
                      indent: 64,
                    ),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final isSelected =
                          voiceController.activeLocaleId.value == item.localeId;

                      return ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFCC0000).withValues(alpha: 0.25)
                                : const Color(0xFF2A2A2A),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.language_rounded,
                            color: isSelected
                                ? const Color(0xFFFF4D4D)
                                : Colors.white70,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          _buildSubtitle(item),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFFCC0000),
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          voiceController.changeLocale(item);
                          Get.back();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Voice Search Dialog Widget (1:1 YouTube Parity with Multilingual Speech Recognition)
class VoiceSearchDialog extends StatelessWidget {
  const VoiceSearchDialog({required this.onSearch, super.key});
  final Function(String) onSearch;

  VoiceSearchController get controller => Get.find<VoiceSearchController>();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VoiceSearchController>(
      init: VoiceSearchController(onSearch: onSearch, context: context),
      dispose: (_) {
        if (Get.isRegistered<VoiceSearchController>()) {
          Get.delete<VoiceSearchController>();
        }
      },
      builder: (controller) {
        // Dark background color matching YouTube mobile app (#0F0F0F)
        const darkBackground = Color(0xFF0F0F0F);

        return Scaffold(
          backgroundColor: darkBackground,
          body: SafeArea(
            child: Stack(
              children: [
                // Top App Bar with Language Switcher and Close Button
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Voice Search Status Headline
                      Obx(() {
                        final currentState = controller.voiceState.value;
                        var headerText = 'Search with your voice';
                        if (currentState == VoiceSearchState.listening ||
                            currentState == VoiceSearchState.recognized) {
                          headerText = 'Listening...';
                        } else if (currentState ==
                            VoiceSearchState.submitting) {
                          headerText = 'Searching...';
                        }

                        return Text(
                          headerText,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Language Switcher Icon Button (Top Right)
                          IconButton(
                            icon: const Icon(
                              Icons.language_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () =>
                                controller.openLanguagePicker(context),
                            splashRadius: 22,
                            tooltip: 'Select language',
                          ),

                          // Close IconButton (Top Right)
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              controller.stopListening();
                              Get.back();
                            },
                            splashRadius: 22,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Center & Bottom Area
                Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: Column(
                    children: [
                      // Center Spoken Query Display / Prompt View
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Obx(_buildCenterContent),
                          ),
                        ),
                      ),

                      // Bottom Section: Red Animated Sound Wave Mic Button & Interactive Locale Pill
                      _buildBottomSection(context),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the main prompt / transcription view based on controller state
  Widget _buildCenterContent() {
    final currentState = controller.voiceState.value;
    final text = controller.recognizedText.value;

    switch (currentState) {
      case VoiceSearchState.initializing:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Listening...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );

      case VoiceSearchState.listening:
      case VoiceSearchState.recognized:
      case VoiceSearchState.submitting:
        if (text.isEmpty) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Listening...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Say something to search',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.35,
              letterSpacing: 0.1,
            ),
          ),
        );

      case VoiceSearchState.unrecognized:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Didn't hear that. Try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap the microphone to speak',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            // Sample suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: controller.suggestions.map((sug) {
                return ActionChip(
                  label: Text(
                    sug,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: const Color(0xFF272727),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onPressed: () {
                    controller.submitSearch(sug);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case VoiceSearchState.permissionDenied:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF272727),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_off_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Microphone access needed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                controller.rxErrorMessage.value.isNotEmpty
                    ? controller.rxErrorMessage.value
                    : 'To search by voice, please grant microphone permissions.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: openAppSettings,
              icon: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Open Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3EA6FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        );

      case VoiceSearchState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              controller.rxErrorMessage.value.isNotEmpty
                  ? controller.rxErrorMessage.value
                  : 'An error occurred during speech recognition.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: controller.initAndStartListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF272727),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
    }
  }

  /// Builds Animated Red Sound Wave Mic Button & Interactive Multilingual Pill
  Widget _buildBottomSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // YouTube Red Pulsating Mic Button
        Obx(() {
          final currentState = controller.voiceState.value;
          final isListening = currentState == VoiceSearchState.listening ||
              currentState == VoiceSearchState.recognized;
          final soundValue = controller.normalizedSoundLevel.value;

          return GestureDetector(
            onTap: controller.onMicButtonTapped,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Wave Ring 3 (reacts to decibels + pulsate)
                  if (isListening)
                    AnimatedBuilder(
                      animation: controller.pulsateController,
                      builder: (context, child) {
                        final waveScale = 1.0 +
                            (soundValue * 0.45) +
                            (controller.pulsateController.value * 0.2);
                        return Transform.scale(
                          scale: waveScale,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF0000).withValues(
                                alpha: 0.12 + (soundValue * 0.1),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Middle Wave Ring 2
                  if (isListening)
                    AnimatedBuilder(
                      animation: controller.pulsateController,
                      builder: (context, child) {
                        final waveScale = 1.0 +
                            (soundValue * 0.3) +
                            (controller.pulsateController.value * 0.1);
                        return Transform.scale(
                          scale: waveScale,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF0000).withValues(
                                alpha: 0.22 + (soundValue * 0.15),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Inner Wave Ring 1
                  if (isListening)
                    Transform.scale(
                      scale: 1.0 + (soundValue * 0.18),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF0000).withValues(
                            alpha: 0.35 + (soundValue * 0.2),
                          ),
                        ),
                      ),
                    ),

                  // Center Red Microphone Action Button
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isListening
                          ? const Color(0xFFCC0000)
                          : const Color(0xFF272727),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isListening
                                  ? const Color(0xFFFF0000)
                                  : Colors.black)
                              .withValues(alpha: isListening ? 0.5 : 0.3),
                          blurRadius: isListening ? 16 : 8,
                          spreadRadius: isListening ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Interactive Spoken Language Pill at bottom (Tap to switch language)
        Obx(() {
          final locale = controller.activeLocaleName.value;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.openLanguagePicker(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        locale,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
