import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/place_models.dart';

/// A cooperative cancellation signal for a Places operation.
///
/// Pass the same token to a client method and call [cancel] when its result is
/// no longer needed. HTTP transports abort the underlying request; JavaScript
/// operations suppress late results and complete with a typed cancellation
/// error.
class PlacesCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  final List<void Function()> _listeners = <void Function()>[];

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when the token is cancelled.
  Future<void> get whenCancelled => _cancelled.future;

  /// Cancels work associated with this token.
  ///
  /// Calling this method more than once has no effect.
  void cancel() {
    if (_cancelled.isCompleted) {
      return;
    }
    _cancelled.complete();
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Registers [listener] to run once when this token is cancelled, and
  /// returns a function that detaches it.
  ///
  /// A token may be reused across many requests, so every caller must detach
  /// its listener when its own work finishes. Otherwise the token accumulates
  /// one retained closure per request issued.
  ///
  /// If the token is already cancelled, [listener] runs synchronously and the
  /// returned function does nothing.
  ///
  /// Prefer this over `whenCancelled.then(...)`, which cannot be detached and
  /// therefore retains one closure per call for the lifetime of the token.
  void Function() addCancellationListener(void Function() listener) {
    if (isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    var removed = false;
    return () {
      if (removed) {
        return;
      }
      removed = true;
      _listeners.remove(listener);
    };
  }

  /// Number of attached cancellation listeners. Test-only.
  @visibleForTesting
  int get debugListenerCount => _listeners.length;

  /// Throws the package's typed cancellation error when already cancelled.
  void throwIfCancelled(PlacesOperation operation) {
    if (isCancelled) {
      throw PlacesException(
        'The Places operation was cancelled.',
        kind: PlacesErrorKind.cancellation,
        code: 'request_cancelled',
        operation: operation,
      );
    }
  }
}
