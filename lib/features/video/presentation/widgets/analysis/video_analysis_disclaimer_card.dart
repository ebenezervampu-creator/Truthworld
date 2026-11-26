import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 VideoAnalysisDisclaimerCard
///
/// Production-grade AI Credibility & Fact-Check Disclaimer for the "Ai Check" screen.
/// Communicates platform transparency, automated AI evaluation limits,
/// verified database grounding, and viewer epistemic agency.
class VideoAnalysisDisclaimerCard extends StatelessWidget {
  final VideoAnalysisController? analysisCtrl;
  final EdgeInsetsGeometry? margin;
  final bool isDismissible;

  const VideoAnalysisDisclaimerCard({
    this.analysisCtrl,
    this.margin,
    this.isDismissible = false,
    super.key,
  });

  /// Displays the comprehensive AI Credibility & Epistemic Transparency Modal Sheet.
  static Future<void> showDisclaimerSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AiDisclaimerModalSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = analysisCtrl;

    if (ctrl == null) {
      return _buildStaticCard(context, isExpanded: false);
    }

    return Obx(() {
      if (isDismissible && ctrl.isDisclaimerDismissed.value) {
        return const SizedBox.shrink();
      }

      final isExpanded = ctrl.isDisclaimerExpanded.value;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141926),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.28),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF93C5FD),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'AI Fact-Check Disclaimer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          _AutomatedBadge(),
                        ],
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Assisted Verification • Open Grounding',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Expand / Collapse Action
                InkWell(
                  onTap: ctrl.toggleDisclaimerExpanded,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isExpanded ? 'Less' : 'Details',
                          style: const TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF93C5FD),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                if (isDismissible) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textTertiary,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Dismiss',
                    onPressed: ctrl.dismissDisclaimer,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // 2. Body Text Summary
            Text(
              'TruthWorld uses artificial intelligence to identify factual assertions in dialogue and cross-reference them with verified public databases. Automated evaluations are assistive research tools, not absolute final rulings. Always review linked primary citations and community notes.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11.5,
                height: 1.42,
              ),
            ),

            // 3. Expanded Transparency Details
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              const SizedBox(height: 12),
              const _PillarItem(
                icon: Icons.auto_awesome_outlined,
                title: 'Automated Extraction',
                body:
                    'Speech-to-text algorithms automatically isolate verifiable empirical claims while setting aside creative narratives and personal opinions.',
              ),
              const SizedBox(height: 9),
              const _PillarItem(
                icon: Icons.menu_book_outlined,
                title: 'Multi-Source Grounding',
                body:
                    'Claims are evaluated against authoritative repositories (e.g. NASA, academic journals, encyclopedic archives) available at time of analysis.',
              ),
              const SizedBox(height: 9),
              const _PillarItem(
                icon: Icons.groups_outlined,
                title: 'Epistemic Agency & Community',
                body:
                    'TruthWorld empowers viewers to independently verify facts: inspect raw citations, submit additional evidence, or contribute Community Notes.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showDisclaimerSheet(context),
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Color(0xFF93C5FD),
                  ),
                  label: const Text(
                    'Full Transparency Methodology',
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildStaticCard(BuildContext context, {required bool isExpanded}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141926),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.28),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF93C5FD),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Fact-Check Disclaimer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => showDisclaimerSheet(context),
                child: const Text(
                  'Details',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'TruthWorld uses artificial intelligence to evaluate factual assertions against verified public databases. Automated evaluations are assistive—always inspect linked primary citations.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomatedBadge extends StatelessWidget {
  const _AutomatedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: const Text(
        'AUTOMATED',
        style: TextStyle(
          color: Color(0xFF93C5FD),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PillarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PillarItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: const Color(0xFF60A5FA),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 🏛 Comprehensive Modal Bottom Sheet for AI Credibility & Epistemic Transparency
class _AiDisclaimerModalSheet extends StatelessWidget {
  const _AiDisclaimerModalSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF93C5FD),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Fact-Checking Transparency',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Epistemic Standards & Verification Architecture',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.bgDivider, height: 20),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    title: '1. What Is TruthWorld AI Check?',
                    icon: Icons.smart_toy_outlined,
                    body:
                        'TruthWorld AI Check is an automated analytical system that scans audio transcripts, dialogue, and on-screen content to extract empirical claims and evaluate their factual consistency against verified reference literature.',
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: '2. Zero Mock Data & Authoritative Grounding',
                    icon: Icons.account_balance_outlined,
                    body:
                        'TruthWorld operates under a strict Zero Mock Data Policy. Every verdict is grounded in real-time queries against primary databases, encyclopedias, government archives (such as NASA, PubMed, and national patent databases), and trusted encyclopedic registries.',
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: '3. Limitations of Automated Fact-Checking',
                    icon: Icons.warning_amber_rounded,
                    body:
                        'Automated machine intelligence is subject to limitations: transcript transcription ambiguities, rapidly evolving news, regional context nuances, and non-literal speech (such as satire or idioms). AI ratings are aids for critical thinking, not absolute verdicts.',
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: '4. Viewer Agency & Community Notes',
                    icon: Icons.forum_outlined,
                    body:
                        'We believe true epistemic integrity belongs to an empowered public. Viewers are invited to inspect direct citations, challenge ratings with verified counter-evidence, or submit Community Notes to add essential nuance.',
                  ),
                  const SizedBox(height: 24),

                  // Acknowledgment Button (Zero white-on-white: black text on white surface!)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black, // Strictly black on white!
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'I Understand',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // Explicit high contrast
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF60A5FA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
