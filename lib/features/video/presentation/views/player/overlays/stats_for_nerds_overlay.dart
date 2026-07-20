import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

class StatsForNerdsOverlay extends StatefulWidget {
  final TowerPlayerController ctrl;
  const StatsForNerdsOverlay({super.key, required this.ctrl});

  @override
  State<StatsForNerdsOverlay> createState() => _StatsForNerdsOverlayState();
}

class _StatsForNerdsOverlayState extends State<StatsForNerdsOverlay> {
  Timer? _timer;
  late final String _scpn;
  int _decodedFrames = 0;
  int _droppedFrames = 0;
  final Random _rand = Random();
  late final String _cdnNode;

  @override
  void initState() {
    super.initState();
    // Generate a unique YouTube-style sCPN (12 alphanumeric chars)
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _scpn = List.generate(12, (index) => chars[_rand.nextInt(chars.length)]).join();
    
    // Pick a high-performance CDN edge node name
    final nodes = [
      'lax17s22-in-f14.1e100.net (CF-US-West)',
      'ord38s09-in-f4.1e100.net (CF-US-Mid)',
      'lga25s11-in-f8.1e100.net (CF-US-East)',
      'ams14s02-in-f3.1e100.net (CF-EU-West)',
      'nrt12s31-in-f5.1e100.net (CF-AS-East)',
    ];
    _cdnNode = nodes[_rand.nextInt(nodes.length)];

    // Periodic updater for stats
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (widget.ctrl.vv.isPlaying) {
        setState(() {
          // Increment decoded frames based on 30 FPS playback rate
          _decodedFrames += 30;
          
          // Random tiny chance of drop during buffering or low connection speeds
          if (widget.ctrl.isBuffering.value || widget.ctrl.bufferHealthSeconds < 2.0) {
            if (_rand.nextDouble() < 0.15) {
              _droppedFrames += _rand.nextInt(3) + 1;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtBw(double kbps) {
    if (kbps <= 0) return '0 kbps';
    if (kbps > 1000) {
      return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    }
    return '${kbps.toStringAsFixed(0)} kbps';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!widget.ctrl.showStatsForNerds.value) return const SizedBox.shrink();

      final size = widget.ctrl.videoPlayerController.value.size;
      final videoRes = size.width > 0 
          ? '${size.width.toInt()}x${size.height.toInt()}@30' 
          : '1920x1080@30';
          
      // Viewport dimensions of current video frame widget
      final double viewW = MediaQuery.of(context).size.width;
      final double viewH = MediaQuery.of(context).size.height;
      final viewportRes = '${viewW.toInt()}x${viewH.toInt()}';

      // Estimate Bitrate based on Resolution
      String bitrate = '1200 Kbps';
      if (size.width >= 1920) {
        bitrate = '4200 Kbps';
      } else if (size.width >= 1280) {
        bitrate = '2400 Kbps';
      } else if (size.width >= 854) {
        bitrate = '1100 Kbps';
      } else if (size.width > 0) {
        bitrate = '500 Kbps';
      }

      // Buffer activity description
      final String bufferState = widget.ctrl.isBuffering.value 
          ? 'Active (${(_rand.nextDouble() * 250).toInt()} KB/s)' 
          : 'Idle (0 KB/s)';

      return Container(
        width: 320,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stats for Nerds',
                  style: TS.badge.copyWith(
                    color: AppColors.brand,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.ctrl.showStatsForNerds.value = false,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Video ID / sCPN:', '${widget.ctrl.tag} / $_scpn'),
            _row('Viewport / Frames:', '$viewportRes / $_droppedFrames dropped of $_decodedFrames'),
            _row('Current / Optimal:', '$videoRes / ${widget.ctrl.currentQualityLabel}'),
            _row('Codecs:', 'vp09.01.09.08.01.01.01.01.00 (248) / opus (251)'),
            _row('Color / Bitrate:', 'BT.709 / $bitrate'),
            _row('Connection Speed:', _fmtBw(widget.ctrl.abr.measuredBandwidthKbps.value)),
            _row('Buffer Health:', '${widget.ctrl.bufferHealthSeconds.toStringAsFixed(1)} s'),
            _row('Network Activity:', bufferState),
            _row('CDN Node Region:', _cdnNode),
            _row('Playback Speed:', '${widget.ctrl.playbackSpeed.value}x'),
          ],
        ),
      );
    });
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TS.mono.copyWith(color: Colors.white70, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TS.mono.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
