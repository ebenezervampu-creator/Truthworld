import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoAnalysisBottomSheet extends StatefulWidget {
  const VideoAnalysisBottomSheet({
    required this.video,
    super.key,
    this.initialTabIndex = 0,
  });
  final Video video;
  final int initialTabIndex;

  @override
  State<VideoAnalysisBottomSheet> createState() =>
      _VideoAnalysisBottomSheetState();
}

class _VideoAnalysisBottomSheetState extends State<VideoAnalysisBottomSheet> {
  late final VideoController videoCtrl;
  bool _showRawJson = false;

  @override
  void initState() {
    super.initState();

    final tag = widget.video.id;
    if (Get.isRegistered<VideoController>(tag: tag)) {
      videoCtrl = Get.find<VideoController>(tag: tag);
    } else if (Get.isRegistered<VideoController>()) {
      videoCtrl = Get.find<VideoController>();
    } else {
      videoCtrl = Get.put(VideoController());
    }

    if (widget.video.factCheckUrl.isNotEmpty &&
        videoCtrl.factCheckData.isEmpty) {
      videoCtrl.loadFactCheckData(widget.video.factCheckUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(context),
              const Divider(height: 1, color: AppColors.bgDivider),
              Expanded(
                child: _buildFactCheckContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI CREDIBILITY & ANALYSIS',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brand,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
            onPressed: Get.back,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactCheckContent() {
    if (widget.video.factCheckUrl.isEmpty) {
      return _buildNoFactCheckFallback();
    }

    return Obx(() {
      final reportData = videoCtrl.factCheckData;
      if (videoCtrl.isLoadingFactCheck.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        );
      }

      if (reportData.isEmpty) {
        return _buildNoFactCheckFallback();
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(reportData);

      return Column(
        children: [
          _buildViewToggleBar(jsonString),
          Expanded(
            child: _showRawJson
                ? _buildRawJsonView(jsonString)
                : _buildFormattedDashboard(reportData, jsonString),
          ),
        ],
      );
    });
  }

  Widget _buildViewToggleBar(String jsonString) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: const Border(
          bottom: BorderSide(color: AppColors.bgDivider, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // View mode toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  label: 'Analysis View',
                  icon: Icons.analytics_outlined,
                  isSelected: !_showRawJson,
                  onTap: () => setState(() => _showRawJson = false),
                ),
                _buildToggleButton(
                  label: 'Raw JSON',
                  icon: Icons.code_rounded,
                  isSelected: _showRawJson,
                  onTap: () => setState(() => _showRawJson = true),
                ),
              ],
            ),
          ),

          // Copy JSON button
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Get.snackbar(
                'Copied',
                'Credibility report JSON copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.bgSurface,
                colorText: AppColors.textPrimary,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(16),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: Colors.white,
            ),
            label: Text(
              'Copy JSON',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedDashboard(
    Map<String, dynamic> data,
    String jsonString,
  ) {
    final analysisState =
        (data['analysisState'] ?? data['state'] ?? 'VERIFIED').toString();
    final scoreAvailable = data['scoreAvailable'] == true;
    final viewerNote = (data['viewerNote'] ??
            data['narrative'] ??
            data['summary'] ??
            data['explanation'] ??
            '')
        .toString();

    final rawTrustScore = data['trustScore'] ??
        data['trustIndex'] ??
        data['score'] ??
        data['videoRating'];
    final trustScore = (rawTrustScore is num) ? rawTrustScore.toDouble() : null;

    final trustLabel = (data['trustLabel'] ??
            data['label'] ??
            (trustScore != null
                ? _getRatingLabel(trustScore)
                : analysisState))
        .toString();

    final confidenceRaw = data['confidence'];
    final confidenceTier = (data['confidenceTier'] ?? '').toString();
    final confidenceVal = (confidenceRaw is num)
        ? (confidenceRaw > 1.0
            ? (confidenceRaw / 100.0)
            : confidenceRaw.toDouble())
        : (confidenceTier.toLowerCase() == 'high'
            ? 0.9
            : (confidenceTier.toLowerCase() == 'medium' ? 0.6 : 0.3));

    final chapters = (data['chapters'] as List?) ?? [];
    final claims = (data['claims'] as List?) ?? [];
    final sources =
        (data['sources'] ?? data['richSources'] as List?) as List? ?? [];
    final factors =
        (data['scoringFactors'] ?? data['factors']) as Map? ?? {};

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Hero Status & Credibility Badge Card
        _buildHeroCard(
          analysisState: analysisState,
          scoreAvailable: scoreAvailable,
          trustScore: trustScore,
          trustLabel: trustLabel,
          confidenceVal: confidenceVal,
          confidenceTier: confidenceTier,
        ),
        const SizedBox(height: 16),

        // 2. AI Viewer Note / Advisory
        if (viewerNote.isNotEmpty) ...[
          _buildViewerNoteCard(viewerNote),
          const SizedBox(height: 16),
        ],

        // 3. Scoring Factors / Multi-Dimensional Breakdown
        if (factors.isNotEmpty) ...[
          _buildFactorsCard(factors),
          const SizedBox(height: 16),
        ],

        // 4. Chapter Trust Breakdown & Topic Extraction
        if (chapters.isNotEmpty) ...[
          _buildChaptersSection(chapters),
          const SizedBox(height: 16),
        ],

        // 5. Fact-Checked Claims
        if (claims.isNotEmpty) ...[
          _buildClaimsSection(claims),
          const SizedBox(height: 16),
        ],

        // 6. Citations & Verified Sources
        if (sources.isNotEmpty) ...[
          _buildSourcesSection(sources),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildHeroCard({
    required String analysisState,
    required bool scoreAvailable,
    required double? trustScore,
    required String trustLabel,
    required double confidenceVal,
    required String confidenceTier,
  }) {
    Color stateColor;
    if (analysisState.toUpperCase() == 'VERIFIED') {
      stateColor = AppColors.success;
    } else if (analysisState.toUpperCase().contains('FLAG') ||
        analysisState.toUpperCase().contains('DISPUTE')) {
      stateColor = AppColors.error;
    } else {
      stateColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stateColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: stateColor.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: stateColor.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: stateColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            analysisState.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: stateColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        if (confidenceTier.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${confidenceTier.toUpperCase()} CONFIDENCE',
                            style: GoogleFonts.roboto(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trustLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Trust Score gauge badge (if score is available)
              if (scoreAvailable && trustScore != null && trustScore > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(trustScore > 5 ? trustScore : trustScore * 20).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _getScoreColor(trustScore > 5 ? trustScore : trustScore * 20).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        trustScore <= 5.0
                            ? '${trustScore.toStringAsFixed(1)} / 5.0'
                            : '${trustScore.toInt()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _getScoreColor(trustScore > 5 ? trustScore : trustScore * 20),
                        ),
                      ),
                      Text(
                        'TRUST INDEX',
                        style: GoogleFonts.roboto(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Confidence Progress Bar
          const SizedBox(height: 14),
          _buildConfidenceBar(confidenceVal),
        ],
      ),
    );
  }

  Widget _buildViewerNoteCard(String note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'AI VIEWER ADVISORY & SUMMARY',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: GoogleFonts.roboto(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard(Map<dynamic, dynamic> factors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREDIBILITY FACTORS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          ...factors.entries.map((e) {
            final key = e.key.toString();
            final val = e.value;
            final label = _formatFactorKey(key);
            final numVal = (val is num) ? val.toDouble() : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    numVal <= 5.0 && numVal > 0
                        ? '${numVal.toStringAsFixed(1)} / 5.0'
                        : (numVal > 5 ? '${numVal.toInt()}%' : val.toString()),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChaptersSection(List<dynamic> chapters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bookmarks_outlined,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'CHAPTER CREDIBILITY & KEY TOPICS (${chapters.length})',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chapters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = chapters[index] as Map?;
            if (item == null) return const SizedBox.shrink();

            final title = (item['title'] ?? 'Chapter ${index + 1}').toString();
            final startMs = (item['start'] ?? 0) as num;
            final endMs = (item['end'] ?? 0) as num;
            final trustIndex = item['trustIndex'] as num?;
            final topics = (item['primaryTopics'] ?? item['topics']) as List? ?? [];

            final startDuration = Duration(
              milliseconds: (startMs < 10000 && startMs > 0)
                  ? (startMs * 1000).toInt()
                  : startMs.toInt(),
            );
            final endDuration = Duration(
              milliseconds: (endMs < 10000 && endMs > 0)
                  ? (endMs * 1000).toInt()
                  : endMs.toInt(),
            );

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${FormatUtils.formatDuration(startDuration)} - ${FormatUtils.formatDuration(endDuration)}',
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (trustIndex != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(trustIndex > 5 ? trustIndex.toDouble() : trustIndex * 20).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                trustIndex <= 5.0
                                    ? '${trustIndex.toStringAsFixed(1)}'
                                    : '${trustIndex.toInt()}%',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: topics.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            t.toString(),
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildClaimsSection(List<dynamic> claims) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'FACT-CHECKED CLAIMS (${claims.length})',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: claims.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final claim = claims[index];
            if (claim is! Map) return const SizedBox.shrink();
            return _buildClaimCard(claim, index);
          },
        ),
      ],
    );
  }

  Widget _buildSourcesSection(List<dynamic> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'VERIFIED SOURCES & CITATIONS (${sources.length})',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final source = sources[index];
            if (source is! Map) return const SizedBox.shrink();
            return _buildSourceCard(source);
          },
        ),
      ],
    );
  }

  Widget _buildRawJsonView(String jsonString) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SelectableText(
            jsonString,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final color = clamped >= 0.75
        ? AppColors.success
        : (clamped >= 0.45 ? AppColors.warning : AppColors.error);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SYSTEM CONFIDENCE',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${(clamped * 100).toInt()}%',
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.5), color],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClaimCard(Map<dynamic, dynamic> claim, int index) {
    final status = (claim['status'] ?? '').toString().toLowerCase();
    final isVerified =
        status == 'correct' ||
        status == 'mostly_correct' ||
        status == 'verified' ||
        claim['isVerified'] == true;
    final isDisputed = status.contains('dispute') || status.contains('caution');
    final color = isVerified
        ? AppColors.success
        : (isDisputed ? AppColors.warning : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (claim['text'] ?? claim['claim'] ?? '').toString(),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (claim['reasoning'] != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                claim['reasoning'].toString(),
                style: GoogleFonts.roboto(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
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
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author ?? title ?? 'Source Reference',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (citationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      citationText,
                      style: GoogleFonts.roboto(
                        fontSize: 11,
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
                      style: GoogleFonts.roboto(
                        fontSize: 11,
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
                          style: GoogleFonts.roboto(
                            fontSize: 9,
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
                            style: GoogleFonts.roboto(
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
              Icons.open_in_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFactCheckFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Fact-Checked Yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Artificial intelligence and fact-checking engines are deployed for popular or requested streams to verify authenticity.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Get.snackbar(
                  'Request Received',
                  'AI Verification has been queued for this video stream.',
                  backgroundColor: AppColors.brand,
                  colorText: AppColors.textPrimary,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(16),
                );
              },
              icon: const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'Request AI Verification',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFactorKey(String key) {
    return key
        .replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .capitalizeFirst ??
        key;
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return AppColors.warning;
    return AppColors.error;
  }

  String _getRatingLabel(double score) {
    final s = score <= 5.0 ? score * 20 : score;
    if (s >= 90) return 'EXCEPTIONAL INTEGRITY';
    if (s >= 75) return 'HIGH INTEGRITY';
    if (s >= 60) return 'TRUSTWORTHY';
    if (s >= 45) return 'CAUTION ADVISED';
    return 'LOW INTEGRITY';
  }
}
