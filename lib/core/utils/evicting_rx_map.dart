import 'package:get/get.dart';

/// A size-bounded [RxMap] implementation that automatically evicts the oldest
/// entries (Least Recently Used based on insertion/access order) when it exceeds [maxEntries].
/// Fully compatible drop-in replacement for GetX [RxMap].
class EvictingRxMap<K, V> extends RxMap<K, V> {
  final int maxEntries;

  EvictingRxMap({this.maxEntries = 1000}) : super(<K, V>{});

  @override
  void operator []=(K key, V value) {
    if (containsKey(key)) {
      remove(key);
    } else if (length >= maxEntries && isNotEmpty) {
      final oldestKey = keys.first;
      remove(oldestKey);
    }
    super[key] = value;
  }

  @override
  void addAll(Map<K, V> other) {
    other.forEach((key, value) {
      this[key] = value;
    });
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (containsKey(key)) {
      return this[key] as V;
    }
    final val = ifAbsent();
    this[key] = val;
    return val;
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    if (containsKey(key)) {
      final newVal = update(this[key] as V);
      this[key] = newVal;
      return newVal;
    } else {
      if (ifAbsent != null) {
        final newVal = ifAbsent();
        this[key] = newVal;
        return newVal;
      } else {
        throw ArgumentError.value(
          key,
          "key",
          "Key not in map and no ifAbsent parameter provided",
        );
      }
    }
  }
}
