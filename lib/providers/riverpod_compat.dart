import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 3.x 统一兼容层
///
/// 在 Riverpod 3.0 中，StateProvider、StateNotifierProvider 等历史 API 被统一归拢为
/// Notifier 与 NotifierProvider。本文件提供零性能损耗的桥接与辅助工具。

class StateController<T> extends Notifier<T> {
  StateController(this._init);
  final T Function(Ref ref) _init;

  @override
  T build() => _init(ref);

  @override
  set state(T value) => super.state = value;

  T update(T Function(T state) cb) => state = cb(state);
}

class _StateProviderFactory {
  const _StateProviderFactory();

  NotifierProvider<StateController<T>, T> call<T>(
    T Function(Ref ref) init, {
    String? name,
  }) {
    return NotifierProvider<StateController<T>, T>(
      () => StateController<T>(init),
      name: name,
    );
  }

  NotifierProvider<StateController<T>, T> autoDispose<T>(
    T Function(Ref ref) init, {
    String? name,
  }) {
    return NotifierProvider<StateController<T>, T>(
      () => StateController<T>(init),
      name: name,
    );
  }

  dynamic family<T, Arg>(
    T Function(Ref ref, Arg arg) init, {
    String? name,
  }) {
    return NotifierProvider.family<StateController<T>, T, Arg>(
      (arg) => StateController<T>((ref) => init(ref, arg)),
      name: name,
    );
  }
}

/// Riverpod 3.x 兼容 StateProvider
// ignore: constant_identifier_names
const StateProvider = _StateProviderFactory();
