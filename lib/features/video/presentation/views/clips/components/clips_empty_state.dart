import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class ClipsEmptyState extends StatelessWidget {
  const ClipsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  Icons.content_cut_rounded,
                  size: 48,
                  color: AppColors.textPrimary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No clips yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find your favorite moments and clip them!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
