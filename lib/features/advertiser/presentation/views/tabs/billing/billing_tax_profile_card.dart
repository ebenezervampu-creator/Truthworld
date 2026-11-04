import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_tax_info_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card presenting GST entity and tax invoicing profile details.
class BillingTaxProfileCard extends StatelessWidget {
  const BillingTaxProfileCard({required this.controller, super.key});
  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
              const Text(
                'GST & Business Invoicing Profile',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: () => BillingTaxInfoDialog.show(context, controller),
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Edit Details',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            return Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    label: 'Registered Entity',
                    value: controller.billingCompanyName.value,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    label: 'GSTIN / Tax ID',
                    value: controller.billingGstin.value,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    label: 'Billing Email',
                    value: controller.billingEmail.value,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Obx(() {
            return _buildInfoTile(
              label: 'Registered Address',
              value: controller.billingAddress.value,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
