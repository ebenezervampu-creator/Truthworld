import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_dispute_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class FactCheckReportWidget extends StatelessWidget {
  const FactCheckReportWidget({
    required this.data,
    required this.video,
    super.key,
  });
  final Map<String, dynamic> data;
  final Video video;

  @override
  Widget build(BuildContext context) {
    // 🧠 Extract multi-dimensional data
    final trustScore =
        ((data['trustScore'] ??
                    data['compositeRating'] ??
                    0.0)
                as num)
            .toDouble();
    final truthScore = ((data['truthScore'] ?? trustScore) as num).toDouble();
    final honestyScore = ((data['honestyScore'] ?? 0.0) as num).toDouble();
    final rationalityScore = ((data['rationalityScore'] ?? 0.0) as num)
        .toDouble();

    final stats = data['factCheckStats'] as Map? ?? {};
    final claims = data['claims'] as List? ?? [];
    final diagnostics = data['diagnostics'] as List? ?? [];
    final deductions = data['deductions'] as List? ?? [];
    final factors = data['factors'] as Map? ?? {};

    // 🏛 Extract UI Report fields if available
    final uiReport = data['uiReport'] as Map? ?? {};
    final narrative =
        uiReport['narrative'] as String? ?? data['viewerNote'] as String? ?? '';
    final sources =
        uiReport['sources'] as List? ?? data['richSources'] as List? ?? [];
    final conclusion = uiReport['conclusion'] as String? ?? '';
    final confidence = ((data['confidence'] ?? 0.5) as num).toDouble();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(height: 24),

                    _buildMetricsRow(
                      truth: truthScore,
                      honesty: honestyScore,
                      rationality: rationalityScore,
                    ),
                    const SizedBox(height: 24),
                    _buildConfidenceBar(confidence),
                    const SizedBox(height: 32),

                    _buildStatsRow(stats),
                    const SizedBox(height: 32),

                    if (narrative.isNotEmpty) ...[
                      _buildNarrativeSection(narrative),
                      const SizedBox(height: 32),
                    ],

                    if (factors.isNotEmpty) ...[
                      const SizedBox.shrink(),
                      const SizedBox(height: 32),
                    ],

                    if (deductions.isNotEmpty) ...[
                      const SizedBox.shrink(),
                      const SizedBox(height: 32),
                    ],

                    _buildClaimsSection(context, claims),
                    const SizedBox(height: 32),

                    if (sources.isNotEmpty) ...[
                      _buildSourcesSection(sources),
                      const SizedBox(height: 32),
                    ],

                    if (conclusion.isNotEmpty) ...[
                      _buildConclusionSection(conclusion),
                      const SizedBox(height: 32),
                    ],

                    _buildDiagnosticsSection(diagnostics),
                    const SizedBox(height: 48),

                    _buildFooter(context),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI FULL DISCLOSURE',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 10,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CRYPTO-VERIFIED ANALYSIS',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainRatingSection(double rating, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child:
                    CircularProgressIndicator(
                      value: rating / 100,
                      strokeWidth: 12,
                      backgroundColor: AppColors.bgDivider,
                      color: color,
                      strokeCap: StrokeCap.round,
                    ).animate().custom(
                      duration: 1500.ms,
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) =>
                          CircularProgressIndicator(
                            value: value * (rating / 100),
                            strokeWidth: 12,
                            backgroundColor: AppColors.bgDivider,
                            color: color,
                            strokeCap: StrokeCap.round,
                          ),
                    ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${rating.toInt()}',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  Text(
                    '%',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _getRatingLabel(rating),
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'VIDEO INTEGRITY RATING',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMetricsRow({
    required double truth,
    required double honesty,
    required double rationality,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetricRing(
          label: 'TRUTH',
          score: truth,
          color: AppColors.success,
          icon: Icons.fact_check_outlined,
        ),
        _buildMetricRing(
          label: 'HONESTY',
          score: honesty,
          color: AppColors.info,
          icon: Icons.face_outlined,
        ),
        _buildMetricRing(
          label: 'LOGIC',
          score: rationality,
          color: AppColors.brandHover,
          icon: Icons.psychology_outlined,
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildMetricRing({
    required String label,
    required double score,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 4,
                backgroundColor: AppColors.bgDivider,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Icon(icon, color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${score.toInt()}%',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    // confidence is 0.0 to 1.0
    final value = confidence > 1.0 ? confidence / 100 : confidence;
    final color = value >= 0.8
        ? AppColors.success
        : (value >= 0.5 ? AppColors.warning : AppColors.error);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ANALYSIS CONFIDENCE',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgDivider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: 1000.ms,
              height: 6,
              width: (Get.width - 48) * value,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.5), color],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
                ],
              ),
            ).animate().shimmer(delay: 500.ms, duration: 2000.ms),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map stats) {
    return Row(
      children: [
        _buildStatCard(
          'Total Claims',
          '${stats['totalClaims'] ?? 0}',
          Icons.article_outlined,
          AppColors.info,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Verified',
          '${stats['correct'] ?? stats['verifiedClaims'] ?? 0}',
          Icons.check_circle_outlined,
          AppColors.success,
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTextStyles.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrativeSection(String narrative) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUMMARY ANALYSIS',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Text(
            narrative,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFactorsSection(Map factors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRUST DRIVERS',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: factors.entries
              .map((e) => _buildFactorChip(e.key as String, e.value))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFactorChip(String key, dynamic value) {
    final score = ((value ?? 0) as num).toDouble();
    final color = _getScoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${score.toInt()}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionsSection(List deductions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSTITUTIONAL DEDUCTIONS',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.error,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...deductions.map((e) => _buildDeductionItem(e as Map)),
      ],
    );
  }

  Widget _buildDeductionItem(Map d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.remove_circle_outline,
            color: AppColors.error,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (d['reason'] as String?) ?? '',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '-${d['points']}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsSection(BuildContext context, List claims) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CLAIM VERIFICATION',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            TextButton.icon(
              onPressed: () => ClaimSourceSubmissionDialog.show(
                context: context,
                video: video,
                claims: claims,
              ),
              icon: const Icon(
                Icons.add_link_rounded,
                color: AppColors.textPrimary,
                size: 14,
              ),
              label: const Text(
                'Provide Evidence',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (claims.isEmpty)
          _buildEmptyBox('No specific claims extracted for this analysis.')
        else
          ...claims.asMap().entries.map(
            (entry) =>
                _buildClaimItem(context, entry.value as Map, claims, entry.key),
          ),
      ],
    );
  }

  Widget _buildClaimItem(
    BuildContext context,
    Map claim,
    List claims,
    int index,
  ) {
    final status = (claim['status'] ?? '').toString().toLowerCase();
    final isVerified =
        status == 'correct' ||
        status == 'mostly_correct' ||
        claim['isVerified'] == true;
    final color = isVerified ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isVerified ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (claim['claim'] ?? claim['text'] ?? '').toString(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (claim['explanation'] != null ||
                        claim['reasoning'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        (claim['explanation'] ?? claim['reasoning'])
                                ?.toString() ??
                            '',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => ClaimSourceSubmissionDialog.show(
                context: context,
                video: video,
                claims: claims,
                initialClaim: claim,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_link_rounded,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Provide Source for Claim',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (600 + (index * 100)).ms).slideX(begin: 0.05);
  }

  Widget _buildSourcesSection(List<dynamic> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VERIFIED SOURCES',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: sources
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSourceCard(s as Map<dynamic, dynamic>),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSourceCard(Map<dynamic, dynamic> source) {
    final sourceType = source['sourceType']?.toString() ?? 'default';
    final author = source['author']?.toString();
    final bookTitle = source['bookTitle']?.toString();
    final chapter = source['chapter']?.toString();
    final pageNumbers = source['pageNumbers']?.toString();
    final volume = source['volume']?.toString();
    final journalName = source['journalName']?.toString();
    final yearPublished = source['yearPublished'];
    final title = source['title']?.toString();
    final domain = source['domain']?.toString();
    final trustLevel = source['trustLevel']?.toString();
    final snippet = source['snippet']?.toString();
    final directUrl = source['directUrl']?.toString();
    final url = source['url']?.toString();

    IconData icon;
    switch (sourceType) {
      case 'book':
        icon = Icons.menu_book_rounded;
      case 'journal':
        icon = Icons.science_rounded;
      case 'newspaper':
        icon = Icons.newspaper_rounded;
      case 'website':
        icon = Icons.language_rounded;
      case 'government':
        icon = Icons.account_balance_rounded;
      case 'scripture':
        icon = Icons.auto_stories_rounded;
      case 'legal':
        icon = Icons.gavel_rounded;
      case 'encyclopedia':
        icon = Icons.library_books_rounded;
      case 'academic_press':
        icon = Icons.school_rounded;
      case 'archive':
        icon = Icons.archive_rounded;
      default:
        icon = Icons.link_rounded;
    }

    final citationParts = <String>[];
    var prefix = '';
    if (sourceType == 'book') {
      prefix = '📖 ';
      if (bookTitle != null) citationParts.add(bookTitle);
      if (chapter != null) citationParts.add(chapter);
      if (pageNumbers != null) citationParts.add(pageNumbers);
    } else if (sourceType == 'journal') {
      prefix = '📰 ';
      if (journalName != null) citationParts.add(journalName);
      if (volume != null) citationParts.add(volume);
      if (pageNumbers != null) citationParts.add(pageNumbers);
    } else {
      if (domain != null) citationParts.add(domain);
    }
    if (yearPublished != null) citationParts.add(yearPublished.toString());

    final citationText = '$prefix${citationParts.join(', ')}';

    var trustColor = AppColors.textTertiary;
    if (trustLevel == 'High') trustColor = AppColors.success;
    if (trustLevel == 'Medium') trustColor = AppColors.warning;
    if (trustLevel == 'Low') trustColor = AppColors.error;

    return GestureDetector(
      onTap: () async {
        final link = directUrl ?? url;
        if (link != null && link.isNotEmpty) {
          try {
            await launchUrl(Uri.parse(link));
          } on Exception catch (_) {}
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author ?? title ?? 'Source',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (citationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      citationText,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"$snippet"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (trustLevel != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: trustColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trustLevel.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 8,
                            color: trustColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (domain != null)
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConclusionSection(String conclusion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            'CONCLUSION',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            conclusion,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsSection(List diagnostics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANALYSIS DIAGNOSTICS',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (diagnostics.isEmpty)
          _buildEmptyBox('No additional diagnostic data recorded.')
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: diagnostics
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              d.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.bgDivider),
        const SizedBox(height: 16),
        Text(
          'TruthWorld employs multi-stage AI verification using institutional-grade data sources. This report represents a point-in-time analysis of the audio-visual content provided.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => FactCheckDisputeDialog.show(context, video),
          icon: const Icon(
            Icons.gavel_rounded,
            color: AppColors.textPrimary,
            size: 16,
          ),
          label: const Text(
            'Report Incorrect? Dispute & Provide Sources',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFF59E0B)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return AppColors.brandHover;
    if (score >= 45) return AppColors.warning;
    if (score >= 30) return AppColors.error;
    return const Color(0xFF991B1B);
  }

  String _getRatingLabel(double score) {
    if (score >= 90) return 'EXCEPTIONAL';
    if (score >= 75) return 'HIGH INTEGRITY';
    if (score >= 60) return 'TRUSTWORTHY';
    if (score >= 45) return 'CAUTION ADVISED';
    if (score >= 30) return 'LOW INTEGRITY';
    return 'UNRELIABLE';
  }
}
