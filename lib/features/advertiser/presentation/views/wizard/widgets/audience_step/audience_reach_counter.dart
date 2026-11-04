import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudienceReachCounter extends StatelessWidget {
  const AudienceReachCounter({
    required this.targetAllAges,
    required this.targetAllGenders,
    required this.targetWorldwide,
    required this.targetAllAudiences,
    required this.selectedAgeGroups,
    required this.selectedLocations,
    required this.selectedAudiences,
    super.key,
  });

  final RxBool targetAllAges;
  final RxBool targetAllGenders;
  final RxBool targetWorldwide;
  final RxBool targetAllAudiences;
  final RxList<String> selectedAgeGroups;
  final RxList<String> selectedLocations;
  final RxList<String> selectedAudiences;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.track_changes_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated Reach',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
              Obx(() => Text(
                (targetAllAges.value &&
                        targetAllGenders.value &&
                        targetWorldwide.value &&
                        targetAllAudiences.value)
                    ? '250K+ Viewers'
                    : '${(50 + (selectedAgeGroups.length * 15) + (selectedLocations.length * 20) + (selectedAudiences.length * 10)).clamp(20, 240)}K Viewers',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }
}
