/// Immutable UI state for the video screen.
class VideoScreenState {

  const VideoScreenState({
    required this.isLoadingVideo,
    required this.isLoadingRecommendations,
    required this.hasVideoError,
    required this.hasRecommendations,
    required this.hasVideoData,
  });

  factory VideoScreenState.fromValues({
    required bool isLoadingVideo,
    required bool isLoadingRecommendations,
    required bool hasVideoError,
    required bool hasRecommendations,
    required bool hasVideoData,
  }) {
    return VideoScreenState(
      isLoadingVideo: isLoadingVideo,
      isLoadingRecommendations: isLoadingRecommendations,
      hasVideoError: hasVideoError,
      hasRecommendations: hasRecommendations,
      hasVideoData: hasVideoData,
    );
  }
  final bool isLoadingVideo;
  final bool isLoadingRecommendations;
  final bool hasVideoError;
  final bool hasRecommendations;
  final bool hasVideoData;

  bool get showPlayerFallback => isLoadingVideo || hasVideoError;
  bool get showRecommendationsEmptyState =>
      !isLoadingRecommendations && !hasRecommendations;
}
