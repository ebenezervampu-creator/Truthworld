import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Creative Assets & Media Library tab for Truthworld Advertiser Studio.
class CreativeAssetsTabView extends StatelessWidget {
  const CreativeAssetsTabView({required this.controller, super.key});

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    final searchQuery = ''.obs;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildStorageBar(),
          const SizedBox(height: 24),
          _buildFilterAndSearchBar(searchQuery),
          const SizedBox(height: 20),
          _buildAssetsGrid(context, searchQuery),
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
              'Creative Assets & Media Library',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage 4K video creatives, rich display banners, and official brandmarks.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showUploadAssetDialog(context),
          icon: const Icon(
            Icons.cloud_upload_rounded,
            color: Colors.black,
            size: 18,
          ),
          label: const Text(
            'Upload Asset',
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

  Widget _buildStorageBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cloud Media Storage Allocation',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                '16.8 MB of 10.0 GB used (0.17%)',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.0017,
              minHeight: 6,
              backgroundColor: Color(0xFF27272A),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar(RxString searchQuery) {
    final categories = ['All', 'Video', 'Banner', 'Logo'];

    return Row(
      children: [
        Expanded(
          child: Obx(() {
            final sel = controller.selectedAssetCategory.value;
            return Row(
              children: categories.map((cat) {
                final isSel = sel == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: AppColors.brand,
                    backgroundColor: const Color(0xFF1E1E22),
                    side: BorderSide(
                      color: isSel ? AppColors.brand : const Color(0xFF323238),
                    ),
                    onSelected: (_) {
                      controller.selectedAssetCategory.value = cat;
                    },
                  ),
                );
              }).toList(),
            );
          }),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            maxLength: defaultMaxSearchLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
            onChanged: (val) => searchQuery.value = val.toLowerCase(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Search creative assets...',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white, size: 18),
              isDense: true,
              filled: true,
              fillColor: Color(0xFF161618),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Color(0xFF27272A)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetsGrid(BuildContext context, RxString searchQuery) {
    return Obx(() {
      final selCategory = controller.selectedAssetCategory.value;
      final query = searchQuery.value;

      final filtered = controller.creativeAssetsList.where((asset) {
        final matchesCat = selCategory == 'All' || asset['type'] == selCategory;
        final title = (asset['title'] as String? ?? '').toLowerCase();
        final matchesQuery = query.isEmpty || title.contains(query);
        return matchesCat && matchesQuery;
      }).toList();

      if (filtered.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No creative assets found.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      }

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: filtered.map((asset) {
          final isVideo = asset['type'] == 'Video';
          final isLogo = asset['type'] == 'Logo';

          return Container(
            width: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media preview container
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E22),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        isVideo
                            ? Icons.videocam_rounded
                            : isLogo
                                ? Icons.token_rounded
                                : Icons.image_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            asset['format'] as String? ?? '',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isVideo
                                ? '${asset['duration']} • ${asset['resolution']}'
                                : asset['resolution'] as String? ?? '',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset['title'] as String? ?? '',
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${asset['size']} • ${asset['date']}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${asset['campaignUsage']} campaigns',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF27272A), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.link_rounded, color: Colors.white, size: 18),
                            tooltip: 'Copy Asset URL',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: asset['url'] as String? ?? ''));
                              AppSnackbar.show(
                                'URL Copied',
                                'CDN link copied to clipboard.',
                                backgroundColor: AppColors.success,
                                colorText: AppColors.textPrimary,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                            tooltip: 'Delete Asset',
                            onPressed: () {
                              controller.deleteCreativeAsset(asset['id'] as String);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  void _showUploadAssetDialog(BuildContext context) {
    final titleController = TextEditingController();
    final typeChoice = 'Video'.obs;
    final resController = TextEditingController(text: '1920x1080');
    final durationController = TextEditingController(text: '00:15');
    final urlController = TextEditingController(text: 'https://cdn.truthworld.org/creatives/new_promo.mp4');

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Upload Creative Asset',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Asset Name / Title',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                return DropdownButtonFormField<String>(
                  value: typeChoice.value,
                  dropdownColor: const Color(0xFF1C1C1F),
                  style: const TextStyle(color: Colors.white, fontFamily: TWTypography.uiFamily),
                  decoration: const InputDecoration(
                    labelText: 'Creative Type',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  items: ['Video', 'Banner', 'Logo'].map((t) {
                    return DropdownMenuItem<String>(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      typeChoice.value = val;
                      if (val == 'Video') {
                        resController.text = '1920x1080';
                        durationController.text = '00:15';
                      } else if (val == 'Banner') {
                        resController.text = '1200x628';
                        durationController.text = 'Static';
                      } else {
                        resController.text = '512x512';
                        durationController.text = 'Static';
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: resController,
                      maxLength: 30,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Resolution',
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
                      controller: durationController,
                      maxLength: 30,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Duration',
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
                controller: urlController,
                maxLength: 500,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(500),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Asset CDN / Source URL',
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
              if (title.isEmpty) {
                AppSnackbar.warning('Please enter an asset title.');
                return;
              }
              final val = ContentValidator.validate(title, checkEnglishOnly: false, fieldName: 'Asset Title');
              if (!val.isValid) {
                AppSnackbar.warning(val.message);
                return;
              }
              final type = typeChoice.value;
              controller.addCreativeAsset({
                  'id': 'asset_${DateTime.now().millisecondsSinceEpoch}',
                  'title': title,
                  'type': type,
                  'resolution': resController.text.trim(),
                  'duration': durationController.text.trim(),
                  'format': type == 'Video' ? 'MP4' : (type == 'Logo' ? 'SVG' : 'PNG'),
                  'size': '2.4 MB',
                  'url': urlController.text.trim(),
                  'date': 'Today',
                  'campaignUsage': 0,
                });
                Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Asset', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
