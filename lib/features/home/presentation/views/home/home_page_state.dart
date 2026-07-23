/// Immutable UI state for the home screen feed.
class HomePageState {

  const HomePageState({
    required this.isLoadingTopics,
    required this.isLoadingVideos,
    required this.isLoadingMore,
    required this.hasTopics,
    required this.hasVideos,
  });

  factory HomePageState.fromValues({
    required bool isLoadingTopics,
    required bool isLoadingVideos,
    required bool isLoadingMore,
    required bool hasTopics,
    required bool hasVideos,
  }) {
    return HomePageState(
      isLoadingTopics: isLoadingTopics,
      isLoadingVideos: isLoadingVideos,
      isLoadingMore: isLoadingMore,
      hasTopics: hasTopics,
      hasVideos: hasVideos,
    );
  }
  final bool isLoadingTopics;
  final bool isLoadingVideos;
  final bool isLoadingMore;
  final bool hasTopics;
  final bool hasVideos;

  bool get showTopicsSection => hasTopics && !isLoadingTopics;
  bool get showVideoGrid => !isLoadingVideos;
  bool get showEmptyState => !isLoadingVideos && !hasVideos;
  bool get showLoadingIndicator => isLoadingVideos || isLoadingMore;
}
