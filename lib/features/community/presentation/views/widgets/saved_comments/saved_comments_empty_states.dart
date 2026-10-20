import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Generic empty state matching NotificationEmptyGeneralState.
class SavedCommentsEmptyState extends StatelessWidget {
  const SavedCommentsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 60,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading indicator state matching NotificationLoadingState.
class SavedCommentsLoadingState extends StatelessWidget {
  const SavedCommentsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.textPrimary.withValues(alpha: 0.6),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Error display state with retry trigger matching NotificationErrorState.
class SavedCommentsErrorState extends StatelessWidget {
  const SavedCommentsErrorState({
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage.isNotEmpty ? errorMessage : 'Something went wrong',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

/// State shown when user is not authenticated.
class SavedCommentsAuthRequiredState extends StatelessWidget {
  const SavedCommentsAuthRequiredState({super.key});

  @override
  Widget build(BuildContext context) {
    return const SavedCommentsEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Sign in to view saved comments',
      subtitle: 'Please sign in to access your saved comments',
    );
  }
}
