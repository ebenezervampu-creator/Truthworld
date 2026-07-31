import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:truthworld/theme/app_theme.dart';

class VoiceSearchController extends GetxController
    with GetSingleTickerProviderStateMixin {
  VoiceSearchController({required this.onSearch, required this.context});
  final Function(String) onSearch;
  final BuildContext context;

  final stt.SpeechToText speech = stt.SpeechToText();
  final RxBool isInitialized = false.obs;
  final RxBool isListening = false.obs;
  final RxString text = 'Listening...'.obs;
  final RxDouble soundLevel = 0.0.obs;
  final RxString errorMessage = ''.obs;
  late AnimationController pulsateController;
  bool _isSubmitting = false;

  @override
  void onInit() {
    super.onInit();
    pulsateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initSpeech();
  }

  @override
  void onClose() {
    speech.cancel();
    pulsateController.dispose();
    super.onClose();
  }

  bool _isValidSpeechText(String str) {
    final trimmed = str.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == 'Listening...') return false;
    if (trimmed == 'Try saying something...') return false;
    if (trimmed.startsWith("Didn't catch")) return false;
    if (trimmed.startsWith('Permission')) return false;
    if (trimmed.startsWith('Voice search')) return false;
    if (trimmed.startsWith('Speech recognition')) return false;
    return true;
  }

  Future<void> _initSpeech() async {
    try {
      final available = await speech.initialize(
        onStatus: (status) {
          debugPrint('🎙️ [VoiceSearch] Status: $status');
          if (status == 'listening') {
            isListening.value = true;
          } else if (status == 'notListening' || status == 'done') {
            isListening.value = false;
            if (_isValidSpeechText(text.value)) {
              _submitSearch();
            } else if (text.value == 'Listening...') {
              text.value = "Didn't catch that. Tap mic to try again.";
            }
          }
        },
        onError: (SpeechRecognitionError error) {
          debugPrint(
            '🎙️ [VoiceSearch] Error: ${error.errorMsg} - permanent: ${error.permanent}',
          );
          isListening.value = false;
          if (_isValidSpeechText(text.value)) {
            _submitSearch();
            return;
          }
          if (error.errorMsg == 'error_permission') {
            errorMessage.value =
                'Microphone permission is required for voice search. Please enable it in device settings.';
            text.value = 'Permission denied.';
          } else if (error.errorMsg == 'error_speech_timeout' ||
              error.errorMsg == 'error_no_match') {
            errorMessage.value = '';
            text.value = "Didn't catch that. Tap mic to try again.";
          } else {
            errorMessage.value = 'Speech recognition error: ${error.errorMsg}';
            text.value = "Didn't catch that. Tap mic to try again.";
          }
        },
      );

      isInitialized.value = available;
      if (available) {
        startListening();
      } else {
        text.value = 'Voice search is not available on this device.';
      }
    } catch (e) {
      debugPrint('🎙️ [VoiceSearch] Exception in init: $e');
      text.value = 'Speech recognition initialization failed.';
      errorMessage.value = e.toString();
    }
  }

  Future<void> startListening() async {
    _isSubmitting = false;
    if (!isInitialized.value) {
      await _initSpeech();
      return;
    }

    text.value = 'Listening...';
    errorMessage.value = '';
    soundLevel.value = 0.0;

    try {
      if (speech.isListening) {
        await speech.stop();
      }

      await speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.recognizedWords.isNotEmpty) {
            text.value = result.recognizedWords;
          }
          if (result.finalResult) {
            _submitSearch();
          }
        },
        onSoundLevelChange: (level) {
          soundLevel.value = level;
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 5),
          listenMode: stt.ListenMode.search,
        ),
      );
      isListening.value = true;
    } catch (e) {
      debugPrint('🎙️ [VoiceSearch] Exception in listen: $e');
      isListening.value = false;
      if (_isValidSpeechText(text.value)) {
        _submitSearch();
      } else {
        text.value = "Didn't catch that. Tap mic to try again.";
      }
    }
  }

  Future<void> stopListening() async {
    await speech.stop();
    isListening.value = false;
  }

  void _submitSearch() {
    if (_isSubmitting) return;
    if (_isValidSpeechText(text.value)) {
      _isSubmitting = true;
      speech.stop();
      isListening.value = false;
      Future.delayed(const Duration(milliseconds: 350), () {
        onSearch(text.value.trim());
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }
}

class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({required this.onSearch, super.key});
  final Function(String) onSearch;

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog> {
  late final VoiceSearchController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      VoiceSearchController(onSearch: widget.onSearch, context: context),
    );
  }

  @override
  void dispose() {
    Get.delete<VoiceSearchController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage.withValues(alpha: 0.85),
      body: SafeArea(
        child: Stack(
          children: [
            // Close Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: () {
                  controller.stopListening();
                  Navigator.of(context).pop();
                },
              ),
            ),

            // Main layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  // Title / Status Instruction
                  Obx(
                    () => Text(
                      controller.isListening.value
                          ? 'Search with voice'
                          : 'Tap mic to try again',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Transcribed text display
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Obx(() {
                          final t = controller.text.value;
                          return Text(
                            t,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  (t == 'Listening...' ||
                                      t.startsWith("Didn't catch") ||
                                      t.startsWith('Permission'))
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // Error message fallback
                  Obx(() {
                    final err = controller.errorMessage.value;
                    if (err.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        err,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }),

                  // Pulsating animated Mic Button
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        if (controller.isListening.value) {
                          controller.stopListening();
                        } else {
                          controller.startListening();
                        }
                      },
                      child: Obx(() {
                        final isListening = controller.isListening.value;
                        final soundScale =
                            1.0 +
                            (controller.soundLevel.value.clamp(0.0, 10.0) /
                                    10.0) *
                                0.7;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer ripple ring (only if listening)
                            if (isListening)
                              AnimatedBuilder(
                                animation: controller.pulsateController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale:
                                        soundScale *
                                        (1.0 +
                                            controller.pulsateController.value *
                                                0.15),
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // Inner sound wave bubble (only if listening)
                            if (isListening)
                              Transform.scale(
                                scale: soundScale,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.25,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),

                            // Main red center button
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: isListening
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isListening
                                                ? AppColors.error
                                                : AppColors.bgPage)
                                            .withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isListening
                                    ? Icons.mic
                                    : Icons.mic_off_outlined,
                                color: AppColors.textPrimary,
                                size: 32,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
