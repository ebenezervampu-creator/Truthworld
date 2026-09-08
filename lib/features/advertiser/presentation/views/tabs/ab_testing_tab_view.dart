import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// A/B Testing & Multivariate Optimization tab for Truthworld Advertiser Studio.
class AbTestingTabView extends StatelessWidget {
  const AbTestingTabView({required this.controller, super.key});

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildExperimentsList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A/B Testing & Multivariate Optimization',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Split traffic dynamically to test headlines, CTAs, and video bumpers with statistical certainty.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateExperimentDialog(context),
          icon: const Icon(
            Icons.science_rounded,
            color: Colors.white,
            size: 18,
          ),
          label: const Text(
            'New A/B Test',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Obx(() {
      final tests = controller.abExperimentsList;
      final running = tests.where((t) => t['status'] == 'Running').length;
      final concluded = tests.where((t) => t['status'] == 'Concluded').length;

      return Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'Active Experiments',
              value: '$running Running',
              subtitle: 'Splitting live traffic',
              icon: Icons.alt_route_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              title: 'Concluded Tests',
              value: '$concluded Finalized',
              subtitle: 'Winners applied',
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              title: 'Average CTR Uplift',
              value: '+36.5%',
              subtitle: 'Over single-variant baseline',
              icon: Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              title: 'Statistical Confidence',
              value: '95%+ Threshold',
              subtitle: 'Industry gold standard',
              icon: Icons.insights_rounded,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentsList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Experiments & Multivariate Tests',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final experiments = controller.abExperimentsList;
            if (experiments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No experiments launched yet. Create an A/B test to optimize campaigns.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return Column(
              children: experiments.map((exp) {
                final isRunning = exp['status'] == 'Running';
                final variantA = exp['variantA'] as Map<String, dynamic>;
                final variantB = exp['variantB'] as Map<String, dynamic>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRunning ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFF27272A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.science_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp['title'] as String? ?? '',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${exp['campaign']} • Variable: ${exp['variable']}',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRunning
                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                  : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exp['status'] as String? ?? '',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isRunning ? const Color(0xFF60A5FA) : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Variant comparison row
                      Row(
                        children: [
                          Expanded(
                            child: _buildVariantBox(
                              label: variantA['label'] as String,
                              value: variantA['value'] as String,
                              impressions: variantA['impressions'] as int,
                              clicks: variantA['clicks'] as int,
                              ctr: (variantA['ctr'] as num).toDouble(),
                              conversions: variantA['conversions'] as int,
                              isLeading: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildVariantBox(
                              label: variantB['label'] as String,
                              value: variantB['value'] as String,
                              impressions: variantB['impressions'] as int,
                              clicks: variantB['clicks'] as int,
                              ctr: (variantB['ctr'] as num).toDouble(),
                              conversions: variantB['conversions'] as int,
                              isLeading: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Result and Confidence banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2E2E34)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Result: ${exp['winner']} • ${exp['confidence']}',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isRunning)
                              ElevatedButton(
                                onPressed: () {
                                  controller.declareExperimentWinner(
                                    exp['id'] as String,
                                    variantB['label'] as String,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                child: const Text(
                                  'Declare Winner & Scale',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVariantBox({
    required String label,
    required String value,
    required int impressions,
    required int clicks,
    required double ctr,
    required int conversions,
    required bool isLeading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeading ? AppColors.brand.withValues(alpha: 0.6) : const Color(0xFF2E2E34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              if (isLeading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LEADER',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"$value"',
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Impressions', impressions.toString()),
              _buildMiniMetric('Clicks', clicks.toString()),
              _buildMiniMetric('CTR', '${ctr.toStringAsFixed(2)}%'),
              _buildMiniMetric('Conv', conversions.toString()),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (ctr / 10).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFF27272A),
              valueColor: AlwaysStoppedAnimation<Color>(
                isLeading ? AppColors.brand : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showCreateExperimentDialog(BuildContext context) {
    final titleController = TextEditingController();
    final campaignController = TextEditingController(text: 'Truthworld Next Generation');
    final variableChoice = 'CTA Button'.obs;
    final variantAController = TextEditingController(text: 'Learn More');
    final variantBController = TextEditingController(text: 'Join The Movement Now');

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Launch A/B Multivariate Test',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Experiment Name (e.g. CTA Button Urgency Test)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: campaignController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Target Campaign',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                return DropdownButtonFormField<String>(
                  value: variableChoice.value,
                  dropdownColor: const Color(0xFF1C1C1F),
                  style: const TextStyle(color: Colors.white, fontFamily: TWTypography.uiFamily),
                  decoration: const InputDecoration(
                    labelText: 'Tested Variable',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  items: ['CTA Button', 'Headline', 'Video Creative', 'Audience Persona'].map((v) {
                    return DropdownMenuItem<String>(value: v, child: Text(v));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) variableChoice.value = val;
                  },
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: variantAController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Variant A (Control)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: variantBController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Variant B (Challenger)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                controller.createAbExperiment({
                  'id': 'exp_${DateTime.now().millisecondsSinceEpoch}',
                  'title': title,
                  'campaign': campaignController.text.trim(),
                  'variable': variableChoice.value,
                  'status': 'Running',
                  'trafficSplit': '50% / 50%',
                  'startDate': 'Today',
                  'variantA': {
                    'label': 'Variant A (Control)',
                    'value': variantAController.text.trim(),
                    'impressions': 0,
                    'clicks': 0,
                    'ctr': 0.0,
                    'conversions': 0,
                  },
                  'variantB': {
                    'label': 'Variant B (Challenger)',
                    'value': variantBController.text.trim(),
                    'impressions': 0,
                    'clicks': 0,
                    'ctr': 0.0,
                    'conversions': 0,
                  },
                  'winner': 'Collecting traffic...',
                  'confidence': 'Awaiting sample size',
                });
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Launch Experiment', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
