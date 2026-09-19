import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Role selection checklist section with select-all toggle, available roles list,
/// checkboxes, descriptions, and Super Admin badge.
class TeamRoleSelectionSection extends StatelessWidget {
  const TeamRoleSelectionSection({
    required this.selectedRoles,
    super.key,
  });

  final RxList<String> selectedRoles;

  @override
  Widget build(BuildContext context) {
    final allCount = AdminController.availableRoles.length;

    return Obx(() {
      final selectedCount = selectedRoles.length;
      final isAllSelected = selectedCount == allCount;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assign Roles & Permissions ($selectedCount/$allCount)',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {
                  if (isAllSelected) {
                    selectedRoles.clear();
                  } else {
                    selectedRoles.assignAll(AdminController.allRoleNames);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAllSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAllSelected ? 'Deselect All' : 'Select All Roles',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: AdminController.availableRoles.length,
              separatorBuilder: (_, _) => Divider(
                color: Colors.white.withValues(alpha: 0.04),
                height: 1,
              ),
              itemBuilder: (context, idx) {
                final roleMeta = AdminController.availableRoles[idx];
                final roleName = roleMeta['name'] as String;
                final roleDesc = roleMeta['description'] as String;
                final isSelected = selectedRoles.contains(roleName);

                return InkWell(
                  onTap: () {
                    if (isSelected) {
                      selectedRoles.remove(roleName);
                    } else {
                      selectedRoles.add(roleName);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFF2BA640),
                          checkColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            if (val == true) {
                              if (!selectedRoles.contains(roleName)) {
                                selectedRoles.add(roleName);
                              }
                            } else {
                              selectedRoles.remove(roleName);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    roleName,
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (roleName == 'Super Admin') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ALL TABS',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Color(0xFFD8B4FE),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roleDesc,
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontSize: 10,
                                  color: isSelected
                                      ? AppColors.textSecondary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
