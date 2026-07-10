import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

class VideoAnalysisBottomSheet extends StatefulWidget {
  final Video video;
  final int initialTabIndex;

  const VideoAnalysisBottomSheet({
    super.key,
    required this.video,
    this.initialTabIndex = 0,
  });

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

    // Locate controllers
    final tag = widget.video.id;
    if (Get.isRegistered<VideoController>(tag: tag) &&
        Get.isRegistered<TowerPlayerController>(tag: tag)) {
      videoCtrl = Get.find<VideoController>(tag: tag);
      playerCtrl = Get.find<TowerPlayerController>(tag: tag);
      controllersFound = true;

      // Automatically load fact-checking data in background if needed
      if (videoCtrl.factCheckData.isEmpty && widget.video.factCheckUrl.isNotEmpty) {
        videoCtrl.loadFactCheckData();
      }

      // Automatically load transcript if empty
      _checkAndLoadTranscript();
    }
  }

  void _checkAndLoadTranscript() {
    if (playerCtrl.subtitleSegments.isEmpty) {
      if (playerCtrl.subtitleTracks.isNotEmpty) {
        playerCtrl.fetchAndParseSubtitles(playerCtrl.subtitleTracks.first.url);
      } else if (widget.video.transcriptionUrl.isNotEmpty) {
        playerCtrl.fetchAndParseSubtitles(widget.video.transcriptionUrl);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controllersFound) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(
          child: Text(
            'Error: Video controllers not found.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 10,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildTabBar(),
                const Divider(height: 1, color: Colors.white10),
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
      ),
    );
  }

  // --- Header ---
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
                  style: GoogleFonts.roboto(
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
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Get.back(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab Bar ---
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.brand,
      unselectedLabelColor: Colors.white38,
      indicatorColor: AppColors.brand,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: GoogleFonts.roboto(
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

  // ==========================================================================
  // TAB 1: FACT CHECK
  // ==========================================================================
  Widget _buildFactCheckTab() {
    if (widget.video.factCheckUrl.isEmpty) {
      return _buildNoFactCheckFallback();
    }

    return Obx(() {
      if (videoCtrl.isLoadingFactCheck.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        );
      }

      final data = videoCtrl.factCheckData;
      if (data.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not load fact check data.',
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => videoCtrl.loadFactCheckData(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }

      final double trustScore = (data['trustScore'] ?? data['compositeRating'] ?? data['videoRating'] ?? 0.0).toDouble();
      final double truthScore = (data['truthScore'] ?? trustScore).toDouble();
      final double honestyScore = (data['honestyScore'] ?? 0.0).toDouble();
      final double rationalityScore = (data['rationalityScore'] ?? 0.0).toDouble();
      
       final stats = data['factCheckStats'] as Map? ?? {};
      final claims = data['claims'] as List? ?? [];
      final factors = data['factors'] as Map? ?? {};
      
      final uiReport = data['uiReport'] as Map? ?? {};
      final narrative = uiReport['narrative'] as String? ?? data['viewerNote'] as String? ?? '';
      final sources = uiReport['sources'] as List? ?? data['richSources'] as List? ?? [];
      final confidence = (data['confidence'] ?? 0.5).toDouble();
      
      final themeColor = _getScoreColor(trustScore);

      return ListView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        children: [
          // Main trust score ring
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withValues(alpha: 0.03),
                border: Border.all(color: themeColor.withValues(alpha: 0.1), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${trustScore.toInt()}',
                    style: GoogleFonts.roboto(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _getRatingLabel(trustScore),
                    style: GoogleFonts.roboto(
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
              _buildStatCard('Total Claims', '${stats['totalClaims'] ?? claims.length}', Icons.article_outlined, Colors.blueAccent),
              const SizedBox(width: 12),
              _buildStatCard('Verified', '${stats['correct'] ?? stats['verifiedClaims'] ?? claims.where((c) => c['status'] == 'correct' || c['isVerified'] == true).length}', Icons.check_circle_outlined, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 24),

          // Narrative Analysis
          if (narrative.isNotEmpty) ...[
            Text('SUMMARY ANALYSIS', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text(
                narrative,
                style: GoogleFonts.roboto(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Trust drivers (Factors)
          if (factors.isNotEmpty) ...[
            Text('TRUST DRIVERS', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: factors.entries.map((e) {
                final score = (e.value ?? 0).toDouble();
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
                      Text(e.key.toString().toUpperCase(), style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(width: 6),
                      Text('${score.toInt()}', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Claims Verification list
          Text('CLAIM VERIFICATIONS', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (claims.isEmpty)
            _buildEmptyBox('No specific claims extracted for this analysis.')
          else
            ...claims.asMap().entries.map((entry) => _buildClaimCard(entry.value, entry.key)),
          const SizedBox(height: 24),

          // Verified Sources section
          if (sources.isNotEmpty) ...[
            Text('VERIFIED SOURCES', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1)),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sources.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _buildSourceCard(sources[index]),
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Icon(
                Icons.verified_user_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 72,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Fact-Checked Yet',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Not all videos on our network are fact-checked. Our artificial intelligence and fact-checking engines are deployed for popular or requested streams to verify authenticity.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Get.snackbar(
                  'Request Received',
                  'AI Verification has been queued for this video stream.',
                  backgroundColor: AppColors.brand.withValues(alpha: 0.9),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(16),
                );
              },
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Request AI Verification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
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
          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    final double value = confidence > 1.0 ? confidence / 100 : confidence;
    final color = value >= 0.8 ? const Color(0xFF10B981) : (value >= 0.5 ? Colors.orangeAccent : Colors.redAccent);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ANALYSIS CONFIDENCE', style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38)),
            Text('${(value * 100).toInt()}%', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(3)),
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
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(label, style: GoogleFonts.roboto(fontSize: 9, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map claim, int index) {
    final status = (claim['status'] ?? '').toString().toLowerCase();
    final bool isVerified = status == 'correct' || status == 'mostly_correct' || claim['isVerified'] == true;
    final color = isVerified ? const Color(0xFF10B981) : Colors.redAccent;

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
                  claim['claim'] ?? claim['text'] ?? '',
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                ),
                if (claim['explanation'] != null || claim['reasoning'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    claim['explanation'] ?? claim['reasoning'],
                    style: GoogleFonts.roboto(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
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
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source['title'] ?? 'Source',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const Spacer(),
          Text(
            source['domain'] ?? 'Verified Source',
            style: GoogleFonts.roboto(fontSize: 9, color: Colors.white38),
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
        color: Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        text,
        style: GoogleFonts.roboto(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF10B981);
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return Colors.orangeAccent;
    return Colors.redAccent;
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
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.brand),
              SizedBox(height: 16),
              Text(
                'Loading or parsing transcript...',
                style: TextStyle(color: Colors.white54, fontSize: 13),
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
                      style: GoogleFonts.robotoMono(
                        color: isActive ? AppColors.brand : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      seg.text,
                      style: GoogleFonts.roboto(
                        color: isActive ? Colors.white : Colors.white70,
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
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
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
          const Divider(height: 32, color: Colors.white10),

          Text(
            'AVAILABLE SUBTITLE LANGUAGES',
            style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No subtitle tracks available', style: GoogleFonts.roboto(color: Colors.white54, fontSize: 13)),
              ),
            )
          else
            ...tracks.map((t) {
              final isSelected = enabled && activeLang == t.label;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.brand.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => playerCtrl.setSubtitles(enabled: true, track: t),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? AppColors.brand : Colors.white38,
                    size: 18,
                  ),
                  title: Text(
                    t.label,
                    style: GoogleFonts.roboto(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.langCode.toUpperCase(),
                      style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold),
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
            style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          if (resolutions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No adaptive resolutions available', style: GoogleFonts.roboto(color: Colors.white54, fontSize: 13)),
              ),
            )
          else
            ...resolutions.map((r) {
              final isSelected = currentRes?.url == r.url;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.brand.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => videoCtrl.setResolution(r),
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.crop_free_rounded,
                    color: isSelected ? AppColors.brand : Colors.white38,
                    size: 18,
                  ),
                  title: Text(
                    r.label,
                    style: GoogleFonts.roboto(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${r.width} x ${r.height} @ ${(r.bitrate / 1000).toInt()} Kbps',
                    style: GoogleFonts.roboto(fontSize: 11, color: Colors.white38),
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
                            style: GoogleFonts.roboto(fontSize: 9, color: AppColors.brand, fontWeight: FontWeight.w900),
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
