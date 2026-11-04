import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/location_search_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/location_autocomplete_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/wizard/widgets/campaign_wizard_targeting_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceLocationsSection extends StatelessWidget {
  const AudienceLocationsSection({
    required this.targetWorldwide,
    required this.selectedLocations,
    required this.popularLocations,
    required this.customLocationController,
    required this.locController,
    super.key,
  });

  final RxBool targetWorldwide;
  final RxList<String> selectedLocations;
  final List<String> popularLocations;
  final TextEditingController customLocationController;
  final LocationAutocompleteController locController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isWorldwide = targetWorldwide.value;
      return CampaignWizardAudienceSectionCard(
        title: 'Locations & Geography',
        subtitle:
            'Target global audiences or specific countries and cities.',
        icon: Icons.public_rounded,
        isAllSelected: isWorldwide,
        allSelectedLabel: 'Worldwide / All Locations',
        onToggleAll: (val) {
          targetWorldwide.value = val;
          if (val) {
            selectedLocations.clear();
          }
        },
        content: isWorldwide
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Countries:',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: popularLocations.map((loc) {
                      final isSelected = selectedLocations.contains(loc);
                      return FilterChip(
                        label: Text(
                          loc,
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        showCheckmark: isSelected,
                        checkmarkColor: isSelected ? Colors.black : Colors.white,
                        selectedColor: AppColors.brand,
                        backgroundColor: AppColors.bgPage,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.brand
                              : AppColors.bgSurface,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            selectedLocations.add(loc);
                          } else {
                            selectedLocations.remove(loc);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() {
                          final hasText = locController
                              .searchQuery.value.isNotEmpty;
                          final isLoading = locController.isLoading.value;

                          Widget? suffix;
                          if (isLoading) {
                            suffix = const Padding(
                              padding: EdgeInsets.all(11),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    Colors.white70,
                                  ),
                                ),
                              ),
                            );
                          } else if (hasText) {
                            suffix = IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textTertiary,
                                size: 16,
                              ),
                              splashRadius: 16,
                              onPressed: () => locController
                                  .clearSearch(customLocationController),
                            );
                          }

                          return TextField(
                            controller: customLocationController,
                            maxLength: ContentValidator.defaultMaxLocationLength,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: TruthworldTextInputFormatters.withLimit(ContentValidator.defaultMaxLocationLength),
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.textTertiary,
                                size: 18,
                              ),
                              suffixIcon: suffix,
                              hintText:
                                  'Enter city, state or country...',
                              hintStyle: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: AppColors.bgPage,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.bgSurface,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.bgSurface,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            onChanged: locController.onQueryChanged,
                            onSubmitted: (val) =>
                                locController.addCustomLocation(
                              val,
                              selectedLocations,
                              customLocationController,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => locController.addCustomLocation(
                          customLocationController.text,
                          selectedLocations,
                          customLocationController,
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Real Location Autocomplete Dropdown
                  Obx(() {
                    if (!locController.isOpen.value ||
                        locController.searchQuery.value.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final query =
                        locController.searchQuery.value.trim();
                    final suggestions = locController.suggestions;
                    final isLoading = locController.isLoading.value;

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.bgSurface,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: AppColors.bgPage,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.explore_outlined,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    suggestions.isNotEmpty
                                        ? 'Real Locations (${suggestions.length})'
                                        : 'Searching Locations...',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTertiary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isLoading)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white70,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(
                              color: AppColors.bgSurface,
                              height: 1,
                            ),
                            if (suggestions.isEmpty && !isLoading)
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_off_outlined,
                                      size: 16,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No matching locations found for "$query"',
                                        style: const TextStyle(
                                          fontFamily:
                                              TWTypography.uiFamily,
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          locController.addCustomLocation(
                                        query,
                                        selectedLocations,
                                        customLocationController,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Add anyway',
                                              style: TextStyle(
                                                fontFamily:
                                                    TWTypography.uiFamily,
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: suggestions.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                    color: AppColors.bgSurface,
                                    height: 1,
                                  ),
                                  itemBuilder: (ctx, idx) {
                                    final item = suggestions[idx];
                                    final isAlreadyAdded =
                                        selectedLocations
                                            .contains(item.displayName);

                                    return InkWell(
                                      onTap: () {
                                        locController.selectSuggestion(
                                          item,
                                          selectedLocations,
                                          customLocationController,
                                        );
                                      },
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.type ==
                                                      LocationType.country
                                                  ? Icons.public_rounded
                                                  : item.type ==
                                                          LocationType
                                                              .state
                                                      ? Icons
                                                          .map_outlined
                                                      : Icons
                                                          .location_city_rounded,
                                              size: 16,
                                              color: isAlreadyAdded
                                                  ? AppColors.textTertiary
                                                  : Colors.white70,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    item.displayName,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          TWTypography
                                                              .uiFamily,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isAlreadyAdded
                                                          ? AppColors
                                                              .textTertiary
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                  Text(
                                                    item.subtitle,
                                                    style:
                                                        const TextStyle(
                                                      fontFamily:
                                                          TWTypography
                                                              .uiFamily,
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    AppColors.bgSurface,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        4),
                                                border: Border.all(
                                                  color: AppColors.searchBorder,
                                                ),
                                              ),
                                              child: Text(
                                                item.type.label,
                                                style: const TextStyle(
                                                  fontFamily: TWTypography
                                                      .uiFamily,
                                                  color: AppColors
                                                      .textTertiary,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (isAlreadyAdded) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                size: 16,
                                                color: Colors.white70,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedLocations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedLocations.map((loc) {
                        return Chip(
                          label: Text(
                            loc,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          deleteIcon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          onDeleted: () => selectedLocations.remove(loc),
                          backgroundColor: AppColors.bgSurface,
                          padding: const EdgeInsets.all(4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
      );
    });
  }
}
