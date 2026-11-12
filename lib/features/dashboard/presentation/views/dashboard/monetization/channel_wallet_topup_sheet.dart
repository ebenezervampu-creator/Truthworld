import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';

/// Modal bottom sheet for Channel Wallet Topup (Discontinued).
/// Wallet services have been removed. Creators pay directly or with channel revenue.
class ChannelWalletTopupSheet {
  ChannelWalletTopupSheet._();

  static void show(
    BuildContext context, {
    required Channel channel,
    VoidCallback? onTopupSuccess,
  }) {
    AppSnackbar.info(
      'Channel wallet top-up has been removed. You can now pay directly or use your channel revenue.',
    );
  }
}
