import 'package:flutter/material.dart';

typedef LibraryLoader = Future<void> Function();
typedef WidgetBuilder = Widget Function();

class DeferredWidget extends StatefulWidget {
  final LibraryLoader loader;
  final WidgetBuilder builder;
  final Widget? placeholder;

  const DeferredWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.placeholder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  bool _loaded = false;
  LibraryLoader? _currentLoader;

  @override
  void initState() {
    super.initState();
    _currentLoader = widget.loader;
    _load();
  }

  @override
  void didUpdateWidget(DeferredWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loader != oldWidget.loader) {
      setState(() {
        _loaded = false;
        _currentLoader = widget.loader;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final loader = _currentLoader;
    if (loader == null) return;
    try {
      await loader();
      if (mounted && _currentLoader == loader) {
        setState(() {
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading deferred library: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) {
      return widget.builder();
    }
    return widget.placeholder ?? const Scaffold(
      backgroundColor: Color(0xFF0D0014),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF9B30FF),
        ),
      ),
    );
  }
}
