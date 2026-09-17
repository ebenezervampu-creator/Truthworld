import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable UI states and helper widgets for Channel Details tabs.
class ChannelDetailsStateWidgets {
  static Widget buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: ytTextTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: ytTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: ytTextSecondary),
          ),
        ],
      ),
    );
  }

  static Widget buildShimmerGrid({
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Shimmer.fromColors(
      baseColor: ytSurface,
      highlightColor: ytSurfaceLight,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 280 : 160,
                height: (isDesktop ? 280 : 160) * 9 / 16,
                decoration: BoxDecoration(
                  color: ytSurfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, color: ytSurfaceLight),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 100, color: ytSurfaceLight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: ytTextSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: ytTextSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: ytTextPrimary,
              foregroundColor: ytBackground,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  static String formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  static Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppSnackbar.warning('Unable to open link. Please check the URL.');
    }
  }
}
