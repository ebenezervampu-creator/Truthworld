import 'package:flutter/foundation.dart';

/// Sealed class hierarchy representing immutable UI events emitted by [BaseController].
///
/// Controllers emit events via the `uiEvents` stream without touching `Get.context`
/// or directly invoking UI framework side-effects (like `Get.snackbar`).
@immutable
abstract class UiEvent {
  const UiEvent();
}

/// Event to display a snackbar in the UI.
class UiEventShowSnackbar extends UiEvent {
  const UiEventShowSnackbar({
    required this.title,
    required this.message,
    this.isError = false,
    this.isWarning = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final bool isError;
  final bool isWarning;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Event to display a toast notification in the UI.
class UiEventShowToast extends UiEvent {
  const UiEventShowToast({
    required this.message,
    this.isShort = true,
  });

  final String message;
  final bool isShort;
}

/// Event to trigger route navigation.
class UiEventNavigate extends UiEvent {
  const UiEventNavigate({
    required this.routeName,
    this.arguments,
    this.replace = false,
    this.clearHistory = false,
  });

  final String routeName;
  final dynamic arguments;
  final bool replace;
  final bool clearHistory;
}

/// Event to trigger custom UI callbacks or dialogs.
class UiEventCustom<T> extends UiEvent {
  const UiEventCustom(this.payload);

  final T payload;
}
