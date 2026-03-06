import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/performance_span.dart';
import '../constants/rivium_trace_constants.dart';
import '../services/rivium_trace_logger.dart';

/// Helper class for tracking performance of custom operations
///
/// Usage:
/// ```dart
/// // Manual tracking
/// final tracker = PerformanceTracker(
///   operation: 'processPayment',
///   apiKey: 'your-api-key',
/// );
/// // ... perform operation
/// tracker.finish(status: SpanStatus.ok);
///
/// // Automatic tracking with closure
/// await PerformanceTracker.track(
///   'fetchUserProfile',
///   apiKey: 'your-api-key',
///   block: () async => await api.fetchProfile(),
/// );
/// ```
class PerformanceTracker {
  final String _operation;
  final String _operationType;
  final String _apiKey;
  final DateTime _startTime;
  final String? _environment;
  final String? _releaseVersion;
  final String? _platform;

  final Map<String, String> _tags = {};
  final Map<String, dynamic> _metadata = {};
  String? _httpMethod;
  String? _httpUrl;
  String? _httpHost;

  bool _finished = false;

  /// Create a new performance tracker
  ///
  /// [operation] - Name of the operation being tracked
  /// [apiKey] - RiviumTrace API key
  /// [operationType] - Type of operation (http, db, custom)
  /// [environment] - Environment name
  /// [releaseVersion] - App version
  /// [platform] - Platform name
  PerformanceTracker({
    required String operation,
    required String apiKey,
    String operationType = 'custom',
    String? environment,
    String? releaseVersion,
    String? platform,
  })  : _operation = operation,
        _operationType = operationType,
        _apiKey = apiKey,
        _startTime = DateTime.now(),
        _environment = environment,
        _releaseVersion = releaseVersion,
        _platform = platform;

  /// Create a tracker for an HTTP request
  factory PerformanceTracker.forHttpRequest({
    required String method,
    required String url,
    required String apiKey,
    String? environment,
    String? releaseVersion,
    String? platform,
  }) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;

    final tracker = PerformanceTracker(
      operation: '$method $path',
      apiKey: apiKey,
      operationType: 'http',
      environment: environment,
      releaseVersion: releaseVersion,
      platform: platform,
    );

    tracker._httpMethod = method;
    tracker._httpUrl = url;
    tracker._httpHost = uri?.host;

    return tracker;
  }

  /// Create a tracker for a database query
  factory PerformanceTracker.forDbQuery({
    required String queryType,
    required String apiKey,
    String? tableName,
    String? environment,
    String? releaseVersion,
    String? platform,
  }) {
    final operation = tableName != null ? '$queryType $tableName' : queryType;

    return PerformanceTracker(
      operation: operation,
      apiKey: apiKey,
      operationType: 'db',
      environment: environment,
      releaseVersion: releaseVersion,
      platform: platform,
    );
  }

  /// Add a tag to the span
  void setTag(String key, String value) {
    _tags[key] = value;
  }

  /// Add metadata to the span
  void setMetadata(String key, dynamic value) {
    _metadata[key] = value;
  }

  /// Set HTTP-specific details
  void setHttpDetails({
    required String method,
    required String url,
    String? host,
  }) {
    _httpMethod = method;
    _httpUrl = url;
    _httpHost = host ?? Uri.tryParse(url)?.host;
  }

  /// Finish tracking and report the span
  ///
  /// [status] - Final status of the operation
  /// [statusCode] - HTTP status code (for HTTP operations)
  /// [errorMessage] - Error message if status is error
  Future<void> finish({
    SpanStatus status = SpanStatus.ok,
    int? statusCode,
    String? errorMessage,
  }) async {
    if (_finished) {
      RiviumTraceLogger.warning('PerformanceTracker.finish() called multiple times');
      return;
    }
    _finished = true;

    final durationMs = DateTime.now().difference(_startTime).inMilliseconds.toDouble();

    final span = PerformanceSpan(
      operation: _operation,
      operationType: _operationType,
      httpMethod: _httpMethod,
      httpUrl: _httpUrl,
      httpStatusCode: statusCode,
      httpHost: _httpHost,
      durationMs: durationMs,
      startTime: _startTime,
      endTime: DateTime.now(),
      platform: _platform,
      environment: _environment,
      releaseVersion: _releaseVersion,
      tags: _tags.isNotEmpty ? _tags : null,
      metadata: _metadata.isNotEmpty ? _metadata : null,
      status: status.value,
      errorMessage: errorMessage,
    );

    await _sendSpan(span);
  }

  /// Finish with an error
  Future<void> finishWithError(Object error, {int? statusCode}) async {
    await finish(
      status: SpanStatus.error,
      statusCode: statusCode,
      errorMessage: error.toString(),
    );
  }

  Future<void> _sendSpan(PerformanceSpan span) async {
    try {
      final response = await http.post(
        Uri.parse('${RiviumTraceConstants.apiUrl}/api/performance/spans'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
          'User-Agent': 'RiviumTrace-SDK/${RiviumTraceConstants.sdkVersion} (${_platform ?? 'flutter'}; ${_releaseVersion ?? 'unknown'})',
        },
        body: jsonEncode(span.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        RiviumTraceLogger.debug('Performance span sent: ${span.operation}');
      } else {
        RiviumTraceLogger.warning(
          'Failed to send span: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      RiviumTraceLogger.error('Failed to send performance span', e);
    }
  }

  // === Static Helpers ===

  /// Track an operation with automatic timing
  ///
  /// [operation] - Name of the operation
  /// [apiKey] - RiviumTrace API key
  /// [operationType] - Type of operation
  /// [block] - The operation to perform
  static Future<T> track<T>({
    required String operation,
    required String apiKey,
    String operationType = 'custom',
    String? environment,
    String? releaseVersion,
    String? platform,
    required Future<T> Function() block,
  }) async {
    final tracker = PerformanceTracker(
      operation: operation,
      apiKey: apiKey,
      operationType: operationType,
      environment: environment,
      releaseVersion: releaseVersion,
      platform: platform,
    );

    try {
      final result = await block();
      await tracker.finish(status: SpanStatus.ok);
      return result;
    } catch (e) {
      await tracker.finishWithError(e);
      rethrow;
    }
  }

  /// Track a synchronous operation with automatic timing
  static T trackSync<T>({
    required String operation,
    required String apiKey,
    String operationType = 'custom',
    String? environment,
    String? releaseVersion,
    String? platform,
    required T Function() block,
  }) {
    final tracker = PerformanceTracker(
      operation: operation,
      apiKey: apiKey,
      operationType: operationType,
      environment: environment,
      releaseVersion: releaseVersion,
      platform: platform,
    );

    try {
      final result = block();
      // Fire and forget - don't await
      tracker.finish(status: SpanStatus.ok);
      return result;
    } catch (e) {
      tracker.finishWithError(e);
      rethrow;
    }
  }
}

/// Status of a performance span
enum SpanStatus {
  ok('ok'),
  error('error'),
  timeout('timeout'),
  cancelled('cancelled');

  final String value;
  const SpanStatus(this.value);
}
