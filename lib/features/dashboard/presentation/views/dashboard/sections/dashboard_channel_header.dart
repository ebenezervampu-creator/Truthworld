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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel Overview',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 28 days',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            if (channel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                    Text(
                      channelName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
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
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius.lg),
        border: Border.all(
          color: AppColors.bgSurfaceContainerHighest,
        ),
      ),
      child: TextField(
        controller: searchController,
        style: TextStyle(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
          fontSize: 14,
        ),
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search your content...',
          hintStyle: TextStyle(
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black,
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
            horizontal: 16,
            vertical: 14,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Channel violations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Copyright claims',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your channel has $copyrightClaimsCount active copyright claims. This may affect your visibility or monetization.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? AppColors.textSecondary : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onViewDetails,
            child: const Text(
              'VIEW DETAILS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
