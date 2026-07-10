import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/components/ui/user_avatar.dart';

class DiscoverChannelsPage extends StatelessWidget {
  final bool isDashboard;
  DiscoverChannelsPage({super.key, this.isDashboard = false});

  final DiscoverChannelsController controller = Get.put(DiscoverChannelsController());

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        final backgroundColor = AppColors.bgPage;
        final textColor = AppColors.textPrimary;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: (context.isMobile && !isDashboard)
              ? AppBar(
                  title: Text('Discover Channels', style: GoogleFonts.roboto(color: textColor, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                )
              : null,
          body: Padding(
            padding: EdgeInsets.all(context.layoutSpacing),
            child: CustomScrollView(
              slivers: [
                if (!context.isMobile || isDashboard)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Discover Channels',
                        style: GoogleFonts.roboto(
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
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                onPressed: controller.clearSearch,
                              )
                            : const SizedBox.shrink()),
                      ),
                    ),
                  ),
                ),
                
                // Categories Horizontal List or Grid
                Obx(() => controller.selectedCategory.value == 'All' 
                  ? _buildCategoryGrid(context)
                  : _buildSelectedCategoryHeader(context)),

                // Filters Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _buildFilterBar(context),
                  ),
                ),

                // Channels List
                Obx(() {
                  if (controller.isLoading.value) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
                    );
                  }
                  
                  if (controller.channels.isEmpty) {
                    return SliverFillRemaining(
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
                      childAspectRatio: 0.8,
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
        );
      },
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isMobile ? 2 : (ResponsiveContext(context).isTablet ? 3 : 4),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = controller.categories[index + 1]; // Skip 'All' for grid
          return _buildCategoryCard(context, category);
        },
        childCount: controller.categories.length - 1,
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    return InkWell(
      onTap: () => controller.selectCategory(category['name']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(_getCategoryImage(category['name'])),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.4),
              BlendMode.darken,
            ),
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(16),
        child: Text(
          category['name'],
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getCategoryImage(String category) {
    // Mock images based on category name
    switch (category.toLowerCase()) {
      case 'ai & tech':
      case 'technology':
        return 'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1000&auto=format&fit=crop';
      case 'deep research':
      case 'science':
        return 'https://images.unsplash.com/photo-1532094349884-543bc11b234d?q=80&w=1000&auto=format&fit=crop';
      case 'geopolitics':
      case 'news':
        return 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?q=80&w=1000&auto=format&fit=crop';
      case 'economics':
      case 'business & finance':
        return 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?q=80&w=1000&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop';
    }
  }

  Widget _buildSelectedCategoryHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
        children: [
          IconButton(
            icon: const BackSymbol(color: AppColors.textPrimary),
            onPressed: () => controller.selectCategory('All'),
          ),
          Text(
            controller.selectedCategory.value,
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
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
        children: controller.filters.map((filter) {
          return Obx(() {
            final isSelected = controller.selectedFilter.value == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) controller.selectFilter(filter);
                },
                backgroundColor: AppColors.bgSurface,
                selectedColor: AppColors.brand,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          });
        }).toList(),
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
              Get.toNamed(channel.channelRoute, arguments: {'channel': channel});
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
                              placeholder: (context, url) => Container(color: AppColors.bgDivider),
                              errorWidget: (context, url, error) => Container(color: AppColors.bgDivider),
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
                          textColor: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                              style: GoogleFonts.roboto(
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
                              child: Icon(Icons.verified, color: AppColors.brand, size: 14),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        channel.handle.isNotEmpty 
                            ? channel.handle 
                            : '@${channel.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                        style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatCount(channel.subscriberCount)} subscribers',
                        style: GoogleFonts.roboto(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Text(
                            'Subscribe',
                            style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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





