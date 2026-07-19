import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/src/internal/autocomplete_session_cache.dart';

void main() {
  test('reuses a transport token for the same logical session', () {
    final cache = AutocompleteSessionCache<String, String>();
    var creations = 0;

    final first = cache.tokenFor('session-1', () => 'token-${++creations}');
    final second = cache.tokenFor('session-1', () => 'token-${++creations}');

    expect(first, 'token-1');
    expect(second, same(first));
    expect(creations, 1);
  });

  test('replaces stale predictions and consumes the selected prediction', () {
    final cache = AutocompleteSessionCache<String, String>();
    cache.tokenFor('session-1', () => 'token-1');
    final firstRequest = cache.beginRequest('session-1');
    cache.beginPredictionSet('session-1', firstRequest);
    cache.putPrediction('session-1', 'place-1', 'prediction-1');
    cache.putPrediction('session-1', 'place-2', 'prediction-2');

    final secondRequest = cache.beginRequest('session-1');
    cache.beginPredictionSet('session-1', secondRequest);
    cache.putPrediction('session-1', 'place-3', 'prediction-3');

    expect(cache.takePrediction('session-1', 'place-1'), isNull);
    expect(cache.takePrediction('session-1', 'place-3'), 'prediction-3');
    expect(cache.takePrediction('session-1', 'place-3'), isNull);
  });

  test('does not let an older response replace newer predictions', () {
    final cache = AutocompleteSessionCache<String, String>();
    cache.tokenFor('session-1', () => 'token-1');
    final olderRequest = cache.beginRequest('session-1');
    final newerRequest = cache.beginRequest('session-1');

    expect(cache.beginPredictionSet('session-1', newerRequest), isTrue);
    cache.putPrediction('session-1', 'new-place', 'new-prediction');
    expect(cache.beginPredictionSet('session-1', olderRequest), isFalse);

    expect(cache.takePrediction('session-1', 'new-place'), 'new-prediction');
  });

  test('bounds sessions and predictions', () {
    final cache = AutocompleteSessionCache<String, String>(
      maxSessions: 2,
      maxPredictionsPerSession: 2,
    );
    cache.tokenFor('session-1', () => 'token-1');
    cache.tokenFor('session-2', () => 'token-2');
    cache.tokenFor('session-1', () => 'unused');
    cache.tokenFor('session-3', () => 'token-3');

    expect(cache.length, 2);
    expect(cache.takePrediction('session-2', 'missing'), isNull);
    expect(cache.tokenFor('session-2', () => 'replacement-2'), 'replacement-2');

    final request = cache.beginRequest('session-3');
    cache.beginPredictionSet('session-3', request);
    cache.putPrediction('session-3', 'place-1', 'prediction-1');
    cache.putPrediction('session-3', 'place-2', 'prediction-2');
    cache.putPrediction('session-3', 'place-3', 'prediction-3');

    expect(cache.takePrediction('session-3', 'place-1'), isNull);
    expect(cache.takePrediction('session-3', 'place-2'), 'prediction-2');
    expect(cache.takePrediction('session-3', 'place-3'), 'prediction-3');
  });

  test('expires inactive sessions and supports explicit cleanup', () {
    var now = DateTime.utc(2026, 7, 19, 12);
    final cache = AutocompleteSessionCache<String, String>(
      inactivityTimeout: const Duration(minutes: 5),
      now: () => now,
    );
    cache.tokenFor('session-1', () => 'token-1');
    now = now.add(const Duration(minutes: 6));

    expect(cache.length, 0);

    cache.tokenFor('session-2', () => 'token-2');
    cache.end('session-2');
    expect(cache.length, 0);

    cache.tokenFor('session-3', () => 'token-3');
    cache.clear();
    expect(cache.length, 0);
  });
}
