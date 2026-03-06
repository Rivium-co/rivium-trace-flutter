import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/performance_span.dart';
import '../services/rivium_trace_breadcrumbs.dart';
import '../constants/rivium_trace_constants.dart';
import '../services/rivium_trace_logger.dart';

/// HTTP client that tracks performance spans and sends them to RiviumTrace APM
///
/// Usage:
/// ```dart
/// final client = PerformanceHttpClient(
///   apiKey: 'your-api-key',
///   environment: 'production',
/// );
/// final response = await client.get(Uri.parse('https://api.example.com/data'));
/// ```
class PerformanceHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String _apiKey;
  final String? _environment;
  final String? _releaseVersion;
  final String _platform;
  final bool _addBreadcrumbs;
  final Set<String> _excludedHosts;
  final double _minDurationMs;

  // Buffer for batch sending
  final List<PerformanceSpan> _spanBuffer = [];
  static const int _maxBufferSize = 10;
  Timer? _flushTimer;

  /// Create a Performance HTTP client
  ///
  /// [apiKey] - RiviumTrace API key
  /// [environment] - Environment name (production, staging, etc.)
  /// [releaseVersion] - App version
  /// [platform] - Platform name (flutter, web, android, ios)
  /// [inner] - The underlying HTTP client
  /// [addBreadcrumbs] - Whether to also add HTTP breadcrumbs
  /// [excludedHosts] - Hosts to exclude from tracking
  /// [minDurationMs] - Minimum duration to report (default 0)
  PerformanceHttpClient({
    required String apiKey,
    String? environment,
    String? releaseVersion,
    String? platform,
    http.Client? inner,
    bool addBreadcrumbs = true,
    Set<String>? excludedHosts,
    double minDurationMs = 0,
  })  : _inner = inner ?? http.Client(),
        _apiKey = apiKey,
        _environment = environment,
        _releaseVersion = releaseVersion,
        _platform = platform ?? (kIsWeb ? 'web' : 'flutter'),
        _addBreadcrumbs = addBreadcrumbs,
        _excludedHosts = excludedHosts ?? {},
        _minDurationMs = minDurationMs {
    // Start periodic flush timer
    _flushTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _flushBuffer(),
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final url = request.url.toString();
    final method = request.method;

    // Skip tracking for excluded hosts
    if (_shouldSkipTracking(request.url)) {
      return _inner.send(request);
    }

    String? errorMessage;
    int? statusCode;

    try {
      final response = await _inner.send(request);
      stopwatch.stop();
      statusCode = response.statusCode;

      // Track error responses
      if (response.statusCode >= 400) {
        errorMessage = 'HTTP ${response.statusCode}';
      }

      // Add breadcrumb if enabled
      if (_addBreadcrumbs) {
        RiviumTraceBreadcrumbs.addHttp(method, _sanitizeUrl(url), statusCode);
      }

      // Report span
      _reportSpan(
        method: method,
        url: url,
        startTime: startTime,
        durationMs: stopwatch.elapsedMilliseconds.toDouble(),
        statusCode: statusCode,
        errorMessage: errorMessage,
      );

      return response;
    } catch (e) {
      stopwatch.stop();
      errorMessage = e.toString();

      // Add error breadcrumb
      if (_addBreadcrumbs) {
        RiviumTraceBreadcrumbs.addError(
          'HTTP Request Failed: $method ${_sanitizeUrl(url)}',
          data: {'error': e.toString()},
        );
      }

      // Report span with error
      _reportSpan(
        method: method,
        url: url,
        startTime: startTime,
        durationMs: stopwatch.elapsedMilliseconds.toDouble(),
        statusCode: statusCode,
        errorMessage: errorMessage,
      );

      rethrow;
    }
  }

  bool _shouldSkipTracking(Uri url) {
    // Skip RiviumTrace API calls
    if (url.host.contains('rivium') ||
        url.toString().contains(RiviumTraceConstants.apiUrl)) {
      return true;
    }

    // Skip excluded hosts
    if (_excludedHosts.contains(url.host)) {
      return true;
    }

    return false;
  }

  void _reportSpan({
    required String method,
    required String url,
    required DateTime startTime,
    required double durationMs,
    int? statusCode,
    String? errorMessage,
  }) {
    // Skip if below minimum duration
    if (durationMs < _minDurationMs) {
      return;
    }

    final span = PerformanceSpan.fromHttpRequest(
      method: method,
      url: url,
      startTime: startTime,
      durationMs: durationMs,
      statusCode: statusCode,
      errorMessage: errorMessage,
      platform: _platform,
      environment: _environment,
      releaseVersion: _releaseVersion,
    );

    _spanBuffer.add(span);

    // Flush if buffer is full
    if (_spanBuffer.length >= _maxBufferSize) {
      _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    if (_spanBuffer.isEmpty) return;

    final spansToSend = List<PerformanceSpan>.from(_spanBuffer);
    _spanBuffer.clear();

    try {
      final response = await http.post(
        Uri.parse('${RiviumTraceConstants.apiUrl}/api/performance/spans/batch'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
          'User-Agent': 'RiviumTrace-SDK/${RiviumTraceConstants.sdkVersion} ($_platform; ${_releaseVersion ?? 'unknown'})',
        },
        body: jsonEncode({
          'spans': spansToSend.map((s) => s.toJson()).toList(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        RiviumTraceLogger.debug(
          'Sent ${spansToSend.length} performance spans',
        );
      } else {
        RiviumTraceLogger.warning(
          'Failed to send spans: ${response.statusCode} - ${response.body}',
        );
        // Re-add failed spans to buffer (up to max size)
        if (_spanBuffer.length < _maxBufferSize) {
          _spanBuffer.addAll(
            spansToSend.take(_maxBufferSize - _spanBuffer.length),
          );
        }
      }
    } catch (e) {
      RiviumTraceLogger.error('Failed to send performance spans', e);
      // Re-add failed spans to buffer
      if (_spanBuffer.length < _maxBufferSize) {
        _spanBuffer.addAll(
          spansToSend.take(_maxBufferSize - _spanBuffer.length),
        );
      }
    }
  }

  /// Sanitize URL by removing sensitive query parameters
  String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final sanitizedParams = <String, String>{};

      uri.queryParameters.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        if (_isSensitiveParam(lowerKey)) {
          sanitizedParams[key] = '[REDACTED]';
        } else {
          sanitizedParams[key] = value;
        }
      });

      if (sanitizedParams.isEmpty) {
        return '${uri.scheme}://${uri.host}${uri.path}';
      }

      return uri.replace(queryParameters: sanitizedParams).toString();
    } catch (e) {
      return url;
    }
  }

  bool _isSensitiveParam(String key) {
    const sensitiveParams = [
      'token', 'api_key', 'apikey', 'key', 'secret', 'password',
      'pwd', 'auth', 'authorization', 'access_token', 'refresh_token',
      'session', 'sessionid', 'session_id', 'credential', 'credentials',
    ];
    return sensitiveParams.any((param) => key.contains(param));
  }

  /// Force flush any buffered spans
  Future<void> flush() async {
    await _flushBuffer();
  }

  @override
  void close() {
    _flushTimer?.cancel();
    _flushBuffer(); // Send remaining spans
    _inner.close();
  }
}

/// Extension to wrap an existing http.Client with performance tracking
extension PerformanceHttpClientExtension on http.Client {
  /// Wrap this client with RiviumTrace performance tracking
  PerformanceHttpClient withPerformanceTracking({
    required String apiKey,
    String? environment,
    String? releaseVersion,
    String? platform,
    bool addBreadcrumbs = true,
    Set<String>? excludedHosts,
    double minDurationMs = 0,
  }) {
    return PerformanceHttpClient(
      apiKey: apiKey,
      environment: environment,
      releaseVersion: releaseVersion,
      platform: platform,
      inner: this,
      addBreadcrumbs: addBreadcrumbs,
      excludedHosts: excludedHosts,
      minDurationMs: minDurationMs,
    );
  }
}
