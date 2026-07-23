import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategoryTabBar extends StatelessWidget {

  const CategoryTabBar({
    required this.tabs, required this.selectedIndex, required this.onTabSelected, super.key,
  });
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppTheme.colors.textPrimary;
    final unselectedColor = AppTheme.colors.textPrimary.withValues(
      alpha: 0.7,
    );
    final selectedBgColor = AppTheme.colors.textPrimary.withValues(
      alpha: 0.2,
    );
    final selectedBorderColor = AppTheme.colors.textPrimary;
    final unselectedBorderColor = AppTheme.colors.textPrimary.withValues(
      alpha: 0.5,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          tabs.length,
          (index) => InkWell(
            onTap: () => onTabSelected(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selectedIndex == index
                    ? selectedBgColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedIndex == index
                      ? selectedBorderColor
                      : unselectedBorderColor,
                ),
                boxShadow: selectedIndex == index
                    ? [
                        BoxShadow(
                          color: AppTheme.colors.background.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: selectedIndex == index
                      ? selectedColor
                      : unselectedColor,
                  fontWeight: selectedIndex == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}





