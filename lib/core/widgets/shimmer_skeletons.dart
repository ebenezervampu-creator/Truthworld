/// Reusable Shimmer Skeleton Components
///
/// Drop-in loading skeletons that match the shape of real content.
/// Use these instead of bare CircularProgressIndicator.
///
/// Truthworld-style: content-shaped skeletons that feel alive before data arrives.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

// ─── Base Shimmer Wrapper ────────────────────────────────────────────────────

class _ShimmerBase extends StatelessWidget {
  const _ShimmerBase({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceHover,
      highlightColor: AppColors.bgDivider,
      child: child,
    );
  }
}

Widget _bone({double? width, double height = 14, double radius = 4}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ─── Video Card Skeleton (List Layout) ───────────────────────────────────────

/// Matches the shape of [VideoListCard].
/// Use in ListView.builder when videos are loading.
class ShimmerVideoListCard extends StatelessWidget {
  const ShimmerVideoListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            _bone(width: 160, height: 90, radius: 12),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.7,
                    alignment: Alignment.centerLeft,
                    child: _bone(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _bone(width: 24, height: 24, radius: 12),
                      const SizedBox(width: 8),
                      Expanded(child: _bone(height: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _bone(height: 10)),
                      const SizedBox(width: 12),
                      Expanded(child: _bone(height: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Video Card Skeleton (Grid Layout) ───────────────────────────────────────

/// Matches the shape of [VideoGridCard].
/// Use in GridView.builder when the home feed is loading.
class ShimmerVideoGridCard extends StatelessWidget {
  const ShimmerVideoGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail placeholder (16:9)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Details placeholder
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar bone
              _bone(width: 36, height: 36, radius: 18),
              const SizedBox(width: 8),
              // Title and info bones
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bone(width: double.infinity),
                    const SizedBox(height: 6),
                    _bone(width: 120, height: 12),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _bone(width: 50, height: 10),
                        const SizedBox(width: 8),
                        _bone(width: 50, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Comment Skeleton ────────────────────────────────────────────────────────

/// Matches a typical comment row: avatar + username + text lines.
class ShimmerCommentCard extends StatelessWidget {
  const ShimmerCommentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _bone(width: 36, height: 36, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username + timestamp
                  Row(
                    children: [
                      _bone(width: 100, height: 12),
                      const SizedBox(width: 8),
                      _bone(width: 50, height: 10),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Comment text (2 lines)
                  _bone(width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  _bone(width: 200, height: 12),
                  const SizedBox(height: 10),
                  // Action row (like, dislike, reply)
                  Row(
                    children: [
                      _bone(width: 20, height: 20, radius: 10),
                      const SizedBox(width: 4),
                      _bone(width: 24, height: 10),
                      const SizedBox(width: 16),
                      _bone(width: 20, height: 20, radius: 10),
                      const SizedBox(width: 16),
                      _bone(width: 40, height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Channel Card Skeleton ───────────────────────────────────────────────────

/// Matches a channel discovery card: avatar + name + subscriber count.
class ShimmerChannelCard extends StatelessWidget {
  const ShimmerChannelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            // Channel avatar
            _bone(width: 48, height: 48, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(width: 140),
                  const SizedBox(height: 6),
                  _bone(width: 90, height: 11),
                ],
              ),
            ),
            // Subscribe button
            _bone(width: 80, height: 32, radius: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Convenience Builders ────────────────────────────────────────────────────

/// Builds a list of N shimmer video skeletons (list layout).
Widget buildShimmerVideoList({int count = 6}) {
  return ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: count,
    itemBuilder: (_, i) => const ShimmerVideoListCard(),
  );
}

/// Builds a grid of N shimmer video skeletons.
Widget buildShimmerVideoGrid({int crossAxisCount = 2, int count = 6}) {
  return GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
    ),
    itemCount: count,
    itemBuilder: (_, i) => const ShimmerVideoGridCard(),
  );
}

/// Builds a list of N shimmer comment skeletons.
Widget buildShimmerCommentList({int count = 5}) {
  return ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: count,
    itemBuilder: (_, i) => const ShimmerCommentCard(),
  );
}

// ─── Discover Channel Card Skeleton ──────────────────────────────────────────

/// Matches the shape of [_ChannelCard] in [DiscoverChannelsPage].
class ShimmerDiscoverChannelCard extends StatelessWidget {
  const ShimmerDiscoverChannelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBase(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner (Height 72)
            Container(
              height: 72,
              width: double.infinity,
              color: AppColors.textPrimary,
            ),
            // Channel details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar (radius 22 -> width 44)
                        _bone(width: 44, height: 44, radius: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _bone(width: 100),
                              const SizedBox(height: 4),
                              _bone(width: 60, height: 11),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Description (2 lines)
                    _bone(width: double.infinity, height: 12),
                    const SizedBox(height: 6),
                    _bone(width: 150, height: 12),
                    const Spacer(),
                    // Stats and subscribe button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bone(width: 80, height: 11),
                            const SizedBox(height: 4),
                            _bone(width: 50, height: 10),
                          ],
                        ),
                        // Subscribe button
                        _bone(width: 80, height: 32, radius: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Playlist Detail Skeleton ────────────────────────────────────────────────

class ShimmerPlaylistDetail extends StatelessWidget {
  const ShimmerPlaylistDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1000;
          final isTablet =
              constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

          if (isDesktop) {
            return Row(
              children: [
                // Left sidebar
                Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.bgDivider, width: 0.5),
                    ),
                  ),
                  child: _ShimmerBase(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Large thumbnail
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _bone(width: double.infinity, radius: 12),
                        ),
                        const SizedBox(height: 24),
                        // Title
                        _bone(width: 220, height: 24),
                        const SizedBox(height: 16),
                        // Channel info
                        Row(
                          children: [
                            _bone(width: 32, height: 32, radius: 16),
                            const SizedBox(width: 10),
                            _bone(width: 120),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats
                        _bone(width: 180, height: 12),
                        const SizedBox(height: 24),
                        // Buttons
                        Row(
                          children: [
                            Expanded(child: _bone(height: 38, radius: 20)),
                            const SizedBox(width: 8),
                            Expanded(child: _bone(height: 38, radius: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Right video list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: 5,
                    itemBuilder: (_, _) => const ShimmerVideoListCard(),
                  ),
                ),
              ],
            );
          } else {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ShimmerBase(
                    child: Padding(
                      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                          SizedBox(
                            width: isTablet ? 200.0 : 140.0,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _bone(width: double.infinity, radius: 12),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _bone(width: double.infinity, height: 18),
                                const SizedBox(height: 8),
                                _bone(width: 100),
                                const SizedBox(height: 10),
                                _bone(width: 120, height: 12),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _bone(height: 38, radius: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _bone(height: 38, radius: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ShimmerBase(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: _bone(
                        width: double.infinity,
                        height: 40,
                        radius: 8,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const ShimmerVideoListCard(),
                    childCount: 4,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

// ─── Creator Studio Dashboard Skeleton ───────────────────────────────────────

class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _ShimmerBase(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bone(width: 250, height: 28),
                      const SizedBox(height: 8),
                      _bone(width: 180),
                    ],
                  ),
                  _bone(width: 140, height: 40, radius: 20),
                ],
              ),
              const SizedBox(height: 32),

              // Stats Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet =
                      constraints.maxWidth >= 600 &&
                      constraints.maxWidth < 1000;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.bgDivider,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                _bone(width: 24, height: 24, radius: 12),
                                const SizedBox(width: 8),
                                _bone(width: 70, height: 12),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _bone(width: 100, height: 24),
                            const SizedBox(height: 8),
                            _bone(width: 60, height: 11),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),

              // Performance & Quick Actions rows
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSingleColumn = constraints.maxWidth < 900;

                  final mainArea = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recent Performance Shimmer Card
                      Container(
                        height: 240,
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.bgDivider,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bone(width: 180, height: 18),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                color: AppColors.bgDivider,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Latest Content Section
                      _bone(width: 140, height: 18),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              _bone(width: 120, height: 68, radius: 8),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _bone(width: double.infinity),
                                    const SizedBox(height: 6),
                                    _bone(width: 150, height: 11),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final sidebarArea = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.bgDivider,
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bone(width: 100, height: 16),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                _bone(width: 20, height: 20, radius: 10),
                                const SizedBox(width: 10),
                                _bone(width: 80, height: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isSingleColumn) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        mainArea,
                        const SizedBox(height: 24),
                        sidebarArea,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: mainArea),
                      const SizedBox(width: 24),
                      Expanded(child: sidebarArea),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Video Screen Placeholder Skeleton ────────────────────────────────────────

class ShimmerVideoScreen extends StatelessWidget {
  const ShimmerVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1050;

            final videoPlayerPlaceholder = _ShimmerBase(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.bgPage),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: AppColors.textDisabled,
                      size: 64,
                    ),
                  ),
                ),
              ),
            );

            final mainContent = _ShimmerBase(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    _bone(width: double.infinity, height: 20),
                    const SizedBox(height: 8),
                    _bone(width: 200),
                    const SizedBox(height: 16),
                    // Channel Info & Subscribe Button
                    Row(
                      children: [
                        _bone(width: 40, height: 40, radius: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bone(width: 120),
                            const SizedBox(height: 4),
                            _bone(width: 80, height: 11),
                          ],
                        ),
                        const Spacer(),
                        _bone(width: 90, height: 36, radius: 18),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons Row (Like, share, download)
                    Row(
                      children: [
                        _bone(width: 80, height: 36, radius: 18),
                        const SizedBox(width: 8),
                        _bone(width: 80, height: 36, radius: 18),
                        const SizedBox(width: 8),
                        _bone(width: 80, height: 36, radius: 18),
                      ],
                    ),
                  ],
                ),
              ),
            );

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side (Video + details)
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          videoPlayerPlaceholder,
                          mainContent,
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(
                              color: AppColors.bgDivider,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right side (Recommendations sidebar)
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppColors.bgDivider,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      itemBuilder: (_, _) => const ShimmerVideoListCard(),
                    ),
                  ),
                ],
              );
            } else {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    videoPlayerPlaceholder,
                    mainContent,
                    const Divider(color: AppColors.bgDivider, height: 1),
                    // Mobile comments / recommendations preview
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _ShimmerBase(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bone(width: 100, height: 16),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _bone(width: 28, height: 28, radius: 14),
                                const SizedBox(width: 10),
                                _bone(width: 200, height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

/// A shimmering text widget typically used inside a button when in a loading/submitting state.
class ShimmerButtonText extends StatelessWidget {
  const ShimmerButtonText(
    this.text, {
    super.key,
    this.style,
    this.baseColor,
    this.highlightColor,
  });
  final String text;
  final TextStyle? style;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.labelLarge;
    final textColor = defaultStyle?.color ?? AppColors.textPrimary;

    return Shimmer.fromColors(
      baseColor: baseColor ?? textColor.withValues(alpha: 0.6),
      highlightColor: highlightColor ?? textColor,
      child: Text(text, style: defaultStyle),
    );
  }
}

class ShimmerVideoGrid extends StatelessWidget {
  const ShimmerVideoGrid({
    super.key,
    this.itemCount = 6,
    this.isDesktop = false,
    this.isTablet = false,
  });
  final int itemCount;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final isMobile = !isDesktop && !isTablet;
    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isMobile ? 1.2 : 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          highlightColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.1,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}

/// Matches the shape of [ChannelDetailsPage].
/// Used when loading channel from a deep link or direct URL.
class ShimmerChannelDetailsScreen extends StatelessWidget {
  const ShimmerChannelDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: _ShimmerBase(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Shimmer
              Container(
                width: double.infinity,
                height: 140,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 16),
              // Channel Header Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bone(width: 80, height: 80, radius: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bone(width: 180, height: 22, radius: 6),
                          const SizedBox(height: 8),
                          _bone(width: 120),
                          const SizedBox(height: 8),
                          _bone(width: 200, height: 12),
                          const SizedBox(height: 12),
                          _bone(width: 130, height: 36, radius: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Tab Bar Bones
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _bone(width: 60, height: 32, radius: 8),
                    const SizedBox(width: 12),
                    _bone(width: 70, height: 32, radius: 8),
                    const SizedBox(width: 12),
                    _bone(width: 70, height: 32, radius: 8),
                    const SizedBox(width: 12),
                    _bone(width: 60, height: 32, radius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 16),
              // Video Grid Bones
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    final crossAxisCount = isDesktop ? 3 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isDesktop ? 16 / 13 : 16 / 10,
                      ),
                      itemCount: isDesktop ? 6 : 3,
                      itemBuilder: (context, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _bone(
                                width: double.infinity,
                                radius: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _bone(width: double.infinity, height: 16),
                            const SizedBox(height: 4),
                            _bone(width: 140, height: 12),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
