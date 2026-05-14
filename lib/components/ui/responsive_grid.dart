import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// ResponsiveGrid: Token-based grid system with consistent spacing
///
/// Provides:
/// - Responsive column count based on screen width
/// - Consistent spacing using tokens
/// - Accessibility support
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int columnsDesktop;
  final int columnsTablet;
  final int columnsMobile;
  final double? spacing;
  final double? horizontalPadding;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columnsDesktop = 4,
    this.columnsTablet = 3,
    this.columnsMobile = 2,
    this.spacing,
    this.horizontalPadding,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
  });

  int _getColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return columnsDesktop;
    if (width >= 768) return columnsTablet;
    return columnsMobile;
  }

  @override
  Widget build(BuildContext context) {
    final columns = _getColumns(context);
    final gridSpacing = spacing ?? AppTheme.components.gridSpacing;
    final hPadding = horizontalPadding ?? AppTheme.spacing.md;

    return GridView.builder(
      controller: scrollController,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: AppTheme.spacing.md,
          ),
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
}





