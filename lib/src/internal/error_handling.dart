import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/place_models.dart';
import '../places_cancellation_token.dart';

Future<T> runPlacesOperation<T>({
  required PlacesOperation operation,
  required Duration timeout,
  required Future<T> Function() action,
  PlacesErrorKind fallbackKind = PlacesErrorKind.unknown,
  PlacesCancellationToken? cancellationToken,
}) async {
  if (timeout <= Duration.zero) {
    throw const PlacesException.configuration(
      'requestTimeout must be greater than zero.',
      code: 'invalid_request_timeout',
    );
  }
  cancellationToken?.throwIfCancelled(operation);
  void Function()? detachCancellation;
  try {
    final operationFuture = action();
    if (cancellationToken == null) {
      return await operationFuture.timeout(timeout);
    }
    // A reused token must not accumulate one retained closure per operation,
    // so the listener is detached in the finally below.
    final cancelled = Completer<T>();
    detachCancellation = cancellationToken.addCancellationListener(() {
      if (cancelled.isCompleted) {
        return;
      }
      cancelled.completeError(
        PlacesException(
          'The Places operation was cancelled.',
          kind: PlacesErrorKind.cancellation,
          code: 'request_cancelled',
          operation: operation,
        ),
        StackTrace.current,
      );
    });
    return await Future.any<T>(<Future<T>>[
      operationFuture,
      cancelled.future,
    ]).timeout(timeout);
  } on PlacesException {
    rethrow;
  } on TimeoutException {
    throw PlacesException(
      'The Places operation timed out.',
      kind: PlacesErrorKind.timeout,
      code: 'request_timeout',
      retryable: true,
      operation: operation,
      metadata: <String, Object?>{
        'timeoutMilliseconds': timeout.inMilliseconds,
      },
    );
  } on http.ClientException {
    throw PlacesException(
      'The Places network request failed.',
      kind: PlacesErrorKind.network,
      code: 'network_failure',
      retryable: true,
      operation: operation,
    );
  } catch (error) {
    throw PlacesException(
      _fallbackMessage(fallbackKind),
      kind: fallbackKind,
      code: '${fallbackKind.name}_failure',
      operation: operation,
      metadata: <String, Object?>{'errorType': error.runtimeType.toString()},
    );
  } finally {
    detachCancellation?.call();
  }
}

Future<http.Response> sendPlacesHttpRequest({
  required http.Client client,
  required String method,
  required Uri uri,
  required Map<String, String> headers,
  String? body,
  required PlacesOperation operation,
  required Duration timeout,
  PlacesCancellationToken? cancellationToken,
}) async {
  if (timeout <= Duration.zero) {
    throw const PlacesException.configuration(
      'requestTimeout must be greater than zero.',
      code: 'invalid_request_timeout',
    );
  }
  cancellationToken?.throwIfCancelled(operation);
  final abort = Completer<void>();
  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    if (!abort.isCompleted) {
      abort.complete();
    }
  });
  // A reused token must not accumulate one retained closure per request, so
  // the listener is detached in the finally below.
  final detachCancellation = cancellationToken?.addCancellationListener(() {
    if (!abort.isCompleted) {
      abort.complete();
    }
  });
  final request = http.AbortableRequest(method, uri, abortTrigger: abort.future)
    ..headers.addAll(headers);
  if (body != null) {
    request.body = body;
  }
  Never throwAbortReason() {
    if (cancellationToken?.isCancelled ?? false) {
      throw PlacesException(
        'The Places operation was cancelled.',
        kind: PlacesErrorKind.cancellation,
        code: 'request_cancelled',
        operation: operation,
      );
    }
    if (timedOut) {
      throw PlacesException(
        'The Places operation timed out.',
        kind: PlacesErrorKind.timeout,
        code: 'request_timeout',
        retryable: true,
        operation: operation,
        metadata: <String, Object?>{
          'timeoutMilliseconds': timeout.inMilliseconds,
        },
      );
    }
    throw PlacesException(
      'The Places operation was cancelled.',
      kind: PlacesErrorKind.cancellation,
      code: 'request_cancelled',
      operation: operation,
    );
  }

  try {
    final streamed =
        await Future.any<http.StreamedResponse>(<Future<http.StreamedResponse>>[
          client.send(request),
          abort.future.then<http.StreamedResponse>((_) => throwAbortReason()),
        ]);
    return await Future.any<http.Response>(<Future<http.Response>>[
      http.Response.fromStream(streamed),
      abort.future.then<http.Response>((_) => throwAbortReason()),
    ]);
  } on http.RequestAbortedException {
    throwAbortReason();
  } on PlacesException {
    rethrow;
  } on http.ClientException {
    throw PlacesException(
      'The Places network request failed.',
      kind: PlacesErrorKind.network,
      code: 'network_failure',
      retryable: true,
      operation: operation,
    );
  } finally {
    timer.cancel();
    detachCancellation?.call();
  }
}

String _fallbackMessage(PlacesErrorKind kind) => switch (kind) {
  PlacesErrorKind.javascript => 'The Maps JavaScript operation failed.',
  PlacesErrorKind.proxy => 'The configured Places proxy operation failed.',
  PlacesErrorKind.network => 'The Places network request failed.',
  _ => 'The Places operation failed.',
};
