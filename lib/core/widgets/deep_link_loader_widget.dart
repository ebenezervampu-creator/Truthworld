import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Branded loading screen used by all deep-link loaders (video, channel, playlist).
///
/// Features:
/// - Animated pulsing icon with glow effect
/// - Status message with shimmer
/// - Error state with retry button
/// - Consistent dark theme matching Truthworld branding
class DeepLinkLoaderWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;

  const DeepLinkLoaderWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.onGoHome,
  });

  @override
  State<DeepLinkLoaderWidget> createState() => _DeepLinkLoaderWidgetState();
}

class _DeepLinkLoaderWidgetState extends State<DeepLinkLoaderWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.surface,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: widget.hasError ? _buildErrorState() : _buildLoadingState(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated icon with glow
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, child) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(
                    alpha: _glowAnim.value * 0.4,
                  ),
                  blurRadius: 30 + (_glowAnim.value * 20),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor,
                    widget.accentColor.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: AppTheme.colors.textPrimary,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Title
        Text(
          widget.title,
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppTheme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle
        Text(
          widget.subtitle,
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: AppTheme.colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Progress bar
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.colors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
              minHeight: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.colors.surface.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.colors.surface.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: AppTheme.colors.error,
            size: 48,
          ),
        ),
        const SizedBox(height: 28),
        // Error title
        Text(
          'Content Not Found',
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppTheme.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        // Error message
        Text(
          widget.errorMessage ??
              'The content you\'re looking for may have been removed or is unavailable.',
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: AppTheme.colors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onRetry != null)
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Retry',
                color: widget.accentColor,
                filled: true,
                onTap: widget.onRetry!,
              ),
            if (widget.onRetry != null && widget.onGoHome != null)
              const SizedBox(width: 12),
            if (widget.onGoHome != null)
              _ActionButton(
                icon: Icons.home_rounded,
                label: 'Go Home',
                color: AppTheme.colors.textSecondary,
                filled: false,
                onTap: widget.onGoHome!,
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.colors.textPrimary,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.colors.textPrimary,
        side: BorderSide(color: color),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}





