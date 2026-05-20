import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/search/domain/enums/search_state.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_controller;
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

class SearchPage extends GetView<search_controller.SearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: SearchBarWidget(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SearchFilterChips(),
        ),
      ),
      body: Obx(() {
        switch (controller.state.value) {
          case SearchState.idle:
            return _buildIdleState();
          case SearchState.loading:
            return _buildLoadingState();
          case SearchState.results:
            return _buildResultsState();
          case SearchState.empty:
            return EmptySearchState(query: controller.searchQuery.value);
          case SearchState.error:
            return _buildErrorState();
        }
      }),
    );
  }

  Widget _buildIdleState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          RecentSearchesList(),
          TrendingSearchesView(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => const SearchResultSkeleton(),
    );
  }

  Widget _buildResultsState() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          controller.loadNextPage();
        }
        return true;
      },
      child: ListView.builder(
        itemCount: controller.searchResults.length + (controller.hasMoreResults.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == controller.searchResults.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final result = controller.searchResults[index];
          
          if (result.type == ResultType.video) {
            return VideoCard(
              video: Video.fromSearchResult(result),
              onTap: () => controller.onResultTapped(result),
            );
          }

          return SearchResultCard(
            result: result,
            onTap: () {
              controller.onResultTapped(result);
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => controller.onSearchChanged(controller.searchQuery.value),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
