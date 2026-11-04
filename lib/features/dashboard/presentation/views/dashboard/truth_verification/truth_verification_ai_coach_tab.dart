import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Embedded interactive Ask AI Truth Coach Tab.
///
/// Designed to match the exact Channel Creation page theme:
/// - AppColors.appBarSurface card background, AppColors.bgSurface borders, AppColors.bgInput inputs/canvases
/// - Minimalist, simple and clean typography (no discordant font families or blue/indigo tints)
/// - High contrast (strictly black on white for user messages and buttons)
/// - Zero setState policy via GetX reactive state
class TruthVerificationAiCoachTab extends StatelessWidget {
  TruthVerificationAiCoachTab({
    required this.channelId,
    required this.allClaims,
    required this.videos,
    required this.isDarkMode,
    super.key,
  }) {
    // Seed initial welcome message if empty
    if (_messages.isEmpty) {
      _messages.add(
        _CoachMessage(
          isUser: false,
          text:
              'Hello Creator! I am your Truth Intelligence Coach. I can help you understand why claims were flagged, recommend institutional sources for your video topics, or explain how to maximize your channel\'s TruthScore and algorithmic reach. What can I assist you with today?',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  final String channelId;
  final List<RealExtractedClaim> allClaims;
  final List<VideoFactCheckItem> videos;
  final bool isDarkMode;

  final TextEditingController _inputController = TextEditingController();
  final RxList<_CoachMessage> _messages = <_CoachMessage>[].obs;
  final RxBool _isThinking = false.obs;

  void _handleSend([String? presetText]) {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty || _isThinking.value) return;

    if (presetText == null) {
      _inputController.clear();
    }

    _messages.add(
      _CoachMessage(
        isUser: true,
        text: text,
        timestamp: DateTime.now(),
      ),
    );

    _isThinking.value = true;

    // Simulate intelligent coach synthesis grounded in channel context
    Future.delayed(const Duration(milliseconds: 650), () {
      final reply = _generateCoachResponse(text);
      _messages.add(
        _CoachMessage(
          isUser: false,
          text: reply,
          timestamp: DateTime.now(),
        ),
      );
      _isThinking.value = false;
    });
  }

  String _generateCoachResponse(String prompt) {
    final q = prompt.toLowerCase();
    final verifiedCount = allClaims.where((c) => c.isVerified).length;
    final cautionCount = allClaims.where((c) => c.isNeedsSource).length;

    if (q.contains('caution') || q.contains('needs evidence') || q.contains('turn caution')) {
      if (cautionCount == 0) {
        return 'Great news! Your channel currently has 0 claims in the "Needs Evidence" tier. All evaluated assertions are either fully verified or subjective opinions. To maintain this status on future uploads, always include direct citations in your video description or on-screen graphics.';
      }
      return 'You currently have $cautionCount assertion${cautionCount == 1 ? '' : 's'} flagged for caution. To elevate them to verified status:\n\n1. Go to the "Fact Claims" tab and tap "Provide Evidence" on the flagged card.\n2. Paste an official external URL from a reputable institutional registry (e.g. government archive, peer-reviewed journal, or wire agency).\n3. Our AI Credibility Engine will re-scan the source and upgrade the assertion upon positive corroboration.';
    }

    if (q.contains('algorithmic') || q.contains('boost') || q.contains('discovery') || q.contains('reach')) {
      return 'TruthWorld applies an automatic +15% to 20% algorithmic discovery boost to verified creators. This elevates your content on the Home Feed "Unexplored" tab, search rankings, and recommendation carousels. To maintain this boost, keep your channel\'s verified claims ratio above 85% and resolve any high concern flags promptly.';
    }

    if (q.contains('opinion') || q.contains('subjective') || q.contains('belief') || q.contains('prediction')) {
      return 'TruthWorld strictly distinguishes empirical claims from subjective viewpoints! Opinions, philosophical discourse, artistic hyperbole, and speculative predictions are completely excluded from negative score penalties.\n\nTip: Frame subjective ideas with phrases like "In my perspective", "I predict that", or "Philosophically speaking". Our multimodal extractor automatically routes these to the "Opinions & Context" tab without affecting your TruthScore.';
    }

    if (q.contains('source') || q.contains('database') || q.contains('citation') || q.contains('registry')) {
      return 'For the strongest credibility weighting, prioritize Tier 1 Primary Sources:\n\n• Health & Biology: PubMed, NCBI, WHO, CDC, FDA\n• Science & Physics: NIST, CERN, IUPAC, Nature, ScienceDirect\n• Economics & Demographics: World Bank, IMF, Federal Reserve, US Census Bureau\n• History & Law: National Archives, Library of Congress, Supreme Court Opinions\n\nCitations from these repositories receive 98%+ confidence ratings in TruthWorld verification.';
    }

    return 'Based on your channel\'s evaluation ($verifiedCount verified assertions across ${videos.length} videos):\n\nYour factual accuracy stands at ${allClaims.isEmpty ? 100 : ((verifiedCount / allClaims.length) * 100).round()}%. To maintain top standing, make sure all numerical figures have cited sources, review preliminary claims before the 24-hour grace window closes, and dispute any verdicts where new empirical data has surfaced.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clean Header
          _buildCoachHeader(),
          const SizedBox(height: 16),

          // 2. Quick Prompt Chips
          _buildQuickPromptChips(),
          const SizedBox(height: 16),

          // 3. Chat Canvas
          _buildChatContainer(),
          const SizedBox(height: 16),

          // 4. Message Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildCoachHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Truth Intelligence AI Creator Coach',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Interactive verification diagnostics, source discovery & script pre-evaluations.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Online',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPromptChips() {
    final prompts = [
      'How do I turn caution flags into verified claims?',
      'How does TruthScore impact my algorithmic feed placement?',
      'What primary databases are best for scientific claims?',
      'How do I separate personal opinions from factual assertions?',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: prompts.map((p) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _handleSend(p),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatContainer() {
    return Container(
      constraints: const BoxConstraints(minHeight: 280, maxHeight: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Obx(() {
        final msgs = _messages.toList();
        final thinking = _isThinking.value;

        return ListView.separated(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: msgs.length + (thinking ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == msgs.length && thinking) {
              return _buildThinkingBubble();
            }
            final m = msgs[index];
            return _buildMessageBubble(m);
          },
        );
      }),
    );
  }

  Widget _buildMessageBubble(_CoachMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? Colors.white : AppColors.appBarSurface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(10),
              topRight: const Radius.circular(10),
              bottomLeft: isUser ? const Radius.circular(10) : const Radius.circular(2),
              bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(10),
            ),
            border: isUser
                ? null
                : Border.all(color: AppColors.bgSurface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Truth Coach AI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isUser ? Colors.black : Colors.white,
                  fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.appBarSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Consulting epistemic registry...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgSurface),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                hintText: 'Ask about any claim, TruthScore rule, or verification source...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          Obx(() {
            final thinking = _isThinking.value;
            return InkWell(
              onTap: thinking ? null : () => _handleSend(),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: thinking ? AppColors.bgSurface : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: thinking ? AppColors.textTertiary : Colors.black,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CoachMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;

  _CoachMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
  });
}


