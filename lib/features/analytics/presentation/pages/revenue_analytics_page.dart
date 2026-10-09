import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';

/// Unified Studio Earnings & Revenue Analytics Page.
/// Renders the unified MonetizationScreen (Earnings page) containing all merged
/// revenue streams, payout cards, KYC, and monetization features.
class RevenueAnalyticsPage extends StatelessWidget {
  const RevenueAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonetizationScreen(pageTitle: 'Revenue Analytics');
  }
}
