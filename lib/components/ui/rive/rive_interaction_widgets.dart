import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:rive/rive.dart';
import 'package:truthworld/theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// TruthWorld Industry-Standard Rive Micro-Interaction Specification
/// 
/// Core Principles:
/// 1. GetX owns business state; Rive strictly owns presentation.
/// 2. Non-blocking fallback: Rive asset loading/runtime errors fall back to
///    high-performance Flutter vector widgets automatically.
/// 3. Event-driven: Discrete 300-500ms bursts returning immediately to idle.
/// 4. Accessibility: Wrapped in standard Flutter Semantics and hit targets.
/// 5. Icon Color Rule: All icon tints strictly use neutral white/textPrimary.
/// ---------------------------------------------------------------------------

/// 1. Rive Signature Like Button with SMITrigger Burst & Flutter Fallback
class TruthworldRiveLikeButton extends StatefulWidget {
  const TruthworldRiveLikeButton({
    required this.isLiked,
    required this.onTap,
    super.key,
    this.size = 28.0,
    this.activeColor,
    this.inactiveColor,
    this.semanticLabel = 'Like video',
  });

  final bool isLiked;
  final VoidCallback onTap;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final String semanticLabel;

  @override
  State<TruthworldRiveLikeButton> createState() =>
      _TruthworldRiveLikeButtonState();
}

class _TruthworldRiveLikeButtonState extends State<TruthworldRiveLikeButton> {
  SMIBool? _isLikedInput;
  SMITrigger? _burstTrigger;
  SMIBool? _hoverInput;
  StateMachineController? _controller;
  final RxBool _hasError = false.obs;

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        'LikeStateMachine',
      );

      if (controller != null) {
        artboard.addController(controller);
        _controller = controller;
        _isLikedInput = controller.findInput<bool>('liked') as SMIBool?;
        _burstTrigger = controller.findInput<bool>('burst') as SMITrigger?;
        _hoverInput = controller.findInput<bool>('hover') as SMIBool?;

        _isLikedInput?.value = widget.isLiked;
      }
    } catch (_) {
      _hasError.value = true;
    }
  }

  @override
  void didUpdateWidget(covariant TruthworldRiveLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && !_hasError.value) {
      _isLikedInput?.value = widget.isLiked;
      if (widget.isLiked) {
        _burstTrigger?.fire();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? AppColors.textPrimary;
    final inactiveColor = widget.inactiveColor ?? AppColors.textPrimary;

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: true,
      toggled: widget.isLiked,
      child: MouseRegion(
        onEnter: (_) => _hoverInput?.value = true,
        onExit: (_) => _hoverInput?.value = false,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Obx(
              () => _hasError.value
                  ? Icon(
                      widget.isLiked
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                      size: widget.size,
                      color: widget.isLiked ? activeColor : inactiveColor,
                    )
                  : RiveAnimation.asset(
                      'assets/rive/interactions/like.riv',
                      onInit: _onRiveInit,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2. Rive Channel Subscribe & Multi-State Bell Component
class TruthworldRiveSubscribeButton extends StatefulWidget {
  const TruthworldRiveSubscribeButton({
    required this.isSubscribed,
    required this.onPressed,
    super.key,
    this.notificationOption = 'all',
    this.compact = false,
  });

  final bool isSubscribed;
  final VoidCallback onPressed;
  final String notificationOption;
  final bool compact;

  @override
  State<TruthworldRiveSubscribeButton> createState() =>
      _TruthworldRiveSubscribeButtonState();
}

class _TruthworldRiveSubscribeButtonState
    extends State<TruthworldRiveSubscribeButton> {
  SMIBool? _subscribedInput;
  SMINumber? _stateInput;
  StateMachineController? _controller;
  final RxBool _hasError = false.obs;

  int _getOptionIndex(String option) {
    switch (option) {
      case 'none':
        return 0;
      case 'personalized':
        return 2;
      case 'all':
      default:
        return 1;
    }
  }

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        'SubscribeStateMachine',
      );

      if (controller != null) {
        artboard.addController(controller);
        _controller = controller;
        _subscribedInput =
            controller.findInput<bool>('subscribed') as SMIBool?;
        _stateInput = controller.findInput<double>('state') as SMINumber?;

        _subscribedInput?.value = widget.isSubscribed;
        _stateInput?.value = _getOptionIndex(widget.notificationOption).toDouble();
      }
    } catch (_) {
      _hasError.value = true;
    }
  }

  @override
  void didUpdateWidget(covariant TruthworldRiveSubscribeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasError.value) {
      _subscribedInput?.value = widget.isSubscribed;
      _stateInput?.value = _getOptionIndex(widget.notificationOption).toDouble();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSub = widget.isSubscribed;
    final bgColor = isSub
        ? AppColors.bgSurfaceContainerHighest
        : AppColors.textPrimary;
    final fgColor = isSub ? AppColors.textPrimary : AppColors.bgPage;

    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 9);

    final fontSize = widget.compact ? 12.0 : 13.0;

    return Semantics(
      label: isSub ? 'Subscribed to channel' : 'Subscribe to channel',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  if (isSub && !_hasError.value) {
                    return SizedBox(
                      width: fontSize + 6,
                      height: fontSize + 6,
                      child: RiveAnimation.asset(
                        'assets/rive/interactions/subscribe.riv',
                        onInit: _onRiveInit,
                      ),
                    );
                  } else if (isSub) {
                    return Icon(
                      widget.notificationOption == 'none'
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                      size: fontSize + 3,
                      color: fgColor,
                    );
                  }
                  return const SizedBox.shrink();
                }),
                if (isSub) const SizedBox(width: 6),
                Text(
                  isSub ? 'Subscribed' : 'Subscribe',
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3. Rive Play / Pause Vector Morph Component
class TruthworldRivePlayPauseButton extends StatefulWidget {
  const TruthworldRivePlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    super.key,
    this.size = 36.0,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  @override
  State<TruthworldRivePlayPauseButton> createState() =>
      _TruthworldRivePlayPauseButtonState();
}

class _TruthworldRivePlayPauseButtonState
    extends State<TruthworldRivePlayPauseButton> {
  SMIBool? _isPlayingInput;
  StateMachineController? _controller;
  final RxBool _hasError = false.obs;

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        'PlayPauseStateMachine',
      );

      if (controller != null) {
        artboard.addController(controller);
        _controller = controller;
        _isPlayingInput = controller.findInput<bool>('isPlaying') as SMIBool?;
        _isPlayingInput?.value = widget.isPlaying;
      }
    } catch (_) {
      _hasError.value = true;
    }
  }

  @override
  void didUpdateWidget(covariant TruthworldRivePlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying && !_hasError.value) {
      _isPlayingInput?.value = widget.isPlaying;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isPlaying ? 'Pause video' : 'Play video',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Obx(
            () => _hasError.value
                ? Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: widget.size,
                    color: AppColors.textPrimary,
                  )
                : RiveAnimation.asset(
                    'assets/rive/player/play_pause.riv',
                    onInit: _onRiveInit,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 4. Rive Download Progress Component
class TruthworldRiveDownloadButton extends StatefulWidget {
  const TruthworldRiveDownloadButton({
    required this.progress, // 0.0 to 1.0 from GetX controller
    required this.isCompleted,
    required this.onTap,
    super.key,
    this.size = 28.0,
  });

  final double progress;
  final bool isCompleted;
  final VoidCallback onTap;
  final double size;

  @override
  State<TruthworldRiveDownloadButton> createState() =>
      _TruthworldRiveDownloadButtonState();
}

class _TruthworldRiveDownloadButtonState
    extends State<TruthworldRiveDownloadButton> {
  SMINumber? _progressInput;
  SMIBool? _completedInput;
  StateMachineController? _controller;
  final RxBool _hasError = false.obs;

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        'DownloadStateMachine',
      );

      if (controller != null) {
        artboard.addController(controller);
        _controller = controller;
        _progressInput = controller.findInput<double>('progress') as SMINumber?;
        _completedInput = controller.findInput<bool>('completed') as SMIBool?;

        _progressInput?.value = (widget.progress * 100).clamp(0.0, 100.0);
        _completedInput?.value = widget.isCompleted;
      }
    } catch (_) {
      _hasError.value = true;
    }
  }

  @override
  void didUpdateWidget(covariant TruthworldRiveDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasError.value) {
      _progressInput?.value = (widget.progress * 100).clamp(0.0, 100.0);
      _completedInput?.value = widget.isCompleted;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isCompleted
          ? 'Download completed'
          : 'Download video (${(widget.progress * 100).toInt()}%)',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Obx(
            () => _hasError.value
                ? Icon(
                    widget.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.download_rounded,
                    size: widget.size,
                    color: AppColors.textPrimary,
                  )
                : RiveAnimation.asset(
                    'assets/rive/interactions/download.riv',
                    onInit: _onRiveInit,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
