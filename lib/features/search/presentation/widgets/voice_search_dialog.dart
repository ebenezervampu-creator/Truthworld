import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:truthworld/theme/app_theme.dart';

/// Distinct lifecycle states for voice search
enum VoiceSearchState {
  initializing,
  listening,
  recognized,
  submitting,
  unrecognized,
  permissionDenied,
  error,
}

/// Controller managing speech recognition lifecycle, permissions, and sound visualization
class VoiceSearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  VoiceSearchController({required this.onSearch, required this.context});

  final Function(String) onSearch;
  final BuildContext context;

  final stt.SpeechToText speech = stt.SpeechToText();

  final Rx<VoiceSearchState> voiceState = VoiceSearchState.initializing.obs;
  final RxString recognizedText = ''.obs;
  final RxDouble normalizedSoundLevel = 0.0.obs;
  final RxString rxErrorMessage = ''.obs;
  final RxString activeLocaleName = 'English'.obs;

  late final AnimationController pulsateController;
  Timer? _silenceTimer;
  Timer? _maxListenTimer;
  bool _isSubmitting = false;
  bool _isDisposed = false;
  String? _selectedLocaleId;

  // Sample prompt suggestions shown when waiting/retrying
  final List<String> suggestions = const [
    'Flutter tutorials',
    'Latest news',
    'Tech innovations',
    'Documentaries',
    'Trending topics',
  ];

  @override
  void onInit() {
    super.onInit();
    pulsateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    initAndStartListening();
  }

  @override
  void onClose() {
    _isDisposed = true;
    _cancelTimers();
    try {
      speech.stop();
      speech.cancel();
    } catch (_) {}
    pulsateController.dispose();
    super.onClose();
  }

  void _cancelTimers() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxListenTimer?.cancel();
    _maxListenTimer = null;
  }

  /// Proactively verify & request microphone permission, then initialize STT engine
  Future<void> initAndStartListening() async {
    if (_isDisposed) return;
    voiceState.value = VoiceSearchState.initializing;
    rxErrorMessage.value = '';
    recognizedText.value = '';
    normalizedSoundLevel.value = 0.0;
    _isSubmitting = false;

    // 1. Check microphone permission (on mobile platforms)
    if (!kIsWeb) {
      final status = await Permission.microphone.status;
      if (status.isPermanentlyDenied || status.isRestricted) {
        voiceState.value = VoiceSearchState.permissionDenied;
        rxErrorMessage.value =
            'Microphone access is disabled. Please enable it in device Settings to search with your voice.';
        return;
      }

      if (!status.isGranted) {
        final reqStatus = await Permission.microphone.request();
        if (reqStatus.isPermanentlyDenied || reqStatus.isRestricted) {
          voiceState.value = VoiceSearchState.permissionDenied;
          rxErrorMessage.value =
              'Microphone access is disabled. Please enable it in device Settings to search with your voice.';
          return;
        }
        if (!reqStatus.isGranted) {
          voiceState.value = VoiceSearchState.permissionDenied;
          rxErrorMessage.value =
              'Microphone permission is required to search with your voice.';
          return;
        }
      }
    }

    // 2. Initialize STT engine
    try {
      final isAvailable = await speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );

      if (_isDisposed) return;

      if (!isAvailable) {
        voiceState.value = VoiceSearchState.error;
        rxErrorMessage.value =
            'Voice search is not available on this device right now.';
        return;
      }

      // 3. Resolve preferred locale
      try {
        final systemLocale = await speech.systemLocale();
        if (systemLocale != null) {
          _selectedLocaleId = systemLocale.localeId;
          activeLocaleName.value = systemLocale.name;
        }
      } catch (_) {
        // Fallback gracefully
      }

      // 4. Start active listening
      await startListening();
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('🎙️ [VoiceSearch] Error during init: $e');
      voiceState.value = VoiceSearchState.error;
      rxErrorMessage.value = 'Failed to start voice search. Tap mic to retry.';
    }
  }

  /// Begin actively recording audio and transcribing words
  Future<void> startListening() async {
    if (_isDisposed) return;
    _cancelTimers();
    _isSubmitting = false;
    rxErrorMessage.value = '';
    recognizedText.value = '';
    normalizedSoundLevel.value = 0.0;
    voiceState.value = VoiceSearchState.listening;

    try {
      if (speech.isListening) {
        await speech.stop();
      }

      await speech.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: _handleSoundLevel,
        localeId: _selectedLocaleId,
        listenMode: stt.ListenMode.search,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
      );

      // Max listening safety fallback timeout
      _maxListenTimer = Timer(const Duration(seconds: 20), () {
        if (_isDisposed || _isSubmitting) return;
        if (recognizedText.value.trim().isNotEmpty) {
          submitSearch(recognizedText.value);
        } else {
          stopListening(promptUnrecognized: true);
        }
      });
    } catch (e) {
      if (_isDisposed) return;
      debugPrint('🎙️ [VoiceSearch] Exception in startListening: $e');
      voiceState.value = VoiceSearchState.error;
      rxErrorMessage.value = 'Unable to listen. Tap the microphone to retry.';
    }
  }

  /// Strips trailing/leading punctuation marks (. ? ! , ; : - _) and collapses whitespace
  static String sanitizeQuery(String text) {
    var cleaned = text.trim();
    // Strip trailing punctuation marks commonly appended by speech recognition engines
    cleaned = cleaned.replaceAll(RegExp(r'[\.\?\!\,\;\:\-_]+$'), '').trim();
    // Strip leading punctuation marks
    cleaned = cleaned.replaceAll(RegExp(r'^[\.\?\!\,\;\:\-_]+'), '').trim();
    // Collapse multiple whitespaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  /// Handles incoming streaming recognition result
  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (_isDisposed || _isSubmitting) return;

    final words = sanitizeQuery(result.recognizedWords);
    if (words.isNotEmpty) {
      recognizedText.value = words;
      voiceState.value = VoiceSearchState.recognized;

      // Reset silence debounce timer on every spoken phrase
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(milliseconds: 950), () {
        if (_isDisposed || _isSubmitting) return;
        if (recognizedText.value.trim().isNotEmpty) {
          submitSearch(recognizedText.value);
        }
      });
    }

    if (result.finalResult && words.isNotEmpty) {
      submitSearch(words);
    }
  }

  /// Normalizes hardware decibels into a smooth 0.0 .. 1.0 curve for wave animation
  void _handleSoundLevel(double level) {
    if (_isDisposed || voiceState.value != VoiceSearchState.listening) return;

    // Standardize decibels across iOS (-60..0), Android (-2..10), and Web (0..1)
    double normalized;
    if (level < 0) {
      // Typically iOS / dBFS range (-60 dB to 0 dB)
      normalized = ((level + 60.0) / 60.0).clamp(0.0, 1.0);
    } else if (level <= 1.0) {
      // Normalized Web range
      normalized = level.clamp(0.0, 1.0);
    } else {
      // Android range (0.0 to 12.0+)
      normalized = (level / 10.0).clamp(0.0, 1.0);
    }

    // Apply exponential ease-out curve for natural visual bounce
    final eased = math.pow(normalized, 0.7).toDouble();
    normalizedSoundLevel.value = eased;
  }

  /// Handles speech engine status transitions
  void _handleStatus(String status) {
    if (_isDisposed) return;
    debugPrint('🎙️ [VoiceSearch] Engine Status: $status');

    if (status == 'listening') {
      if (voiceState.value != VoiceSearchState.recognized) {
        voiceState.value = VoiceSearchState.listening;
      }
    } else if (status == 'notListening' || status == 'done') {
      if (_isSubmitting) return;

      if (recognizedText.value.trim().isNotEmpty) {
        submitSearch(recognizedText.value);
      } else if (voiceState.value == VoiceSearchState.listening) {
        voiceState.value = VoiceSearchState.unrecognized;
      }
    }
  }

  /// Handles speech recognition engine errors gracefully
  void _handleError(SpeechRecognitionError error) {
    if (_isDisposed) return;
    debugPrint('🎙️ [VoiceSearch] Recognition Error: ${error.errorMsg} (permanent: ${error.permanent})');

    if (_isSubmitting) return;

    if (recognizedText.value.trim().isNotEmpty) {
      submitSearch(recognizedText.value);
      return;
    }

    if (error.errorMsg == 'error_permission') {
      voiceState.value = VoiceSearchState.permissionDenied;
      rxErrorMessage.value =
          'Microphone permission is required. Please grant permission to search by voice.';
    } else if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      voiceState.value = VoiceSearchState.unrecognized;
    } else {
      voiceState.value = VoiceSearchState.error;
      rxErrorMessage.value = "Didn't catch that. Tap the microphone to try again.";
    }
  }

  /// Stop listening manually
  Future<void> stopListening({bool promptUnrecognized = false}) async {
    _cancelTimers();
    try {
      await speech.stop();
    } catch (_) {}

    if (_isDisposed) return;
    normalizedSoundLevel.value = 0.0;

    if (recognizedText.value.trim().isNotEmpty) {
      submitSearch(recognizedText.value);
    } else if (promptUnrecognized) {
      voiceState.value = VoiceSearchState.unrecognized;
    }
  }

  /// Submit finalized query to search page and close modal
  void submitSearch(String query) {
    final cleanQuery = sanitizeQuery(query);
    if (cleanQuery.isEmpty || _isSubmitting || _isDisposed) return;

    _isSubmitting = true;
    _cancelTimers();
    voiceState.value = VoiceSearchState.submitting;

    try {
      speech.stop();
    } catch (_) {}

    // Short tactile pause before dismissing
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isDisposed) return;
      onSearch(cleanQuery);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Toggle or retry listening on tapping the center mic button
  void onMicButtonTapped() {
    if (voiceState.value == VoiceSearchState.listening ||
        voiceState.value == VoiceSearchState.recognized) {
      if (recognizedText.value.trim().isNotEmpty) {
        submitSearch(recognizedText.value);
      } else {
        stopListening(promptUnrecognized: true);
      }
    } else if (voiceState.value == VoiceSearchState.permissionDenied) {
      openAppSettings();
    } else {
      startListening();
    }
  }
}

/// Voice Search Dialog Widget
class VoiceSearchDialog extends StatelessWidget {
  const VoiceSearchDialog({required this.onSearch, super.key});
  final Function(String) onSearch;

  VoiceSearchController get controller => Get.find<VoiceSearchController>();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VoiceSearchController>(
      init: VoiceSearchController(onSearch: onSearch, context: context),
      dispose: (_) {
        if (Get.isRegistered<VoiceSearchController>()) {
          Get.delete<VoiceSearchController>();
        }
      },
      builder: (controller) {
        // Dark background color
        const darkBackground = Color(0xFF0F0F0F);

        return Scaffold(
          backgroundColor: darkBackground,
          body: SafeArea(
            child: Stack(
              children: [
                // Top App Bar with Close Button (Rule: icon must be white)
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Voice Search Title
                      Obx(() {
                        final currentState = controller.voiceState.value;
                        var headerText = 'Search with your voice';
                        if (currentState == VoiceSearchState.listening ||
                            currentState == VoiceSearchState.recognized) {
                          headerText = 'Listening...';
                        } else if (currentState == VoiceSearchState.submitting) {
                          headerText = 'Searching...';
                        }

                        return Text(
                          headerText,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),

                      // Close IconButton (Top Right)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          controller.stopListening();
                          Get.back();
                        },
                        splashRadius: 22,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Main Center & Bottom Area
                Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: Column(
                    children: [
                      // Center Spoken Query Display / Prompt View
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Obx(_buildCenterContent),
                          ),
                        ),
                      ),

                      // Bottom Section: Red Animated Mic Button & Locale Indicator
                      _buildBottomSection(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the main prompt / transcription view based on controller state
  Widget _buildCenterContent() {
    final currentState = controller.voiceState.value;
    final text = controller.recognizedText.value;

    switch (currentState) {
      case VoiceSearchState.initializing:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Listening...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );

      case VoiceSearchState.listening:
      case VoiceSearchState.recognized:
      case VoiceSearchState.submitting:
        if (text.isEmpty) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Listening...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Say something to search',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          );
        }

        return Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.35,
            letterSpacing: 0.1,
          ),
        );

      case VoiceSearchState.unrecognized:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Didn't hear that. Try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap the microphone to speak',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            // Sample suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: controller.suggestions.map((sug) {
                return ActionChip(
                  label: Text(
                    sug,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: const Color(0xFF272727),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onPressed: () {
                    controller.submitSearch(sug);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case VoiceSearchState.permissionDenied:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF272727),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_off_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Microphone access needed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                controller.rxErrorMessage.value.isNotEmpty
                    ? controller.rxErrorMessage.value
                    : 'To search by voice, please grant microphone permissions.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: openAppSettings,
              icon: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Open Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3EA6FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        );

      case VoiceSearchState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              controller.rxErrorMessage.value.isNotEmpty
                  ? controller.rxErrorMessage.value
                  : 'An error occurred during speech recognition.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: controller.initAndStartListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF272727),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
    }
  }

  /// Builds Animated Red Sound Wave Mic Button & Locale Badge
  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Red Pulsating Mic Button
        Obx(() {
          final currentState = controller.voiceState.value;
          final isListening = currentState == VoiceSearchState.listening ||
              currentState == VoiceSearchState.recognized;
          final soundValue = controller.normalizedSoundLevel.value;

          return GestureDetector(
            onTap: controller.onMicButtonTapped,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Wave Ring 3 (reacts to decibels + pulsate)
                  if (isListening)
                    AnimatedBuilder(
                      animation: controller.pulsateController,
                      builder: (context, child) {
                        final waveScale = 1.0 +
                            (soundValue * 0.45) +
                            (controller.pulsateController.value * 0.2);
                        return Transform.scale(
                          scale: waveScale,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF0000).withValues(
                                alpha: 0.12 + (soundValue * 0.1),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Middle Wave Ring 2
                  if (isListening)
                    AnimatedBuilder(
                      animation: controller.pulsateController,
                      builder: (context, child) {
                        final waveScale =
                            1.0 + (soundValue * 0.3) + (controller.pulsateController.value * 0.1);
                        return Transform.scale(
                          scale: waveScale,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF0000).withValues(
                                alpha: 0.22 + (soundValue * 0.15),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Inner Wave Ring 1
                  if (isListening)
                    Transform.scale(
                      scale: 1.0 + (soundValue * 0.18),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF0000).withValues(
                            alpha: 0.35 + (soundValue * 0.2),
                          ),
                        ),
                      ),
                    ),

                  // Center Red Microphone Action Button
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isListening
                          ? const Color(0xFFCC0000)
                          : const Color(0xFF272727),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isListening
                                  ? const Color(0xFFFF0000)
                                  : Colors.black)
                              .withValues(alpha: isListening ? 0.5 : 0.3),
                          blurRadius: isListening ? 16 : 8,
                          spreadRadius: isListening ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Spoken Language / Status Pill at bottom
        Obx(() {
          final locale = controller.activeLocaleName.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF212121),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  locale,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

