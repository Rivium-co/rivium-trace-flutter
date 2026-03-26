import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/log_entry.dart';
import '../constants/rivium_trace_constants.dart';
import 'rivium_trace_logger.dart';

/// Service for batching and sending logs to RiviumTrace
///
/// Features (matching Better Stack/Logtail):
/// - Lazy timer: only runs when buffer has logs
/// - Exponential backoff: retries with increasing delays (1s, 2s, 4s, 8s...)
/// - Max buffer size: drops oldest logs when buffer exceeds limit
/// - Lifecycle hooks: flushes on app background, pauses when inactive
class LogService with WidgetsBindingObserver {
  final String apiKey;
  final String apiUrl;
  final String? sourceId;
  final String? sourceName;
  final String platform;
  final String environment;
  final String? release;
  final int batchSize;
  final Duration flushInterval;
  final int maxBufferSize;
  final http.Client _httpClient;

  final List<LogEntry> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;
  int _retryAttempt = 0;
  bool _isAppActive = true;

  // Exponential backoff constants
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(seconds: 60);
  static const int _maxRetryAttempts = 10;

  LogService({
    required this.apiKey,
    String? apiUrl,
    this.sourceId,
    this.sourceName,
    required this.platform,
    required this.environment,
    this.release,
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 30),
    this.maxBufferSize = 1000, // Drop oldest logs when exceeding this
    http.Client? httpClient,
  }) : apiUrl = apiUrl ?? RiviumTraceConstants.apiUrl,
       _httpClient = httpClient ?? http.Client() {
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App going to background - flush immediately
        _isAppActive = false;
        flush();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground - resume normal operation
        _isAppActive = true;
        _retryAttempt = 0; // Reset retry count
        if (_buffer.isNotEmpty) {
          _scheduleFlush();
        }
        break;
      case AppLifecycleState.hidden:
        _isAppActive = false;
        break;
    }
  }

  /// Calculate retry delay with exponential backoff
  Duration _getRetryDelay() {
    final delay = _baseRetryDelay * math.pow(2, _retryAttempt).toInt();
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
  }

  /// Start or restart the flush timer (only if buffer has logs)
  void _scheduleFlush() {
    // Cancel existing timer
    _flushTimer?.cancel();

    // Don't schedule if app is inactive
    if (!_isAppActive) return;

    // Only schedule if there are logs to send
    if (_buffer.isNotEmpty) {
      // Use exponential backoff delay if retrying, otherwise normal interval
      final delay = _retryAttempt > 0 ? _getRetryDelay() : flushInterval;

      _flushTimer = Timer(delay, () {
        flush();
      });
    }
  }

  /// Enforce max buffer size by dropping oldest logs
  void _enforceMaxBufferSize() {
    if (_buffer.length > maxBufferSize) {
      final dropCount = _buffer.length - maxBufferSize;
      _buffer.removeRange(0, dropCount);
      RiviumTraceLogger.warning('Buffer overflow: dropped $dropCount oldest logs');
    }
  }

  /// Add a log entry to the buffer
  void add(LogEntry entry) {
    _buffer.add(entry);

    // Enforce max buffer size (drop oldest if exceeds limit)
    _enforceMaxBufferSize();

    // Auto-flush if buffer is full
    if (_buffer.length >= batchSize) {
      flush();
    } else if (_flushTimer == null || !_flushTimer!.isActive) {
      // Schedule flush only if timer isn't already running
      _scheduleFlush();
    }
  }

  /// Add a log with convenience parameters
  void log(
    String message, {
    LogLevel level = LogLevel.info,
    Map<String, dynamic>? metadata,
    String? userId,
  }) {
    add(LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
      metadata: metadata,
      userId: userId,
    ));
  }

  /// Send a single log immediately (bypasses batching)
  Future<bool> sendImmediate(LogEntry entry) async {
    try {
      final payload = {
        ...entry.toJson(),
        'platform': platform,
        'environment': environment,
        if (release != null) 'release': release,
        if (sourceId != null) 'sourceId': sourceId,
        if (sourceName != null) 'sourceName': sourceName,
        'sourceType': 'sdk',
      };

      final response = await _httpClient.post(
        Uri.parse('$apiUrl/api/logs/ingest'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'User-Agent': 'RiviumTrace-SDK/${RiviumTraceConstants.sdkVersion} ($platform)',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        RiviumTraceLogger.debug('Log sent successfully');
        return true;
      } else {
        RiviumTraceLogger.warning('Failed to send log: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      RiviumTraceLogger.error('Error sending log', e);
      return false;
    }
  }

  /// Flush all buffered logs to the server
  Future<bool> flush() async {
    // Cancel timer since we're flushing now
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_buffer.isEmpty || _isFlushing) return true;

    _isFlushing = true;
    final logsToSend = List<LogEntry>.from(_buffer);
    _buffer.clear();

    try {
      // If no sourceId, send individual logs
      if (sourceId == null) {
        var allSucceeded = true;
        for (final entry in logsToSend) {
          if (!await sendImmediate(entry)) {
            allSucceeded = false;
          }
        }
        _retryAttempt = 0; // Reset on success
        return allSucceeded;
      }

      // Batch send
      final payload = {
        'sourceId': sourceId,
        if (sourceName != null) 'sourceName': sourceName,
        'sourceType': 'sdk',
        'logs': logsToSend.map((e) => {
          ...e.toJson(),
          'platform': platform,
          'environment': environment,
          if (release != null) 'release': release,
        }).toList(),
      };

      final response = await _httpClient.post(
        Uri.parse('$apiUrl/api/logs/ingest/batch'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'User-Agent': 'RiviumTrace-SDK/${RiviumTraceConstants.sdkVersion} ($platform)',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        RiviumTraceLogger.debug('Batch logs sent: ${logsToSend.length}');
        _retryAttempt = 0; // Reset on success
        return true;
      } else {
        RiviumTraceLogger.warning('Failed to send batch logs: ${response.statusCode}');
        // Put logs back in buffer for retry
        _buffer.insertAll(0, logsToSend);
        _enforceMaxBufferSize(); // Don't exceed max when re-adding
        // Increment retry attempt and schedule with backoff
        if (_retryAttempt < _maxRetryAttempts) {
          _retryAttempt++;
          _scheduleFlush();
        } else {
          RiviumTraceLogger.error('Max retry attempts reached, logs will be dropped');
          _retryAttempt = 0;
        }
        return false;
      }
    } catch (e) {
      RiviumTraceLogger.error('Error flushing logs', e);
      // Put logs back in buffer for retry
      _buffer.insertAll(0, logsToSend);
      _enforceMaxBufferSize(); // Don't exceed max when re-adding
      // Increment retry attempt and schedule with backoff
      if (_retryAttempt < _maxRetryAttempts) {
        _retryAttempt++;
        _scheduleFlush();
      } else {
        RiviumTraceLogger.error('Max retry attempts reached, logs will be dropped');
        _retryAttempt = 0;
      }
      return false;
    } finally {
      _isFlushing = false;
    }
  }

  /// Get the number of buffered logs
  int get bufferSize => _buffer.length;

  /// Dispose the service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    flush(); // Try to send remaining logs
    _httpClient.close();
  }
}
