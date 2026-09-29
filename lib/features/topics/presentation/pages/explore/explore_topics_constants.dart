import 'package:flutter/material.dart';

// ==========================================================================
// THEME COLORS (EXACT MATCH WITH LIBRARY SCREEN)
// ==========================================================================
const Color _ytBlack = Color(0xFF0F0F0F);
const Color _ytCardBg = Color(0xFF1E1E1E);
const Color _ytLightDark = Color(0xFF272727);
const Color _ytBorder = Color(0xFF383838);
const Color _ytRed = Color(0xFFFF0000);
const Color _ytRedLight = Color(0xFFCC0000);
const Color _ytGray = Color(0xFFAAAAAA);
const Color _ytLightGray = Color(0xFFE5E5E5);
const Color _ytWhite = Colors.white;

// ==========================================================================
// RESPONSIVE BREAKPOINTS (EXACT MATCH WITH LIBRARY SCREEN)
// ==========================================================================
const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1024;
const double kDesktopBreakpoint = 1440;

/// Theme tokens and color constants for the Explore Topics screen.
class ExploreTopicsTheme {
  const ExploreTopicsTheme._();

  static const Color bgColor = _ytBlack;
  static const Color surfaceColor = _ytCardBg;
  static const Color cardColor = _ytCardBg;
  static const Color buttonBg = _ytLightDark;
  static const Color primaryText = _ytWhite;
  static const Color secondaryText = _ytGray;
  static const Color ytRed = _ytRed;
  static const Color ytRedLight = _ytRedLight;
  static const Color ytBorder = _ytBorder;
  static const Color ytLightGray = _ytLightGray;
}

// Convenient top-level constants matching original internal identifiers
const Color bgColor = ExploreTopicsTheme.bgColor;
const Color surfaceColor = ExploreTopicsTheme.surfaceColor;
const Color cardColor = ExploreTopicsTheme.cardColor;
const Color buttonBg = ExploreTopicsTheme.buttonBg;
const Color primaryText = ExploreTopicsTheme.primaryText;
const Color secondaryText = ExploreTopicsTheme.secondaryText;
