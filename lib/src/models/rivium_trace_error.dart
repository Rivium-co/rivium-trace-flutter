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

  const RiviumTraceError({
    required this.message,
    required this.stackTrace,
    required this.platform,
    required this.environment,
    this.release,
    required this.timestamp,
    this.extra,
    this.tags,
    this.url,
  });

  /// Convert error to JSON for API transmission
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'message': message,
      'stack_trace': stackTrace,
      'platform': platform,
      'environment': environment,
      'timestamp': timestamp.toIso8601String(),
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
