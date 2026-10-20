import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlayerToast extends StatelessWidget {
  const PlayerToast({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isZoomToast = message.contains('Zoom') ||
        message.contains('Original') ||
        RegExp(r'^\d+(\.\d+)?x$').hasMatch(message);

    return Align(
      alignment: isZoomToast ? Alignment.topCenter : Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(top: isZoomToast ? 28.0 : 0.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgPage.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PT.border),
          ),
          child: Text(
            message,
            style: TS.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN CONTROLS
// ─────────────────────────────────────────────────────────────────────────────

