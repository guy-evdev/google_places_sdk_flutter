import 'dart:collection';

/// Bounded, expiring cache for transport-specific autocomplete session state.
class AutocompleteSessionCache<TToken, TPrediction> {
  AutocompleteSessionCache({
    this.maxSessions = 32,
    this.maxPredictionsPerSession = 5,
    this.inactivityTimeout = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxSessions;
  final int maxPredictionsPerSession;
  final Duration inactivityTimeout;
  final DateTime Function() _now;
  final LinkedHashMap<String, _AutocompleteSessionEntry<TToken, TPrediction>>
  _entries =
      LinkedHashMap<String, _AutocompleteSessionEntry<TToken, TPrediction>>();

  /// Number of live sessions, exposed for deterministic regression tests.
  int get length {
    _pruneExpired();
    return _entries.length;
  }

  /// Returns the transport token for [sessionValue], creating it if needed.
  TToken tokenFor(String sessionValue, TToken Function() createToken) {
    _pruneExpired();
    final existing = _entries.remove(sessionValue);
    if (existing != null) {
      existing.lastTouched = _now();
      _entries[sessionValue] = existing;
      return existing.token;
    }

    while (_entries.length >= maxSessions && _entries.isNotEmpty) {
      _entries.remove(_entries.keys.first);
    }
    final entry = _AutocompleteSessionEntry<TToken, TPrediction>(
      token: createToken(),
      lastTouched: _now(),
    );
    _entries[sessionValue] = entry;
    return entry.token;
  }

  /// Registers an autocomplete request and returns its session generation.
  int beginRequest(String sessionValue) {
    final entry = _touch(sessionValue);
    if (entry == null) {
      throw StateError(
        'Create the transport token before beginning a session request.',
      );
    }
    return ++entry.latestRequestGeneration;
  }

  /// Replaces predictions only when [generation] is the latest request.
  bool beginPredictionSet(String sessionValue, int generation) {
    final entry = _touch(sessionValue);
    if (entry == null || entry.latestRequestGeneration != generation) {
      return false;
    }
    entry.predictions.clear();
    return true;
  }

  /// Caches one prediction from the latest response for a session.
  void putPrediction(
    String sessionValue,
    String placeId,
    TPrediction prediction,
  ) {
    final entry = _touch(sessionValue);
    if (entry == null || placeId.isEmpty) {
      return;
    }
    if (!entry.predictions.containsKey(placeId) &&
        entry.predictions.length >= maxPredictionsPerSession) {
      entry.predictions.remove(entry.predictions.keys.first);
    }
    entry.predictions[placeId] = prediction;
  }

  /// Removes and returns the prediction matching a selected place.
  TPrediction? takePrediction(String sessionValue, String placeId) {
    final entry = _touch(sessionValue);
    return entry?.predictions.remove(placeId);
  }

  /// Discards all state for a concluded or abandoned session.
  void end(String sessionValue) {
    _entries.remove(sessionValue);
  }

  /// Discards all cached sessions.
  void clear() {
    _entries.clear();
  }

  _AutocompleteSessionEntry<TToken, TPrediction>? _touch(String sessionValue) {
    _pruneExpired();
    final entry = _entries.remove(sessionValue);
    if (entry == null) {
      return null;
    }
    entry.lastTouched = _now();
    _entries[sessionValue] = entry;
    return entry;
  }

  void _pruneExpired() {
    final cutoff = _now().subtract(inactivityTimeout);
    _entries.removeWhere((_, entry) => entry.lastTouched.isBefore(cutoff));
  }
}

class _AutocompleteSessionEntry<TToken, TPrediction> {
  _AutocompleteSessionEntry({required this.token, required this.lastTouched});

  final TToken token;
  DateTime lastTouched;
  int latestRequestGeneration = 0;
  final LinkedHashMap<String, TPrediction> predictions =
      LinkedHashMap<String, TPrediction>();
}
