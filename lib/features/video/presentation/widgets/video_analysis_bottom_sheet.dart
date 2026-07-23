import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoAnalysisBottomSheet extends StatefulWidget {

  const VideoAnalysisBottomSheet({
    required this.video, super.key,
    this.initialTabIndex = 0,
  });
  final Video video;
  final int initialTabIndex;

  @override
  State<VideoAnalysisBottomSheet> createState() => _VideoAnalysisBottomSheetState();
}

class _VideoAnalysisBottomSheetState extends State<VideoAnalysisBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final VideoController videoCtrl;
  late final TowerPlayerController playerCtrl;
  bool controllersFound = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    final tag = widget.video.id;
    if (Get.isRegistered<VideoController>(tag: tag)) {
      videoCtrl = Get.find<VideoController>(tag: tag);
    } else if (Get.isRegistered<VideoController>()) {
      videoCtrl = Get.find<VideoController>();
    } else {
      videoCtrl = Get.put(VideoController());
    }

    if (Get.isRegistered<TowerPlayerController>(tag: tag)) {
      playerCtrl = Get.find<TowerPlayerController>(tag: tag);
    } else {
      playerCtrl = Get.find<TowerPlayerController>();
    }
    controllersFound = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              _buildTabBar(),
              const Divider(height: 1, color: AppColors.bgDivider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFactCheckTab(),
                    _buildTranscriptTab(),
                    _buildSubtitlesTab(),
                    _buildResolutionsTab(),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIDEO ANALYSIS & MEDIA',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brand,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
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

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.brand,
      unselectedLabelColor: AppColors.textTertiary,
      indicatorColor: AppColors.brand,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: AppTextStyles.labelMedium.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      tabs: const [
        Tab(text: 'FACT CHECK'),
        Tab(text: 'TRANSCRIPT'),
        Tab(text: 'SUBTITLES'),
        Tab(text: 'RESOLUTIONS'),
      ],
    );
  }

  Widget _buildFactCheckTab() {
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

      final trustScore = ((reportData['trustScore'] ?? reportData['compositeRating'] ?? 0.0) as num).toDouble();
      final truthScore = ((reportData['truthScore'] ?? trustScore) as num).toDouble();
      final honestyScore = ((reportData['honestyScore'] ?? 0.0) as num).toDouble();
      final rationalityScore = ((reportData['rationalityScore'] ?? 0.0) as num).toDouble();
      final confidence = ((reportData['confidence'] ?? 0.5) as num).toDouble();

      final stats = reportData['factCheckStats'] as Map? ?? {};
      final claims = reportData['claims'] as List? ?? [];
      final factors = reportData['factors'] as Map? ?? {};
      final uiReport = reportData['uiReport'] as Map? ?? {};
      final narrative = uiReport['narrative'] as String? ?? reportData['viewerNote'] as String? ?? '';
      final sources = uiReport['sources'] as List? ?? reportData['richSources'] as List? ?? [];

      final themeColor = _getScoreColor(trustScore);

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withValues(alpha: 0.03),
                border: Border.all(color: themeColor.withValues(alpha: 0.1), width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${trustScore.toInt()}',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _getRatingLabel(trustScore),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: themeColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rating components
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('TRUTH', truthScore),
              _buildMetricItem('HONESTY', honestyScore),
              _buildMetricItem('RATIONALITY', rationalityScore),
            ],
          ),
          const SizedBox(height: 24),

          // Confidence meter
          _buildConfidenceBar(confidence),
          const SizedBox(height: 24),

          // Stats: Total and Verified Claims
          Row(
            children: [
              _buildStatCard('Total Claims', '${stats['totalClaims'] ?? claims.length}', Icons.article_outlined, AppColors.info),
              const SizedBox(width: 12),
              _buildStatCard('Verified', '${stats['correct'] ?? stats['verifiedClaims'] ?? claims.where((c) => c['status'] == 'correct' || c['isVerified'] == true).length}', Icons.check_circle_outlined, AppColors.success),
            ],
          ),
          const SizedBox(height: 24),

          if (narrative.isNotEmpty) ...[
            Text('SUMMARY ANALYSIS', style: AppTextStyles.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Text(
                narrative,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (factors.isNotEmpty) ...[
            Text('TRUST DRIVERS', style: AppTextStyles.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: factors.entries.map((e) {
                final score = (e.value ?? 0).toDouble();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.key.toString().toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(width: 6),
                      Text('${score.toInt()}', style: AppTextStyles.bodyMedium.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          Text('CLAIM VERIFICATIONS', style: AppTextStyles.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (claims.isEmpty)
            _buildEmptyBox('No specific claims extracted for this analysis.')
          else
            ...claims.asMap().entries.map((entry) => _buildClaimCard(entry.value as Map, entry.key)),
          const SizedBox(height: 24),

          // Verified Sources section
          if (sources.isNotEmpty) ...[
            Text('VERIFIED SOURCES', style: AppTextStyles.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sources.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _buildSourceCard(sources[index] as Map),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    });
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
                color: AppColors.textTertiary,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Fact-Checked Yet',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Not all videos on our network are fact-checked. Our artificial intelligence and fact-checking engines are deployed for popular or requested streams to verify authenticity.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
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
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text('Request AI Verification', style: AppTextStyles.buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

  Widget _buildMetricItem(String label, double score) {
    final color = _getScoreColor(score);
    return Column(
      children: [
        Text(
          '${score.toInt()}%',
          style: AppTextStyles.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    final value = confidence > 1.0 ? confidence / 100 : confidence;
    final color = value >= 0.8 ? AppColors.success : (value >= 0.5 ? AppColors.warning : AppColors.error);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ANALYSIS CONFIDENCE', style: AppTextStyles.labelSmall.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
            Text('${(value * 100).toInt()}%', style: AppTextStyles.bodyMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(color: AppColors.bgDivider, borderRadius: BorderRadius.circular(3)),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.5), color]),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map claim, int index) {
    final status = (claim['status'] ?? '').toString().toLowerCase();
    final isVerified = status == 'correct' || status == 'mostly_correct' || claim['isVerified'] == true;
    final color = isVerified ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isVerified ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (claim['claim'] ?? claim['text'] ?? '').toString(),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                ),
                if (claim['explanation'] != null || claim['reasoning'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    (claim['explanation'] ?? claim['reasoning'])?.toString() ?? '',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(Map source) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (source['title'] ?? 'Source').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const Spacer(),
          Text(
            (source['domain'] ?? 'Verified Source').toString(),
            style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textTertiary),
          ),
        ],
      ),
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
        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return AppColors.warning;
    return AppColors.error;
  }

  String _getRatingLabel(double score) {
    if (score >= 90) return 'EXCEPTIONAL';
    if (score >= 75) return 'HIGH INTEGRITY';
    if (score >= 60) return 'TRUSTWORTHY';
    if (score >= 45) return 'CAUTION ADVISED';
    return 'LOW INTEGRITY';
  }

  // ==========================================================================
  // TAB 2: TRANSCRIPT
  // ==========================================================================
  Widget _buildTranscriptTab() {
    return Obx(() {
      final segments = playerCtrl.subtitleSegments;
      if (segments.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.brand),
              const SizedBox(height: 16),
              Text(
                'Loading or parsing transcript...',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );
      }

      final pos = playerCtrl.vv.position;

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final seg = segments[index];
          final isActive = pos >= seg.start && pos <= seg.end;

          return InkWell(
            onTap: () {
              playerCtrl.seekTo(seg.start);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isActive ? AppColors.brand.withValues(alpha: 0.15) : Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      _formatDuration(seg.start),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isActive ? AppColors.brand : AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      seg.text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$mins:$secs';
    return '$mins:$secs';
  }

  // ==========================================================================
  // TAB 3: SUBTITLES
  // ==========================================================================
  Widget _buildSubtitlesTab() {
    return Obx(() {
      final tracks = playerCtrl.subtitleTracks;
      final enabled = playerCtrl.subtitlesEnabled.value;
      final activeLang = playerCtrl.activeSubLang.value;

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Enable switch
          Row(
            children: [
              const Icon(Icons.closed_caption_rounded, color: AppColors.brand, size: 24),
              const SizedBox(width: 16),
              Text(
                'Show Subtitles on Player',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: enabled,
                onChanged: (v) => playerCtrl.setSubtitles(enabled: v),
                activeThumbColor: AppColors.brand,
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.bgDivider),

          Text(
            'AVAILABLE SUBTITLE LANGUAGES',
            style: AppTextStyles.labelSmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No subtitle tracks available', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...tracks.map((t) {
              final isSelected = enabled && activeLang == t.label;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.brand.withValues(alpha: 0.3) : AppColors.bgDivider,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => playerCtrl.setSubtitles(enabled: true, track: t),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? AppColors.brand : AppColors.textTertiary,
                    size: 18,
                  ),
                  title: Text(
                    t.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.langCode.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            }),
        ],
      );
    });
  }

  // ==========================================================================
  // TAB 4: RESOLUTIONS
  // ==========================================================================
  Widget _buildResolutionsTab() {
    return Obx(() {
      final resolutions = videoCtrl.availableResolutions;
      final currentRes = videoCtrl.currentResolution.value;

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'STREAM QUALITY & RESOLUTION',
            style: AppTextStyles.labelSmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          if (resolutions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No adaptive resolutions available', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...resolutions.map((r) {
              final isSelected = currentRes?.url == r.url;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.brand.withValues(alpha: 0.3) : AppColors.bgDivider,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => videoCtrl.setResolution(r),
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.crop_free_rounded,
                    color: isSelected ? AppColors.brand : AppColors.textTertiary,
                    size: 18,
                  ),
                  title: Text(
                    r.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${r.width} x ${r.height} @ ${(r.bitrate / 1000).toInt()} Kbps',
                    style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: AppTextStyles.labelSmall.copyWith(fontSize: 9, color: AppColors.brand, fontWeight: FontWeight.w900),
                          ),
                        )
                      : null,
                ),
              );
            }),
        ],
      );
    });
  }
}
