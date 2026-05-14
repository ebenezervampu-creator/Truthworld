// This file provides stubs for platform-specific view registration on non-web platforms.
// It is used to satisfy the compiler when conditional imports are used.

class PlatformViewRegistry {
  void registerViewFactory(String viewId, dynamic Function(int) viewFactory) {}
}

final platformViewRegistry = PlatformViewRegistry();





