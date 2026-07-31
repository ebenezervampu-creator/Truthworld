import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// ResponsivePageWrapper: Standardized page template with consistent spacing
///
/// Ensures all pages follow the same responsive patterns and spacing rules.
/// Replaces hardcoded padding/spacing throughout the app.
///
/// Features:
/// - Automatic responsive spacing based on screen size
/// - Token-based spacing (8px grid)
/// - Consistent padding top/bottom using standard App Bar height
/// - Full responsive support for mobile, tablet, desktop
/// - Safe area support
///
/// Usage:
/// ```dart
/// ResponsivePageWrapper(
///   body: Column(children: [...]),
///   padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing.md),
/// )
/// ```
class ResponsivePageWrapper extends StatelessWidget {
  const ResponsivePageWrapper({
    required this.body,
    super.key,
    this.padding,
    this.backgroundColor,
    this.scrollController,
    this.useScroll = true,
    this.useSafeArea = true,
  });
  final Widget body;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final ScrollController? scrollController;
  final bool useScroll;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Get responsive padding based on device type
    final defaultPadding = EdgeInsets.symmetric(
      horizontal: _getResponsiveHorizontalPadding(screenWidth),
      vertical: AppTheme.spacing.md,
    );

    final Widget child = Padding(
      padding: padding ?? defaultPadding,
      child: body,
    );

    final wrappedChild = useSafeArea ? SafeArea(child: child) : child;

    return ColoredBox(
      color: backgroundColor ?? AppTheme.colors.background,
      child: useScroll
          ? SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: wrappedChild,
            )
          : wrappedChild,
    );
  }

  /// Get responsive horizontal padding based on screen width
  /// Follows the 8px grid system and standard breakpoints
  double _getResponsiveHorizontalPadding(double screenWidth) {
    if (Responsive.isMobile(screenWidth)) {
      return AppTheme.spacing.sm; // 16px
    } else if (Responsive.isTablet(screenWidth)) {
      return AppTheme.spacing.md; // 24px
    } else {
      return AppTheme.spacing.lg; // 32px
    }
  }
}

/// ResponsiveSection: Standardized section with consistent vertical spacing
///
/// Use this for grouping related content within a page.
/// Provides consistent spacing between sections.
///
/// Usage:
/// ```dart
/// ResponsiveSection(
///   title: 'Featured Videos',
///   child: VideoGrid(...),
/// )
/// ```
class ResponsiveSection extends StatelessWidget {
  const ResponsiveSection({
    required this.child,
    super.key,
    this.title,
    this.padding,
    this.bottomSpacing,
    this.titleStyle,
  });
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? bottomSpacing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: padding ?? EdgeInsets.only(bottom: AppTheme.spacing.sm),
            child: Text(
              title!,
              style:
                  titleStyle ??
                  AppTheme.typography.h2.copyWith(
                    color: AppTheme.colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
        child,
        SizedBox(height: bottomSpacing ?? AppTheme.spacing.md),
      ],
    );
  }
}

/// ResponsiveGridWrapper: Standardized grid with consistent spacing
///
/// Automatically handles responsive column counts and spacing.
/// All spacing aligns with the 8px grid system.
///
/// Usage:
/// ```dart
/// ResponsiveGridWrapper(
///   children: videos.map((v) => VideoCard(video: v)).toList(),
/// )
/// ```
class ResponsiveGridWrapper extends StatelessWidget {
  const ResponsiveGridWrapper({
    required this.children,
    super.key,
    this.columnsDesktop,
    this.columnsTablet,
    this.columnsMobile,
    this.spacing,
  });
  final List<Widget> children;
  final int? columnsDesktop;
  final int? columnsTablet;
  final int? columnsMobile;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = _getColumns(screenWidth);
    final gridSpacing = spacing ?? AppTheme.spacing.md;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gridSpacing,
        mainAxisSpacing: gridSpacing,
        childAspectRatio: 0.9,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  int _getColumns(double screenWidth) {
    if (Responsive.isMobile(screenWidth)) {
      return columnsMobile ?? 2;
    } else if (Responsive.isTablet(screenWidth)) {
      return columnsTablet ?? 3;
    } else {
      return columnsDesktop ?? 4;
    }
  }
}

/// ResponsiveListWrapper: Standardized list with consistent spacing
///
/// Automatically handles responsive item spacing.
/// All spacing aligns with the 8px grid system.
///
/// Usage:
/// ```dart
/// ResponsiveListWrapper(
///   children: videos.map((v) => VideoCard(video: v, isGrid: false)).toList(),
/// )
/// ```
class ResponsiveListWrapper extends StatelessWidget {
  const ResponsiveListWrapper({
    required this.children,
    super.key,
    this.spacing,
  });
  final List<Widget> children;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final itemSpacing = spacing ?? AppTheme.spacing.md;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      separatorBuilder: (context, index) => SizedBox(height: itemSpacing),
      itemBuilder: (context, index) => children[index],
    );
  }
}
