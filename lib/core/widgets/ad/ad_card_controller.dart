import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_colors.dart';

/// GetX controller managing hover animations and states for ad cards.
class AdCardController extends GetxController {
  bool isHovered = false;

  void setHovered(bool val) {
    if (isHovered != val) {
      isHovered = val;
      update();
    }
  }
}

/// Options popup menu button for reporting, saving, and copying ad link.
class AdOptionsMenuButton extends StatelessWidget {
  const AdOptionsMenuButton({
    required this.ad,
    super.key,
    this.iconSize = 20,
  });

  final AdItem ad;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert_rounded,
        size: iconSize,
        color: Colors.white,
      ),
      color: AppColors.bgSurface,
      onSelected: (value) {
        if (value == 'report') {
          AdService.to.showReportAdDialog(context, ad);
        } else if (value == 'copy') {
          Clipboard.setData(ClipboardData(text: ad.ctaTarget));
          AppSnackbar.show(
            'Link Copied',
            'Ad destination link copied.',
          );
        } else if (value == 'save') {
          AdService.to.toggleSaveAd(ad.id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(
                Icons.report_problem_outlined,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                "Report Ad / Don't Show",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                'Copy Ad Link',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'save',
          child: Row(
            children: [
              const Icon(
                Icons.bookmark_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                AdService.to.savedAdIds.contains(ad.id)
                    ? 'Remove Bookmark'
                    : 'Save Ad',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Action bar for ad cards with like counter and bookmark button.
Widget buildAdActionBar(BuildContext context, AdItem ad) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thumbs Up (Like)
        Obx(() {
          final isLiked = AdService.to.likedAdIds.contains(ad.id);
          return StreamBuilder<int>(
            stream: AdService.to.getAdLikesCountStream(ad.id),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return TextButton.icon(
                onPressed: () => AdService.to.toggleLikeAd(ad.id),
                icon: Icon(
                  isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  '$count',
                  style: TextStyle(
                    color: isLiked
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          );
        }),
        const SizedBox(width: 8),
        // Save / Bookmark
        Obx(() {
          final isSaved = AdService.to.savedAdIds.contains(ad.id);
          return IconButton(
            onPressed: () => AdService.to.toggleSaveAd(ad.id),
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 16,
              color: Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          );
        }),
      ],
    ),
  );
}

/// Circular avatar showing the advertiser's logo or a stylized fallback letter.
Widget buildAdvertiserLogoAvatar(AdItem ad, {double radius = 16}) {
  final logoUrl = ad.imageUrl.trim();
  final isValidUrl = logoUrl.isNotEmpty &&
      (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'));

  if (isValidUrl) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF333333),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: Text(
              ad.advertiser.isNotEmpty ? ad.advertiser[0].toUpperCase() : 'S',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            return Center(
              child: Text(
                ad.advertiser.isNotEmpty ? ad.advertiser[0].toUpperCase() : 'S',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF333333),
    child: Text(
      ad.advertiser.isNotEmpty ? ad.advertiser[0].toUpperCase() : 'S',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    ),
  );
}
