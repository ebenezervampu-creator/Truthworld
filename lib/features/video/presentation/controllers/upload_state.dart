import 'package:file_picker/file_picker.dart';
import 'package:truthworld/data/models/channel.dart';

class UploadState {
  const UploadState({
    required this.scheduledDate,
    this.selectedCategory = 'Music',
    this.selectedChannel,
    this.selectedVisibility = 'public',
    this.isKidFriendly = false,
    this.isShort = false,
    this.uploadQuality = 'Auto',
    this.enableComments = true,
    this.allowRatings = false,
    this.selectedPlaylist = '',
    this.isScheduled = false,

    this.aiTranscriptEnabled = true,
    this.aiChaptersEnabled = false,
    this.aiGenerateSubtitles = false,
    this.aiGenerateDubbing = false,
    this.aiDiarizationEnabled = false,
    this.aiSummaryEnabled = false,
    this.aiSubtitleLanguages = const [],
    this.aiDubbingLanguages = const [],
    this.aiTTSEnabled = false,
    this.aiTTSVoiceType = 'default',
    this.aiFactCheckEnabled = false,
    this.voiceSampleFile,

    this.pickedImage,
    this.pickedVideo,
  });
  final String selectedCategory;
  final Channel? selectedChannel;
  final String selectedVisibility;
  final bool isKidFriendly;
  final bool isShort;
  final String uploadQuality;
  final bool enableComments;
  final bool allowRatings;
  final String selectedPlaylist;
  final bool isScheduled;
  final DateTime scheduledDate;

  // AI Features
  final bool aiTranscriptEnabled;
  final bool aiChaptersEnabled;
  final bool aiGenerateSubtitles;
  final bool aiGenerateDubbing;
  final bool aiDiarizationEnabled;
  final bool aiSummaryEnabled;
  final List<String> aiSubtitleLanguages;
  final List<String> aiDubbingLanguages;
  final bool aiTTSEnabled;
  final String aiTTSVoiceType;
  final bool aiFactCheckEnabled;
  final PlatformFile? voiceSampleFile;

  // Media
  final PlatformFile? pickedImage;
  final PlatformFile? pickedVideo;

  UploadState copyWith({
    String? selectedCategory,
    Channel? selectedChannel,
    String? selectedVisibility,
    bool? isKidFriendly,
    bool? isShort,
    String? uploadQuality,
    bool? enableComments,
    bool? allowRatings,
    String? selectedPlaylist,
    bool? isScheduled,
    DateTime? scheduledDate,
    bool? aiTranscriptEnabled,
    bool? aiChaptersEnabled,
    bool? aiGenerateSubtitles,
    bool? aiGenerateDubbing,
    bool? aiDiarizationEnabled,
    bool? aiSummaryEnabled,
    List<String>? aiSubtitleLanguages,
    List<String>? aiDubbingLanguages,
    bool? aiTTSEnabled,
    String? aiTTSVoiceType,
    bool? aiFactCheckEnabled,
    PlatformFile? voiceSampleFile,
    PlatformFile? pickedImage,
    PlatformFile? pickedVideo,
  }) {
    return UploadState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      selectedVisibility: selectedVisibility ?? this.selectedVisibility,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      isShort: isShort ?? this.isShort,
      uploadQuality: uploadQuality ?? this.uploadQuality,
      enableComments: enableComments ?? this.enableComments,
      allowRatings: allowRatings ?? this.allowRatings,
      selectedPlaylist: selectedPlaylist ?? this.selectedPlaylist,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      aiTranscriptEnabled: aiTranscriptEnabled ?? this.aiTranscriptEnabled,
      aiChaptersEnabled: aiChaptersEnabled ?? this.aiChaptersEnabled,
      aiGenerateSubtitles: aiGenerateSubtitles ?? this.aiGenerateSubtitles,
      aiGenerateDubbing: aiGenerateDubbing ?? this.aiGenerateDubbing,
      aiDiarizationEnabled: aiDiarizationEnabled ?? this.aiDiarizationEnabled,
      aiSummaryEnabled: aiSummaryEnabled ?? this.aiSummaryEnabled,
      aiSubtitleLanguages: aiSubtitleLanguages ?? this.aiSubtitleLanguages,
      aiDubbingLanguages: aiDubbingLanguages ?? this.aiDubbingLanguages,
      aiTTSEnabled: aiTTSEnabled ?? this.aiTTSEnabled,
      aiTTSVoiceType: aiTTSVoiceType ?? this.aiTTSVoiceType,
      aiFactCheckEnabled: aiFactCheckEnabled ?? this.aiFactCheckEnabled,
      voiceSampleFile: voiceSampleFile ?? this.voiceSampleFile,
      pickedImage: pickedImage ?? this.pickedImage,
      pickedVideo: pickedVideo ?? this.pickedVideo,
    );
  }
}
