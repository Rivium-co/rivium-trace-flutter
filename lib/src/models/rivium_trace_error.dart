import 'dart:math';

/// Represents an error captured by RiviumTrace
class RiviumTraceError {
  final String message;
  final String stackTrace;
  final String platform;
  final String environment;
  final String? release;
  final DateTime timestamp;
  final Map<String, dynamic>? extra;
  final Map<String, String>? tags;
  final String? url;

  /// Identifies this one event. An error that is sent again (for example a
  /// copy stored while offline) keeps its id, so the server counts it once.
  final String eventId;

  RiviumTraceError({
    required this.message,
    required this.stackTrace,
    required this.platform,
    required this.environment,
    this.release,
    required this.timestamp,
    this.extra,
    this.tags,
    this.url,
    String? eventId,
  }) : eventId = eventId ?? _newEventId();

  static final Random _random = Random.secure();

  /// A random UUID (version 4).
  static String _newEventId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Convert error to JSON for API transmission
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'message': message,
      'stack_trace': stackTrace,
      'platform': platform,
      'environment': environment,
      'timestamp': timestamp.toIso8601String(),
      'event_id': eventId,
    };

    if (release != null) {
      json['release_version'] = release;
    }

    // Add tags if present
    if (tags != null && tags!.isNotEmpty) {
      json['tags'] = tags;
    }

    // Extract breadcrumbs and url to root level
    if (extra != null && extra!.isNotEmpty) {
      final cleanExtra = Map<String, dynamic>.from(extra!);

      // Move breadcrumbs to root level (not nested in extra)
      if (cleanExtra.containsKey('breadcrumbs')) {
        json['breadcrumbs'] = cleanExtra.remove('breadcrumbs');
      }

      // Move url to root level if present in extra and not already set
      if (url == null && cleanExtra.containsKey('url')) {
        json['url'] = cleanExtra.remove('url');
      }

      // Only add extra if there's still data
      if (cleanExtra.isNotEmpty) {
        json['extra'] = cleanExtra;
      }
    }

    // Add url at root level
    if (url != null) {
      json['url'] = url;
    }

    return json;
  }

  @override
  String toString() {
    return 'RiviumTraceError(message: $message, platform: $platform, environment: $environment)';
  }
}
