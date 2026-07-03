import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

class RealTimeFactOverlayWidget extends StatelessWidget {
  final ClaimResult claim;

  const RealTimeFactOverlayWidget({super.key, required this.claim});

  Color _getVerdictColor(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'verified_true':
      case 'mostly_true':
        return Colors.greenAccent;
      case 'false_claim':
      case 'misleading':
      case 'disputed':
        return Colors.redAccent;
      case 'unproven':
      case 'inconclusive':
      case 'limited_support':
      case 'verification_timeout':
        return Colors.amberAccent;
      default:
        return Colors.blueAccent;
    }
  }

  String _getVerdictLabel(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'verified_true':
        return 'Verified True';
      case 'mostly_true':
        return 'Mostly True';
      case 'false_claim':
        return 'False';
      case 'misleading':
        return 'Misleading';
      case 'disputed':
        return 'Disputed';
      case 'unproven':
        return 'Unproven';
      case 'inconclusive':
        return 'Inconclusive';
      case 'limited_support':
        return 'Limited Support';
      case 'verification_timeout':
        return 'Verification Timeout';
      default:
        return 'Opinion / Unverified';
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdictColor = _getVerdictColor(claim.verdict);
    final verdictLabel = _getVerdictLabel(claim.verdict);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verdict indicator vertical bar
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: verdictColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: verdictColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          verdictLabel.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: verdictColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (claim.isLowRiskTrivia == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.blueAccent.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'TRIVIA',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      claim.text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    if (claim.effectiveSources.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: claim.effectiveSources.take(3).map((src) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  size: 9,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  src.domain ?? src.title,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
