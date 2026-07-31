import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/pipeline_config.dart';
import 'package:truthworld/features/video/presentation/controllers/pipeline_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Pipeline Configuration Widget
/// Allows users to select and configure pipeline features
class PipelineConfigurationWidget extends StatefulWidget {
  const PipelineConfigurationWidget({
    required this.videoTitle,
    required this.videoDescription,
    required this.videoDuration,
    required this.videoCategory,
    required this.channelId,
    super.key,
    this.onConfigChanged,
  });
  final String videoTitle;
  final String videoDescription;
  final String videoDuration;
  final String videoCategory;
  final String channelId;
  final VoidCallback? onConfigChanged;

  @override
  State<PipelineConfigurationWidget> createState() =>
      _PipelineConfigurationWidgetState();
}

class _PipelineConfigurationWidgetState
    extends State<PipelineConfigurationWidget>
    with TickerProviderStateMixin {
  late PipelineController controller;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<PipelineController>();
    tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Template Selector
        _buildTemplateSelector(),
        const SizedBox(height: 24),

        // Configuration Tabs
        _buildTabs(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TEMPLATE SELECTOR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start Templates',
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: controller.getTemplates().length,
            itemBuilder: (context, index) {
              final template = controller.getTemplates()[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildTemplateCard(template),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return InkWell(
      onTap: () {
        controller.loadTemplate(
          template['id'].toString(),
          videoTitle: widget.videoTitle,
          videoDescription: widget.videoDescription,
          videoDuration: widget.videoDuration,
          videoCategory: widget.videoCategory,
          channelId: widget.channelId,
        );
        widget.onConfigChanged?.call();
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgDivider),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (template['icon'] as String?) ?? '',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                (template['name'] as String?) ?? '',
                style: AppTextStyles.videoTitleSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '${template['tier']} Tier',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION TABS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabs() {
    return Column(
      children: [
        ColoredBox(
          color: AppColors.textSecondary,
          child: TabBar(
            controller: tabController,
            tabs: const [
              Tab(text: 'Dubbing'),
              Tab(text: 'Credibility'),
              Tab(text: 'Auxiliary'),
              Tab(text: 'Summary'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 500,
          child: TabBarView(
            controller: tabController,
            children: [
              _buildDubbingTab(),
              _buildCredibilityTab(),
              _buildAuxiliaryTab(),
              _buildSummaryTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── DUBBING TAB ───

  Widget _buildDubbingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable Path 2 Toggle
          Obx(
            () => SwitchListTile(
              title: const Text('Enable Dubbing & Translation'),
              subtitle: const Text('Path 2: Multi-language audio output'),
              value: controller.enablePath2.value,
              onChanged: (value) {
                controller.enablePath2.value = value;
                widget.onConfigChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),

          // Language Selection
          if (controller.enablePath2.value) ...[
            Text(
              'Select Languages for Dubbing',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.supportedLanguages.entries
                  .map(
                    (e) => _buildLanguageChip(e.key, e.value, isDubbing: true),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Subtitle Languages
          Text(
            'Select Languages for Subtitles',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.supportedLanguages.entries
                .map(
                  (e) => _buildLanguageChip(e.key, e.value),
                )
                .toList(),
          ),
          const SizedBox(height: 24),

          // Voice Type Selection
          if (controller.enablePath2.value) ...[
            Text(
              'Voice Type',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            Obx(
              () => RadioGroup<String>(
                groupValue: controller.voiceType.value,
                onChanged: (value) {
                  controller.voiceType.value = value ?? 'natural';
                  widget.onConfigChanged?.call();
                },
                child: Column(
                  children: ['natural', 'standard', 'premium']
                      .map(
                        (type) => RadioListTile<String>(
                          title: Text(
                            '${type[0].toUpperCase()}${type.substring(1)}',
                          ),
                          value: type,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],

          // TTS Speed Slider
          if (controller.enablePath2.value) ...[
            const SizedBox(height: 24),
            Text(
              'Dubbing Speed',
              style: AppTextStyles.titleMedium,
            ),
            Obx(
              () => Slider(
                value: controller.ttsSpeed.value,
                min: 0.8,
                max: 1.2,
                divisions: 8,
                label: '${controller.ttsSpeed.value.toStringAsFixed(1)}x',
                onChanged: (value) {
                  controller.ttsSpeed.value = value;
                  widget.onConfigChanged?.call();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── CREDIBILITY TAB ───

  Widget _buildCredibilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable Path 1
          Obx(
            () => SwitchListTile(
              title: const Text('Enable Credibility Analysis'),
              subtitle: const Text(
                'Path 1: Fact-checking & claim verification',
              ),
              value: controller.enablePath1.value,
              onChanged: (value) {
                controller.enablePath1.value = value;
                widget.onConfigChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),

          if (controller.enablePath1.value) ...[
            // Enable Fact-Check
            Obx(
              () => SwitchListTile(
                title: const Text('Enable Fact-Checking'),
                value: controller.enableFactCheck.value,
                onChanged: (value) {
                  controller.enableFactCheck.value = value;
                  widget.onConfigChanged?.call();
                },
              ),
            ),
            const SizedBox(height: 16),

            if (controller.enableFactCheck.value) ...[
              // Scoring Method
              Text(
                'Scoring Method',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 12),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: ['strict', 'balanced', 'lenient']
                      .map(
                        (method) => ChoiceChip(
                          label: Text(
                            '${method[0].toUpperCase()}${method.substring(1)}',
                          ),
                          selected: controller.factCheckScoring.value == method,
                          onSelected: (selected) {
                            if (selected) {
                              controller.factCheckScoring.value = method;
                              widget.onConfigChanged?.call();
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Confidence Threshold
              Text(
                'Confidence Threshold',
                style: AppTextStyles.titleMedium,
              ),
              Obx(
                () => Slider(
                  value: controller.confidenceThreshold.value,
                  divisions: 10,
                  label:
                      '${(controller.confidenceThreshold.value * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    controller.confidenceThreshold.value = value;
                    widget.onConfigChanged?.call();
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Explainability
              Obx(
                () => SwitchListTile(
                  title: const Text('Enable Explainability'),
                  subtitle: const Text(
                    'Detailed claim analysis with explanations',
                  ),
                  value: controller.enableExplainability.value,
                  onChanged: (value) {
                    controller.enableExplainability.value = value;
                    widget.onConfigChanged?.call();
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── AUXILIARY TAB ───

  Widget _buildAuxiliaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => SwitchListTile(
              title: const Text('Enable OCR'),
              subtitle: const Text('Optical Character Recognition from video'),
              value: controller.enableOCR.value,
              onChanged: (value) {
                controller.enableOCR.value = value;
                widget.onConfigChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => SwitchListTile(
              title: const Text('Enable Visual Context'),
              subtitle: const Text('Extract scene and object information'),
              value: controller.enableVisualContext.value,
              onChanged: (value) {
                controller.enableVisualContext.value = value;
                widget.onConfigChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => SwitchListTile(
              title: const Text('Enable Audio Enhancement'),
              subtitle: const Text('Improve audio quality and clarity'),
              value: controller.enableAudioEnhancement.value,
              onChanged: (value) {
                controller.enableAudioEnhancement.value = value;
                widget.onConfigChanged?.call();
              },
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => SwitchListTile(
              title: const Text('Enable Auto Chapters'),
              subtitle: const Text('Automatically segment video into chapters'),
              value: controller.enableChapters.value,
              onChanged: (value) {
                controller.enableChapters.value = value;
                widget.onConfigChanged?.call();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── SUMMARY TAB ───

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard('Selected Features', _buildFeaturesList()),
          const SizedBox(height: 24),
          _buildSummaryCard('Cost Analysis', _buildCostBreakdown()),
          const SizedBox(height: 24),
          _buildSummaryCard('Usage & Limits', _buildUsageSummary()),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.bgDivider),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.enablePath1.value)
            _buildFeatureItem(
              '✓',
              'Path 1: Credibility Analysis',
            ),
          if (!controller.enablePath1.value && !controller.enablePath2.value)
            _buildFeatureItem('✓', 'Path 0: Transcription Only'),
          if (controller.enablePath2.value)
            _buildFeatureItem('✓', 'Path 2: Dubbing'),
          if (controller.enableFactCheck.value)
            _buildFeatureItem('✓', 'Fact-Checking'),
          if (controller.enableOCR.value) _buildFeatureItem('✓', 'OCR'),
          if (controller.enableVisualContext.value)
            _buildFeatureItem('✓', 'Visual Context'),
          if (controller.enableAudioEnhancement.value)
            _buildFeatureItem('✓', 'Audio Enhancement'),
          if (controller.enableChapters.value)
            _buildFeatureItem('✓', 'Auto Chapters'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Text(icon), const SizedBox(width: 8), Text(label)]),
    );
  }

  Widget _buildCostBreakdown() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCostLine(
            'Tier',
            '${controller.userTier.value['tier'] ?? 'free'}',
          ),
          const SizedBox(height: 8),
          _buildCostLine(
            'Estimated Cost',
            '\$${_estimateCost().toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _buildCostLine(
            'Remaining Budget',
            '\$${controller.remainingBudget.value.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSummary() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUsageLine(
            'This Month',
            '${controller.userTier.value['monthlyUsage'] ?? 0} videos',
          ),
          const SizedBox(height: 8),
          _buildUsageLine(
            'Monthly Limit',
            '${controller.userTier.value['monthlyLimit'] ?? 100} videos',
          ),
        ],
      ),
    );
  }

  Widget _buildCostLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildUsageLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    );
  }

  Widget _buildLanguageChip(
    String code,
    String name, {
    bool isDubbing = false,
  }) {
    late RxList<String> selectedList;
    if (isDubbing) {
      selectedList = controller.selectedDubbingLanguages;
    } else {
      selectedList = controller.selectedSubtitleLanguages;
    }

    return Obx(
      () => FilterChip(
        label: Text(name),
        selected: selectedList.contains(code),
        onSelected: (selected) {
          if (isDubbing) {
            controller.toggleDubbingLanguage(code);
          } else {
            controller.toggleSubtitleLanguage(code);
          }
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  double _estimateCost() {
    try {
      final videoDurationSeconds = int.tryParse(widget.videoDuration) ?? 0;
      return PipelineConfig.calculateCost(
        tier: (controller.userTier.value['tier'] as String?) ?? 'free',
        enablePath1: controller.enablePath1.value,
        enablePath2: controller.enablePath2.value,
        dubbingLanguageCount: controller.selectedDubbingLanguages.length,
        enableFactCheck: controller.enableFactCheck.value,
        enableSubtitles: controller.selectedSubtitleLanguages.isNotEmpty,
        videoDuration: videoDurationSeconds.toString(),
      );
    } catch (e) {
      return 0;
    }
  }
}
