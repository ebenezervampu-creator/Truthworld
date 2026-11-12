import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/source_avatar_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/credibility_chat_message.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/ai_credibility_chat_service.dart';

/// 🧠 AiCredibilityChatController
///
/// Manages reactive message history, real-time token streaming state, quick prompt suggestions,
/// and bidirectional communication with the Gemini-powered credibility service.
class AiCredibilityChatController extends GetxController {
  final RxList<CredibilityChatMessage> messages = <CredibilityChatMessage>[].obs;
  final RxBool isLoading = false.obs;
  final RxString scope = 'video'.obs; // 'video' | 'claim'
  final RxnInt currentClaimIndex = RxnInt();
  final RxString claimText = ''.obs;
  final RxString claimVerdict = ''.obs;
  final RxString claimExplanation = ''.obs;
  final RxString videoTitle = ''.obs;
  final RxString videoCategory = ''.obs;
  final RxString videoId = ''.obs;
  final RxList<String> suggestedPrompts = <String>[].obs;
  final RxList<dynamic> cachedSources = <dynamic>[].obs;
  final RxList<dynamic> cachedClaims = <dynamic>[].obs;
  final RxString videoSummary = ''.obs;
  final RxBool cursorVisible = true.obs;
  final RxBool isSuspended = false.obs;
  final RxString suspensionNotice = ''.obs;

  // ⏱️ Temporal Video & Transcript Anchoring
  final RxnDouble playbackSec = RxnDouble();
  final RxString transcriptSnippet = ''.obs;
  final RxString activeChapterTitle = ''.obs;

  late final TextEditingController textController;
  late final ScrollController scrollController;

  StreamSubscription<CredibilityChatStreamEvent>? _streamSubscription;
  Timer? _scrollThrottleTimer;
  Timer? _cursorTimer;
  Timer? _typewriterTimer;

  final List<String> _tokenQueue = <String>[];
  final StringBuffer _visibleTextBuffer = StringBuffer();
  bool _isNetworkStreamDone = false;

  @override
  void onInit() {
    super.onInit();
    textController = TextEditingController();
    scrollController = ScrollController();
  }

  @override
  void onClose() {
    _streamSubscription?.cancel();
    _scrollThrottleTimer?.cancel();
    _stopCursorTimer();
    _stopTypewriterTimer();
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void _stopTypewriterTimer() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
    _tokenQueue.clear();
    _visibleTextBuffer.clear();
  }

  void _startCursorTimer() {
    _cursorTimer?.cancel();
    cursorVisible.value = true;
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      cursorVisible.value = !cursorVisible.value;
    });
  }

  void _stopCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    cursorVisible.value = false;
  }

  void _enqueueDelta(String delta) {
    if (delta.isEmpty) return;
    final regExp = RegExp(r'(\S+\s*|\n+)');
    final matches = regExp.allMatches(delta);
    if (matches.isEmpty) {
      _tokenQueue.add(delta);
    } else {
      for (final m in matches) {
        _tokenQueue.add(m.group(0)!);
      }
    }
  }

  static String formatTime(double sec) {
    final safe = sec < 0 ? 0 : sec.toInt();
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Updates temporal video and transcript playback context
  void updateTemporalContext({
    double? playbackSec,
    String? transcriptSnippet,
    String? activeChapterTitle,
  }) {
    var changed = false;
    if (playbackSec != null && this.playbackSec.value != playbackSec) {
      this.playbackSec.value = playbackSec;
      changed = true;
    }
    if (transcriptSnippet != null && this.transcriptSnippet.value != transcriptSnippet) {
      this.transcriptSnippet.value = transcriptSnippet;
      changed = true;
    }
    if (activeChapterTitle != null && this.activeChapterTitle.value != activeChapterTitle) {
      this.activeChapterTitle.value = activeChapterTitle;
      changed = true;
    }

    if (changed) {
      _syncSuggestedPrompts();
    }
  }

  /// Clears temporal context and returns to holistic claim/video mode
  void clearTemporalContext() {
    playbackSec.value = null;
    transcriptSnippet.value = '';
    activeChapterTitle.value = '';
    _syncSuggestedPrompts();
  }

  void _syncSuggestedPrompts() {
    if (playbackSec.value != null) {
      final timeStr = formatTime(playbackSec.value!);
      suggestedPrompts.assignAll([
        'Verify what was said at $timeStr',
        'What did the speaker just mean by that?',
        'Did they contradict an earlier claim?',
        if (scope.value == 'claim')
          'Suggest better videos for this claim'
        else
          'Suggest better videos on this topic',
      ]);
    } else if (scope.value == 'claim') {
      suggestedPrompts.assignAll([
        'Suggest better videos for this claim',
        'Why this verdict?',
        'What sources support this claim?',
        'Show counter-evidence',
      ]);
    } else {
      suggestedPrompts.assignAll([
        'Suggest better videos on this topic',
        'Summarize the credibility of this video',
        'What are the most controversial claims?',
        'Summarize verified claims',
      ]);
    }
  }

  /// Initializes context for a particular claim or overall video
  void initScope({
    required String targetVideoId,
    required String targetScope,
    Video? video,
    int? targetClaimIndex,
    String? targetClaimText,
    String? targetVerdict,
    String? title,
    List<dynamic>? allSources,
    List<dynamic>? allClaims,
    String? summary,
    String? claimExplanation,
    double? initialPlaybackSec,
    String? initialTranscriptSnippet,
    String? initialActiveChapterTitle,
  }) {
    videoId.value = targetVideoId;
    scope.value = targetScope;
    currentClaimIndex.value = targetClaimIndex;
    claimText.value = targetClaimText ?? '';
    claimVerdict.value = targetVerdict ?? '';
    this.claimExplanation.value = claimExplanation ?? '';
    videoTitle.value = title ?? video?.title ?? 'Video';
    videoCategory.value = video?.category ?? '';
    if (summary != null && summary.isNotEmpty) {
      videoSummary.value = summary;
    }
    
    if (allSources != null && allSources.isNotEmpty) {
      cachedSources.assignAll(allSources);
    }
    if (allClaims != null && allClaims.isNotEmpty) {
      cachedClaims.assignAll(allClaims);
    }

    if (initialPlaybackSec != null) {
      playbackSec.value = initialPlaybackSec;
    }
    if (initialTranscriptSnippet != null) {
      transcriptSnippet.value = initialTranscriptSnippet;
    }
    if (initialActiveChapterTitle != null) {
      activeChapterTitle.value = initialActiveChapterTitle;
    }

    _syncSuggestedPrompts();

    // If fresh chat, seed greeting and context-aware starter prompts
    if (messages.isEmpty) {
      if (targetScope == 'claim') {
        messages.add(
          CredibilityChatMessage.ai(
            text: 'I am your Truth Intelligence assistant for **Claim #${(targetClaimIndex ?? 0) + 1}**:\n\n'
                '> "${targetClaimText ?? 'Claim under empirical review'}"\n\n'
                'You can ask me to explain why this was classified as **${targetVerdict ?? 'Verified'}**, suggest better videos or sources, request peer-reviewed evidence, or check counter-arguments.',
            scope: 'claim',
            claimIndex: targetClaimIndex,
            suggestedFollowups: suggestedPrompts,
          ),
        );
      } else {
        messages.add(
          CredibilityChatMessage.ai(
            text: 'Welcome to Truth Intelligence for **${videoTitle.value}**.\n\n'
                'I can help you explore the credibility analysis, suggest more authoritative videos and sources, explain how claims were verified, evaluate citations, and answer any questions about the evidence.',
            suggestedFollowups: suggestedPrompts,
          ),
        );
      }
    }
  }

  void _startTypewriterTimer({
    required int aiMsgIndex,
    required CredibilityChatMessage initialAiMessage,
    required List<UISource> Function() getSources,
    required List<String> Function() getFollowups,
    required String? Function() getDisclaimer,
  }) {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (_tokenQueue.isNotEmpty) {
        final int batchSize;
        if (_tokenQueue.length > 30) {
          batchSize = 4;
        } else if (_tokenQueue.length > 15) {
          batchSize = 3;
        } else if (_tokenQueue.length > 6) {
          batchSize = 2;
        } else {
          batchSize = 1;
        }

        for (var i = 0; i < batchSize && _tokenQueue.isNotEmpty; i++) {
          _visibleTextBuffer.write(_tokenQueue.removeAt(0));
        }

        isLoading.value = false;
        if (aiMsgIndex < messages.length) {
          messages[aiMsgIndex] = initialAiMessage.copyWith(
            text: _visibleTextBuffer.toString(),
            sources: getSources(),
            suggestedFollowups: getFollowups(),
            disclaimer: getDisclaimer(),
            isStreaming: true,
          );
        }
        _scheduleScrollToBottom();
      } else if (_isNetworkStreamDone) {
        timer.cancel();
        _typewriterTimer = null;
        _stopCursorTimer();
        isLoading.value = false;

        final finalText = _visibleTextBuffer.isNotEmpty
            ? _visibleTextBuffer.toString()
            : 'Credibility analysis completed.';

        if (finalText.contains('Restriction Activated') ||
            finalText.contains('Account Restriction Active') ||
            finalText.contains('Restriction Active (')) {
          isSuspended.value = true;
          suspensionNotice.value = 'Ask AI access is currently restricted.';
        }

        if (aiMsgIndex < messages.length) {
          messages[aiMsgIndex] = initialAiMessage.copyWith(
            text: finalText,
            sources: getSources(),
            suggestedFollowups: getFollowups().isNotEmpty
                ? getFollowups()
                : suggestedPrompts,
            disclaimer: getDisclaimer(),
            isStreaming: false,
          );
        }
        _scrollToBottom();
      }
    });
  }

  /// Sends a user question to the AI assistant with real-time SSE streaming (<400ms TTFT)
  Future<void> sendMessage([String? explicitText]) async {
    final query = (explicitText ?? textController.text).trim();
    if (query.isEmpty || isLoading.value) return;

    if (query.length > 600) {
      AppSnackbar.warning('Question exceeds the 600-character limit.');
      return;
    }

    if (isSuspended.value) {
      AppSnackbar.warning(
        suspensionNotice.value.isNotEmpty
            ? suspensionNotice.value
            : 'Ask AI is temporarily restricted for your account.',
      );
      return;
    }

    textController.clear();
    messages.add(
      CredibilityChatMessage.user(
        query,
        scope: scope.value,
        claimIndex: currentClaimIndex.value,
      ),
    );

    // Create the active streaming AI message bubble immediately
    final initialAiMessage = CredibilityChatMessage.ai(
      text: '',
      scope: scope.value,
      claimIndex: currentClaimIndex.value,
      isStreaming: true,
    );
    messages.add(initialAiMessage);
    final aiMsgIndex = messages.length - 1;

    isLoading.value = true;
    _isNetworkStreamDone = false;
    _tokenQueue.clear();
    _visibleTextBuffer.clear();
    _startCursorTimer();
    _scrollToBottom();

    _streamSubscription?.cancel();
    var receivedSources = <UISource>[];
    var receivedFollowups = <String>[];
    String? receivedDisclaimer;

    _startTypewriterTimer(
      aiMsgIndex: aiMsgIndex,
      initialAiMessage: initialAiMessage,
      getSources: () => receivedSources,
      getFollowups: () => receivedFollowups,
      getDisclaimer: () => receivedDisclaimer,
    );

    try {
      _streamSubscription = AiCredibilityChatService.instance
          .streamCredibilityAi(
            videoId: videoId.value,
            userQuery: query,
            scope: scope.value,
            claimIndex: currentClaimIndex.value,
            claimText: claimText.value.isNotEmpty ? claimText.value : null,
            verdict: claimVerdict.value.isNotEmpty ? claimVerdict.value : null,
            history: messages.take(messages.length - 2).toList(),
            cachedSources: cachedSources.toList(),
            cachedClaims: cachedClaims.toList(),
            videoTitle: videoTitle.value.isNotEmpty ? videoTitle.value : null,
            videoCategory: videoCategory.value.isNotEmpty ? videoCategory.value : null,
            videoSummary: videoSummary.value.isNotEmpty ? videoSummary.value : null,
            claimExplanation: claimExplanation.value.isNotEmpty ? claimExplanation.value : null,
            playbackSec: playbackSec.value,
            transcriptSnippet: transcriptSnippet.value.isNotEmpty ? transcriptSnippet.value : null,
            activeChapterTitle: activeChapterTitle.value.isNotEmpty ? activeChapterTitle.value : null,
          )
          .listen(
            (event) {
              if (event.error != null) {
                _enqueueDelta(event.error!);
                _isNetworkStreamDone = true;
                return;
              }

              if (event.sources != null && event.sources!.isNotEmpty) {
                receivedSources = event.sources!;
                final domains = receivedSources
                    .map((s) => s.domain ?? SourceAvatarService.cleanDomain(s.url))
                    .where((d) => d.isNotEmpty)
                    .toSet()
                    .toList();
                SourceAvatarService.fetchAvatarsFromBackend(domains: domains);
              }

              if (event.suggestedFollowups != null && event.suggestedFollowups!.isNotEmpty) {
                receivedFollowups = event.suggestedFollowups!;
                suggestedPrompts.assignAll(receivedFollowups);
              }

              if (event.disclaimer != null) {
                receivedDisclaimer = event.disclaimer;
              }

              if (event.textDelta != null && event.textDelta!.isNotEmpty) {
                _enqueueDelta(event.textDelta!);
              }

              if (event.isDone) {
                _isNetworkStreamDone = true;
              }
            },
            onError: (e, s) {
              ErrorHandler.log(e, stackTrace: s, tag: 'AiCredibilityChatController.sendMessage');
              if (_visibleTextBuffer.isEmpty && _tokenQueue.isEmpty) {
                _enqueueDelta(
                  'The credibility analysis is currently available through verified records. You can check the sources or ask about specific claims.',
                );
              }
              _isNetworkStreamDone = true;
            },
            onDone: () {
              _isNetworkStreamDone = true;
            },
          );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AiCredibilityChatController.sendMessage.catch');
      if (_visibleTextBuffer.isEmpty && _tokenQueue.isEmpty) {
        _enqueueDelta(
          'The credibility analysis is currently available through verified records. You can check the sources or ask about specific claims.',
        );
      }
      _isNetworkStreamDone = true;
    }
  }

  void _scheduleScrollToBottom() {
    if (_scrollThrottleTimer?.isActive ?? false) return;
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 60), _scrollToBottom);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void clearChat() {
    _streamSubscription?.cancel();
    _scrollThrottleTimer?.cancel();
    _stopCursorTimer();
    _stopTypewriterTimer();
    isLoading.value = false;
    messages.clear();
    initScope(
      targetVideoId: videoId.value,
      targetScope: scope.value,
      targetClaimIndex: currentClaimIndex.value,
      targetClaimText: claimText.value,
      targetVerdict: claimVerdict.value,
      title: videoTitle.value,
      allSources: cachedSources.toList(),
      allClaims: cachedClaims.toList(),
      summary: videoSummary.value,
      claimExplanation: claimExplanation.value,
    );
  }
}
