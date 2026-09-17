import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_management_widgets.dart';

export 'package:truthworld/features/admin/presentation/views/user_management/user_management_widgets.dart';

/// Master-detail user management tab for TruthWorld administrators.
///
/// Features real-time user listing, search, account status filtering,
/// safety audits, Google Cloud Vision AI avatar verification, and moderation controls.
class UserManagementTab extends StatelessWidget {
  final AdminController controller;
  const UserManagementTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.allUsers.isEmpty && !controller.isSearchingUsers.value) {
      controller.fetchUsers();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: UserListSection(
                controller: controller,
                isDesktop: isDesktop,
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 24),
              Expanded(
                child: Obx(
                  () => controller.selectedUser.value != null
                      ? UserDetailPanel(
                          controller: controller,
                          user: controller.selectedUser.value!,
                        )
                      : const UserEmptyDetailPanel(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
