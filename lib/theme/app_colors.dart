import 'package:flutter/material.dart';

class AppColors {
  // ── Backgrounds
  static const bgPage           = Color(0xFF0F0F0F);
  static const bgSurface        = Color(0xFF212121);
  static const bgSurfaceHover   = Color(0xFF272727);
  static const bgElevated       = Color(0xFF3F3F3F);
  static const bgInput          = Color(0xFF121212);
  static const bgDivider        = Color(0xFF3F3F3F);
  
  // ── Aliases for Material 3 naming consistency
  static const bgSurfaceContainerHighest = bgSurfaceHover;

  // ── Text
  static const textPrimary      = Color(0xFFF1F1F1);
  static const textSecondary    = Color(0xFFAAAAAA);
  static const textTertiary     = Color(0xFF717171);
  static const textLink         = Color(0xFF3EA6FF);
  
  // ── Opacity Aliases (Legacy Support)
  static final textPrimary38 = textPrimary.withValues(alpha: 0.38);
  static final textPrimary54 = textPrimary.withValues(alpha: 0.54);
  static final textPrimary60 = textPrimary.withValues(alpha: 0.60);
  static final textPrimary70 = textPrimary.withValues(alpha: 0.70);
  static final textPrimary30 = textPrimary.withValues(alpha: 0.30);
  
  static final bgPage54 = bgPage.withValues(alpha: 0.54);

  // ── 🟣 Brand (Electric Purple)
  static const brand            = Color(0xFF9B30FF);
  static const brandHover       = Color(0xFF7B20DF);
  static const brandNotif       = Color(0xFFBF00FF);
  static const brandOverlay     = Color(0x299B30FF);
  static const brandContainer   = Color(0xFF2D1060);

  // ── Icons
  static const iconDefault      = Color(0xFFAAAAAA);
  static const iconActive       = Color(0xFFF1F1F1);

  // ── Progress
  static const progressActive   = Color(0xFF9B30FF);
  static const progressBuffered = Color(0xFF717171);
  static const progressTrack    = Color(0xFF404040);

  // ── Misc
  static const searchBorder     = Color(0xFF303030);
  static const scrollbarThumb   = Color(0xFFAAAAAA);
  static const tooltipBg        = Color(0xFF606060);

  // ── Status
  static const success          = Color(0xFF2BA640);
  static const warning          = Color(0xFFF9BF05);
  static const error            = Color(0xFFCF6679);
}
