import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _VideoAnalysisBottomSheetState extends State<VideoAnalysisBottomSheet> {
  late final VideoController videoCtrl;
  late final TowerPlayerController playerCtrl;
  bool controllersFound = false;

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

    if (Get.isRegistered<TowerPlayerController>(tag: tag)) {
      playerCtrl = Get.find<TowerPlayerController>(tag: tag);
    } else {
      playerCtrl = Get.find<TowerPlayerController>();
    }
    controllersFound = true;
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
              const Divider(height: 1, color: AppColors.bgDivider),
              Expanded(
                child: _buildFactCheckTab(),
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

      final jsonString = const JsonEncoder.withIndent('  ').convert(reportData);

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credibility System Output (JSON)',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonString));
                    Get.snackbar(
                      'Copied',
                      'Fact check JSON copied to clipboard',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.bgSurface,
                      colorText: AppColors.textPrimary,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Copy JSON',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.brand),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
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
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildClaimCard(Map<dynamic, dynamic> claim, int index) {
    final status = (claim['status'] ?? '').toString().toLowerCase();
    final isVerified = status == 'correct' || status == 'mostly_correct' || claim['isVerified'] == true;
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
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (claim['text'] ?? claim['claim'] ?? '').toString(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (claim['reasoning'] != null) ...[
            const SizedBox(height: 8),
            Text(
              claim['reasoning'].toString(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
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
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author ?? title ?? 'Source',
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (citationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      citationText,
                      style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary),
                    ),
                  ],
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"$snippet"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 9, fontStyle: FontStyle.italic, color: AppColors.textTertiary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (trustLevel != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: trustColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trustLevel.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(fontSize: 8, color: trustColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (domain != null)
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textTertiary),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
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
}
