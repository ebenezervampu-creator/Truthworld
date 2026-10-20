import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// APP THEME COLORS & DESIGN TOKENS
// ==========================================================================

const Color ytBackground = AppColors.bgPage;
const Color ytSurface = AppColors.bgSurface;
const Color ytSurfaceLight = AppColors.bgSurfaceHover;
const Color ytSurfaceHover = AppColors.bgSurfaceHigh;
const Color ytTextPrimary = AppColors.textPrimary;
const Color ytTextSecondary = AppColors.textSecondary;
const Color ytTextTertiary = AppColors.textTertiary;
const Color ytRed = AppColors.brand;
const Color ytBorder = AppColors.searchBorder;

// ==========================================================================
// FORMATTERS
// ==========================================================================

String formatPlaylistViews(int views) {
  if (views >= 1000000000) {
    return '${(views / 1000000000).toStringAsFixed(1)}B';
  } else if (views >= 1000000) {
    return '${(views / 1000000).toStringAsFixed(1)}M';
  } else if (views >= 1000) {
    return '${(views / 1000).toStringAsFixed(1)}K';
  }
  return views.toString();
}
