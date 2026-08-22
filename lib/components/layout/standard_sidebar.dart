import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/theme/app_theme.dart';

class SidebarItemData {
  SidebarItemData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
}

class StandardSidebar extends StatelessWidget {
  const StandardSidebar({
    required this.items,
    super.key,
    this.channelItems,
    this.isExpanded = true,
    this.onToggleExpanded,
  });
  final List<SidebarItemData> items;
  final List<Widget>? channelItems;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: isExpanded
          ? AppTheme.sizes.sidebarWidth
          : AppTheme.sizes.sidebarWidthCollapsed,
      decoration: BoxDecoration(
        color: AppTheme.colors.surface,
        border: Border(
          right: BorderSide(color: AppTheme.colors.border),
        ),
      ),
      child: Column(
        children: [
          // Header / Logo area
          if (onToggleExpanded != null)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppTheme.spacing.md,
                horizontal: isExpanded
                    ? AppTheme.spacing.md
                    : AppTheme.spacing.sm,
              ),
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  if (isExpanded)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 24, borderRadius: 6),
                        const SizedBox(width: 8),
                        Text(
                          'Truthworld',
                          style: AppTheme.typography.label.copyWith(
                            color: AppTheme.colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    )
                  else
                    const AppLogo(size: 24, borderRadius: 6),
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.menu_open : Icons.menu,
                      color: AppTheme.colors.textSecondary,
                    ),
                    onPressed: onToggleExpanded,
                  ),
                ],
              ),
            ),

          SizedBox(height: AppTheme.spacing.sm),

          // Items list
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing.sm),
              children: [
                ...items.map(
                  (item) => _SidebarItem(item: item, isExpanded: isExpanded),
                ),
                if (channelItems != null && channelItems!.isNotEmpty) ...[
                  if (isExpanded)
                    Padding(
                      padding: EdgeInsets.only(
                        top: AppTheme.spacing.lg,
                        bottom: AppTheme.spacing.sm,
                        left: AppTheme.spacing.md,
                      ),
                      child: Text(
                        'SUBSCRIBED',
                        style: AppTheme.typography.label.copyWith(
                          color: AppTheme.colors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacing.md,
                      ),
                      child: Divider(color: AppTheme.colors.border),
                    ),
                  ...channelItems!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.isExpanded});
  final SidebarItemData item;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final isSelected = item.isSelected;
    final itemWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing.xs,
        vertical: AppTheme.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.colors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: AppTheme.radius.circularMd,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTheme.radius.circularMd,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: AppTheme.radius.circularMd,
          hoverColor: AppTheme.colors.textPrimary.withValues(alpha: 0.05),
          splashColor: AppTheme.colors.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppTheme.spacing.sm,
              horizontal: isExpanded ? AppTheme.spacing.md : 0,
            ),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (isSelected && isExpanded)
                  Container(
                    width: 3,
                    height: 20,
                    margin: EdgeInsets.only(right: AppTheme.spacing.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.colors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else if (isExpanded)
                  SizedBox(width: 3 + AppTheme.spacing.sm),

                Icon(
                  item.icon,
                  color: isSelected
                      ? AppTheme.colors.primary
                      : AppTheme.colors.textSecondary,
                  size: AppTheme.sizes.iconMd,
                ),
                if (isExpanded) ...[
                  SizedBox(width: AppTheme.spacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTheme.typography.bodyMedium.copyWith(
                        color: isSelected
                            ? AppTheme.colors.primary
                            : AppTheme.colors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: item.label,
      selected: item.isSelected,
      child: isExpanded
          ? itemWidget
          : Tooltip(message: item.label, preferBelow: false, child: itemWidget),
    );
  }
}
