import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/team_management/team_role_selection_section.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog allowing the administrator to add a team member with email, name,
/// password generator, and role selection.
void showAddTeamMemberDialog(
  BuildContext context,
  AdminController controller,
) {
  final emailCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final selectedRoles = <String>['Content Moderator'].obs;
  final isObscure = true.obs;
  final isSubmitting = false.obs;

  void generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final generated =
        List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
    passCtrl.text = generated;
  }

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
              const Row(
                children: [
                  Icon(
                    Icons.person_add_alt_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Add Team Member',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter member email, username, password, and assign roles. Credentials will be emailed directly to the member.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),

              // Email
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                maxLength: 254,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(254),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Member Email',
                  hintText: 'e.g. moderator@truthworld.in',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.white,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Username
              TextField(
                controller: usernameCtrl,
                maxLength: 40,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(40),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Member Username',
                  hintText: 'e.g. moderator1 or john_audit',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    color: Colors.white,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Name
              TextField(
                controller: nameCtrl,
                maxLength: defaultMaxDisplayNameLength,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(defaultMaxDisplayNameLength),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Member Name / Designation',
                  hintText: 'e.g. John Doe',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: Colors.white,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Password & Generator
              Obx(
                () => TextField(
                  controller: passCtrl,
                  obscureText: isObscure.value,
                  maxLength: 128,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [LengthLimitingTextInputFormatter(128)],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter or generate password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          tooltip: 'Generate Random Password',
                          onPressed: generatePassword,
                        ),
                        IconButton(
                          icon: Icon(
                            isObscure.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          tooltip: isObscure.value
                              ? 'Show Password'
                              : 'Hide Password',
                          onPressed: isObscure.toggle,
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Role Selection with "Select All Roles" and list of all roles
              TeamRoleSelectionSection(selectedRoles: selectedRoles),
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
                    () => ElevatedButton.icon(
                      onPressed: isSubmitting.value
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim();
                              final pass = passCtrl.text.trim();
                              final username = usernameCtrl.text.trim().isNotEmpty
                                  ? usernameCtrl.text.trim().toLowerCase()
                                  : email.split('@').first.toLowerCase();
                              if (email.isEmpty || pass.isEmpty) {
                                AppSnackbar.warning(
                                  'Please fill in email and password.',
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
                              if (selectedRoles.isEmpty) {
                                AppSnackbar.warning(
                                  'Please select at least one role for this member.',
                                );
                                return;
                              }
                              isSubmitting.value = true;
                              final rolesList = selectedRoles.toList();
                              final primaryRole =
                                  rolesList.contains('Super Admin')
                                      ? 'Super Admin'
                                      : rolesList.join(', ');
                              final success = await controller.addTeamMember(
                                email: email,
                                username: username,
                                password: pass,
                                role: primaryRole,
                                roles: rolesList,
                                name: name,
                              );
                              isSubmitting.value = false;
                              if (success) {
                                Get.back();
                                controller.copyMemberCredentials(
                                  email: email,
                                  username: username,
                                  password: pass,
                                  role: primaryRole,
                                );
                              }
                            },
                      icon: isSubmitting.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                      label: const Text(
                        'Save & Share',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
