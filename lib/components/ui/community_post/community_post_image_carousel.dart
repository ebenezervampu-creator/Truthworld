import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Fullscreen Image Viewer Modal for Community Post Images
void showCommunityFullScreenImageViewer(
  BuildContext context,
  List<String> images,
  int initialIndex,
) {
  if (images.isEmpty) return;
  final pageController = PageController(initialPage: initialIndex);
  final currentPage = initialIndex.obs;

  Get.dialog(
    Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              currentPage.value = index;
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white, // Rule compliance: white icon
                size: 28,
              ),
              onPressed: Get.back,
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Obx(
                    () => Text(
                      '${currentPage.value + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    useSafeArea: false,
  );
}

/// Image Carousel for Community Post Card
/// Renders swipeable image pages with shimmer loading placeholders and page counter badge.
class CommunityPostImageCarousel extends StatelessWidget {
  CommunityPostImageCarousel({
    required this.images,
    super.key,
  });

  final List<String> images;
  final RxInt _currentPage = 0.obs;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              _currentPage.value = index;
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => showCommunityFullScreenImageViewer(
                  context,
                  images,
                  index,
                ),
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppColors.bgSurface,
                    highlightColor: AppColors.bgDivider,
                    child: Container(color: AppColors.bgSurface),
                  ),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: AppColors.bgSurface,
                    child: Icon(
                      Icons.error,
                      color: Colors.white, // Rule compliance: white icon
                    ),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPage.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Obx(
                  () => Text(
                    '${_currentPage.value + 1}/${images.length}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
