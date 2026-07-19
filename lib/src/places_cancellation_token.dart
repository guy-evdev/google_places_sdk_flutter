import 'dart:async';

import 'models/place_models.dart';

/// A cooperative cancellation signal for a Places operation.
///
/// Pass the same token to a client method and call [cancel] when its result is
/// no longer needed. HTTP transports abort the underlying request; JavaScript
/// operations suppress late results and complete with a typed cancellation
/// error.
class PlacesCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when the token is cancelled.
  Future<void> get whenCancelled => _cancelled.future;

  /// Cancels work associated with this token.
  ///
  /// Calling this method more than once has no effect.
  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

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
