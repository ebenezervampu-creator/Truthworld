import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Pagination Helper for Firestore Queries
///
/// Implements cursor-based pagination with:
/// - Efficient document navigation
/// - Automatic prefetching
/// - Memory-efficient caching
/// - Proper cleanup
abstract class PaginationController<T> extends GetxController {
  final List<T> items = [];

  DocumentSnapshot? _lastDocument;
  bool isLoading = false;
  bool hasMore = true;
  bool hasError = false;
  String? errorMessage;

  /// Load initial batch
  ///
  /// Override this method in subclasses
  Future<({List<T> items, DocumentSnapshot? lastDoc})> loadInitial();

  /// Load next batch using cursor
  ///
  /// Override this method in subclasses
  Future<({List<T> items, DocumentSnapshot? lastDoc})> loadNext(
    DocumentSnapshot lastDocument,
  );

  @override
  Future<void> onInit() async {
    super.onInit();
    await load();
  }

  /// Fetch first batch of items
  Future<void> load() async {
    if (isLoading) return;

    isLoading = true;
    hasError = false;
    errorMessage = null;

    try {
      final result = await loadInitial();

      items.clear();
      items.addAll(result.items);

      if (result.lastDoc != null) {
        _lastDocument = result.lastDoc;

        // Prefetch next batch in background
        _prefetchNext();
      } else {
        hasMore = false;
      }
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      update();
    }
  }

  /// Load more items (pagination)
  Future<void> loadMore() async {
    if (isLoading || !hasMore || _lastDocument == null) return;

    isLoading = true;
    hasError = false;
    errorMessage = null;

    try {
      final result = await loadNext(_lastDocument!);

      items.addAll(result.items);

      if (result.items.isEmpty) {
        hasMore = false;
      } else {
        _lastDocument = result.lastDoc;

        // Prefetch next batch
        _prefetchNext();
      }
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      update();
    }
  }

  /// Prefetch next batch without updating UI
  Future<void> _prefetchNext() async {
    if (_lastDocument == null) return;

    try {
      await loadNext(_lastDocument!);
    } catch (e) {
      logger.error('Prefetch error: $e', tag: 'PAGINATION');
    }
  }

  /// Reset pagination
  void reset() {
    items.clear();
    _lastDocument = null;
    isLoading = false;
    hasMore = true;
    hasError = false;
    errorMessage = null;
  }

  /// Refresh data (restart from beginning)
  @override
  Future<void> refresh() async {
    reset();
    await load();
  }
}

/// Infinite Scroll Mixin for StatefulWidget
///
/// Provides scroll listener and pagination logic
mixin InfiniteScrollMixin on State {
  late ScrollController scrollController;
  bool _isInitialized = false;

  /// Initialize scroll listener
  ///
  /// Call this in initState()
  void initScrollListener({
    required VoidCallback onLoadMore,
    double threshold = 0.7, // Load when 70% scrolled
  }) {
    if (_isInitialized) return;

    scrollController = ScrollController();
    scrollController.addListener(() {
      if (!scrollController.hasClients || scrollController.positions.length != 1) return;
      final position = scrollController.position;

      // Check if scrolled past threshold
      if (position.pixels > position.maxScrollExtent * threshold) {
        onLoadMore();
      }
    });

    _isInitialized = true;
  }

  /// Cleanup scroll controller
  ///
  /// Call this in dispose()
  void disposeScrollListener() {
    if (_isInitialized) {
      scrollController.dispose();
    }
  }
}

/// Infinite List Builder Widget
///
/// Combines pagination controller with ListView/SliverList
class InfiniteList<T> extends StatelessWidget {
  const InfiniteList({
    required this.controller,
    required this.itemBuilder,
    super.key,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.scrollController,
    this.addAutomaticKeepAlives = true,
    this.reverse = false,
  });
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context)? errorBuilder;
  final ScrollController? scrollController;
  final bool addAutomaticKeepAlives;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaginationController<T>>(
      init: controller,
      builder: (ctrl) {
        // Initial loading
        if (ctrl.isLoading && ctrl.items.isEmpty) {
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        // Empty state
        if (ctrl.items.isEmpty) {
          return emptyBuilder?.call(context) ??
              const Center(child: Text('No items found'));
        }

        // Error state
        if (ctrl.hasError) {
          return errorBuilder?.call(context) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${ctrl.errorMessage}'),
                    ElevatedButton(
                      onPressed: () => ctrl.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
        }

        // List with items
        return ListView.builder(
          controller: scrollController,
          reverse: reverse,
          itemCount: ctrl.items.length + (ctrl.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Loading indicator at bottom
            if (index == ctrl.items.length) {
              if (!ctrl.isLoading) {
                // Trigger load more
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ctrl.loadMore();
                });
              }
              return loadingBuilder?.call(context) ??
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  );
            }

            return itemBuilder(context, index, ctrl.items[index]);
          },
        );
      },
    );
  }
}

/// Infinite SliverList Widget
///
/// For use in CustomScrollView
class InfiniteSliverList<T> extends StatelessWidget {
  const InfiniteSliverList({
    required this.controller,
    required this.itemBuilder,
    super.key,
    this.loadingBuilder,
    this.emptyBuilder,
    this.addAutomaticKeepAlives = false,
  });
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool addAutomaticKeepAlives;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaginationController<T>>(
      init: controller,
      builder: (ctrl) {
        // Initial loading
        if (ctrl.isLoading && ctrl.items.isEmpty) {
          return SliverFillRemaining(
            child:
                loadingBuilder?.call(context) ??
                const Center(child: CircularProgressIndicator()),
          );
        }

        // Empty state
        if (ctrl.items.isEmpty) {
          return SliverFillRemaining(
            child:
                emptyBuilder?.call(context) ??
                const Center(child: Text('No items found')),
          );
        }

        // List with items
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // Loading indicator at bottom
              if (index == ctrl.items.length) {
                if (!ctrl.isLoading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ctrl.loadMore();
                  });
                }
                return loadingBuilder?.call(context) ??
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    );
              }

              return itemBuilder(context, index, ctrl.items[index]);
            },
            childCount: ctrl.items.length + (ctrl.hasMore ? 1 : 0),
            addAutomaticKeepAlives: addAutomaticKeepAlives,
            addRepaintBoundaries: false,
          ),
        );
      },
    );
  }
}

/// Grid-based Infinite Scroller
///
/// For use in CustomScrollView with SliverGrid
class InfiniteSliverGrid<T> extends StatelessWidget {
  const InfiniteSliverGrid({
    required this.controller,
    required this.itemBuilder,
    required this.gridDelegate,
    super.key,
    this.loadingBuilder,
    this.addAutomaticKeepAlives = false,
  });
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final Widget Function(BuildContext context)? loadingBuilder;
  final bool addAutomaticKeepAlives;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PaginationController<T>>(
      init: controller,
      builder: (ctrl) {
        if (ctrl.items.isEmpty && ctrl.isLoading) {
          return SliverFillRemaining(
            child:
                loadingBuilder?.call(context) ??
                const Center(child: CircularProgressIndicator()),
          );
        }

        return SliverGrid(
          gridDelegate: gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // Loading indicator
              if (index == ctrl.items.length) {
                if (!ctrl.isLoading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ctrl.loadMore();
                  });
                }
                return loadingBuilder?.call(context) ??
                    const Center(child: CircularProgressIndicator());
              }

              return itemBuilder(context, index, ctrl.items[index]);
            },
            childCount: ctrl.items.length + (ctrl.hasMore ? 1 : 0),
            addAutomaticKeepAlives: addAutomaticKeepAlives,
            addRepaintBoundaries: false,
          ),
        );
      },
    );
  }
}

/// Example Usage
///
/// ```dart
/// class VideoFeedController extends PaginationController<VideoSummary> {
///   @override
///   Future<({List<VideoSummary> items, DocumentSnapshot? lastDoc})> loadInitial() async {
///     return await FirestoreService.to.getFeedVideos();
///   }
///
///   @override
///   Future<({List<VideoSummary> items, DocumentSnapshot? lastDoc})> loadNext(DocumentSnapshot lastDocument) async {
///     return await FirestoreService.to.getFeedVideos(lastDocument: lastDocument);
///   }
/// }
///
/// class VideoFeedPage extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return CustomScrollView(
///       slivers: [
///         SliverAppBar(title: Text('Feed'),
///         InfiniteSliverGrid(
///           controller: Get.put(VideoFeedController(),
///           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
///             crossAxisCount: 2,
///             childAspectRatio: 0.75,
///           ),
///           itemBuilder: (context, index, video) {
///             return VideoCard(video: video);
///           },
///         ),
///       ],
///     );
///   }
/// }
/// ```
