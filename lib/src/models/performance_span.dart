/// Performance span model for APM tracking
class PerformanceSpan {
  /// Unique trace identifier
  final String? traceId;

  /// Unique span identifier
  final String? spanId;

  /// Parent span ID for nested spans
  final String? parentSpanId;

  /// Operation name (e.g., "GET /api/users", "SELECT users")
  final String operation;

  /// Type of operation (http, db, custom)
  final String operationType;

  /// HTTP method (GET, POST, etc.)
  final String? httpMethod;

  /// Full HTTP URL
  final String? httpUrl;

  /// HTTP response status code
  final int? httpStatusCode;

  /// HTTP host
  final String? httpHost;

  /// Duration in milliseconds
  final double durationMs;

  /// When the operation started
  final DateTime startTime;

  /// When the operation ended
  final DateTime? endTime;

  /// Platform (flutter, web, android, ios)
  final String? platform;

  /// Environment (production, staging, development)
  final String? environment;

  /// Release version
  final String? releaseVersion;

  /// Custom tags
  final Map<String, String>? tags;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Status of the span (ok, error)
  final String status;

  /// Error message if status is error
  final String? errorMessage;

  PerformanceSpan({
    this.traceId,
    this.spanId,
    this.parentSpanId,
    required this.operation,
    this.operationType = 'http',
    this.httpMethod,
    this.httpUrl,
    this.httpStatusCode,
    this.httpHost,
    required this.durationMs,
    required this.startTime,
    this.endTime,
    this.platform,
    this.environment,
    this.releaseVersion,
    this.tags,
    this.metadata,
    this.status = 'ok',
    this.errorMessage,
  });

  /// Create a span from an HTTP request
  factory PerformanceSpan.fromHttpRequest({
    required String method,
    required String url,
    required DateTime startTime,
    required double durationMs,
    int? statusCode,
    String? errorMessage,
    String? platform,
    String? environment,
    String? releaseVersion,
    Map<String, String>? tags,
  }) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final host = uri?.host;

    return PerformanceSpan(
      operation: '$method $path',
      operationType: 'http',
      httpMethod: method,
      httpUrl: url,
      httpStatusCode: statusCode,
      httpHost: host,
      durationMs: durationMs,
      startTime: startTime,
      endTime: DateTime.now(),
      platform: platform,
      environment: environment,
      releaseVersion: releaseVersion,
      tags: tags,
      status: errorMessage != null || (statusCode != null && statusCode >= 400)
          ? 'error'
          : 'ok',
      errorMessage: errorMessage,
    );
  }

  /// Create a span for a database query
  factory PerformanceSpan.forDbQuery({
    required String queryType,
    String? tableName,
    required DateTime startTime,
    required double durationMs,
    int? rowsAffected,
    String? errorMessage,
    String? platform,
    String? environment,
    String? releaseVersion,
  }) {
    final operation = tableName != null ? '$queryType $tableName' : queryType;

    return PerformanceSpan(
      operation: operation,
      operationType: 'db',
      durationMs: durationMs,
      startTime: startTime,
      endTime: DateTime.now(),
      platform: platform,
      environment: environment,
      releaseVersion: releaseVersion,
      metadata: rowsAffected != null ? {'rows_affected': rowsAffected} : null,
      status: errorMessage != null ? 'error' : 'ok',
      errorMessage: errorMessage,
    );
  }

  /// Create a custom span
  factory PerformanceSpan.custom({
    required String operation,
    required DateTime startTime,
    required double durationMs,
    String? errorMessage,
    String? platform,
    String? environment,
    String? releaseVersion,
    Map<String, String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return PerformanceSpan(
      operation: operation,
      operationType: 'custom',
      durationMs: durationMs,
      startTime: startTime,
      endTime: DateTime.now(),
      platform: platform,
      environment: environment,
      releaseVersion: releaseVersion,
      tags: tags,
      metadata: metadata,
      status: errorMessage != null ? 'error' : 'ok',
      errorMessage: errorMessage,
    );
  }

  /// Convert to JSON map for API submission
  Map<String, dynamic> toJson() {
    return {
      if (traceId != null) 'trace_id': traceId,
      if (spanId != null) 'span_id': spanId,
      if (parentSpanId != null) 'parent_span_id': parentSpanId,
      'operation': operation,
      'operation_type': operationType,
      if (httpMethod != null) 'http_method': httpMethod,
      if (httpUrl != null) 'http_url': httpUrl,
      if (httpStatusCode != null) 'http_status_code': httpStatusCode,
      if (httpHost != null) 'http_host': httpHost,
      'duration_ms': durationMs,
      'start_time': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toUtc().toIso8601String(),
      if (platform != null) 'platform': platform,
      if (environment != null) 'environment': environment,
      if (releaseVersion != null) 'release_version': releaseVersion,
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
      'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }

  @override
  String toString() {
    return 'PerformanceSpan(operation: $operation, type: $operationType, duration: ${durationMs}ms, status: $status)';
  }
}
