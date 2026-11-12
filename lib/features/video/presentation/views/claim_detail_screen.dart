import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/isolate_compute_utils.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_detail_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/ai_chat/ai_credibility_chat_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/claim_ledger_timeline.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/claim_media_stage.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/claim_sources_bottom_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/comments/claim_community_notes_section.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_share_card.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check/fact_check_epistemic_banner.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 ClaimDetailScreen
///
/// Dedicated full-page screen displaying a specific claim verification
/// with exact layout fidelity to the uploaded design specification:
/// - Claim Number badge, Verdict Pill, and Timestamp Pill
/// - Prominent Claim Statement
/// - Truth Intelligence Breakdown Card
/// - Sources Card with top 3 visual source avatars & "View all X sources" action
/// - Interactive Sources Bottom Sheet
/// - Fixed Bottom Action Bar with "Search web" and "Provide source"
class ClaimDetailScreen extends StatelessWidget {
  final Map<dynamic, dynamic>? claim;
  final int claimIndex;
  final Video? video;
  final VideoController? controller;
  final List<dynamic>? allSources;
  final List<dynamic>? allClaims;

  const ClaimDetailScreen({
    this.claim,
    this.claimIndex = 0,
    this.video,
    this.controller,
    this.allSources,
    this.allClaims,
    super.key,
  });

  /// Opens the ClaimDetailScreen as a dedicated page route.
  static Future<T?> open<T>(
    BuildContext context, {
    required Map<dynamic, dynamic> claim,
    required int claimIndex,
    required Video video,
    VideoController? controller,
    List<dynamic>? allSources,
    List<dynamic>? allClaims,
  }) {
    return Get.to<T>(
          () => ClaimDetailScreen(
            claim: claim,
            claimIndex: claimIndex,
            video: video,
            controller: controller,
            allSources: allSources,
            allClaims: allClaims,
          ),
          routeName: '${AppRoutes.claimDetail}?videoId=${video.id}&claimIndex=$claimIndex',
          arguments: {
            'claim': claim,
            'claimIndex': claimIndex,
            'video': video,
            'controller': controller,
            'allSources': allSources,
            'allClaims': allClaims,
            'videoId': video.id,
          },
          transition: Transition.rightToLeftWithFade,
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 320),
        ) ??
        Future.value();
  }

  /// Asynchronously loads video document and credibility claims for direct deep links.
  static Future<Map<String, dynamic>> loadVideoAndCredibility(String videoId) async {
    final doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Video reference not found.');
    }
    final loadedVideo = Video.fromDocumentSnapshot(doc);
    final cred = await VideoMediaService().getCredibility(videoId);

    var claims = cred.claims.isNotEmpty
        ? cred.claims
        : (cred.uiReport?.keyClaims.map((c) => c.toMap()).toList() ?? <dynamic>[]);
    var sources = cred.sources.isNotEmpty
        ? cred.sources
        : (cred.uiReport?.sources.map((s) => s.toMap()).toList() ?? <dynamic>[]);

    if (claims.isEmpty && loadedVideo.factCheckUrl.isNotEmpty) {
      try {
        var fetchUrl = loadedVideo.factCheckUrl;
        if (fetchUrl.startsWith('gs://')) {
          fetchUrl = await FirebaseStorage.instance.refFromURL(fetchUrl).getDownloadURL();
        }
        final res = await AppHttpClient.get(Uri.parse(fetchUrl));
        if (res.statusCode == 200) {
          final decoded = await IsolateComputeUtils.parseJsonMapAsync(res.body);
          final parsedCred = VideoMediaCredibility.fromMap(decoded);
          claims = parsedCred.claims.isNotEmpty
              ? parsedCred.claims
              : (parsedCred.uiReport?.keyClaims.map((c) => c.toMap()).toList() ?? <dynamic>[]);
          sources = parsedCred.sources.isNotEmpty
              ? parsedCred.sources
              : (parsedCred.uiReport?.sources.map((s) => s.toMap()).toList() ?? <dynamic>[]);
        }
      } catch (_) {}
    }

    return {
      'video': loadedVideo,
      'claims': claims,
      'sources': sources,
    };
  }

  /// Asynchronously loads credibility claims for a known video instance if not already cached.
  static Future<Map<String, dynamic>> loadCredibilityForVideo(Video video) async {
    final cred = await VideoMediaService().getCredibility(video.id);
    var claims = cred.claims.isNotEmpty
        ? cred.claims
        : (cred.uiReport?.keyClaims.map((c) => c.toMap()).toList() ?? <dynamic>[]);
    var sources = cred.sources.isNotEmpty
        ? cred.sources
        : (cred.uiReport?.sources.map((s) => s.toMap()).toList() ?? <dynamic>[]);

    if (claims.isEmpty && video.factCheckUrl.isNotEmpty) {
      try {
        var fetchUrl = video.factCheckUrl;
        if (fetchUrl.startsWith('gs://')) {
          fetchUrl = await FirebaseStorage.instance.refFromURL(fetchUrl).getDownloadURL();
        }
        final res = await AppHttpClient.get(Uri.parse(fetchUrl));
        if (res.statusCode == 200) {
          final decoded = await IsolateComputeUtils.parseJsonMapAsync(res.body);
          final parsedCred = VideoMediaCredibility.fromMap(decoded);
          claims = parsedCred.claims.isNotEmpty
              ? parsedCred.claims
              : (parsedCred.uiReport?.keyClaims.map((c) => c.toMap()).toList() ?? <dynamic>[]);
          sources = parsedCred.sources.isNotEmpty
              ? parsedCred.sources
              : (parsedCred.uiReport?.sources.map((s) => s.toMap()).toList() ?? <dynamic>[]);
        }
      } catch (_) {}
    }

    return {
      'claims': claims,
      'sources': sources,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 1. Resolve arguments if loaded via named route or deep link
    var resolvedClaim = claim;
    var resolvedIndex = claimIndex;
    var resolvedVideo = video;
    var resolvedController = controller;
    var resolvedAllSources = allSources ?? <dynamic>[];
    var resolvedAllClaims = allClaims ?? <dynamic>[];

    final args = Get.arguments;
    if (args is Map) {
      if (resolvedClaim == null && args['claim'] is Map) {
        resolvedClaim = args['claim'] as Map<dynamic, dynamic>;
      }
      if (args['claimIndex'] is int) {
        resolvedIndex = args['claimIndex'] as int;
      }
      if (resolvedVideo == null && args['video'] is Video) {
        resolvedVideo = args['video'] as Video;
      }
      if (resolvedController == null && args['controller'] is VideoController) {
        resolvedController = args['controller'] as VideoController;
      }
      if (args['allSources'] is List) {
        resolvedAllSources = args['allSources'] as List<dynamic>;
      }
      if (args['allClaims'] is List) {
        resolvedAllClaims = args['allClaims'] as List<dynamic>;
      }
    }

    final routeVideoId = resolvedVideo?.id ??
        (args is Map ? args['videoId']?.toString() : null) ??
        Get.parameters['videoId'] ??
        Get.parameters['v'];

    final paramIndex = Get.parameters['claimIndex'] ??
        Get.parameters['index'] ??
        Get.parameters['claim'];
    if (paramIndex != null && int.tryParse(paramIndex) != null) {
      final parsedNum = int.parse(paramIndex);
      if (Get.parameters['claim'] != null && Get.parameters['claimIndex'] == null) {
        resolvedIndex = (parsedNum > 0) ? parsedNum - 1 : 0;
      } else {
        resolvedIndex = parsedNum;
      }
    }

    // 2. If video is missing (e.g. direct deep link), load video & credibility from Firestore
    if (resolvedVideo == null) {
      if (routeVideoId == null || routeVideoId.isEmpty) {
        return _buildErrorScaffold('Video reference not found.');
      }
      return FutureBuilder<Map<String, dynamic>>(
        future: loadVideoAndCredibility(routeVideoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorScaffold('Unable to load video details.');
          }
          final loadedVideo = snapshot.data!['video'] as Video;
          final loadedClaims = snapshot.data!['claims'] as List<dynamic>? ?? <dynamic>[];
          final loadedSources = snapshot.data!['sources'] as List<dynamic>? ?? <dynamic>[];
          return _buildClaimScaffold(
            context,
            video: loadedVideo,
            claim: resolvedClaim,
            claimIndex: resolvedIndex,
            controller: resolvedController,
            allSources: loadedSources.isNotEmpty ? loadedSources : resolvedAllSources,
            allClaims: loadedClaims.isNotEmpty ? loadedClaims : resolvedAllClaims,
          );
        },
      );
    }

    // 3. If video is known but claims/sources are missing (e.g. navigated with just video/id)
    if (resolvedClaim == null && resolvedAllClaims.isEmpty) {
      return FutureBuilder<Map<String, dynamic>>(
        future: loadCredibilityForVideo(resolvedVideo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScaffold();
          }
          final loadedClaims = snapshot.data?['claims'] as List<dynamic>? ?? <dynamic>[];
          final loadedSources = snapshot.data?['sources'] as List<dynamic>? ?? <dynamic>[];
          return _buildClaimScaffold(
            context,
            video: resolvedVideo!,
            claim: resolvedClaim,
            claimIndex: resolvedIndex,
            controller: resolvedController,
            allSources: loadedSources.isNotEmpty ? loadedSources : resolvedAllSources,
            allClaims: loadedClaims.isNotEmpty ? loadedClaims : resolvedAllClaims,
          );
        },
      );
    }

    return _buildClaimScaffold(
      context,
      video: resolvedVideo,
      claim: resolvedClaim,
      claimIndex: resolvedIndex,
      controller: resolvedController,
      allSources: resolvedAllSources,
      allClaims: resolvedAllClaims,
    );
  }

  Widget _buildClaimScaffold(
    BuildContext context, {
    required Video video,
    required int claimIndex,
    required List<dynamic> allSources,
    required List<dynamic> allClaims,
    Map<dynamic, dynamic>? claim,
    VideoController? controller,
  }) {
    // 3. Resolve effective Claim map
    var effectiveClaim = claim ?? <dynamic, dynamic>{};
    if (effectiveClaim.isEmpty && allClaims.isNotEmpty && claimIndex >= 0 && claimIndex < allClaims.length) {
      final item = allClaims[claimIndex];
      if (item is Map) effectiveClaim = item;
    }

    // If still empty, parse from video's fact-check report
    if (effectiveClaim.isEmpty && video.uiReport != null) {
      final parsed = FactCheckDataParser.parse(
        video.uiReport!.toMap(),
        fallbackReport: video.uiReport,
        isVideoFactChecked: video.isFactChecked,
      );
      if (parsed.claims.isNotEmpty && claimIndex >= 0 && claimIndex < parsed.claims.length) {
        effectiveClaim = parsed.claims[claimIndex];
      }
    }

    final verdict = ClaimVerdictHelper.resolveVerdict(effectiveClaim);
    final resolvedDetails = VideoAnalysisHelpers.resolveRealClaimDetails(
      effectiveClaim,
      claimIndex,
      allSources,
    );

    final cleanClaimText = resolvedDetails.cleanText.isNotEmpty
        ? resolvedDetails.cleanText
        : 'Claim statement under empirical verification.';
    var responseText = resolvedDetails.response;

    // For opinion claims, ensure the breakdown always explains why it is an opinion and not a fact
    if (verdict.isOpinion) {
      if (responseText.isEmpty ||
          responseText.contains('personal point of view') ||
          responseText.contains('subjective content') ||
          responseText.contains('not subject to factual verification') ||
          responseText.contains('Why is this an opinion and not a fact?')) {
        responseText = ClaimVerdictHelper.formatOpinionExplanation(cleanClaimText);
      }
    }

    // Convert raw sources to typed UISource items
    final typedSources = <UISource>[];
    for (final dynamic s in resolvedDetails.sources) {
      if (!SourceUrlSanitizer.isValidSource(s)) continue;
      if (s is UISource) {
        typedSources.add(s);
      } else if (s is Map) {
        typedSources.add(UISource.fromMap(Map<String, dynamic>.from(s)));
      }
    }

    // Trigger async backend avatar collection for these sources
    if (typedSources.isNotEmpty) {
      final domains = typedSources
          .map((s) => s.domain ?? SourceAvatarService.cleanDomain(s.url))
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      SourceAvatarService.fetchAvatarsFromBackend(domains: domains);
    }

    // Timestamp formatting
    final startSec = _extractStartSeconds(effectiveClaim);
    final timestampText = startSec != null
        ? FormatUtils.formatDuration(Duration(milliseconds: (startSec * 1000).toInt()))
        : '00:00';

    // Initialize ClaimDetailController for desktop command center & timeline scrubbing
    final detailTag = 'claim_${video.id}';
    final detailCtrl = Get.isRegistered<ClaimDetailController>(tag: detailTag)
        ? Get.find<ClaimDetailController>(tag: detailTag)
        : Get.put(ClaimDetailController(initialIndex: claimIndex), tag: detailTag);

    if (detailCtrl.currentClaimIndex.value != claimIndex) {
      detailCtrl.currentClaimIndex.value = claimIndex;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= TWBreakpoints.desktop;
        if (isDesktop) {
          return _buildDesktopScaffold(
            context,
            video: video,
            claimIndex: claimIndex,
            allSources: allSources,
            allClaims: allClaims,
            effectiveClaim: effectiveClaim,
            verdict: verdict,
            cleanClaimText: cleanClaimText,
            responseText: responseText,
            typedSources: typedSources,
            startSec: startSec,
            timestampText: timestampText,
            controller: controller,
            detailCtrl: detailCtrl,
          );
        }
        return _buildMobileScaffold(
          context,
          video: video,
          claimIndex: claimIndex,
          allSources: allSources,
          allClaims: allClaims,
          effectiveClaim: effectiveClaim,
          verdict: verdict,
          cleanClaimText: cleanClaimText,
          responseText: responseText,
          typedSources: typedSources,
          startSec: startSec,
          timestampText: timestampText,
          controller: controller,
        );
      },
    );
  }

  // 🖥️ DESKTOP SCAFFOLD (Command Center Split View: Left 65% / Right 35%)
  Widget _buildDesktopScaffold(
    BuildContext context, {
    required Video video,
    required int claimIndex,
    required List<dynamic> allSources,
    required List<dynamic> allClaims,
    required Map<dynamic, dynamic> effectiveClaim,
    required ClaimVerdictInfo verdict,
    required String cleanClaimText,
    required String responseText,
    required List<UISource> typedSources,
    required double? startSec,
    required String timestampText,
    required ClaimDetailController detailCtrl,
    VideoController? controller,
  }) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() {
          final activeIdx = detailCtrl.currentClaimIndex.value;
          var curClaim = effectiveClaim;
          if (allClaims.isNotEmpty && activeIdx >= 0 && activeIdx < allClaims.length) {
            final c = allClaims[activeIdx];
            if (c is Map) curClaim = c;
          }
          final curVerdict = ClaimVerdictHelper.resolveVerdict(curClaim);
          final curDetails = VideoAnalysisHelpers.resolveRealClaimDetails(
            curClaim,
            activeIdx,
            allSources,
          );
          final curCleanClaimText = curDetails.cleanText.isNotEmpty
              ? curDetails.cleanText
              : cleanClaimText;
          final curTypedSources = <UISource>[];
          for (final dynamic s in curDetails.sources) {
            if (!SourceUrlSanitizer.isValidSource(s)) continue;
            if (s is UISource) {
              curTypedSources.add(s);
            } else if (s is Map) {
              curTypedSources.add(UISource.fromMap(Map<String, dynamic>.from(s)));
            }
          }

          return _buildDesktopAppBar(
            context,
            video: video,
            claimIndex: activeIdx,
            allClaims: allClaims,
            allSources: allSources,
            controller: controller,
            cleanClaimText: curCleanClaimText,
            verdict: curVerdict,
            typedSources: curTypedSources.isNotEmpty ? curTypedSources : typedSources,
            detailCtrl: detailCtrl,
          );
        }),
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          final isDocked = detailCtrl.isAiChatDocked.value;
          final activeIdx = detailCtrl.currentClaimIndex.value;

          var curClaim = effectiveClaim;
          if (allClaims.isNotEmpty && activeIdx >= 0 && activeIdx < allClaims.length) {
            final c = allClaims[activeIdx];
            if (c is Map) curClaim = c;
          }
          final curVerdict = ClaimVerdictHelper.resolveVerdict(curClaim);
          final curDetails = VideoAnalysisHelpers.resolveRealClaimDetails(
            curClaim,
            activeIdx,
            allSources,
          );
          final curCleanClaimText = curDetails.cleanText.isNotEmpty
              ? curDetails.cleanText
              : cleanClaimText;
          var curResponseText = curDetails.response;
          if (curVerdict.isOpinion) {
            if (curResponseText.isEmpty ||
                curResponseText.contains('personal point of view') ||
                curResponseText.contains('subjective content') ||
                curResponseText.contains('not subject to factual verification') ||
                curResponseText.contains('Why is this an opinion and not a fact?')) {
              curResponseText = ClaimVerdictHelper.formatOpinionExplanation(curCleanClaimText);
            }
          }
          final curStartSec = _extractStartSeconds(curClaim) ?? startSec;
          final curTimestampText = curStartSec != null
              ? FormatUtils.formatDuration(Duration(milliseconds: (curStartSec * 1000).toInt()))
              : timestampText;

          final curTypedSources = <UISource>[];
          for (final dynamic s in curDetails.sources) {
            if (!SourceUrlSanitizer.isValidSource(s)) continue;
            if (s is UISource) {
              curTypedSources.add(s);
            } else if (s is Map) {
              curTypedSources.add(UISource.fromMap(Map<String, dynamic>.from(s)));
            }
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Pane: 65% when docked, 100% when collapsed
              Expanded(
                flex: isDocked ? 65 : 100,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDocked ? double.infinity : 1380),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Video Player + Live Transcript (Command Media Stage)
                          ClaimMediaStage(
                            video: video,
                            controller: controller,
                            startSec: curStartSec,
                            timestampText: curTimestampText,
                            claimText: curCleanClaimText,
                            onSeekToClaim: () {
                              if (curStartSec != null) {
                                final target = Duration(milliseconds: (curStartSec * 1000).toInt());
                                controller?.videoPlayerController?.seekTo(target);
                              }
                            },
                          ),
                          const SizedBox(height: 18),

                          // 2. Claim Ledger Timeline
                          if (allClaims.isNotEmpty) ...[
                            ClaimLedgerTimeline(
                              allClaims: allClaims,
                              activeIndex: activeIdx,
                              scrollController: detailCtrl.timelineScrollController,
                              onClaimSelected: (newIdx) {
                                detailCtrl.selectClaim(
                                  index: newIdx,
                                  allClaims: allClaims,
                                  videoController: controller,
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                          ],

                          // 3. Top Claim Card
                          _buildDesktopTopClaimCard(
                            context,
                            index: activeIdx,
                            verdict: curVerdict,
                            timestampText: curTimestampText,
                            claimText: curCleanClaimText,
                            startSec: curStartSec,
                            controller: controller,
                            video: video,
                            initialClaim: curClaim,
                            onAskAiTap: () {
                              if (!isDocked) {
                                detailCtrl.openAiChat();
                              }
                            },
                            onShareTap: () {
                              final domain = curTypedSources.isNotEmpty ? curTypedSources.first.domain : null;
                              _shareClaim(
                                context,
                                video: video,
                                claimText: curCleanClaimText,
                                verdict: curVerdict,
                                primarySourceDomain: domain,
                                claimIndex: activeIdx,
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // 4. Truth Intelligence Breakdown Card
                          _buildDesktopAiVerificationCard(
                            context,
                            responseText: curResponseText,
                            sourcesCount: curTypedSources.length,
                          ),
                          const SizedBox(height: 20),

                          // 5. Sources Panel
                          _buildDesktopSourcesPanel(
                            context,
                            sources: curTypedSources,
                            claimText: curCleanClaimText,
                            video: video,
                            initialClaim: curClaim,
                            claimIndex: activeIdx,
                          ),
                          const SizedBox(height: 20),

                          // 6. Community Deliberation & Notes
                          ClaimCommunityNotesSection(
                            videoId: video.id,
                            claimIndex: activeIdx,
                            claimText: curCleanClaimText,
                          ),
                          const SizedBox(height: 20),

                          // 7. Epistemic Transparency Banner
                          const FactCheckEpistemicBanner(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Right Pane: Persistent Truth AI Chat (35%)
              if (isDocked) ...[
                Container(
                  width: 1,
                  color: AppColors.bgDivider,
                ),
                Expanded(
                  flex: 35,
                  child: Container(
                    color: const Color(0xFF000000),
                    child: AiCredibilityChatSheet(
                      video: video,
                      scope: 'claim',
                      claimIndex: activeIdx,
                      claimText: curCleanClaimText,
                      verdict: curVerdict.label,
                      allSources: curClaim['sources'] as List? ?? allSources,
                      allClaims: [curClaim],
                      summary: curResponseText.isNotEmpty ? curResponseText : null,
                      claimExplanation: curResponseText.isNotEmpty ? curResponseText : null,
                      playbackSec: curStartSec,
                      transcriptSnippet: curCleanClaimText,
                      activeChapterTitle: 'Claim #${activeIdx + 1}',
                      isEmbedded: true,
                      onClose: () => detailCtrl.closeAiChat(),
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  // Desktop App Bar
  PreferredSizeWidget _buildDesktopAppBar(
    BuildContext context, {
    required Video video,
    required int claimIndex,
    required List<dynamic> allClaims,
    required List<dynamic> allSources,
    required VideoController? controller,
    required String cleanClaimText,
    required ClaimVerdictInfo verdict,
    required List<UISource> typedSources,
    ClaimDetailController? detailCtrl,
  }) {
    return AppBar(
      backgroundColor: AppColors.bgSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.bgDivider,
          height: 0.8,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        tooltip: 'Back to Analysis',
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Get.offNamed('/watch?v=${video.id}');
          }
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Text(
              'Claim #${claimIndex + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '•',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (allClaims.isNotEmpty && allClaims.length > 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  color: claimIndex > 0 ? Colors.white : Colors.white24,
                  tooltip: 'Previous Claim',
                  splashRadius: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: claimIndex > 0
                      ? () {
                          if (detailCtrl != null) {
                            detailCtrl.selectClaim(
                              index: claimIndex - 1,
                              allClaims: allClaims,
                              videoController: controller,
                            );
                          } else {
                            _navigateToClaim(
                              context,
                              video: video,
                              targetIndex: claimIndex - 1,
                              allClaims: allClaims,
                              allSources: allSources,
                              controller: controller,
                            );
                          }
                        }
                      : null,
                ),
                const SizedBox(width: 4),
                Text(
                  '${claimIndex + 1} of ${allClaims.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  color: claimIndex < allClaims.length - 1 ? Colors.white : Colors.white24,
                  tooltip: 'Next Claim',
                  splashRadius: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: claimIndex < allClaims.length - 1
                      ? () {
                          if (detailCtrl != null) {
                            detailCtrl.selectClaim(
                              index: claimIndex + 1,
                              allClaims: allClaims,
                              videoController: controller,
                            );
                          } else {
                            _navigateToClaim(
                              context,
                              video: video,
                              targetIndex: claimIndex + 1,
                              allClaims: allClaims,
                              allSources: allSources,
                              controller: controller,
                            );
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (detailCtrl != null) ...[
          Obx(() {
            final isDocked = detailCtrl.isAiChatDocked.value;
            return OutlinedButton.icon(
              onPressed: () => detailCtrl.toggleAiChatDock(),
              icon: Icon(
                isDocked ? Icons.view_sidebar_rounded : Icons.auto_awesome_rounded,
                size: 16,
                color: isDocked ? const Color(0xFF2DD4BF) : Colors.white,
              ),
              label: Text(
                isDocked ? 'Truth AI (35%)' : 'Dock Truth AI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDocked ? const Color(0xFF2DD4BF) : Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDocked
                      ? const Color(0xFF2DD4BF).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 0.8,
                ),
                backgroundColor: isDocked
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.1)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            );
          }),
          const SizedBox(width: 10),
        ],
        OutlinedButton.icon(
          onPressed: () {
            final domain = typedSources.isNotEmpty ? typedSources.first.domain : null;
            _shareClaim(
              context,
              video: video,
              claimText: cleanClaimText,
              verdict: verdict,
              primarySourceDomain: domain,
              claimIndex: claimIndex,
            );
          },
          icon: const Icon(Icons.share_outlined, size: 16, color: Colors.white),
          label: Text(
            'Share',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.8,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        const SizedBox(width: 18),
      ],
    );
  }

  // Desktop Top Claim Card
  Widget _buildDesktopTopClaimCard(
    BuildContext context, {
    required int index,
    required ClaimVerdictInfo verdict,
    required String timestampText,
    required String claimText,
    required double? startSec,
    required VideoController? controller,
    required Video video,
    required Map<dynamic, dynamic> initialClaim,
    VoidCallback? onShareTap,
    VoidCallback? onAskAiTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Claim Index Circle Badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Verdict Pill
              () {
                final isMostly = verdict.type == ClaimVerdictType.mostlyTrue ||
                    verdict.label.toLowerCase().contains('mostly');
                final isPartially = verdict.label.toLowerCase().contains('partial') ||
                    verdict.label.toLowerCase().contains('half');
                final Color pillColor;
                if (isMostly) {
                  pillColor = const Color(0xFF2DD4BF);
                } else if (isPartially) {
                  pillColor = AppColors.warning;
                } else if (verdict.isVerified) {
                  pillColor = AppColors.success;
                } else if (verdict.isFalse) {
                  pillColor = AppColors.error;
                } else if (verdict.isCaution) {
                  pillColor = const Color(0xFFFB923C);
                } else if (verdict.isContextual) {
                  pillColor = AppColors.textLink;
                } else {
                  pillColor = AppColors.warning;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: pillColor.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        verdict.icon,
                        size: 16,
                        color: pillColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        verdict.localizedLabel().toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: pillColor,
                        ),
                      ),
                    ],
                  ),
                );
              }(),
              const SizedBox(width: 10),

              // Timestamp Pill (Tappable to seek video)
              Tooltip(
                message: 'Jump to video timestamp',
                child: InkWell(
                  onTap: () {
                    if (startSec != null) {
                      final target =
                          Duration(milliseconds: (startSec * 1000).toInt());
                      controller?.videoPlayerController?.seekTo(target);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timestampText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Copy Claim Button
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Copy claim text',
                splashRadius: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: claimText));
                  AppToast.info('Claim statement copied to clipboard');
                },
              ),
              const SizedBox(width: 8),

              // Share Button on Claim Card
              IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Share Claim',
                splashRadius: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: onShareTap,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Prominent Claim Statement
          Text(
            claimText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Subtle Divider
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            height: 1,
            thickness: 0.8,
          ),
          const SizedBox(height: 18),

          // Action Buttons Row (Directly on Desktop Claim Card)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  if (onAskAiTap != null) {
                    onAskAiTap();
                    return;
                  }
                  final explanation = (initialClaim['explanation'] ??
                          initialClaim['truthBreakdown'] ??
                          initialClaim['reasoning'] ??
                          '')
                      .toString();
                  final claimSources = initialClaim['sources'] as List?;
                  AiCredibilityChatSheet.show(
                    context,
                    video: video,
                    scope: 'claim',
                    claimIndex: index,
                    claimText: claimText,
                    verdict: verdict.label,
                    allSources: claimSources,
                    allClaims: [initialClaim],
                    summary: explanation.isNotEmpty ? explanation : null,
                    claimExplanation: explanation.isNotEmpty ? explanation : null,
                    playbackSec: startSec,
                    transcriptSnippet: claimText,
                    activeChapterTitle: 'Claim #${index + 1}',
                  );
                },
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Ask AI',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                onPressed: () => _searchWeb(claimText),
                icon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Search web',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: () => ClaimSourceSubmissionDialog.show(
                  context: context,
                  video: video,
                  initialClaim: initialClaim,
                ),
                icon: const Icon(
                  Icons.add_link_rounded,
                  size: 18,
                  color: Colors.black, // Strictly black on white
                ),
                label: Text(
                  'Provide source',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Strictly black on white
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black, // High contrast compliance
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Desktop Truth Intelligence Breakdown Card
  Widget _buildDesktopAiVerificationCard(
    BuildContext context, {
    required String responseText,
    required int sourcesCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                'Truth Intelligence Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Simple Breakdown',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Formatted Explanation with Markdown Bold Emphasis
          _buildFormattedExplanation(responseText, isDesktop: true),
        ],
      ),
    );
  }

  // Desktop Sources Sidebar Panel
  Widget _buildDesktopSourcesPanel(
    BuildContext context, {
    required List<UISource> sources,
    required String claimText,
    required Video video,
    Map<dynamic, dynamic>? initialClaim,
    int claimIndex = 0,
  }) {
    final sourceStatus = _resolveSourceStatus(initialClaim);
    final academicMetadata = _extractAcademicMetadata(initialClaim);
    final verifiedSources =
        sourceStatus == 'missing' ? const <UISource>[] : sources;
    final hasLiveSources = verifiedSources.isNotEmpty;
    final claimId = _resolveClaimId(initialClaim, claimIndex);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(
                Icons.link_rounded,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                'Sources',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${verifiedSources.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Provide additional source',
                child: IconButton(
                  icon: const Icon(
                    Icons.add_link_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  splashRadius: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => ClaimSourceSubmissionDialog.show(
                    context: context,
                    video: video,
                    initialClaim: initialClaim ?? {'claim': claimText, 'text': claimText},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasLiveSources
                ? 'Verified sources confirmed live for this claim.'
                : 'Verified source links are currently unavailable for this claim.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            height: 1,
            thickness: 0.8,
          ),
          const SizedBox(height: 14),

          // Sources List or Honest Missing-Source Notice
          if (hasLiveSources) ...[
            ListView.separated(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: verifiedSources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = verifiedSources[index];
                return _buildDesktopSourceTile(
                  context,
                  s,
                  videoId: video.id,
                  claimId: claimId,
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Showing all ${verifiedSources.length} sources',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ClaimSourceSubmissionDialog.show(
                    context: context,
                    video: video,
                    initialClaim: initialClaim ?? {'claim': claimText, 'text': claimText},
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                  label: Text(
                    'Add source',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildMissingSourcesCard(
              context,
              claimText: claimText,
              video: video,
              initialClaim: initialClaim,
            ),
          ],
          if (academicMetadata.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildAcademicMetadataSection(context, metadata: academicMetadata),
          ],
        ],
      ),
    );
  }

  // Desktop Individual Source Tile
  Widget _buildDesktopSourceTile(
    BuildContext context,
    UISource s, {
    String? videoId,
    String? claimId,
  }) {
    final effectivePublisher = (s.publisher != null && s.publisher!.isNotEmpty)
        ? s.publisher!
        : (s.domain != null && s.domain!.isNotEmpty ? s.domain! : 'Verified Organization');
    final domainName = s.domain ?? SourceAvatarService.cleanDomain(s.url);

    return InkWell(
      onTap: () => _launchSourceUrl(
        s.url,
        source: s,
        videoId: videoId,
        claimId: claimId,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SourceAvatarService.buildAvatar(
              domain: s.domain,
              publisher: s.publisher,
              url: s.url,
              avatarUrl: s.avatarUrl,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          effectivePublisher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (domainName.isNotEmpty && domainName != effectivePublisher) ...[
                        const SizedBox(width: 6),
                        Text(
                          '($domainName)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  if (s.publishedAt != null && s.publishedAt!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.publishedAt!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Smooth Navigation Between Claims on Desktop
  void _navigateToClaim(
    BuildContext context, {
    required Video video,
    required int targetIndex,
    required List<dynamic> allClaims,
    required List<dynamic> allSources,
    VideoController? controller,
  }) {
    if (targetIndex < 0 || targetIndex >= allClaims.length) return;
    final targetClaim = allClaims[targetIndex];
    Get.off(
      () => ClaimDetailScreen(
        claim: targetClaim is Map ? targetClaim : null,
        claimIndex: targetIndex,
        video: video,
        controller: controller,
        allSources: allSources,
        allClaims: allClaims,
      ),
      arguments: {
        'claim': targetClaim,
        'claimIndex': targetIndex,
        'video': video,
        'controller': controller,
        'allSources': allSources,
        'allClaims': allClaims,
        'videoId': video.id,
      },
      preventDuplicates: false,
    );
  }

  // 📱 MOBILE & MOBILE WEB SCAFFOLD (Strictly Unchanged for Mobiles and Web Mobile Sizes)
  Widget _buildMobileScaffold(
    BuildContext context, {
    required Video video,
    required int claimIndex,
    required List<dynamic> allSources,
    required List<dynamic> allClaims,
    required Map<dynamic, dynamic> effectiveClaim,
    required ClaimVerdictInfo verdict,
    required String cleanClaimText,
    required String responseText,
    required List<UISource> typedSources,
    required double? startSec,
    required String timestampText,
    VideoController? controller,
  }) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Back to Analysis',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.offNamed('/watch?v=${video.id}');
            }
          },
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim #${claimIndex + 1}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            tooltip: 'Share Claim',
            onPressed: () {
              final domain = typedSources.isNotEmpty ? typedSources.first.domain : null;
              _shareClaim(
                context,
                video: video,
                claimText: cleanClaimText,
                verdict: verdict,
                primarySourceDomain: domain,
                claimIndex: claimIndex,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 🏛 1. TOP CLAIM STATEMENT CARD
                      _buildTopClaimCard(
                        context,
                        index: claimIndex,
                        verdict: verdict,
                        timestampText: timestampText,
                        claimText: cleanClaimText,
                        startSec: startSec,
                        controller: controller,
                        onShareTap: () {
                          final domain = typedSources.isNotEmpty ? typedSources.first.domain : null;
                          _shareClaim(
                            context,
                            video: video,
                            claimText: cleanClaimText,
                            verdict: verdict,
                            primarySourceDomain: domain,
                            claimIndex: claimIndex,
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // ✨ 2. TRUTH INTELLIGENCE BREAKDOWN CARD
                      _buildAiVerificationCard(context, responseText: responseText),
                      const SizedBox(height: 14),

                      // 🔗 3. SOURCES CARD
                      _buildSourcesCard(
                        context,
                        sources: typedSources,
                        claimText: cleanClaimText,
                        video: video,
                        initialClaim: effectiveClaim,
                        claimIndex: claimIndex,
                      ),
                      const SizedBox(height: 14),

                      // 💬 4. COMMUNITY DELIBERATION & NOTES CARD
                      ClaimCommunityNotesSection(
                        videoId: video.id,
                        claimIndex: claimIndex,
                        claimText: cleanClaimText,
                      ),
                      const SizedBox(height: 16),
                      const FactCheckEpistemicBanner(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // 📌 4. FIXED BOTTOM ACTION BAR ("Ask AI", "Search web" & "Provide source")
                _buildBottomActionBar(
                  context,
                  claimText: cleanClaimText,
                  video: video,
                  initialClaim: effectiveClaim,
                  bottomPadding: bottomPadding,
                  claimIndex: claimIndex,
                  verdict: verdict,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🏛 1. Top Claim Card
  Widget _buildTopClaimCard(
    BuildContext context, {
    required int index,
    required ClaimVerdictInfo verdict,
    required String timestampText,
    required String claimText,
    required double? startSec,
    required VideoController? controller,
    VoidCallback? onShareTap,
  }) {
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
          Row(
            children: [
              // Claim Index Circle Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Verdict Pill
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: () {
                final isMostly = verdict.type == ClaimVerdictType.mostlyTrue ||
                    verdict.label.toLowerCase().contains('mostly');
                final isPartially = verdict.label.toLowerCase().contains('partial') ||
                    verdict.label.toLowerCase().contains('half');
                final Color pillColor;
                if (isMostly) {
                  pillColor = const Color(0xFF2DD4BF);
                } else if (isPartially) {
                  pillColor = AppColors.warning;
                } else if (verdict.isVerified) {
                  pillColor = AppColors.success;
                } else if (verdict.isFalse) {
                  pillColor = AppColors.error;
                } else if (verdict.isCaution) {
                  pillColor = const Color(0xFFFB923C);
                } else if (verdict.isContextual) {
                  pillColor = AppColors.textLink;
                } else {
                  pillColor = AppColors.warning;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: pillColor.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        verdict.icon,
                        size: 15,
                        color: pillColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        verdict.localizedLabel().toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: pillColor,
                        ),
                      ),
                    ],
                  ),
                );
              }(),
                ),
              ),
              const SizedBox(width: 8),

              // Timestamp Pill (Tappable to seek video)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: InkWell(
                onTap: () {
                  if (startSec != null) {
                    final target =
                        Duration(milliseconds: (startSec * 1000).toInt());
                    controller?.videoPlayerController?.seekTo(target);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timestampText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              const Spacer(),

              // Share Button on Claim Card
              IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  size: 19,
                  color: Colors.white,
                ),
                tooltip: 'Share Claim',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onShareTap,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Prominent Claim Statement
          Text(
            claimText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ✨ 2. Truth Intelligence Breakdown Card
  Widget _buildAiVerificationCard(
    BuildContext context, {
    required String responseText,
  }) {
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
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Truth Intelligence Breakdown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Formatted Explanation with Markdown Bold Emphasis
          _buildFormattedExplanation(responseText),
        ],
      ),
    );
  }

  // 🔗 3. Sources Card with Top Avatars and "View all X sources" (or Honest Unavailable Notice)
  Widget _buildSourcesCard(
    BuildContext context, {
    required List<UISource> sources,
    required String claimText,
    required Video video,
    Map<dynamic, dynamic>? initialClaim,
    int claimIndex = 0,
  }) {
    final sourceStatus = _resolveSourceStatus(initialClaim);
    final academicMetadata = _extractAcademicMetadata(initialClaim);
    final verifiedSources =
        sourceStatus == 'missing' ? const <UISource>[] : sources;
    final hasLiveSources = verifiedSources.isNotEmpty;
    final claimId = _resolveClaimId(initialClaim, claimIndex);

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
          // Header Row
          InkWell(
            onTap: hasLiveSources
                ? () => ClaimSourcesBottomSheet.show(
                      context,
                      sources: verifiedSources,
                      claimText: claimText,
                      video: video,
                      initialClaim: initialClaim,
                    )
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sources',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${verifiedSources.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                if (hasLiveSources) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sources Horizontal Rail or Honest Missing-Source Notice
          if (hasLiveSources) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: verifiedSources.take(8).map((s) {
                  final domainName = s.domain ?? SourceAvatarService.cleanDomain(s.url);
                  return Container(
                    width: 175,
                    margin: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => _launchSourceUrl(
                        s.url,
                        source: s,
                        videoId: video.id,
                        claimId: claimId,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top Row: Favicon + Domain Name + External Icon
                            Row(
                              children: [
                                SourceAvatarService.buildAvatar(
                                  domain: s.domain,
                                  publisher: s.publisher,
                                  url: s.url,
                                  avatarUrl: s.avatarUrl,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    domainName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Article Title
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Action Button: "View all X sources"
            InkWell(
              onTap: () => ClaimSourcesBottomSheet.show(
                context,
                sources: verifiedSources,
                claimText: claimText,
                video: video,
                initialClaim: initialClaim,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'View all ${verifiedSources.length} sources',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            _buildMissingSourcesCard(
              context,
              claimText: claimText,
              video: video,
              initialClaim: initialClaim,
            ),
          ],
          if (academicMetadata.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildAcademicMetadataSection(context, metadata: academicMetadata),
          ],
        ],
      ),
    );
  }

  // 📌 4. Fixed Bottom Action Bar
  Widget _buildBottomActionBar(
    BuildContext context, {
    required String claimText,
    required Video video,
    required double bottomPadding,
    Map<dynamic, dynamic>? initialClaim,
    int? claimIndex,
    ClaimVerdictInfo? verdict,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding > 0 ? bottomPadding : 16),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Ask AI Button
          Expanded(
            flex: 3,
            child: OutlinedButton(
              onPressed: () {
                final startSec = initialClaim != null ? _extractStartSeconds(initialClaim) : null;
                final explanation = (initialClaim?['explanation'] ??
                        initialClaim?['truthBreakdown'] ??
                        initialClaim?['reasoning'] ??
                        '')
                    .toString();
                final claimSources = initialClaim?['sources'] as List?;
                AiCredibilityChatSheet.show(
                  context,
                  video: video,
                  scope: 'claim',
                  claimIndex: claimIndex,
                  claimText: claimText,
                  verdict: verdict?.label,
                  allSources: claimSources,
                  allClaims: initialClaim != null ? [initialClaim] : null,
                  summary: explanation.isNotEmpty ? explanation : null,
                  claimExplanation: explanation.isNotEmpty ? explanation : null,
                  playbackSec: startSec,
                  transcriptSnippet: claimText,
                  activeChapterTitle: claimIndex != null ? 'Claim #${claimIndex + 1}' : null,
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                shape: const StadiumBorder(),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Ask AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Search Web Button
          Expanded(
            flex: 4,
            child: OutlinedButton(
              onPressed: () => _searchWeb(claimText),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                shape: const StadiumBorder(),
                backgroundColor: Colors.transparent,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Search web',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Provide Source Button (Pure White background with Black text & icon - WCAG AA Compliant)
          Expanded(
            flex: 4,
            child: ElevatedButton(
              onPressed: () => ClaimSourceSubmissionDialog.show(
                context: context,
                video: video,
                initialClaim: initialClaim ?? {'claim': claimText, 'text': claimText},
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black, // High contrast compliance
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_link_rounded,
                      size: 17,
                      color: Colors.black, // Strictly black on white
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Provide source',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // Strictly black on white
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Parses markdown-style **bold** markers into rich TextSpans
  Widget _buildFormattedExplanation(String text, {bool isDesktop = false}) {
    final cleanText = text.trim();
    final fontSize = isDesktop ? 15.0 : 13.5;
    final lineHeight = isDesktop ? 1.6 : 1.45;

    if (cleanText.isEmpty) {
      return Text(
        'Checking the facts right now...',
        style: TextStyle(fontSize: fontSize, color: AppColors.textTertiary),
      );
    }

    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    var lastIndex = 0;

    for (final match in regex.allMatches(cleanText)) {
      if (match.start > lastIndex) {
        final segment = cleanText.substring(lastIndex, match.start);
        spans.addAll(
          ClickableUrlText.parseSpans(
            segment,
            style: TextStyle(
              fontSize: fontSize,
              height: lineHeight,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        );
      }
      final boldContent = match.group(1) ?? '';
      spans.addAll(
        ClickableUrlText.parseSpans(
          boldContent,
          style: TextStyle(
            fontSize: fontSize,
            height: lineHeight,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < cleanText.length) {
      spans.addAll(
        ClickableUrlText.parseSpans(
          cleanText.substring(lastIndex),
          style: TextStyle(
            fontSize: fontSize,
            height: lineHeight,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  double? _extractStartSeconds(Map<dynamic, dynamic> claim) {
    final raw = claim['startMs'] ??
        claim['startTimeMs'] ??
        claim['start'] ??
        claim['timestampStart'];
    if (raw == null) return null;
    final ms = VideoAnalysisHelpers.normalizeTimestampToMs(raw);
    return ms > 0 ? ms / 1000.0 : 0.0;
  }

  String _resolveClaimId(Map<dynamic, dynamic>? claim, int claimIndex) {
    final rawId = claim?['claimId'] ?? claim?['id'];
    if (rawId != null && rawId.toString().trim().isNotEmpty) {
      return rawId.toString().trim();
    }
    return 'claim_$claimIndex';
  }

  String _resolveSourceStatus(Map<dynamic, dynamic>? claim) {
    return (claim?['sourceStatus'] ?? claim?['sourcesStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  List<Map<String, dynamic>> _extractAcademicMetadata(
    Map<dynamic, dynamic>? claim,
  ) {
    final raw = claim?['verifiedAcademicMetadata'];
    if (raw is! List) return const [];
    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final hasInfo = [
          map['title'],
          map['doi'],
          map['pmid'],
          map['pmcid'],
          map['journal'],
          map['publisher'],
          map['authors'],
        ].any((v) => v != null && v.toString().trim().isNotEmpty);
        if (hasInfo) items.add(map);
      }
    }
    return items;
  }

  Widget _buildMissingSourcesCard(
    BuildContext context, {
    required String claimText,
    required Video video,
    Map<dynamic, dynamic>? initialClaim,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.link_off_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Verified source links are currently unavailable',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'TruthWorld only displays source links confirmed live so you are never sent to broken or unverified pages.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _searchWeb(claimText),
                icon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Search web',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => ClaimSourceSubmissionDialog.show(
                  context: context,
                  video: video,
                  initialClaim:
                      initialClaim ?? {'claim': claimText, 'text': claimText},
                ),
                icon: const Icon(
                  Icons.add_link_rounded,
                  size: 16,
                  color: Colors.black,
                ),
                label: const Text(
                  'Provide source',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicMetadataSection(
    BuildContext context, {
    required List<Map<String, dynamic>> metadata,
  }) {
    if (metadata.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Academic Reference Metadata',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Non-clickable',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Verified bibliographic record. Direct public web links are unavailable or paywalled.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textTertiary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          ...metadata.take(4).map((item) {
            final title = (item['title'] ?? '').toString().trim();
            final authors = item['authors'] is List
                ? (item['authors'] as List)
                    .map((a) => a.toString().trim())
                    .where((a) => a.isNotEmpty)
                    .take(3)
                    .join(', ')
                : (item['authors'] ?? '').toString().trim();
            final journal =
                (item['journal'] ?? item['publisher'] ?? '').toString().trim();
            final year = (item['year'] ?? '').toString().trim();
            final doi = (item['doi'] ?? '').toString().trim();
            final pmid = (item['pmid'] ?? '').toString().trim();
            final pmcid = (item['pmcid'] ?? '').toString().trim();

            final metaParts = [
              if (authors.isNotEmpty) authors,
              if (journal.isNotEmpty) journal,
              if (year.isNotEmpty) year,
            ].join(' • ');
            final idParts = [
              if (doi.isNotEmpty) 'DOI: $doi',
              if (pmid.isNotEmpty) 'PMID: $pmid',
              if (pmcid.isNotEmpty) 'PMCID: $pmcid',
            ].join('  |  ');

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      metaParts,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (idParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      idParts,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _launchSourceUrl(
    String? urlStr, {
    UISource? source,
    String? videoId,
    String? claimId,
  }) async {
    final targetUrl =
        (urlStr != null && urlStr.trim().isEmpty == false) ? urlStr : source?.url;
    if (targetUrl == null || targetUrl.trim().isEmpty) return;
    await SourceUrlSanitizer.launchSourceUrl(
      url: targetUrl,
      title: source?.title,
      publisher: source?.publisher,
      domain: source?.domain,
      source: source?.toMap(),
      videoId: videoId,
      claimId: claimId,
    );
  }

  Future<void> _searchWeb(String claimText) async {
    await SourceUrlSanitizer.launchWebSearch(query: claimText);
  }

  void _shareClaim(
    BuildContext context, {
    required Video video,
    required String claimText,
    required ClaimVerdictInfo verdict,
    String? primarySourceDomain,
    int? claimIndex,
  }) {
    ClaimShareService.shareClaim(
      context: context,
      video: video,
      claimText: claimText,
      verdict: verdict,
      primarySourceDomain: primarySourceDomain,
      claimIndex: claimIndex ?? this.claimIndex,
    );
  }

  Widget _buildLoadingScaffold() {
    return const Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
