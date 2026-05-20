import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

class TruthIndexBadge extends StatelessWidget {
  final Video video;
  final bool showLabel;
  final bool isLarge;

  const TruthIndexBadge({
    super.key,
    required this.video,
    this.showLabel = true,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    // Path 1 Rule: If truthScore is null, it's non-factual content (Belief/Opinion/Satire)
    final isNonFactual = video.truthScore == null;
    final score = video.videoRating; // 0-10 scale
    final color = isNonFactual
        ? const Color(0xFF6366F1)
        : _getScoreColor(score);

    return InkWell(
      onTap: () {
        final vc = Get.find<VideoController>(tag: video.id);
        vc.fetchFullDisclosure();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 16 : 12,
          vertical: isLarge ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Index and Label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNonFactual)
                  Icon(Icons.auto_awesome, size: isLarge ? 18 : 14, color: color)
                else
                  _buildPulseIcon(color, isLarge),
                const SizedBox(width: 8),
                Text(
                  isNonFactual ? 'EPISTEMIC BUCKET' : 'TRUTH INDEX',
                  style: GoogleFonts.outfit(
                    fontSize: isLarge ? 11 : 9,
                    fontWeight: FontWeight.w800,
                    color: color.withValues(alpha: 0.9),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                if (!isNonFactual) ...[
                  Text(
                    '${score.toStringAsFixed(1)}/10',
                    style: GoogleFonts.outfit(
                      fontSize: isLarge ? 15 : 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  video.displayTrustLabel,
                  style: GoogleFonts.outfit(
                    fontSize: isLarge ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            
            // Row 2: Stats (v11.0 Path 1)
            if (video.factCheckStats != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatItem('✅', '${video.factCheckStats!.verifiedTrue} verified', isLarge),
                  const SizedBox(width: 10),
                  _buildStatItem('❌', '${video.factCheckStats!.falseClaim} false', isLarge),
                  const SizedBox(width: 10),
                  _buildStatItem('🕊️', '${video.factCheckStats!.religiousBelief} beliefs', isLarge),
                  if (video.factCheckStats!.verificationTimeout > 0) ...[
                    const SizedBox(width: 10),
                    _buildStatItem('⏳', '${video.factCheckStats!.verificationTimeout} incomplete', isLarge),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String text, bool isLarge) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: isLarge ? 12 : 10)),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: isLarge ? 11 : 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPulseIcon(Color color, bool isLarge) {
    return Container(
      width: isLarge ? 10 : 8,
      height: isLarge ? 10 : 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    // 0-10 scale mapping to premium HSL colors
    if (score >= 9.0) return const Color(0xFF10B981); // Emerald 500
    if (score >= 7.5) return const Color(0xFF84CC16); // Lime 500
    if (score >= 6.0) return const Color(0xFFEAB308); // Yellow 500
    if (score >= 4.5) return const Color(0xFFF59E0B); // Amber 500
    if (score >= 3.0) return const Color(0xFFEF4444); // Red 500
    return const Color(0xFF7F1D1D); // Dark Red 900
  }
}
