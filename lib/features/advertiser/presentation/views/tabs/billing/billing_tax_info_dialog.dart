import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for editing business entity & GSTIN invoicing details.
class BillingTaxInfoDialog extends StatelessWidget {
  const BillingTaxInfoDialog({required this.controller, super.key});
  final AdvertiserPortalController controller;

  static void show(BuildContext context, AdvertiserPortalController controller) {
    Get.dialog(BillingTaxInfoDialog(controller: controller));
  }

  @override
  Widget build(BuildContext context) {
    final companyController = TextEditingController(text: controller.billingCompanyName.value);
    final gstinController = TextEditingController(text: controller.billingGstin.value);
    final addressController = TextEditingController(text: controller.billingAddress.value);
    final emailController = TextEditingController(text: controller.billingEmail.value);

    return AlertDialog(
      backgroundColor: const Color(0xFF161618),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      title: const Text(
        'Edit GST & Tax Invoicing Info',
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
              controller: companyController,
              maxLength: 100,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(100),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Registered Business Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFF121214),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gstinController,
              maxLength: 25,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(25),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'GSTIN / VAT Number',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFF121214),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              maxLength: 254,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(254),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Invoice Delivery Email',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFF121214),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              maxLines: 2,
              maxLength: 300,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(300),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Registered Address',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFF121214),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            controller.saveBillingDetails(
              company: companyController.text.trim(),
              gstin: gstinController.text.trim(),
              address: addressController.text.trim(),
              email: emailController.text.trim(),
            );
            Get.back();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
