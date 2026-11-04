import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean, high-contrast tab bar matching the exact Channel Creation page theme.
///
/// Styled with AppColors.bgPage surface, AppColors.bgSurface dividers, pure white active
/// indicators, high-contrast count pills (strictly black on white), and ZERO white-on-white violations.
class TruthVerificationTabBar extends StatelessWidget {
  const TruthVerificationTabBar({
    required this.selectedTab,
    required this.onTabSelected,
    required this.claimsCount,
    required this.videosCount,
    required this.opinionsCount,
    required this.sourcesCount,
    required this.isDarkMode,
    super.key,
  });

  final int selectedTab;
  final ValueChanged<int> onTabSelected;
  final int claimsCount;
  final int videosCount;
  final int opinionsCount;
  final int sourcesCount;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTabItem(
                  index: 0,
                  title: 'Fact Claims',
                  icon: Icons.article_outlined,
                  count: '$claimsCount',
                ),
                _buildTabItem(
                  index: 1,
                  title: 'Overview',
                  icon: Icons.show_chart_rounded,
                ),
                _buildTabItem(
                  index: 2,
                  title: 'Video Reports',
                  icon: Icons.video_library_outlined,
                  count: '$videosCount',
                ),
                _buildTabItem(
                  index: 3,
                  title: 'Opinions & Context',
                  icon: Icons.psychology_outlined,
                  count: opinionsCount > 0 ? '$opinionsCount' : null,
                ),
                _buildTabItem(
                  index: 4,
                  title: 'Sources & Citations',
                  icon: Icons.menu_book_outlined,
                  count: sourcesCount > 0 ? '$sourcesCount' : null,
                ),
                _buildTabItem(
                  index: 5,
                  title: 'Conclusion & Insights',
                  icon: Icons.verified_user_outlined,
                ),
                _buildTabItem(
                  index: 6,
                  title: 'Audit & Transparency',
                  icon: Icons.history_edu_rounded,
                ),
                _buildTabItem(
                  index: 7,
                  title: 'Ask AI Truth Coach',
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.bgSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required IconData icon,
    String? count,
  }) {
    final isSelected = selectedTab == index;
    const activeFg = Colors.white;
    const inactiveFg = AppColors.textSecondary;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? activeFg : inactiveFg,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? activeFg : inactiveFg,
                    ),
                  ),
                  if (count != null && count.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black // Strictly black on white!
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Active Underline Indicator Bar
            Container(
              height: 2.5,
              width: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
