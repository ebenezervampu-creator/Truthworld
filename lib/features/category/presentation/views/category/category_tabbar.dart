import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class CategoryTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;

  const CategoryTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = AppTheme.colors.textPrimary;
    final Color unselectedColor = AppTheme.colors.textPrimary.withValues(
      alpha: 0.7,
    );
    final Color selectedBgColor = AppTheme.colors.textPrimary.withValues(
      alpha: 0.2,
    );
    final Color selectedBorderColor = AppTheme.colors.textPrimary;
    final Color unselectedBorderColor = AppTheme.colors.textPrimary.withValues(
      alpha: 0.5,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          tabs.length,
          (index) => InkWell(
            onTap: () => onTabSelected(index),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 6.0),
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: selectedIndex == index
                    ? selectedBgColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedIndex == index
                      ? selectedBorderColor
                      : unselectedBorderColor,
                  width: 1,
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





