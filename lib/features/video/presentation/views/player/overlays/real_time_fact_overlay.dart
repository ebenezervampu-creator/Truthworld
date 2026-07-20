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
      case 'faith_based_claim':
      case 'not_historically_verifiable':
      case 'historical_tradition':
        return Colors.purpleAccent;
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
      case 'faith_based_claim':
        return 'Faith-Based Claim';
      case 'not_historically_verifiable':
        return 'Not Historically Verifiable';
      case 'historical_tradition':
        return 'Historical Tradition';
      default:
        return 'Opinion / Unverified';
    }
  }

  Widget _buildDetailChip(String label, String value) {
    Color valColor = Colors.white70;
    final upperVal = value.toUpperCase();
    if (upperVal.contains('STRONG') || upperVal.contains('HIGH')) {
      valColor = Colors.greenAccent;
    } else if (upperVal.contains('LIMITED') || upperVal.contains('MODERATE') || (upperVal.contains('NONE') == false && upperVal.contains('LOW'))) {
      valColor = Colors.amberAccent;
    } else if (upperVal.contains('NONE') || upperVal.contains('CONTRADICTED') || upperVal.contains('NO_') || upperVal.contains('NOT_APPLICABLE')) {
      valColor = Colors.redAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
        Text(
          value.replaceAll('_', ' '),
          style: TextStyle(
            color: valColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
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
                            fontFamily: 'Roboto',
                            color: verdictColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (claim.isLowRiskTrivia == true) ...[
                          const SizedBox(width: 8),
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
                            child: const Text(
                              'TRIVIA',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (claim.claimDomain != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.purpleAccent.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '${claim.claimDomain}${claim.claimNature != null ? " / ${claim.claimNature}" : ""}',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.purpleAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      claim.text,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    if (claim.verdictBasis != null && claim.verdictBasis!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: claim.verdictBasis!.map((basis) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            basis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                    
                    // Multidimensional Assessment details for supernatural/religious/faith-based claims
                    if (claim.classificationConfidence != null || claim.historicalEvidenceConfidence != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (claim.classificationConfidence != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.purpleAccent.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CLASSIFICATION',
                                      style: TextStyle(
                                        color: Colors.purpleAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(claim.classificationConfidence! * 100).toInt()}% Confidence',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (claim.classificationConfidence != null && claim.historicalEvidenceConfidence != null)
                            const SizedBox(width: 8),
                          if (claim.historicalEvidenceConfidence != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blueGrey.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'HISTORICAL EVIDENCE',
                                      style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(claim.historicalEvidenceConfidence! * 100).toInt()}% Confidence',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],

                    if (claim.evidenceDetails != null || claim.consensusDetails != null || (claim.evidence != null && claim.evidence!.isNotEmpty) || (claim.consensus != null && claim.consensus!.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (claim.evidence != null && claim.evidence!.isNotEmpty) ...[
                              const Text(
                                'EVIDENCE LEVELS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: claim.evidence!.map((e) => _buildDetailChip(e.type, e.strength)).toList(),
                              ),
                            ] else if (claim.evidenceDetails != null) ...[
                              const Text(
                                'EVIDENCE LEVELS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDetailChip('Scriptural', claim.evidenceDetails!['scriptural'] ?? 'N/A'),
                                  _buildDetailChip('Historical', claim.evidenceDetails!['historical'] ?? 'N/A'),
                                  _buildDetailChip('Scientific', claim.evidenceDetails!['scientific'] ?? 'N/A'),
                                ],
                              ),
                            ],
                            if (((claim.evidence != null && claim.evidence!.isNotEmpty) || claim.evidenceDetails != null) &&
                                ((claim.consensus != null && claim.consensus!.isNotEmpty) || claim.consensusDetails != null))
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6.0),
                                child: Divider(color: Colors.white12, height: 1),
                              ),
                            if (claim.consensus != null && claim.consensus!.isNotEmpty) ...[
                              const Text(
                                'CONSENSUS STATUS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: claim.consensus!.map((c) => _buildDetailChip(c.domain, c.level)).toList(),
                              ),
                            ] else if (claim.consensusDetails != null) ...[
                              const Text(
                                'CONSENSUS STATUS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDetailChip('Theology', claim.consensusDetails!['theology'] ?? 'N/A'),
                                  _buildDetailChip('Historical', claim.consensusDetails!['historical'] ?? 'N/A'),
                                  _buildDetailChip('Scientific', claim.consensusDetails!['scientific'] ?? 'N/A'),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

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
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
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
