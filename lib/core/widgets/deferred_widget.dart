import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

typedef LibraryLoader = Future<void> Function();
typedef WidgetBuilder = Widget Function();

class DeferredWidgetController extends GetxController {
  DeferredWidgetController({required this.loader});

  final LibraryLoader loader;
  bool isLoaded = false;
  String? errorMessage;

  @override
  void onInit() {
    super.onInit();
    if (DeferredWidget._loadedLibraries.contains(loader)) {
      isLoaded = true;
    } else {
      load();
    }
  }

  Future<void> load() async {
    if (isLoaded) return;
    errorMessage = null;
    update();
    try {
      await loader();
      DeferredWidget._loadedLibraries.add(loader);
      isLoaded = true;
      update();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DeferredWidget.load',
      );
      errorMessage =
          'Failed to load screen component. Please check your connection.';
      update();
    }
  }
}

class DeferredWidget extends StatelessWidget {
  const DeferredWidget({
    required this.loader,
    required this.builder,
    super.key,
    this.placeholder,
  });

  final LibraryLoader loader;
  final WidgetBuilder builder;
  final Widget? placeholder;

  static final Set<LibraryLoader> _loadedLibraries = <LibraryLoader>{};

  /// Preload a deferred library in the background
  static Future<void> preload(LibraryLoader loader) async {
    if (!_loadedLibraries.contains(loader)) {
      await loader();
      _loadedLibraries.add(loader);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DeferredWidgetController>(
      init: DeferredWidgetController(loader: loader),
      global: false,
      builder: (controller) {
        if (controller.isLoaded) {
          return builder();
        }

        if (controller.errorMessage != null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0014),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: controller.load,
                      icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
                      label: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return placeholder ??
            const Scaffold(
              backgroundColor: Color(0xFF0D0014),
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.brand,
                ),
              ),
            );
      },
    );
  }
}
