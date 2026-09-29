import 'package:flutter/material.dart';

/// Notice banner highlighting transparent dubbing pricing.
class DubbingNoticeBanner extends StatelessWidget {
  const DubbingNoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.paid_outlined,
            color: Color(0xFFFBBF24),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dubbing is NOT Free (Predictable Flat Pricing)',
                  style: TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'AI voice synthesis and translation require compute scaled to video duration and target languages. As a bonus, all dubbed languages automatically include matching subtitles at zero extra charge!',
                  style: TextStyle(
                    color: Color(0xFFFEF3C7),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
