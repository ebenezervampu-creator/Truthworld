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
  });

  String id;
  String languageCode;
  String languageName;
  String audioUrl;
  bool isBaseTrack;
  bool isResolved;
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

/// Pre-configured multi-language code dictionary mapping
const List<({String code, String name})> kSupportedLanguages = [
  (code: 'en', name: 'English (Base)'),
  (code: 'es', name: 'Spanish (Español)'),
  (code: 'hi', name: 'Hindi (हिन्दी)'),
  (code: 'fr', name: 'French (Français)'),
  (code: 'te', name: 'Telugu (తెలుగు)'),
  (code: 'ta', name: 'Tamil (தமிழ்)'),
  (code: 'ml', name: 'Malayalam (മലയാളം)'),
  (code: 'kn', name: 'Kannada (കന്നഡ)'),
  (code: 'bn', name: 'Bengali (বাংলা)'),
  (code: 'mr', name: 'Marathi (मराठी)'),
  (code: 'ja', name: 'Japanese (日本語)'),
  (code: 'ko', name: 'Korean (한국어)'),
  (code: 'de', name: 'German (Deutsch)'),
  (code: 'pt', name: 'Portuguese (Português)'),
  (code: 'it', name: 'Italian (Italiano)'),
  (code: 'ar', name: 'Arabic (العربية)'),
  (code: 'ru', name: 'Russian (Русский)'),
  (code: 'zh', name: 'Chinese (中文)'),
];

/// Helper resolving language code to human-friendly display name.
String getSupportedLanguageName(String code) {
  final match = kSupportedLanguages.firstWhereOrNull((l) => l.code == code);
  return match?.name ?? code.toUpperCase();
}
