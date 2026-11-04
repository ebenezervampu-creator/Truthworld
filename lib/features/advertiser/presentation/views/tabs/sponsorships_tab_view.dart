import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Creator Sponsorship Marketplace tab for Truthworld Advertiser Studio.
class SponsorshipsTabView extends StatelessWidget {
  const SponsorshipsTabView({required this.controller, super.key});

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
          _buildHeader(),
          const SizedBox(height: 20),
          _buildActiveProposalsTray(context),
          const SizedBox(height: 24),
          _buildCategoryAndSearchBar(searchQuery),
          const SizedBox(height: 20),
          _buildCreatorsGrid(context, searchQuery),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Creator Sponsorship Marketplace',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Directly sponsor top verified Truthworld creators with integrated escrow and milestone protection.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveProposalsTray(BuildContext context) {
    return Obx(() {
      final proposals = controller.sponsorshipProposals;
      if (proposals.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.appBarSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.handshake_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Your Active Sponsorship Proposals',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${proposals.length} In Pipeline',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: proposals.map((prop) {
                final isAccepted = prop['status'] == 'Accepted';
                final amount = (prop['offeredAmount'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bgSurface),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_pin_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prop['creatorName'] as String? ?? '',
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${prop['format']} • ${prop['campaignTitle']}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAccepted
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              prop['status'] as String? ?? '',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAccepted ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      if (!isAccepted)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          tooltip: 'Retract Proposal',
                          onPressed: () {
                            controller.cancelProposal(prop['id'] as String);
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                          tooltip: 'View Placement',
                          onPressed: () {
                            AppSnackbar.show(
                              'Live Sponsored Video',
                              'Deliverable link: ${prop['deliverableUrl']}',
                              backgroundColor: AppColors.info,
                              colorText: AppColors.textPrimary,
                            );
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCategoryAndSearchBar(RxString searchQuery) {
    final categories = [
      'All',
      ...AppCategories.allCategories,
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() {
              final selCat = controller.selectedSponsorshipCategory.value;
              return Row(
                children: categories.map((cat) {
                  final isSelected = selCat == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.bgSurface,
                      side: BorderSide(
                        color: isSelected ? AppColors.brand : AppColors.bgElevated,
                      ),
                      onSelected: (_) {
                        controller.selectedSponsorshipCategory.value = cat;
                      },
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 240,
          child: TextField(
            maxLength: defaultMaxSearchLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
            onChanged: (val) => searchQuery.value = val.toLowerCase(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Search creator or handle...',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white, size: 18),
              isDense: true,
              filled: true,
              fillColor: AppColors.appBarSurface,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.bgSurface),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorsGrid(BuildContext context, RxString searchQuery) {
    return Obx(() {
      final selectedCategory = controller.selectedSponsorshipCategory.value;
      final query = searchQuery.value;

      final filtered = controller.creatorsList.where((creator) {
        final rawCat = creator['category'] as String? ?? '';
        final creatorCat = AppCategories.normalizeCategory(rawCat).toLowerCase();
        final matchesCat = selectedCategory == 'All' ||
            creatorCat == selectedCategory.toLowerCase() ||
            rawCat.toLowerCase() == selectedCategory.toLowerCase();
        final name = (creator['name'] as String? ?? '').toLowerCase();
        final handle = (creator['handle'] as String? ?? '').toLowerCase();
        final matchesQuery = query.isEmpty || name.contains(query) || handle.contains(query);
        return matchesCat && matchesQuery;
      }).toList();

      if (filtered.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No creators matched the selected category and search.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      }

      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: filtered.map((creator) {
          final packages = (creator['packages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final avatarColor = creator['avatarColor'] is int
              ? Color(creator['avatarColor'] as int)
              : AppColors.info;

          return Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.appBarSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarColor,
                      child: Text(
                        (creator['name'] as String).substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  creator['name'] as String,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (creator['isTrusted'] == true) ...[
                                const SizedBox(width: 4),
                                const ChannelVerifiedBadge(size: 14),
                              ],
                            ],
                          ),
                          Text(
                            creator['handle'] as String,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        creator['category'] as String,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  creator['bio'] as String,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bgSurface),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricCol('Subscribers', creator['subscribers'] as String),
                      Container(width: 1, height: 24, color: AppColors.bgSurface),
                      _buildMetricCol('Avg Views', creator['avgViews'] as String),
                      Container(width: 1, height: 24, color: AppColors.bgSurface),
                      _buildMetricCol('Engage Rate', creator['engagement'] as String),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Sponsorship Packages:',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Column(
                  children: packages.take(2).map((pkg) {
                    final price = (pkg['price'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            pkg['type'] as String,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showProposalDialog(context, creator),
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                    label: const Text(
                      'Sponsor Creator',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
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

  void _showProposalDialog(BuildContext context, Map<String, dynamic> creator) {
    final campaignController = TextEditingController(text: 'Truthworld Next Generation');
    final packages = (creator['packages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final selectedFormat = (packages.isNotEmpty ? packages.first['type'] as String : '15s Mid-roll Sponsor').obs;
    final initialPrice = (packages.isNotEmpty ? (packages.first['price'] as num).toDouble() : 3000.0);
    final amountController = TextEditingController(text: initialPrice.toStringAsFixed(0));
    final noteController = TextEditingController(text: 'We would love to feature our product in your next upcoming video.');

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.appBarSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgSurface),
        ),
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Sponsor ${creator['name']}',
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: campaignController,
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Campaign / Product Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sponsorship Format',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                return DropdownButtonFormField<String>(
                  value: selectedFormat.value,
                  dropdownColor: AppColors.bgSurface,
                  style: const TextStyle(color: Colors.white, fontFamily: TWTypography.uiFamily),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  items: packages.map((pkg) {
                    final t = pkg['type'] as String;
                    return DropdownMenuItem<String>(
                      value: t,
                      child: Text('$t (Base ₹${(pkg['price'] as num).toStringAsFixed(0)})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedFormat.value = val;
                      final match = packages.firstWhereOrNull((p) => p['type'] == val);
                      if (match != null) {
                        amountController.text = (match['price'] as num).toStringAsFixed(0);
                      }
                    }
                  },
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Offer Amount (₹)',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: Colors.white),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: 500,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(500),
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Pitch / Briefing Note for Creator',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escrow Protection: Payment is locked and only released when the creator publishes and verifies your deliverable link.',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
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
              final campaign = campaignController.text.trim();
              if (campaign.isEmpty) {
                AppSnackbar.warning('Please enter a campaign name.');
                return;
              }
              final campVal = ContentValidator.validate(campaign, fieldName: 'Campaign Name');
              if (!campVal.isValid) {
                AppSnackbar.warning(campVal.message);
                return;
              }
              final note = noteController.text.trim();
              if (note.isNotEmpty) {
                final noteVal = ContentValidator.validate(note, fieldName: 'Pitch Note');
                if (!noteVal.isValid) {
                  AppSnackbar.warning(noteVal.message);
                  return;
                }
              }
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amt <= 0) {
                AppSnackbar.warning('Please enter a valid offer amount.');
                return;
              }
              controller.sendSponsorshipProposal({
                'id': 'prop_${DateTime.now().millisecondsSinceEpoch}',
                'creatorId': creator['id'],
                'creatorName': creator['name'],
                'campaignTitle': campaign,
                'format': selectedFormat.value,
                'offeredAmount': amt,
                'pitchNote': note,
                'date': 'Today',
                'status': 'Under Review',
                'deliverableUrl': '',
              });
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Send Proposal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
