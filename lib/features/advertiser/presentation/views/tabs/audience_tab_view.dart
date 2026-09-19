import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Audience & Geo-Targeting Presets tab for Truthworld Advertiser Studio.
class AudienceTabView extends StatelessWidget {
  const AudienceTabView({required this.controller, super.key});

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
          _buildGeoDistributionSimulator(),
          const SizedBox(height: 24),
          _buildPresetsList(context),
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
              'Audience & Geo-Targeting',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create reusable targeting personas and analyze viewer geographic distributions.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreatePresetDialog(context),
          icon: const Icon(
            Icons.add_rounded,
            color: Colors.black,
            size: 18,
          ),
          label: const Text(
            'New Preset',
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
      final totalPresets = controller.audiencePresets.length;
      return Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'Saved Personas',
              value: '$totalPresets Presets',
              subtitle: 'Ready for campaign launch',
              icon: Icons.groups_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              title: 'Global Addressable Reach',
              value: '12.5M Viewers',
              subtitle: 'Active Truthworld watchers',
              icon: Icons.public_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              title: 'Top Regional Density',
              value: 'South Asia & US',
              subtitle: '76% of high-intent traffic',
              icon: Icons.travel_explore_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              title: 'Human Verified Index',
              value: '99.8%',
              subtitle: 'Bot-free ad delivery',
              icon: Icons.verified_user_rounded,
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

  Widget _buildGeoDistributionSimulator() {
    final regions = [
      {'name': 'India & South Asia', 'share': 0.54, 'pct': '54%'},
      {'name': 'United States & Canada', 'share': 0.22, 'pct': '22%'},
      {'name': 'Middle East & UAE', 'share': 0.14, 'pct': '14%'},
      {'name': 'United Kingdom & Europe', 'share': 0.10, 'pct': '10%'},
    ];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Geo-Distribution Simulator',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.radar_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'AI Audience Clustering Active',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: regions.map((reg) {
              final share = reg['share']! as double;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          reg['name']! as String,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          reg['pct']! as String,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF27272A),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsList(BuildContext context) {
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
            'Active Targeting Presets',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final presets = controller.audiencePresets;
            if (presets.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No audience personas defined yet. Click "+ New Preset" to create one.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return Column(
              children: presets.map((preset) {
                final locations = (preset['locations'] as List<dynamic>?)?.cast<String>() ?? [];
                final interests = (preset['interests'] as List<dynamic>?)?.cast<String>() ?? [];
                final genders = (preset['genders'] as List<dynamic>?)?.cast<String>() ?? ['All'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF27272A)),
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
                                  color: const Color(0xFF27272A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                preset['name'] as String? ?? 'Untitled Persona',
                                style: const TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Reach: ${preset['estimatedReach']}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.badge_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Age: ${preset['ageMin']} - ${preset['ageMax']} yrs  •  Gender: ${genders.join(', ')}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: locations.map((loc) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E22),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF323238)),
                                  ),
                                  child: Text(
                                    loc,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.interests_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: interests.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E22),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF323238)),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF27272A), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              AppSnackbar.show(
                                'Preset Applied',
                                'Persona "${preset['name']}" attached to active ad campaigns.',
                                backgroundColor: AppColors.success,
                                colorText: AppColors.textPrimary,
                              );
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text(
                              'Apply to Campaigns',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            tooltip: 'Delete Preset',
                            onPressed: () {
                              controller.deleteAudiencePreset(preset['id'] as String);
                            },
                          ),
                        ],
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

  void _showCreatePresetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final minAgeController = TextEditingController(text: '18');
    final maxAgeController = TextEditingController(text: '35');
    final locationsController = TextEditingController(text: 'India, United States, UAE');
    final interestsController = TextEditingController(text: 'Technology, AI, Video Production');

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Create Audience Preset',
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
            children: [
              TextField(
                controller: nameController,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Preset Name (e.g. AI & Tech Founders)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minAgeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Min Age',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: Color(0xFF121214),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxAgeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Max Age',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: Color(0xFF121214),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationsController,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Target Locations (comma separated)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: interestsController,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Target Interests / Topics (comma separated)',
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                AppSnackbar.warning('Please enter a preset name.');
                return;
              }
              final nameVal = ContentValidator.validate(name, checkEnglishOnly: false, fieldName: 'Preset Name');
              if (!nameVal.isValid) {
                AppSnackbar.warning(nameVal.message);
                return;
              }
              final locText = locationsController.text.trim();
              if (locText.isNotEmpty) {
                final locVal = ContentValidator.validate(locText, checkEnglishOnly: false, fieldName: 'Locations');
                if (!locVal.isValid) {
                  AppSnackbar.warning(locVal.message);
                  return;
                }
              }
              final intText = interestsController.text.trim();
              if (intText.isNotEmpty) {
                final intVal = ContentValidator.validate(intText, checkEnglishOnly: false, fieldName: 'Interests');
                if (!intVal.isValid) {
                  AppSnackbar.warning(intVal.message);
                  return;
                }
              }
              final locs = locationsController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              final ints = interestsController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

              controller.createAudiencePreset({
                'id': 'aud_${DateTime.now().millisecondsSinceEpoch}',
                'name': name,
                'ageMin': int.tryParse(minAgeController.text) ?? 18,
                'ageMax': int.tryParse(maxAgeController.text) ?? 35,
                'genders': ['All'],
                'locations': locs.isEmpty ? ['Global'] : locs,
                'interests': ints.isEmpty ? ['General'] : ints,
                'estimatedReach': '3.1M Viewers',
              });
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Preset', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
