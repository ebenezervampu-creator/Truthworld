import 'package:flutter/material.dart';

/// Reusable high-contrast audio metadata display (Title, Channel, Format Badge).
class AudioMetadata extends StatelessWidget {
  const AudioMetadata({
    required this.title,
    required this.channelName,
    required this.titleSize,
    required this.channelSize,
    this.badgeText,
    this.badgeColor,
    this.textAlign = TextAlign.center,
    super.key,
  });

  final String title;
  final String channelName;
  final double titleSize;
  final double channelSize;
  final String? badgeText;
  final Color? badgeColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (badgeText != null && badgeText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.white).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (badgeColor ?? Colors.white).withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Text(
              badgeText!,
              style: TextStyle(
                color: badgeColor ?? Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          channelName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: channelSize,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
