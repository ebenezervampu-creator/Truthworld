import 'package:flutter/material.dart';

/// Raw hex color palette for TruthWorld.
///
/// NOTE: This class is public but internal to the theme package by convention.
/// Application widgets should not import or use this class directly.
/// Instead, access colors via `context.colors` or `Theme.of(context).colorScheme`.
class AppColors {
  AppColors._();

  // ── Brand
  static const brand = Color(0xFFFFFFFF);
  static const brandVariant = Color(0xFFE0E0E0);
  static const brandContainer = Color(0xFFF5F5F5);
  static const brandOverlay = Color(0x29FFFFFF);
  static const brandHover = Color(0xFFF0F0F0);

  // ── Backgrounds & Surfaces
  static const bgPage = Color(0xFF0F0F0F);
  static const bgPage54 = Color(0x8A0F0F0F);
  static const bgSurface = Color(0xFF212121);
  static const bgSurfaceHover = Color(0xFF272727); // surfaceContainer
  static const bgSurfaceHigh = Color(0xFF2E2E2E); // surfaceContainerHigh
  static const bgElevated = Color(0xFF3F3F3F); // surfaceContainerHighest
  static const bgSurfaceContainerHighest = bgElevated;
  static const bgInput = Color(0xFF121212);
  static const bgDivider = Color(0xFF3F3F3F);
  static const appBarSurface = Color(0xFF161618);

  // ── Text
  static const textPrimary = Color(0xFFF1F1F1);
  static const textPrimary70 = Color(0xB3F1F1F1);
  static const textPrimary60 = Color(0x99F1F1F1);
  static const textPrimary54 = Color(0x89F1F1F1);
  static const textPrimary38 = Color(0x61F1F1F1);
  static const textPrimary30 = Color(0x4DF1F1F1);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textTertiary = Color(0xFF717171);
  static const textDisabled = Color(0xFF545454);
  static const textLink = Color(0xFF3EA6FF);

  // ── Status
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  static const successContainer = Color(0x1A10B981);
  static const warningContainer = Color(0x1AF59E0B);
  static const errorContainer = Color(0x1AEF4444);
  static const infoContainer = Color(0x1A3B82F6);

  // ── Interaction Overlays
  static const selectedOverlay = Color(0x29FFFFFF);
  static const hoverOverlay = Color(0x1FFFFFFF);
  static const pressedOverlay = Color(0x3DFFFFFF);
  static const focusRing = Color(0xFFFFFFFF);

  // ── Icons (Internal/legacy refs)
  static const iconDefault = Color(0xFFAAAAAA);
  static const iconActive = Color(0xFFF1F1F1);

  // ── Progress & Scroll
  static const progressActive = Color(0xFFFFFFFF);
  static const progressBuffered = Color(0xFF717171);
  static const progressTrack = Color(0xFF404040);
  static const searchBorder = Color(0xFF303030);
  static const scrollbarThumb = Color(0xFFAAAAAA);
  static const tooltipBg = Color(0xFF606060);
}
