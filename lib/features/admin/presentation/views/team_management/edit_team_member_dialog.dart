import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/team_management/team_role_selection_section.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog to edit team member name, password, roles, or suspension status.
void showEditTeamMemberDialog(
  BuildContext context,
  AdminController controller,
  Map<String, dynamic> member,
) {
  final email = member['email']?.toString() ?? '';
  final nameCtrl = TextEditingController(
    text: member['name']?.toString() ?? '',
  );
  final passCtrl = TextEditingController(
    text: member['password']?.toString() ?? '',
  );
  final rawRoles = member['roles'];
  var initialRoles = <String>[];
  if (rawRoles is List && rawRoles.isNotEmpty) {
    initialRoles = rawRoles.map((e) => e.toString()).toList();
  } else {
    final singleRole = member['role']?.toString() ?? 'Content Moderator';
    initialRoles = singleRole
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (initialRoles.isEmpty) initialRoles = ['Content Moderator'];
  final selectedRoles = <String>[...initialRoles].obs;
  final isSuspended = ((member['status'] ?? 'active') == 'suspended').obs;
  final isObscure = true.obs;
  final isSaving = false.obs;

  Get.dialog(
    Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit $email',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextField(
                controller: nameCtrl,
                maxLength: defaultMaxDisplayNameLength,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(defaultMaxDisplayNameLength),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Obx(
                () => TextField(
                  controller: passCtrl,
                  obscureText: isObscure.value,
                  maxLength: 128,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [LengthLimitingTextInputFormatter(128)],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Reset Password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscure.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isObscure.toggle,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Roles Selection with "Select All Roles"
              TeamRoleSelectionSection(selectedRoles: selectedRoles),
              const SizedBox(height: 14),

              Obx(
                () => SwitchListTile(
                  title: const Text(
                    'Suspend Account Access',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    isSuspended.value
                        ? 'Member cannot log in while suspended.'
                        : 'Account is currently active and authorized.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  value: isSuspended.value,
                  activeTrackColor: AppColors.error.withValues(alpha: 0.5),
                  activeColor: AppColors.error,
                  onChanged: (val) => isSuspended.value = val,
                ),
              ),
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Obx(
                    () => ElevatedButton(
                      onPressed: isSaving.value
                          ? null
                          : () async {
                              if (selectedRoles.isEmpty) {
                                AppSnackbar.warning(
                                  'Please select at least one role.',
                                );
                                return;
                              }
                              final name = nameCtrl.text.trim();
                              if (name.isNotEmpty) {
                                final nameVal = ContentValidator.validate(
                                  name,
                                  fieldName: 'Member Name',
                                );
                                if (!nameVal.isValid) {
                                  AppSnackbar.warning(nameVal.message);
                                  return;
                                }
                              }
                              isSaving.value = true;
                              final rolesList = selectedRoles.toList();
                              final primaryRole =
                                  rolesList.contains('Super Admin')
                                      ? 'Super Admin'
                                      : rolesList.join(', ');
                              final updates = <String, dynamic>{
                                'role': primaryRole,
                                'status': isSuspended.value
                                    ? 'suspended'
                                    : 'active',
                              };
                              if (name.isNotEmpty) {
                                updates['name'] = name;
                              }
                              if (passCtrl.text.trim().isNotEmpty) {
                                updates['password'] = passCtrl.text.trim();
                              }
                              await controller.updateTeamMember(
                                email: email,
                                updates: updates,
                                roles: rolesList,
                              );
                              isSaving.value = false;
                              Get.back();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Confirmation dialog for revoking admin access for a team member.
void showConfirmDeleteMemberDialog(
  BuildContext context,
  AdminController controller,
  String email,
) {
  Get.dialog(
    AlertDialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Revoke Admin Access',
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        'Are you sure you want to revoke access for $email? This member will no longer be able to log into the Admin Portal.',
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            controller.deleteTeamMember(email);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Revoke Access',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
