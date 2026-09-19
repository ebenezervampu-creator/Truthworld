import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

class StatsForNerdsController extends BaseController {
  StatsForNerdsController({required this.playerCtrl});

  final TowerPlayerController playerCtrl;

  late final String scpn;
  late final String cdnNode;
  final RxInt decodedFrames = 0.obs;
  final RxInt droppedFrames = 0.obs;
  final Random _rand = Random();

  @override
  void onInit() {
    super.onInit();
    // Generate a unique YouTube-style sCPN (12 alphanumeric chars)
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    scpn = List.generate(
      12,
      (index) => chars[_rand.nextInt(chars.length)],
    ).join();

    // Pick a high-performance CDN edge node name
    final nodes = [
      'lax17s22-in-f14.1e100.net (CF-US-West)',
      'ord38s09-in-f4.1e100.net (CF-US-Mid)',
      'lga25s11-in-f8.1e100.net (CF-US-East)',
      'ams14s02-in-f3.1e100.net (CF-EU-West)',
      'nrt12s31-in-f5.1e100.net (CF-AS-East)',
    ];
    cdnNode = nodes[_rand.nextInt(nodes.length)];

    // Periodic updater for stats tracked safely in BaseController
    trackTimer(
      Timer.periodic(const Duration(seconds: 1), (_) {
        if (playerCtrl.isClosed) return;
        if (playerCtrl.vv.isPlaying) {
          decodedFrames.value += 30;

          if (playerCtrl.isBuffering.value ||
              playerCtrl.bufferHealthSeconds < 2.0) {
            if (_rand.nextDouble() < 0.15) {
              droppedFrames.value += _rand.nextInt(3) + 1;
            }
          }
        }
      }),
    );
  }

  String fmtBw(double kbps) {
    if (kbps <= 0) return '0 kbps';
    if (kbps > 1000) {
      return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    }
    return '${kbps.toStringAsFixed(0)} kbps';
  }

  String getEstimatedBitrate(double width) {
    if (width >= 1920) return '4200 Kbps';
    if (width >= 1280) return '2400 Kbps';
    if (width >= 854) return '1100 Kbps';
    if (width > 0) return '500 Kbps';
    return '1200 Kbps';
  }

  String getBufferState() {
    return playerCtrl.isBuffering.value
        ? 'Active (${(_rand.nextDouble() * 250).toInt()} KB/s)'
        : 'Idle (0 KB/s)';
  }
}
