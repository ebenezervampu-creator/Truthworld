import 'package:flutter/material.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Interactive card presenting the channel's wallet balance (Discontinued).
/// Renders empty as the channel wallet feature has been removed.
class ChannelWalletCard extends StatelessWidget {
  const ChannelWalletCard({
    required this.channel,
    this.controller,
    super.key,
  });

  final Channel channel;
  final DashboardController? controller;

  @override
  Widget build(BuildContext context) {
    // Channel wallet feature has been removed.
    return const SizedBox.shrink();
  }
}
