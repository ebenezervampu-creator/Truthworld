import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/dubbing/dubbing_user_detail_panel.dart';
import 'package:truthworld/features/admin/presentation/views/dubbing/dubbing_user_list_section.dart';

export 'package:truthworld/features/admin/presentation/views/dubbing/dubbing_user_detail_panel.dart';
export 'package:truthworld/features/admin/presentation/views/dubbing/dubbing_user_list_section.dart';

/// Master-detail Dubbing Administration Tab for TruthWorld.
///
/// Enables administrators to inspect registered user accounts, view live
/// character credit balances, grant complimentary free dubbing credits, and configure
/// special discounts or 100% free waivers across TruthWorld Dubbing Studio and Video AI.
class DubbingManagementTab extends StatelessWidget {
  final AdminController controller;
  const DubbingManagementTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.allDubbingUsers.isEmpty && !controller.isFetchingDubbingUsers.value) {
      controller.fetchDubbingUsers();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DubbingUserListSection(
                controller: controller,
                isDesktop: isDesktop,
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 24),
              Expanded(
                child: Obx(
                  () => controller.selectedDubbingUser.value != null
                      ? DubbingUserDetailPanel(
                          controller: controller,
                          user: controller.selectedDubbingUser.value!,
                        )
                      : const DubbingEmptyDetailPanel(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
