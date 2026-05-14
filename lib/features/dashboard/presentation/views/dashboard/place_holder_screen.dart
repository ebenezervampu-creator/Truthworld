import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String featureName;
  final bool isDarkMode;

  const PlaceholderScreen({
    super.key,
    required this.icon,
    required this.featureName,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (AppTheme.colors.textSecondary).withValues(alpha: 0.2),
                  (AppTheme.colors.textSecondary).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              icon,
              size: 60,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary54
                  : AppTheme.colors.textSecondary,
            ),
          ),
          SizedBox(height: 32),
          Text(
            '$featureName Coming Soon',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary
                  : AppTheme.colors.background,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'This feature is currently under development.',
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary70
                  : AppTheme.colors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}





