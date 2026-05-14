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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.loader();
    if (mounted) {
      setState(() {
        _loaded = true;
      });
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
