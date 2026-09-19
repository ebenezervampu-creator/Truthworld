import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// ENHANCED THEME COLORS FOR CATEGORY PAGE
// ==========================================================================

const Color musicColor = AppColors.brand;
const Color entertainmentColor = Color(0xFF8B5CF6);
final Color educationColor = AppTokens.colors.info;
const Color sportsColor = Color(0xFFF59E0B);
const Color newsColor = AppColors.textTertiary;
final Color gamingColor = AppTokens.colors.success;

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================

const double kCategoryMobileBreakpoint = 600;
const double kCategoryTabletBreakpoint = 1000;
const double kCategoryDesktopBreakpoint = 1200;

// ==========================================================================
// THEME & FORMATTING HELPER
// ==========================================================================

class CategoryThemeHelper {
  const CategoryThemeHelper._();

  static Color getCategoryColor(String category, BuildContext context) {
    switch (category.toLowerCase()) {
      case 'music':
        return musicColor;
      case 'entertainment':
        return entertainmentColor;
      case 'education':
        return educationColor;
      case 'sports':
        return sportsColor;
      case 'news':
        return newsColor;
      case 'gaming':
        return gamingColor;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'education':
        return Icons.school;
      case 'entertainment':
        return Icons.theater_comedy;
      case 'music':
        return Icons.music_note;
      case 'news':
        return Icons.newspaper;
      case 'sports':
        return Icons.sports_soccer;
      case 'gaming':
        return Icons.videogame_asset;
      case 'technology':
        return Icons.computer;
      case 'science':
        return Icons.science;
      case 'travel':
        return Icons.travel_explore;
      case 'lifestyle':
        return Icons.home;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      case 'documentary':
        return Icons.video_label;
      case 'movies':
        return Icons.movie;
      case 'tv shows':
        return Icons.tv;
      case 'vlogs':
        return Icons.videocam;
      case 'diy & how-to':
        return Icons.build;
      case 'health & fitness':
        return Icons.fitness_center;
      case 'fashion & beauty':
        return Icons.brush;
      case 'food & cooking':
        return Icons.restaurant;
      case 'business & finance':
        return Icons.business;
      case 'animation':
        return Icons.animation;
      case 'short films':
        return Icons.flip_camera_ios;
      case 'motivation':
        return Icons.psychology;
      case 'history':
        return Icons.history;
      case 'art & design':
        return Icons.palette;
      case 'automotive':
        return Icons.directions_car;
      case 'animals & pets':
        return Icons.pets;
      case 'spirituality':
        return Icons.self_improvement;
      case 'nature & wildlife':
        return Icons.eco;
      case 'kids & family':
        return Icons.family_restroom;
      default:
        return Icons.category;
    }
  }

  static String formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }

  static double getResponsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= kCategoryDesktopBreakpoint) return AppTokens.spacing.lg;
    if (width >= kCategoryMobileBreakpoint) return AppTokens.spacing.md;
    return AppTokens.spacing.sm;
  }
}

// ==========================================================================
// CUSTOM PAINTER FOR CATEGORY PATTERN
// ==========================================================================

class CategoryPatternPainter extends CustomPainter {
  const CategoryPatternPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 10; i++) {
      for (var j = 0; j < 10; j++) {
        final x = (size.width / 10) * i;
        final y = (size.height / 10) * j;

        if ((i + j) % 2 == 0) {
          canvas.drawCircle(Offset(x + 20, y + 20), 8, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
