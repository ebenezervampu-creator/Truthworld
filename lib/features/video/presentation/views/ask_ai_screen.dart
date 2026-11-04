import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/ai_credibility_chat_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/ai_chat/ai_credibility_chat_sheet.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated full-page screen displaying conversational Truth Intelligence & Credibility AI ("Ask AI").
///
/// Provides a dedicated full-page conversational interface with its own AppBar,
/// back navigation, conversation management, and keyboard-adaptive layout.
class AskAiScreen extends StatelessWidget {
  const AskAiScreen({
    this.video,
    this.controller,
    this.scope = 'video',
    this.claimIndex,
    this.claimText,
    this.verdict,
    this.allSources,
    this.allClaims,
    this.summary,
    this.trustScore,
    this.claimExplanation,
    super.key,
  });

  final Video? video;
  final VideoController? controller;
  final String scope;
  final int? claimIndex;
  final String? claimText;
  final String? verdict;
  final List<dynamic>? allSources;
  final List<dynamic>? allClaims;
  final String? summary;
  final double? trustScore;
  final String? claimExplanation;

  /// Seamlessly navigates to the Ask AI dedicated screen.
  static Future<T?> open<T>(
    BuildContext context, {
    required Video video,
    VideoController? controller,
    String scope = 'video',
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<dynamic>? allSources,
    List<dynamic>? allClaims,
    String? summary,
    double? trustScore,
    String? claimExplanation,
  }) {
    // 1. Pre-initialize AiCredibilityChatController
    final tag = '${video.id}_${scope}_${claimIndex ?? 'all'}';
    final ctrl = Get.put(AiCredibilityChatController(), tag: tag);
    ctrl.initScope(
      targetVideoId: video.id,
      targetScope: scope,
      video: video,
      targetClaimIndex: claimIndex,
      targetClaimText: claimText,
      targetVerdict: verdict,
      title: video.title,
      allSources: allSources,
      allClaims: allClaims,
      summary: summary,
      trustScore: trustScore,
      claimExplanation: claimExplanation,
    );

    return Get.to<T>(
          () => AskAiScreen(
            video: video,
            controller: controller,
            scope: scope,
            claimIndex: claimIndex,
            claimText: claimText,
            verdict: verdict,
            allSources: allSources,
            allClaims: allClaims,
            summary: summary,
            trustScore: trustScore,
            claimExplanation: claimExplanation,
          ),
          routeName: AppRoutes.askAi,
          arguments: {
            'video': video,
            'controller': controller,
            'scope': scope,
            'claimIndex': claimIndex,
            'claimText': claimText,
            'verdict': verdict,
            'allSources': allSources,
            'allClaims': allClaims,
            'summary': summary,
            'trustScore': trustScore,
            'claimExplanation': claimExplanation,
            'videoId': video.id,
          },
          transition: Transition.rightToLeftWithFade,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 320),
        ) ??
        Future.value();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve parameters from direct props or route arguments
    var resolvedVideo = video;
    var resolvedController = controller;
    var resolvedScope = scope;
    var resolvedClaimIndex = claimIndex;
    var resolvedClaimText = claimText;
    var resolvedVerdict = verdict;
    var resolvedAllSources = allSources;
    var resolvedAllClaims = allClaims;
    var resolvedSummary = summary;
    var resolvedTrustScore = trustScore;
    var resolvedClaimExplanation = claimExplanation;

    final args = Get.arguments;
    if (resolvedVideo == null && args is Video) {
      resolvedVideo = args;
    } else if (args is Map) {
      if (resolvedVideo == null && args['video'] is Video) {
        resolvedVideo = args['video'] as Video;
      }
      if (resolvedController == null && args['controller'] is VideoController) {
        resolvedController = args['controller'] as VideoController;
      }
      if (args['scope'] is String) {
        resolvedScope = args['scope'] as String;
      }
      if (args['claimIndex'] is int) {
        resolvedClaimIndex = args['claimIndex'] as int;
      }
      if (args['claimText'] is String) {
        resolvedClaimText = args['claimText'] as String;
      }
      if (args['verdict'] is String) {
        resolvedVerdict = args['verdict'] as String;
      }
      if (args['allSources'] is List) {
        resolvedAllSources = args['allSources'] as List<dynamic>;
      }
      if (args['allClaims'] is List) {
        resolvedAllClaims = args['allClaims'] as List<dynamic>;
      }
      if (args['summary'] is String) {
        resolvedSummary = args['summary'] as String;
      }
      if (args['trustScore'] is num) {
        resolvedTrustScore = (args['trustScore'] as num).toDouble();
      }
      if (args['claimExplanation'] is String) {
        resolvedClaimExplanation = args['claimExplanation'] as String;
      }
    }

    final routeVideoId = resolvedVideo?.id ??
        (args is Map ? args['videoId']?.toString() : null) ??
        Get.parameters['videoId'] ??
        Get.parameters['v'] ??
        Get.parameters['id'];

    if (resolvedVideo == null && routeVideoId != null && routeVideoId.isNotEmpty) {
      if (Get.isRegistered<VideoController>(tag: routeVideoId)) {
        final existingCtrl = Get.find<VideoController>(tag: routeVideoId);
        resolvedVideo = existingCtrl.video;
        resolvedController ??= existingCtrl;
      }
    }

    // 2. If video reference is still null, fetch from Firestore
    if (resolvedVideo == null) {
      if (routeVideoId == null || routeVideoId.isEmpty) {
        return _buildErrorScaffold('Video reference not found.');
      }
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('videos').doc(routeVideoId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold();
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorScaffold('Unable to load video details.');
          }
          final loadedVideo = Video.fromDocumentSnapshot(snapshot.data!);
          return _buildChatScaffold(
            context,
            video: loadedVideo,
            controller: resolvedController,
            scope: resolvedScope,
            claimIndex: resolvedClaimIndex,
            claimText: resolvedClaimText,
            verdict: resolvedVerdict,
            allSources: resolvedAllSources,
            allClaims: resolvedAllClaims,
            summary: resolvedSummary,
            trustScore: resolvedTrustScore,
            claimExplanation: resolvedClaimExplanation,
          );
        },
      );
    }

    return _buildChatScaffold(
      context,
      video: resolvedVideo,
      controller: resolvedController,
      scope: resolvedScope,
      claimIndex: resolvedClaimIndex,
      claimText: resolvedClaimText,
      verdict: resolvedVerdict,
      allSources: resolvedAllSources,
      allClaims: resolvedAllClaims,
      summary: resolvedSummary,
      trustScore: resolvedTrustScore,
      claimExplanation: resolvedClaimExplanation,
    );
  }

  Widget _buildChatScaffold(
    BuildContext context, {
    required Video video,
    required String scope,
    VideoController? controller,
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<dynamic>? allSources,
    List<dynamic>? allClaims,
    String? summary,
    double? trustScore,
    String? claimExplanation,
  }) {
    final tag = '${video.id}_${scope}_${claimIndex ?? 'all'}';
    final ctrl = Get.isRegistered<AiCredibilityChatController>(tag: tag)
        ? Get.find<AiCredibilityChatController>(tag: tag)
        : Get.put(AiCredibilityChatController(), tag: tag);

    if (ctrl.videoId.value != video.id || ctrl.scope.value != scope || ctrl.messages.isEmpty) {
      ctrl.initScope(
        targetVideoId: video.id,
        targetScope: scope,
        video: video,
        targetClaimIndex: claimIndex,
        targetClaimText: claimText,
        targetVerdict: verdict,
        title: video.title,
        allSources: allSources,
        allClaims: allClaims,
        summary: summary,
        trustScore: trustScore,
        claimExplanation: claimExplanation,
      );
    }

    final isClaim = scope == 'claim';
    final titleText = isClaim
        ? 'Truth AI • Claim #${(claimIndex ?? 0) + 1}'
        : 'Truth Intelligence AI';
    final subtitleText = isClaim && claimText != null && claimText.isNotEmpty
        ? (claimText.length > 60 ? '${claimText.substring(0, 58)}…' : claimText)
        : (video.title.isNotEmpty ? video.title : 'Empirical Fact Verification');

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black canvas
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 19,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.back();
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: TruthLottieAnimation.verifiedShield(size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isClaim && verdict != null && verdict.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            verdict,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: 'Clear conversation',
            onPressed: ctrl.clearChat,
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.bgDivider),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: AiCredibilityChatSheet(
              video: video,
              scope: scope,
              claimIndex: claimIndex,
              claimText: claimText,
              verdict: verdict,
              allSources: allSources,
              allClaims: allClaims,
              summary: summary,
              trustScore: trustScore,
              claimExplanation: claimExplanation,
              isEmbedded: true,
              hideHeader: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Truth Intelligence • Ask AI',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Truth Intelligence • Ask AI',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef AiCredibilityChatScreen = AskAiScreen;
