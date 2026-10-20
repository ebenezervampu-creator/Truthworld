import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Central service governing playback time limits for unsigned (guest) viewers.
///
/// Policy:
/// - Unsigned users are restricted to a maximum of 10 minutes (600 seconds) of total watch time.
/// - Incognito mode and local storage clearing are guarded by server-side IP tracking.
/// - When 10 minutes is reached, playback halts and a polite sign-in modal is presented.
/// - When the viewer signs in, all limits are removed and unlimited playback is restored.
class GuestPlaybackLimitService extends GetxService {
  static GuestPlaybackLimitService get to => Get.find<GuestPlaybackLimitService>();

  static const int maxGuestWatchSeconds = 600; // 10 minutes
  static const String _storageKeyWatchedSeconds = 'guest_watch_seconds_total';
  static const String _storageKeyLimitReached = 'guest_watch_limit_reached';

  final GetStorage _storage = GetStorage();

  // Reactive state
  final RxInt remainingSeconds = maxGuestWatchSeconds.obs;
  final RxInt totalWatchedSeconds = 0.obs;
  final RxBool isLimitReached = false.obs;
  final RxBool isCheckingServer = false.obs;

  Timer? _tickerTimer;
  final Stopwatch _stopwatch = Stopwatch();
  int _lastStopwatchMillis = 0;
  int _unreportedPulseSeconds = 0;
  bool _isPromptShowing = false;
  String? _lastVideoId;

  @override
  void onInit() {
    super.onInit();
    _loadLocalQuota();

    // Check server IP quota immediately (critical for Incognito / private tabs)
    unawaited(checkServerQuota());

    // Listen to authentication state changes
    if (Get.isRegistered<AuthService>()) {
      ever(AuthService.to.isAuthenticated, (isAuth) {
        if (isAuth) {
          // User successfully signed in: lift all guest barriers immediately
          isLimitReached.value = false;
          _stopTicker();
        } else {
          // User signed out: re-check guest quota for current IP
          _loadLocalQuota();
          unawaited(checkServerQuota());
        }
      });
    }
  }

  @override
  void onClose() {
    _stopTicker();
    _stopwatch.reset();
    super.onClose();
  }

  void _loadLocalQuota() {
    try {
      final localSeconds = _storage.read<int>(_storageKeyWatchedSeconds) ?? 0;
      final flagReached = _storage.read<bool>(_storageKeyLimitReached) ?? false;
      totalWatchedSeconds.value = localSeconds;

      final remaining = math.max(0, maxGuestWatchSeconds - localSeconds);
      remainingSeconds.value = remaining;

      if (remaining <= 0 || flagReached) {
        isLimitReached.value = true;
        remainingSeconds.value = 0;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'GuestPlaybackLimitService._loadLocalQuota');
    }
  }

  /// Whether playback is currently permitted for the active viewer.
  bool isPlaybackAllowed() {
    if (AuthService.to.isAuthenticated.value) {
      return true;
    }
    if (isLimitReached.value || remainingSeconds.value <= 0) {
      isLimitReached.value = true;
      remainingSeconds.value = 0;
      return false;
    }
    return true;
  }

  /// Called whenever playback is active to track elapsed seconds and sync with server.
  void onPlaybackActive({String? videoId}) {
    if (AuthService.to.isAuthenticated.value) {
      _stopTicker();
      return;
    }

    if (videoId != null && videoId.isNotEmpty) {
      _lastVideoId = videoId;
    }

    if (!isPlaybackAllowed()) {
      TowerPlayerRegistry.pauseAllActivePlayers();
      promptGuestSignIn();
      return;
    }

    _startTicker();
  }

  /// Called when playback pauses or stops to finalize pulses.
  void onPlaybackPaused() {
    _stopTicker();
    if (_unreportedPulseSeconds > 0 && !AuthService.to.isAuthenticated.value) {
      unawaited(_reportPulseToServer(_unreportedPulseSeconds, _lastVideoId));
      _unreportedPulseSeconds = 0;
    }
  }

  void _startTicker() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _lastStopwatchMillis = _stopwatch.elapsedMilliseconds;
    }
    if (_tickerTimer != null && _tickerTimer!.isActive) return;

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (AuthService.to.isAuthenticated.value) {
        _stopTicker();
        return;
      }

      // Hardware monotonic clock: immune to OS clock manipulation and background tab throttling
      final currentMillis = _stopwatch.elapsedMilliseconds;
      final elapsedMillis = currentMillis - _lastStopwatchMillis;
      final deltaSeconds = math.max(1, elapsedMillis ~/ 1000);
      _lastStopwatchMillis += deltaSeconds * 1000;

      totalWatchedSeconds.value += deltaSeconds;
      remainingSeconds.value = math.max(0, remainingSeconds.value - deltaSeconds);
      _unreportedPulseSeconds += deltaSeconds;

      // Persist locally every 5 seconds
      if (totalWatchedSeconds.value % 5 == 0) {
        _storage.write(_storageKeyWatchedSeconds, totalWatchedSeconds.value);
      }

      // Adaptive pulse frequency for millions of users:
      // - First 5 min (>300s remaining): 60s pulses (reduces API load by 75% for 1M+ users)
      // - 1 to 5 min remaining (60s–300s): 30s pulses
      // - Final minute (<60s remaining): 15s pulses
      final pulseInterval = remainingSeconds.value <= 60
          ? 15
          : (remainingSeconds.value <= 300 ? 30 : 60);

      if (_unreportedPulseSeconds >= pulseInterval) {
        final pulse = _unreportedPulseSeconds;
        _unreportedPulseSeconds = 0;
        unawaited(_reportPulseToServer(pulse, _lastVideoId));
      }

      // Check limit exhaustion
      if (remainingSeconds.value <= 0) {
        isLimitReached.value = true;
        remainingSeconds.value = 0;
        _storage.write(_storageKeyWatchedSeconds, totalWatchedSeconds.value);
        _storage.write(_storageKeyLimitReached, true);
        _stopTicker();
        TowerPlayerRegistry.pauseAllActivePlayers();
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!AuthService.to.isAuthenticated.value) {
            promptGuestSignIn();
          }
        });
      }
    });
  }

  void _stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
  }

  /// Verifies current IP watch quota against the server.
  /// Crucial for detecting users who open Incognito tabs or wipe local cache.
  Future<void> checkServerQuota() async {
    if (AuthService.to.isAuthenticated.value) return;

    try {
      isCheckingServer.value = true;
      final appCheckToken = await StorageUtils.getAppCheckToken();

      final headers = {
        'Content-Type': 'application/json',
        if (appCheckToken != null && appCheckToken.isNotEmpty)
          'X-Firebase-AppCheck': appCheckToken,
      };

      final url = Uri.parse('${AppConfig.cloudFunctionsBaseUrl}/checkGuestWatchQuota');
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isAuth = data['isAuthenticated'] == true;
        if (isAuth) {
          isLimitReached.value = false;
          return;
        }

        final serverRemaining = (data['remainingSeconds'] as num?)?.toInt();
        final serverExceeded = data['isLimitExceeded'] == true ||
            (serverRemaining != null && serverRemaining <= 0);

        if (serverExceeded) {
          isLimitReached.value = true;
          remainingSeconds.value = 0;
          _storage.write(_storageKeyLimitReached, true);
          TowerPlayerRegistry.pauseAllActivePlayers();
          promptGuestSignIn();
        } else if (serverRemaining != null) {
          // Take the stricter of local storage or server IP quota
          final effectiveRemaining = math.min(remainingSeconds.value, serverRemaining);
          remainingSeconds.value = effectiveRemaining;
          if (effectiveRemaining <= 0) {
            isLimitReached.value = true;
            _storage.write(_storageKeyLimitReached, true);
            TowerPlayerRegistry.pauseAllActivePlayers();
            promptGuestSignIn();
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'GuestPlaybackLimitService.checkServerQuota');
    } finally {
      isCheckingServer.value = false;
    }
  }

  /// Sends periodic watch heartbeat pulses to Cloud Functions to increment IP counters.
  Future<void> _reportPulseToServer(int deltaSeconds, String? videoId) async {
    if (AuthService.to.isAuthenticated.value || deltaSeconds <= 0) return;

    try {
      final appCheckToken = await StorageUtils.getAppCheckToken();

      final headers = {
        'Content-Type': 'application/json',
        if (appCheckToken != null && appCheckToken.isNotEmpty)
          'X-Firebase-AppCheck': appCheckToken,
      };

      final body = jsonEncode({
        'deltaSeconds': deltaSeconds,
        if (videoId != null && videoId.isNotEmpty) 'videoId': videoId,
      });

      final url = Uri.parse('${AppConfig.cloudFunctionsBaseUrl}/reportGuestWatchPulse');
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverExceeded = data['isLimitExceeded'] == true;
        final serverRemaining = (data['remainingSeconds'] as num?)?.toInt();

        if (serverExceeded || (serverRemaining != null && serverRemaining <= 0)) {
          isLimitReached.value = true;
          remainingSeconds.value = 0;
          _storage.write(_storageKeyLimitReached, true);
          TowerPlayerRegistry.pauseAllActivePlayers();
          promptGuestSignIn();
        } else if (serverRemaining != null && serverRemaining < remainingSeconds.value) {
          // Multi-tab sync: another tab on this IP consumed quota, sync stricter remaining time
          remainingSeconds.value = serverRemaining;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'GuestPlaybackLimitService._reportPulseToServer');
    }
  }

  /// Displays the polite sign-in prompt when the 10-minute preview expires.
  Future<void> promptGuestSignIn({BuildContext? context}) async {
    if (AuthService.to.isAuthenticated.value) return;
    if (_isPromptShowing) return;

    _isPromptShowing = true;
    final effectiveContext = context ?? Get.context;

    if (effectiveContext == null) {
      _isPromptShowing = false;
      return;
    }

    try {
      await showModalBottomSheet<void>(
        context: effectiveContext,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => const GuestSignInPromptSheet(),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'GuestPlaybackLimitService.promptGuestSignIn');
    } finally {
      _isPromptShowing = false;
    }
  }
}

/// Polite, high-contrast modal bottom sheet inviting guest viewers to sign in.
/// Complies with TruthWorld WCAG AA and zero white-on-white policies.
class GuestSignInPromptSheet extends StatelessWidget {
  const GuestSignInPromptSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Friendly header icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Enjoy Unlimited TruthWorld',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Polite explanation
              const Text(
                "You've enjoyed your 10 minutes of free preview. Please sign in to your free account to continue enjoying unlimited, fact-checked, high-definition videos anytime.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Benefits list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Column(
                  children: [
                    _BenefitRow(text: '100% Free to create an account'),
                    SizedBox(height: 10),
                    _BenefitRow(text: 'Unlimited video streaming & downloads'),
                    SizedBox(height: 10),
                    _BenefitRow(text: 'AI-powered truth verification & claims'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: White button with black foreground (Zero white-on-white)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  AuthBottomSheet.show(Get.context);
                },
                child: const Text(
                  'Sign In to Continue',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Dismiss Button
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// In-Player barrier and countdown overlay shown directly over the video surface:
/// - When > 5 minutes has elapsed (<= 5 minutes / 300s remaining): Smoothly renders
///   a descending countdown timer pill (e.g. "Preview ends in 04:32").
/// - When 10 minutes is reached (0s remaining): Smoothly transitions to the full-screen
///   preview barrier with polite sign-in call to action.
class GuestPlaybackBarrierOverlay extends StatelessWidget {
  const GuestPlaybackBarrierOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final limitService = Get.isRegistered<GuestPlaybackLimitService>()
        ? GuestPlaybackLimitService.to
        : null;

    if (limitService == null) return const SizedBox.shrink();

    return Obx(() {
      final isAuth = AuthService.to.isAuthenticated.value;
      final isReached = limitService.isLimitReached.value;
      final remaining = limitService.remainingSeconds.value;

      if (isAuth) {
        return const SizedBox.shrink();
      }

      // 1. Limit reached: Smoothly show full-screen playback barrier overlay
      if (isReached || remaining <= 0) {
        return Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: child,
              );
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: limitService.promptGuestSignIn,
              child: Container(
                color: Colors.black.withValues(alpha: 0.94),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_clock_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '10-Minute Free Preview Ended',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please sign in to your free account to continue watching unlimited verified content on TruthWorld.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                          ),
                          onPressed: limitService.promptGuestSignIn,
                          child: const Text(
                            'Sign In to Continue',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // 2. Used > 5 minutes (remaining <= 300s): Smoothly show descending countdown pill
      if (remaining <= 300) {
        return Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: child,
                );
              },
              child: GuestCountdownTimerPill(
                remainingSeconds: remaining,
                onTap: limitService.promptGuestSignIn,
              ),
            ),
          ),
        );
      }

      // First 5 minutes of guest viewing: clean player surface, no intrusive timer
      return const SizedBox.shrink();
    });
  }
}

/// Floating, high-contrast countdown timer pill visible after 5 minutes of guest playback.
/// Displays remaining preview time in descending order (e.g. "Preview ends in 04:32").
class GuestCountdownTimerPill extends StatelessWidget {
  final int remainingSeconds;
  final VoidCallback onTap;

  const GuestCountdownTimerPill({
    required this.remainingSeconds,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    final timeString = '$minutes:$seconds';

    final isUrgent = remainingSeconds <= 60; // Final minute accent

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUrgent
                ? Colors.amberAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.2),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              color: isUrgent ? Colors.amberAccent : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'Preview ends in $timeString',
              style: TextStyle(
                color: isUrgent ? Colors.amberAccent : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
