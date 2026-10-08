import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardHeader extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final dynamic channel;
  final String channelName;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  const DashboardHeader({
    required this.isDarkMode,
    required this.isMobile,
    required this.channel,
    required this.channelName,
    required this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Channel Overview',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Last 28 days',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (channel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.textPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (isMobile) ...[
          const SizedBox(height: 16),
          DashboardMobileSearchField(
            isDarkMode: isDarkMode,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            onSearchClear: onSearchClear,
          ),
        ],
      ],
    );
  }
}

class DashboardMobileSearchField extends StatelessWidget {
  final bool isDarkMode;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  const DashboardMobileSearchField({
    required this.isDarkMode,
    required this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search studio content...',
          hintStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: () {
                  searchController.clear();
                  onSearchClear?.call();
                },
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class DashboardChannelViolationsCard extends StatelessWidget {
  final bool isDarkMode;
  final int copyrightClaimsCount;
  final VoidCallback onViewDetails;

  const DashboardChannelViolationsCard({
    required this.isDarkMode,
    required this.copyrightClaimsCount,
    required this.onViewDetails,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Channel violations',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Copyright claims',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your channel has $copyrightClaimsCount active copyright claims. This may affect your visibility or monetization.',
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onViewDetails,
            child: const Text(
              'VIEW DETAILS',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textLink,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
