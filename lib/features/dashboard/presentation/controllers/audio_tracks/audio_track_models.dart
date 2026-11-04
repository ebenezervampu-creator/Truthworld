import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

/// Internal Audio Track layout representation for the studio preview editor
class AudioTrackItem {
  AudioTrackItem({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.audioUrl,
    this.isBaseTrack = false,
    this.isResolved = false,
    this.status = 'Published',
    this.role = 'Dubbing',
    this.generationProgress,
    this.generationStage,
    this.generationStep = 1,
    this.estimatedTimeRemaining,
  });

  String id;
  String languageCode;
  String languageName;
  String audioUrl;
  bool isBaseTrack;
  bool isResolved;
  String status; // 'Published', 'Draft', 'Not added', 'Generating...'
  String role; // 'Original video audio', 'Dubbing', etc.
  int? generationProgress;
  String? generationStage;
  int generationStep;
  String? estimatedTimeRemaining;
}

/// Reactive state tracking live progress, pipeline stages, and ETA for AI voice dubbing
class AudioDubbingProgressState {
  const AudioDubbingProgressState({
    required this.langCode,
    this.progress = 15,
    this.stageTitle = 'Analyzing & transcribing audio...',
    this.stageStep = 1,
    this.totalSteps = 4,
    this.totalStepsText = 'Step 1 of 4',
    this.etaText = '~15-30 sec',
    this.isGenerating = true,
    this.status = 'running',
    this.startedAt,
  });

  final String langCode;
  final int progress; // 0 to 100
  final String stageTitle; // e.g. "Translating dialogue to Telugu"
  final int stageStep; // 1: Transcribe, 2: Translate, 3: Synthesize, 4: Master & Sync
  final int totalSteps; // 4
  final String totalStepsText; // "Step 2 of 4"
  final String etaText; // "Ready in ~15-30 sec"
  final bool isGenerating;
  final String status;
  final DateTime? startedAt;

  AudioDubbingProgressState copyWith({
    int? progress,
    String? stageTitle,
    int? stageStep,
    int? totalSteps,
    String? totalStepsText,
    String? etaText,
    bool? isGenerating,
    String? status,
    DateTime? startedAt,
  }) {
    return AudioDubbingProgressState(
      langCode: langCode,
      progress: progress ?? this.progress,
      stageTitle: stageTitle ?? this.stageTitle,
      stageStep: stageStep ?? this.stageStep,
      totalSteps: totalSteps ?? this.totalSteps,
      totalStepsText: totalStepsText ?? this.totalStepsText,
      etaText: etaText ?? this.etaText,
      isGenerating: isGenerating ?? this.isGenerating,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// Commentary & Multi-Video track metadata item
class CommentaryTrackItem {
  CommentaryTrackItem({
    required this.id,
    required this.title,
    required this.role,
    required this.videoUrl,
    required this.langCode,
    this.audioUrl = '',
    this.uploadedAt = '',
    this.fileSizeMB = 0.0,
  });

  String id;
  String title;
  String role; // 'Director Commentary', 'Actors Commentary', 'Behind the Scenes', 'Alternate Angle', 'Dubbed Video', 'Voiceover Track'
  String videoUrl;
  String audioUrl;
  String langCode;
  String uploadedAt;
  double fileSizeMB;

  Map<String, String> toMap() => {
    'id': id,
    'title': title,
    'role': role,
    'videoUrl': videoUrl,
    'audioUrl': audioUrl,
    'langCode': langCode,
    'uploadedAt': uploadedAt,
    'fileSizeMB': fileSizeMB.toString(),
  };

  factory CommentaryTrackItem.fromMap(String key, Map<String, String> map) =>
      CommentaryTrackItem(
        id: map['id'] ?? key,
        title: map['title'] ?? 'Commentary Track',
        role: map['role'] ?? 'Director Commentary',
        videoUrl: map['videoUrl'] ?? '',
        audioUrl: map['audioUrl'] ?? '',
        langCode: map['langCode'] ?? 'en',
        uploadedAt: map['uploadedAt'] ?? '',
        fileSizeMB: double.tryParse(map['fileSizeMB'] ?? '0') ?? 0.0,
      );
}

/// Configuration entry for batch uploading multi-video and audio tracks
class BatchTrackUploadConfig {
  BatchTrackUploadConfig({
    required this.file,
    required this.title,
    required this.role,
    required this.type,
    required this.langCode,
    this.progress = 0.0,
    this.status = 'Pending',
  });

  PlatformFile file;
  String title;
  String role; // e.g. 'Director Commentary', 'Actors Commentary', 'Behind the Scenes', 'Alternate Angle', 'Dubbed Video'
  String type; // 'Video' or 'Audio'
  String langCode;
  double progress;
  String status;
}

/// Pre-configured multi-language code dictionary mapping for 70+ AI Voice Dubbing languages
const List<({String code, String name})> kSupportedLanguages = [
  // Global & Widely Used
  (code: 'en', name: 'English (Base)'),
  (code: 'zh', name: 'Chinese (中文 / Mandarin)'),
  (code: 'es', name: 'Spanish (Español)'),
  (code: 'fr', name: 'French (Français)'),
  (code: 'de', name: 'German (Deutsch)'),
  (code: 'ja', name: 'Japanese (日本語)'),
  (code: 'ko', name: 'Korean (한국어)'),
  (code: 'pt', name: 'Portuguese (Português)'),
  (code: 'it', name: 'Italian (Italiano)'),
  (code: 'ar', name: 'Arabic (العربية)'),
  (code: 'ru', name: 'Russian (Русский)'),
  (code: 'tr', name: 'Turkish (Türkçe)'),
  (code: 'nl', name: 'Dutch (Nederlands)'),
  (code: 'sv', name: 'Swedish (Svenska)'),
  (code: 'pl', name: 'Polish (Polski)'),

  // Indian Languages
  (code: 'hi', name: 'Hindi (हिन्दी)'),
  (code: 'te', name: 'Telugu (తెలుగు)'),
  (code: 'ta', name: 'Tamil (தமிழ்)'),
  (code: 'ml', name: 'Malayalam (മലയാളം)'),
  (code: 'kn', name: 'Kannada (ಕನ್ನಡ)'),
  (code: 'bn', name: 'Bengali (বাংলা)'),
  (code: 'mr', name: 'Marathi (मराठी)'),
  (code: 'gu', name: 'Gujarati (ગુજરાતી)'),
  (code: 'pa', name: 'Punjabi (ਪੰਜਾਬੀ)'),
  (code: 'ur', name: 'Urdu (اردو)'),
  (code: 'as', name: 'Assamese (অসমীয়া)'),
  (code: 'ne', name: 'Nepali (नेपाली)'),
  (code: 'sd', name: 'Sindhi (سنڌي)'),
  (code: 'si', name: 'Sinhala (සිංහල)'),

  // Asian & Pacific Languages
  (code: 'id', name: 'Indonesian (Bahasa Indonesia)'),
  (code: 'th', name: 'Thai (ไทย)'),
  (code: 'vi', name: 'Vietnamese (Tiếng Việt)'),
  (code: 'tl', name: 'Filipino (Tagalog)'),
  (code: 'ms', name: 'Malay (Bahasa Melayu)'),
  (code: 'my', name: 'Burmese (မြန်မာ)'),
  (code: 'jv', name: 'Javanese (Basa Jawa)'),
  (code: 'ceb', name: 'Cebuano (Bisaya)'),
  (code: 'kk', name: 'Kazakh (Қазақ)'),
  (code: 'uz', name: 'Uzbek (Oʻzbek)'),
  (code: 'ky', name: 'Kirghiz (Кыргызча)'),

  // Middle Eastern & Central Asian Languages
  (code: 'fa', name: 'Persian (فارسی / Farsi)'),
  (code: 'he', name: 'Hebrew (עברית)'),
  (code: 'ps', name: 'Pashto (پښتو)'),
  (code: 'az', name: 'Azerbaijani (Azərbaycan)'),
  (code: 'hy', name: 'Armenian (Հայերեն)'),
  (code: 'ka', name: 'Georgian (ქართული)'),

  // European Languages
  (code: 'uk', name: 'Ukrainian (Українська)'),
  (code: 'ro', name: 'Romanian (Română)'),
  (code: 'el', name: 'Greek (Ελληνικά)'),
  (code: 'cs', name: 'Czech (Čeština)'),
  (code: 'hu', name: 'Hungarian (Magyar)'),
  (code: 'da', name: 'Danish (Dansk)'),
  (code: 'fi', name: 'Finnish (Suomi)'),
  (code: 'no', name: 'Norwegian (Norsk)'),
  (code: 'sk', name: 'Slovak (Slovenčina)'),
  (code: 'bg', name: 'Bulgarian (Български)'),
  (code: 'hr', name: 'Croatian (Hrvatski)'),
  (code: 'sr', name: 'Serbian (Српски)'),
  (code: 'bs', name: 'Bosnian (Bosanski)'),
  (code: 'lt', name: 'Lithuanian (Lietuvių)'),
  (code: 'sl', name: 'Slovenian (Slovenščina)'),
  (code: 'lv', name: 'Latvian (Latviešu)'),
  (code: 'et', name: 'Estonian (Eesti)'),
  (code: 'mk', name: 'Macedonian (Македонски)'),
  (code: 'be', name: 'Belarusian (Беларуская)'),
  (code: 'ca', name: 'Catalan (Català)'),
  (code: 'gl', name: 'Galician (Galego)'),
  (code: 'is', name: 'Icelandic (Íslenska)'),
  (code: 'ga', name: 'Irish (Gaeilge)'),
  (code: 'cy', name: 'Welsh (Cymraeg)'),
  (code: 'lb', name: 'Luxembourgish (Lëtzebuergesch)'),

  // African Languages
  (code: 'sw', name: 'Swahili (Kiswahili)'),
  (code: 'af', name: 'Afrikaans (Afrikaans)'),
  (code: 'ha', name: 'Hausa (Harshen Hausa)'),
  (code: 'so', name: 'Somali (Soomaali)'),
  (code: 'zu', name: 'Zulu (isiZulu)'),
  (code: 'ny', name: 'Chichewa (Nyanja)'),
  (code: 'ln', name: 'Lingala (Lingála)'),
];

/// Set of language codes supported natively by Google Cloud Chirp 3: HD generative speech synthesis.
const Set<String> kChirp3HdSupportedLanguageCodes = {
  // Indian Subcontinent Languages
  'te', // Telugu (తెలుగు)
  'hi', // Hindi (हिन्दी)
  'ta', // Tamil (தமிழ்)
  'kn', // Kannada (ಕನ್ನಡ)
  'ml', // Malayalam (മലയാളം)
  'mr', // Marathi (मराठी)
  'bn', // Bengali (বাংলা)
  'gu', // Gujarati (ગુજરાતી)
  'pa', // Punjabi (ਪੰਜਾਬੀ)

  // Global Core Languages
  'en', // English
  'zh', // Chinese (Mandarin)
  'es', // Spanish
  'fr', // French
  'de', // German
  'ja', // Japanese
  'ko', // Korean
  'pt', // Portuguese
  'it', // Italian
  'ar', // Arabic
  'ru', // Russian
  'tr', // Turkish
  'nl', // Dutch
  'sv', // Swedish
  'pl', // Polish
  'id', // Indonesian
  'th', // Thai
  'vi', // Vietnamese
  'he', // Hebrew
  'ro', // Romanian
  'el', // Greek
  'cs', // Czech
  'hu', // Hungarian
  'da', // Danish
  'fi', // Finnish
  'no', // Norwegian
  'sk', // Slovak
  'bg', // Bulgarian
  'hr', // Croatian
  'sr', // Serbian
  'lt', // Lithuanian
  'sl', // Slovenian
  'lv', // Latvian
  'et', // Estonian
  'sw', // Swahili
};

/// Languages supported by Google Cloud Chirp 3: HD for studio audio track dubbing without voice cloning.
List<({String code, String name})> get kChirp3HdSupportedLanguages =>
    kSupportedLanguages
        .where((lang) => kChirp3HdSupportedLanguageCodes.contains(lang.code.toLowerCase()))
        .toList();

/// Helper resolving language code to human-friendly display name.
String getSupportedLanguageName(String code) {
  final match = kSupportedLanguages.firstWhereOrNull((l) => l.code == code);
  return match?.name ?? code.toUpperCase();
}

/// Internal Video Track layout representation for the Video tab
class VideoTrackItem {
  VideoTrackItem({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.isBaseTrack = false,
    this.isResolved = false,
    this.status = 'Published',
    this.role = 'Original video',
    this.generationProgress,
    this.generationStage,
    this.generationStep = 1,
    this.estimatedTimeRemaining,
  });

  String id;
  String languageCode;
  String languageName;
  String videoUrl;
  String thumbnailUrl;
  bool isBaseTrack;
  bool isResolved;
  String status; // 'Published', 'Generating...', etc.
  String role; // 'Original video', 'Dubbed video'
  int? generationProgress;
  String? generationStage;
  int generationStep;
  String? estimatedTimeRemaining;
}

