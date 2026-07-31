import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
// =============================================================================
// CREATE CONTENT SCREEN — Content Type Chooser
// Replaces the old monolithic EnhancedUploadScreen
// =============================================================================

class CreateContentScreen extends StatelessWidget {
  const CreateContentScreen({super.key});

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPage : AppColors.textPrimary,
      body: SafeArea(
        child: _isMobile(context)
            ? _buildMobileLayout(context, isDark)
            : _buildDesktopLayout(context, isDark),
      ),
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” DESKTOP â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildDesktopLayout(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 40),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.6,
                children: _buildContentCards(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” MOBILE â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildMobileAppBar(context, isDark),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark, compact: true),
                const SizedBox(height: 24),
                ..._buildContentCards(isDark).map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: card,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // â”â”â”â”â”â”â”â”â”â”â” COMPONENTS â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

  Widget _buildMobileAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgPage : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.bgSurface : AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: Get.back,
          ),
          const SizedBox(width: 8),
          Text(
            'Upload',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimary : AppColors.bgPage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, {bool compact = false}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brand,
                AppColors.textSecondary,
              ],
            ),
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: AppColors.textSecondary.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            size: compact ? 24 : 32,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Content',
                style: TextStyle(
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimary : AppColors.bgPage,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what you want to share with your audience',
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  color: isDark
                      ? AppColors.textPrimary54
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContentCards(bool isDark) {
    final items = [
      const _ContentType(
        icon: Icons.videocam_rounded,
        title: 'Upload Video',
        description:
            'Share a video with your audience. Add a thumbnail, title, description, and more.',
        gradient: [AppColors.brand, AppColors.textSecondary],
        route: '/uploadvideo',
        badge: '',
      ),
      const _ContentType(
        icon: Icons.poll_rounded,
        title: 'Create Poll',
        description: 'Ask your audience questions and get their votes.',
        gradient: [Color(0xFF8B5CF6), AppTheme.info],
        route: '/createpoll',
        badge: 'New',
      ),
      const _ContentType(
        icon: Icons.article_rounded,
        title: 'Community Post',
        description: 'Share text and image updates with your subscribers.',
        gradient: [Color(0xFFF59E0B), AppColors.brand],
        route: '/createpost',
        badge: '',
      ),
    ];

    return items.map((item) {
      return InkWell(
        onTap: () => Get.toNamed(item.route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgSurface : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.bgSurface : AppColors.textSecondary,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: item.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                  ),
                  if (item.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.badge,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimary : AppColors.bgPage,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondary : AppColors.bgPage54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Internal data class for content type card rendering.
class _ContentType {
  const _ContentType({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.route,
    required this.badge,
  });
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final String route;
  final String badge;
}
