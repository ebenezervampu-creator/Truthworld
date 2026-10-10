import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Clean Architecture Abstract Reactive Property Contract.
///
/// Decouples view models and presentation controllers from specific state
/// management engines (GetX Rx, Bloc Cubit, or Flutter ValueNotifier),
/// allowing swapping reactive backends without touching controller public APIs.
abstract class IReactiveProperty<T> implements Listenable {
  /// Current synchronous value.
  T get value;

  /// Update the current value and notify subscribers.
  set value(T newValue);

  /// Reactive stream of state changes.
  Stream<T> get stream;

  /// Transform state atomically with a mutator function.
  void update(T Function(T current) updater);

  /// Dispose any underlying listeners or controllers.
  void dispose();
}

/// GetX implementation of [IReactiveProperty] backed by [Rx].
class RxReactiveProperty<T> implements IReactiveProperty<T> {
  final Rx<T> _rx;
  final List<VoidCallback> _listeners = [];
  StreamSubscription<T>? _sub;

  RxReactiveProperty(T initialValue) : _rx = Rx<T>(initialValue) {
    _sub = _rx.stream.listen((_) {
      for (final l in List<VoidCallback>.from(_listeners)) {
        l();
      }
    });
  }

  RxReactiveProperty.fromRx(Rx<T> rx) : _rx = rx {
    _sub = _rx.stream.listen((_) {
      for (final l in List<VoidCallback>.from(_listeners)) {
        l();
      }
    });
  }

  @override
  T get value => _rx.value;

  @override
  set value(T newValue) {
    _rx.value = newValue;
  }

  @override
  Stream<T> get stream => _rx.stream;

  @override
  void update(T Function(T current) updater) {
    _rx.value = updater(_rx.value);
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _listeners.clear();
    _rx.close();
  }

  /// Direct access to underlying Rx when working inside native GetX widgets.
  Rx<T> get rx => _rx;
}

/// Pure Flutter [ValueNotifier] implementation of [IReactiveProperty]
/// (100% agnostic of GetX, proves state engine swappability).
class ValueNotifierReactiveProperty<T> implements IReactiveProperty<T> {
  final ValueNotifier<T> _notifier;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  ValueNotifierReactiveProperty(T initialValue)
      : _notifier = ValueNotifier<T>(initialValue) {
    _notifier.addListener(() {
      if (!_controller.isClosed) {
        _controller.add(_notifier.value);
      }
    });
  }

  @override
  T get value => _notifier.value;

  @override
  set value(T newValue) {
    _notifier.value = newValue;
  }

  @override
  Stream<T> get stream => _controller.stream;

  @override
  void update(T Function(T current) updater) {
    _notifier.value = updater(_notifier.value);
  }

  @override
  void addListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  @override
  void dispose() {
    _notifier.dispose();
    _controller.close();
  }
}

/// Convenience factory for instantiating reactive properties.
IReactiveProperty<T> createReactiveProperty<T>(T initialValue, {bool useGetX = true}) {
  return useGetX
      ? RxReactiveProperty<T>(initialValue)
      : ValueNotifierReactiveProperty<T>(initialValue);
}

/// Extension helper on standard values.
extension ReactivePropertyExtension<T> on T {
  IReactiveProperty<T> toReactiveProperty({bool useGetX = true}) {
    return createReactiveProperty<T>(this, useGetX: useGetX);
  }
}
