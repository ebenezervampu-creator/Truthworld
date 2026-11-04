import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class SettingsSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSectionCard({
    required this.title,
    required this.children,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(context.layoutSpacing),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
