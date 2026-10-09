import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive thin video progress bar at the bottom of the miniplayer video frame.
class MiniplayerVideoProgressBar extends StatelessWidget {
  final MiniplayerController controller;

  MiniplayerVideoProgressBar({
    required this.controller,
    super.key,
  });

  final RxBool _isDragging = false.obs;
  final RxnDouble _dragRatio = RxnDouble();

  void _updateSeek(Offset localPosition, double width) {
    if (width <= 0) return;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    _dragRatio.value = ratio;
    controller.seekToRatio(ratio);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _updateSeek(details.localPosition, width);
          },
          onHorizontalDragStart: (details) {
            _isDragging.value = true;
            _updateSeek(details.localPosition, width);
          },
          onHorizontalDragUpdate: (details) {
            _updateSeek(details.localPosition, width);
          },
          onHorizontalDragEnd: (details) {
            _isDragging.value = false;
            _dragRatio.value = null;
          },
          onHorizontalDragCancel: () {
            _isDragging.value = false;
            _dragRatio.value = null;
          },
          child: Container(
            height: 18,
            color: Colors.transparent,
            alignment: Alignment.bottomCenter,
            child: Obx(() {
              final pos = controller.currentPosition.value.inMilliseconds;
              final dur = controller.totalDuration.value.inMilliseconds;
              final actualValue = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
              final isDraggingVal = _isDragging.value;
              final dragRatioVal = _dragRatio.value;
              final value = isDraggingVal && dragRatioVal != null
                  ? dragRatioVal
                  : actualValue;
              final barHeight = isDraggingVal ? 6.0 : 4.0;

              return SizedBox(
                height: barHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: width,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: width * value,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                    if (isDraggingVal)
                      Positioned(
                        left: (width * value - 5).clamp(0.0, width - 10),
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
