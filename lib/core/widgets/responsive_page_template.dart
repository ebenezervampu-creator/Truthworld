// ==========================================================================
// RESPONSIVE PAGE TEMPLATE
// ==========================================================================
// Comprehensive page template that provides excellent responsive behavior
// across all device sizes with adaptive layouts and navigation

import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class ResponsivePageTemplate extends StatelessWidget {
  const ResponsivePageTemplate({
    required this.body,
    super.key,
    this.appBar,
    this.drawer,
    this.sideNavigation,
    this.bottomNavigation,
    this.floatingActionButton,
    this.persistentFooterButtons,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor,
    this.padding,
  });
  final Widget? appBar;
  final Widget? drawer;
  final Widget? sideNavigation;
  final Widget? bottomNavigation;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? persistentFooterButtons;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          appBar: _getAppBar(context),
          drawer: _getDrawer(context),
          body: _buildBody(context),
          bottomNavigationBar: _getBottomNavigation(context),
          floatingActionButton: floatingActionButton,
          persistentFooterButtons: persistentFooterButtons as List<Widget>?,
        );
      },
    );
  }

  PreferredSizeWidget? _getAppBar(BuildContext context) {
    if (context.isDesktop && sideNavigation != null) return null;
    return appBar as PreferredSizeWidget?;
  }

  Drawer? _getDrawer(BuildContext context) {
    if (context.isDesktop) return null;
    if (context.isTablet && sideNavigation != null) {
      return Drawer(child: sideNavigation);
    }
    return drawer as Drawer?;
  }

  Widget _buildBody(BuildContext context) {
    if (context.showSideNav && sideNavigation != null) {
      return Row(
        children: [
          SizedBox(
            width: context.layoutTokens.sidebarWidth,
            child: sideNavigation,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(child: _buildMainContent(context)),
        ],
      );
    }

    return _buildMainContent(context);
  }

  Widget _buildMainContent(BuildContext context) {
    return ResponsiveContainer(padding: padding, child: body);
  }

  Widget? _getBottomNavigation(BuildContext context) {
    if (context.isDesktop || context.isLargeDesktop || context.isUltraWide) {
      return null;
    }
    return bottomNavigation;
  }
}

// ==========================================================================
// RESPONSIVE CONTENT AREA
// ==========================================================================
class ResponsiveContentArea extends StatelessWidget {
  const ResponsiveContentArea({
    required this.children,
    super.key,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.spaced = true,
    this.spacing,
    this.padding,
  });
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final bool spaced;
  final double? spacing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: padding,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: spaced ? _addSpacing(context, children) : children,
      ),
    );
  }

  List<Widget> _addSpacing(BuildContext context, List<Widget> children) {
    if (children.isEmpty) return children;

    final effectiveSpacing = spacing ?? context.layoutSpacing;
    final spacedChildren = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(height: effectiveSpacing));
      }
    }

    return spacedChildren;
  }
}

// ==========================================================================
// RESPONSIVE SECTION
// ==========================================================================
class ResponsiveSection extends StatelessWidget {
  const ResponsiveSection({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.action,
    this.sectionPadding,
    this.showDivider = false,
  });
  final String? title;
  final Widget? subtitle;
  final Widget? action;
  final Widget child;
  final EdgeInsets? sectionPadding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            _buildHeader(context),
            SizedBox(height: context.layoutSpacing),
          ],
          child,
          if (showDivider) ...[
            SizedBox(height: context.layoutSpacing),
            const Divider(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize:
                      (Theme.of(context).textTheme.headlineSmall?.fontSize ??
                          24) *
                      context.fontScale,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: context.layoutSpacing / 4),
                subtitle!,
              ],
            ],
          ),
        ),
        if (action != null) ...[
          SizedBox(width: context.layoutSpacing),
          action!,
        ],
      ],
    );
  }
}

// ==========================================================================
// RESPONSIVE GRID LAYOUT
// ==========================================================================
class ResponsiveGridLayout extends StatelessWidget {
  const ResponsiveGridLayout({
    required this.children,
    super.key,
    this.maxColumns,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.childAspectRatio,
    this.padding,
  });
  final List<Widget> children;
  final int? maxColumns;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final double? childAspectRatio;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.getGridColumns(
      context.screenWidth,
      maxColumns: maxColumns ?? 4,
    );

    return ResponsiveContainer(
      padding: padding,
      child: GridView.count(
        crossAxisCount: columns,
        crossAxisSpacing: crossAxisSpacing ?? context.layoutSpacing,
        mainAxisSpacing: mainAxisSpacing ?? context.layoutSpacing,
        childAspectRatio: childAspectRatio ?? 1.0,
        children: children,
      ),
    );
  }
}

// ==========================================================================
// RESPONSIVE LIST LAYOUT
// ==========================================================================
class ResponsiveListLayout extends StatelessWidget {
  const ResponsiveListLayout({
    required this.children,
    super.key,
    this.padding,
    this.spacing,
    this.shrinkWrap = false,
    this.physics,
  });
  final List<Widget> children;
  final EdgeInsets? padding;
  final double? spacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: padding,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: children.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: spacing ?? context.layoutSpacing),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

// ==========================================================================
// RESPONSIVE CARD LAYOUT
// ==========================================================================
class ResponsiveCardLayout extends StatelessWidget {
  const ResponsiveCardLayout({
    required this.children,
    super.key,
    this.maxColumns,
    this.padding,
    this.showListView = false,
  });
  final List<Widget> children;
  final int? maxColumns;
  final EdgeInsets? padding;
  final bool showListView;

  @override
  Widget build(BuildContext context) {
    if (showListView || context.isMobileSmall) {
      return ResponsiveListLayout(padding: padding, children: children);
    }

    return ResponsiveGridLayout(
      maxColumns: maxColumns,
      padding: padding,
      childAspectRatio: _getCardAspectRatio(context),
      children: children,
    );
  }

  double _getCardAspectRatio(BuildContext context) {
    if (context.isMobile) return 1.4;
    if (context.isTablet) return 1.3;
    return 1.2;
  }
}

// ==========================================================================
// RESPONSIVE WRAPPER
// ==========================================================================
class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({
    required this.child,
    super.key,
    this.padding,
    this.centerContent = true,
    this.maxWidth,
  });
  final Widget child;
  final EdgeInsets? padding;
  final bool centerContent;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: padding,
      maxWidth: maxWidth,
      centerContent: centerContent,
      child: child,
    );
  }
}
