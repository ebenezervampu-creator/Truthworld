import 'package:flutter/material.dart';
import 'package:get/get.dart';

typedef LibraryLoader = Future<void> Function();
typedef WidgetBuilder = Widget Function();

class DeferredWidget extends StatelessWidget {

  DeferredWidget({
    required this.loader, required this.builder, super.key,
    this.placeholder,
  }) {
    _load();
  }
  final LibraryLoader loader;
  final WidgetBuilder builder;
  final Widget? placeholder;

  final RxBool _loaded = false.obs;

  Future<void> _load() async {
    try {
      await loader();
      _loaded.value = true;
    } catch (e) {
      debugPrint('Error loading deferred library: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_loaded.value) {
        return builder();
      }
      return placeholder ?? const Scaffold(
        backgroundColor: Color(0xFF0D0014),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF9B30FF),
          ),
        ),
      );
    });
  }
}
