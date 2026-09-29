import 'package:flutter/material.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_invoices_card.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_payment_gateway_card.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_tax_profile_card.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_wallet_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Billing & Invoices / Wallet management tab for Truthworld Advertiser Studio.
class BillingTabView extends StatelessWidget {
  const BillingTabView({required this.controller, super.key});

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          BillingWalletCard(controller: controller),
          const SizedBox(height: 24),
          BillingPaymentGatewayCard(controller: controller),
          const SizedBox(height: 24),
          BillingTaxProfileCard(controller: controller),
          const SizedBox(height: 24),
          BillingInvoicesCard(controller: controller),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing, Invoices & Wallet',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage prepaid ad balance, automated reloads, tax invoices, and payment methods.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
