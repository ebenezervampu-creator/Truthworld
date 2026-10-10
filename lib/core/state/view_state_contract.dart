import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/base/ui_event.dart';
import 'package:truthworld/core/state/reactive_property.dart';

/// Clean Architecture Presentation State Controller Contract.
///
/// Decouples UI screens from concrete GetX BaseController classes,
/// allowing any view to bind against an abstract state controller contract.
abstract class IStateController {
  /// Reactive property for current lifecycle and async state.
  IReactiveProperty<ViewState> get rxViewState;

  /// Current synchronous view state.
  ViewState get state;

  /// Human-readable error message, if in error state.
  String get errorMessage;

  /// Convenience flags.
  bool get isLoading;
  bool get isRefreshing;
  bool get isPaginationLoading;
  bool get isError;
  bool get isEmpty;
  bool get isSuccess;
  bool get isOffline;
  bool get isCancelled;

  /// Stream of one-off UI events (snackbars, dialogs, navigation).
  Stream<UiEvent> get uiEvents;

  /// Emit an event to the presentation layer.
  void emitUiEvent(UiEvent event);

  /// Transition to a new view state.
  void setViewState(ViewState state);

  /// Transition to error state with message.
  void setError(String message);

  /// Clear active error state.
  void clearError();
}
