import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class DiscoverChannelsPage extends StatelessWidget {
  const DiscoverChannelsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  DiscoverChannelsController get controller =>
      Get.isRegistered<DiscoverChannelsController>()
          ? Get.find<DiscoverChannelsController>()
          : Get.put(DiscoverChannelsController());

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        const backgroundColor = AppColors.bgPage;
        const textColor = AppColors.textPrimary;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: (context.isMobile && !isDashboard)
              ? AppBar(
                  title: const Text(
                    'Discover Channels',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(context.layoutSpacing),
              child: CustomScrollView(
                slivers: [
                  if (!context.isMobile || isDashboard)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Text(
                          'Discover Channels',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: TextField(
                        controller: controller.searchController,
                        onChanged: controller.onSearchChanged,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search channels by name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: Obx(
                            () => controller.searchQuery.value.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: controller.clearSearch,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Categories Horizontal List or Grid
                  Obx(
                    () => controller.selectedCategory.value == 'All'
                        ? _buildCategoryGrid(context)
                        : _buildSelectedCategoryHeader(context),
                  ),

                  // Filters Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _buildFilterBar(context),
                    ),
                  ),

                  // Channels List
                  Obx(() {
                    if (controller.isLoading) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brand,
                          ),
                        ),
                      );
                    }

                    if (controller.channels.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No channels found in this category',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _getCrossAxisCount(context),
                        childAspectRatio: context.isMobile ? 0.72 : 0.78,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final channel = controller.channels[index];
                          return _buildChannelCard(context, channel);
                        },
                        childCount: controller.channels.length,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isMobile
            ? 2
            : (ResponsiveContext(context).isTablet ? 3 : 4),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category =
              controller.categories[index + 1]; // Skip 'All' for grid
          return _buildCategoryCard(context, category);
        },
        childCount: controller.categories.length - 1,
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    final catName = category['name'] as String;
    final imageUrl = _getCategoryImage(catName);

    return InkWell(
      onTap: () => controller.selectCategory(catName),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: AppColors.bgSurfaceHover,
              ),
            ),
            Container(
              color: AppColors.bgPage.withValues(alpha: 0.4),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  catName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryImage(String category) {
    switch (category.toLowerCase().trim()) {
      case 'education':
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=1000&auto=format&fit=crop';
      case 'entertainment':
        return 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=1000&auto=format&fit=crop';
      case 'music':
        return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1000&auto=format&fit=crop';
      case 'news':
        return 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=1000&auto=format&fit=crop';
      case 'geopolitics':
        return 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?q=80&w=1000&auto=format&fit=crop';
      case 'sports':
        return 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=1000&auto=format&fit=crop';
      case 'technology':
      case 'ai & tech':
        return 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=1000&auto=format&fit=crop';
      case 'science':
      case 'deep research':
        return 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?q=80&w=1000&auto=format&fit=crop';
      case 'travel':
        return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?q=80&w=1000&auto=format&fit=crop';
      case 'lifestyle':
        return 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?q=80&w=1000&auto=format&fit=crop';
      case 'comedy':
        return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1000&auto=format&fit=crop';
      case 'documentary':
        return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1000&auto=format&fit=crop';
      case 'movies':
        return 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?q=80&w=1000&auto=format&fit=crop';
      case 'tv shows':
        return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?q=80&w=1000&auto=format&fit=crop';
      case 'vlogs':
        return 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?q=80&w=1000&auto=format&fit=crop';
      case 'diy & how-to':
      case 'diy':
        return 'https://images.unsplash.com/photo-1530124560676-10551fa77c2a?q=80&w=1000&auto=format&fit=crop';
      case 'health & fitness':
      case 'fitness':
      case 'health':
        return 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1000&auto=format&fit=crop';
      case 'fashion':
      case 'fashion & beauty':
        return 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?q=80&w=1000&auto=format&fit=crop';
      case 'food & cooking':
      case 'food':
        return 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=1000&auto=format&fit=crop';
      case 'business & finance':
      case 'business':
      case 'finance':
      case 'economics':
        return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=1000&auto=format&fit=crop';
      case 'gaming':
        return 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=1000&auto=format&fit=crop';
      case 'art':
      case 'art & design':
        return 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?q=80&w=1000&auto=format&fit=crop';
      case 'automotive':
        return 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?q=80&w=1000&auto=format&fit=crop';
      case 'pets & animals':
      case 'pets':
        return 'https://images.unsplash.com/photo-1450778869180-41d0601e046e?q=80&w=1000&auto=format&fit=crop';
      case 'nature':
      case 'nature & wildlife':
        return 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=1000&auto=format&fit=crop';
      case 'history':
        return 'https://images.unsplash.com/photo-1447069387593-a5de0862481e?q=80&w=1000&auto=format&fit=crop';
      case 'beauty':
        return 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?q=80&w=1000&auto=format&fit=crop';
      case 'spirituality':
        return 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?q=80&w=1000&auto=format&fit=crop';
      case 'kids & family':
        return 'https://images.unsplash.com/photo-1536640712-4d4c36ff0e4e?q=80&w=1000&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop';
    }
  }

  Widget _buildSelectedCategoryHeader(BuildContext context) {
    final selectedCat = controller.selectedCategory.value;
    final catImage = _getCategoryImage(selectedCat);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Category Banner Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: catImage,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.bgSurfaceHover,
                      ),
                    ),
                    Container(
                      color: AppColors.bgPage.withValues(alpha: 0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => controller.selectCategory('All'),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedCat,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Exploring $selectedCat channels',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Horizontal Category Pills Bar for 1-tap Category Switching
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: controller.categories.map((cat) {
                  final catName = cat['name'] as String;
                  final isSelected = selectedCat.toLowerCase() == catName.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(catName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) controller.selectCategory(catName);
                      },
                      backgroundColor: AppColors.bgSurface,
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Sort / Status Filters
          ...controller.filters.map((filter) {
            return Obx(() {
              final isSelected = controller.selectedFilter.value == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) controller.selectFilter(filter);
                  },
                  backgroundColor: AppColors.bgSurface,
                  selectedColor: AppColors.brand,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            });
          }),
          // Divider 1
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.bgDivider,
          ),
          // Topic Hashtags Header Indicator
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(
              Icons.tag,
              color: Colors.white,
              size: 18,
            ),
          ),
          // Niche Topics Selection Chips
          ...controller.nicheTopics.map((topicItem) {
            final topicName = topicItem['name']!;
            return Obx(() {
              final isSelected = controller.selectedTopic.value == topicName;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(topicName == 'All Topics' ? 'All Topics' : '#$topicName'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) controller.selectTopic(topicName);
                  },
                  backgroundColor: AppColors.bgSurface,
                  selectedColor: AppColors.brand,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            });
          }),
          // Divider 2
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.bgDivider,
          ),
          // Language Icon Indicator
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(
              Icons.language,
              color: Colors.white,
              size: 18,
            ),
          ),
          // Language Selection Chips
          ...controller.languages.map((lang) {
            return Obx(() {
              final isSelected = controller.selectedLanguage.value == lang;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(lang),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) controller.selectLanguage(lang);
                  },
                  backgroundColor: AppColors.bgSurface,
                  selectedColor: AppColors.brand,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            });
          }),
        ],
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel channel) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.3)),
        boxShadow: AppTheme.elevationSmall,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDashboard && Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().navigateToChannelDetail(channel);
            } else {
              Get.toNamed(
                channel.channelRoute,
                arguments: {'channel': channel},
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner & Avatar Stack
              SizedBox(
                height: 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Banner Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 64,
                      child: channel.bannerUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: channel.bannerUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: AppColors.bgDivider),
                              errorWidget: (context, url, error) =>
                                  Container(color: AppColors.bgDivider),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: AppTheme.gradientCrimsonSubtle,
                              ),
                            ),
                    ),
                    // Stacked Avatar
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          radius: 30,
                          photoUrl: channel.avatarUrl,
                          displayName: channel.name,
                          backgroundColor: AppTheme.secondaryBackground,
                          textColor: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Channel Info & Action
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              channel.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        channel.handle.isNotEmpty
                            ? channel.handle
                            : '@${channel.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final subscriberCount = controller.getSubscriberCount(channel);
                        return Text(
                          '${_formatCount(subscriberCount)} subscribers',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: Obx(() {
                          final isSubscribed = controller.isSubscribed(channel.channelId);

                          return ElevatedButton(
                            onPressed: () => controller.toggleSubscription(channel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSubscribed
                                  ? AppColors.bgSurfaceContainerHighest
                                  : AppColors.brand,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: isSubscribed
                                    ? const BorderSide(color: AppColors.bgDivider)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isSubscribed) ...[
                                  const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isSubscribed ? 'Subscribed' : 'Subscribe',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSubscribed
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    if (context.isMobile) return 2;
    if (ResponsiveContext(context).isTablet) return 3;
    return 4;
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
