// lib/rivium_trace_flutter.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

// Platform-specific imports
import 'src/platform/platform_handler.dart';
import 'src/constants/rivium_trace_constants.dart';
import 'src/services/rivium_trace_logger.dart';
// Log service is imported via export above

export 'src/models/rivium_trace_error.dart';
export 'src/models/rivium_trace_config.dart';
export 'src/models/performance_span.dart';
export 'src/models/log_entry.dart';
export 'src/tools/rivium_trace_navigator_observer.dart';
export 'src/services/rivium_trace_breadcrumbs.dart';
export 'src/models/breadcrumb.dart' show BreadcrumbType;
export 'src/models/message_level.dart';
export 'src/utils/crash_detector.dart';
export 'src/network/rivium_trace_http_client.dart';
export 'src/performance/performance_http_client.dart';
export 'src/performance/performance_tracker.dart';
export 'src/services/offline_storage_service.dart';
export 'src/services/log_service.dart';
export 'src/services/rivium_trace_logger.dart'
    show RiviumTraceLogLevel, RiviumTraceLogCallback;

/// Main RiviumTrace client for error tracking
class RiviumTrace {
  static RiviumTrace? _instance;
  static RiviumTrace get instance =>
      _instance ??
      (throw StateError(
        'RiviumTrace not initialized. Call RiviumTrace.init() first.',
      ));

  late final RiviumTraceConfig _config;
  late final PlatformHandler _platformHandler;
  final http.Client _httpClient = http.Client();
  final Map<String, DateTime> _lastErrorTimes = {};
  bool _isInitialized = false;
  String? _userId;

  // Session ID for tracking user sessions
  final String _sessionId = _generateSessionId();

  // Extra context data
  final Map<String, dynamic> _extraContext = {};

  // Tags for categorization
  final Map<String, String> _tags = {};

  // Log service for app logging
  LogService? _logService;

  // Random instance for sample rate
  static final Random _random = Random();

  static String _generateSessionId() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  RiviumTrace._();

  /// Initialize RiviumTrace with configuration
  static Future<void> init(RiviumTraceConfig config) async {
    _instance = RiviumTrace._();
    await _instance!._initialize(config);
  }

  /// Initialize RiviumTrace with runZonedGuarded to catch async errors
  /// This is the recommended way to initialize for better error catching
  ///
  /// IMPORTANT: Call this BEFORE WidgetsFlutterBinding.ensureInitialized()
  /// to avoid zone mismatch warnings
  static Future<void> initWithZone(
    RiviumTraceConfig config,
    Future<void> Function() app,
  ) async {
    // Initialize RiviumTrace first (WITHOUT crash detection)
    _instance = RiviumTrace._();
    await _instance!._initializeWithoutCrashDetection(config);

    // Run the app inside the error zone
    await runZonedGuarded(
      () async {
        // Run user's app initialization
        await app();

        // NOW check for crashes (after WidgetsFlutterBinding is initialized)
        if (!kIsWeb) {
          await _instance!._checkPreviousSessionCrash();
          await CrashDetector.markAppStart();
        }
      },
      (error, stackTrace) {
        // Catch async errors that aren't caught by Flutter's error handler
        captureException(
          error,
          stackTrace: stackTrace,
          message: 'Uncaught async error',
          extra: {
            'error_type': 'async_zone_error',
            'caught_by': 'runZonedGuarded',
          },
        );
      },
    );
  }

  Future<void> _initialize(RiviumTraceConfig config) async {
    _config = config;
    _platformHandler = PlatformHandler.create();

    // Configure logger
    RiviumTraceLogger.setEnabled(_config.debug);
    if (_config.logHandler != null) {
      RiviumTraceLogger.setLogHandler(_config.logHandler);
    }

    // Configure breadcrumbs max limit
    RiviumTraceBreadcrumbs.setMaxBreadcrumbs(_config.maxBreadcrumbs);

    // Initialize offline storage if enabled
    if (_config.enableOfflineStorage && !kIsWeb) {
      await OfflineStorageService.initialize();
    }

    // Check for crashes from previous session (mobile only)
    if (!kIsWeb) {
      await _checkPreviousSessionCrash();
    }

    // Set up automatic error catching
    if (_config.captureUncaughtErrors) {
      _setupErrorHandling();
    }

    // Mark app as started (for crash detection)
    if (!kIsWeb) {
      await CrashDetector.markAppStart();
    }

    _isInitialized = true;

    // Add system breadcrumb
    RiviumTraceBreadcrumbs.addSystem(
      'RiviumTrace SDK initialized',
      data: {
        'sdk_version': RiviumTraceConstants.sdkVersion,
        'environment': _config.environment,
        'platform': _platformHandler.getPlatform(),
      },
    );

    // Try to send any stored offline errors
    if (_config.enableOfflineStorage && !kIsWeb) {
      _sendStoredErrors();
    }

    RiviumTraceLogger.info('Initialized for ${_platformHandler.getPlatform()}');
  }

  /// Initialize without crash detection (for initWithZone)
  /// Crash detection will be done AFTER WidgetsFlutterBinding is initialized
  Future<void> _initializeWithoutCrashDetection(RiviumTraceConfig config) async {
    _config = config;
    _platformHandler = PlatformHandler.create();

    // Configure logger
    RiviumTraceLogger.setEnabled(_config.debug);
    if (_config.logHandler != null) {
      RiviumTraceLogger.setLogHandler(_config.logHandler);
    }

    // Configure breadcrumbs max limit
    RiviumTraceBreadcrumbs.setMaxBreadcrumbs(_config.maxBreadcrumbs);

    // Initialize offline storage if enabled
    if (_config.enableOfflineStorage && !kIsWeb) {
      await OfflineStorageService.initialize();
    }

    // Set up automatic error catching
    if (_config.captureUncaughtErrors) {
      _setupErrorHandling();
    }

    _isInitialized = true;

    // Add system breadcrumb
    RiviumTraceBreadcrumbs.addSystem(
      'RiviumTrace SDK initialized',
      data: {
        'sdk_version': RiviumTraceConstants.sdkVersion,
        'environment': _config.environment,
        'platform': _platformHandler.getPlatform(),
      },
    );

    RiviumTraceLogger.info('Initialized for ${_platformHandler.getPlatform()}');
  }

  /// Check if the app crashed in the previous session and report it
  Future<void> _checkPreviousSessionCrash() async {
    try {
      final didCrash = await CrashDetector.didCrashLastSession();

      if (didCrash) {
        final crashReport = await CrashDetector.getCrashReport(
          _platformHandler.getPlatform(),
          _config.environment,
          _config.release,
        );

        if (crashReport != null) {
          RiviumTraceLogger.info(
            'Detected crash from previous session at ${crashReport.timestamp}',
          );

          // Send the crash report
          await _captureError(crashReport);
        }

        // Clean up all crash detection files after reporting
        await CrashDetector.cleanup();
      }
    } catch (e) {
      RiviumTraceLogger.warning('Error checking previous crash', e);
    }
  }

  /// Set user ID for analytics
  static void setUserId(String userId) {
    if (_instance != null) {
      _instance!._userId = userId;
      RiviumTraceBreadcrumbs.addSystem('User ID set', data: {'user_id': userId});
    }
  }

  /// Get current user ID
  static String? getUserId() => _instance?._userId;

  /// Get current session ID
  static String? getSessionId() => _instance?._sessionId;

  // === Extra Context Methods ===

  /// Set extra context data
  static void setExtra(String key, dynamic value) {
    _instance?._extraContext[key] = value;
  }

  /// Set multiple extra context values
  static void setExtras(Map<String, dynamic> extras) {
    _instance?._extraContext.addAll(extras);
  }

  /// Get extra context value
  static dynamic getExtra(String key) => _instance?._extraContext[key];

  /// Get all extra context
  static Map<String, dynamic>? getExtras() => _instance?._extraContext;

  /// Clear extra context
  static void clearExtras() {
    _instance?._extraContext.clear();
  }

  // === Tags Methods ===

  /// Set a tag
  static void setTag(String key, String value) {
    _instance?._tags[key] = value;
  }

  /// Set multiple tags
  static void setTags(Map<String, String> tags) {
    _instance?._tags.addAll(tags);
  }

  /// Get tag value
  static String? getTag(String key) => _instance?._tags[key];

  /// Get all tags
  static Map<String, String>? getTags() => _instance?._tags;

  /// Clear all tags
  static void clearTags() {
    _instance?._tags.clear();
  }

  /// Check if SDK is initialized
  static bool isInitialized() => _instance?._isInitialized ?? false;

  /// Get the current platform (flutter_android, flutter_ios, flutter_web, etc.)
  static String? getPlatform() => _instance?._platformHandler.getPlatform();

  // === Error Tracking Methods ===

  /// Manually capture an exception
  ///
  /// [exception] - The exception to capture
  /// [stackTrace] - Optional stack trace
  /// [message] - Optional custom message
  /// [extra] - Additional context data
  /// [tags] - Tags for categorization
  /// [callback] - Callback with success status
  static Future<void> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
    void Function(bool success)? callback,
  }) async {
    if (!instance._isInitialized) {
      callback?.call(false);
      return;
    }

    // Apply sample rate
    if (instance._config.sampleRate < 1.0 &&
        _random.nextDouble() > instance._config.sampleRate) {
      RiviumTraceLogger.debug('Error dropped due to sample rate');
      callback?.call(false);
      return;
    }

    // Add error breadcrumb
    RiviumTraceBreadcrumbs.addError(
      'Exception: ${exception.runtimeType}',
      data: {'message': exception.toString()},
    );

    // Merge extra context
    final Map<String, dynamic> enhancedExtra = {
      ...instance._extraContext,
      'breadcrumbs': RiviumTraceBreadcrumbs.getBreadcrumbsJson(),
      'user_id': instance._userId,
      'session_id': instance._sessionId,
    };

    // Append user-provided extra data if available
    if (extra != null) {
      enhancedExtra.addAll(extra);
    }

    // Merge tags
    final Map<String, String> mergedTags = {...instance._tags};
    if (tags != null) {
      mergedTags.addAll(tags);
    }

    final success = await instance._captureError(
      RiviumTraceError(
        message: message ?? exception.toString(),
        stackTrace: (stackTrace ?? StackTrace.current).toString(),
        platform: instance._platformHandler.getPlatform(),
        environment: instance._config.environment,
        release: instance._config.release,
        timestamp: DateTime.now(),
        extra: enhancedExtra,
        tags: mergedTags,
      ),
    );

    callback?.call(success);
  }

  /// Manually capture a message
  ///
  /// [message] - The message to capture
  /// [level] - Message severity level
  /// [extra] - Additional context data
  /// [tags] - Tags for categorization
  /// [includeBreadcrumbs] - Whether to include breadcrumbs
  /// [callback] - Callback with success status
  static Future<void> captureMessage(
    String message, {
    MessageLevel level = MessageLevel.info,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
    bool includeBreadcrumbs = true,
    void Function(bool success)? callback,
  }) async {
    if (!instance._isInitialized) {
      callback?.call(false);
      return;
    }

    // Merge extra context
    final Map<String, dynamic> enhancedExtra = {
      ...instance._extraContext,
      'user_id': instance._userId,
      'session_id': instance._sessionId,
    };

    if (includeBreadcrumbs) {
      enhancedExtra['breadcrumbs'] = RiviumTraceBreadcrumbs.getBreadcrumbsJson();
    }

    if (extra != null) {
      enhancedExtra.addAll(extra);
    }

    // Merge tags
    final Map<String, String> mergedTags = {...instance._tags};
    if (tags != null) {
      mergedTags.addAll(tags);
    }

    // Also add this message as a breadcrumb for future errors
    RiviumTraceBreadcrumbs.add(message, type: BreadcrumbType.info, data: extra);

    final success = await instance._sendMessage(
      message: message,
      level: level.value,
      extra: enhancedExtra,
      tags: mergedTags,
    );

    callback?.call(success);
  }

  Future<bool> _sendMessage({
    required String message,
    required String level,
    Map<String, dynamic>? extra,
    Map<String, String>? tags,
  }) async {
    if (!_config.enabled) return false;

    try {
      // Extract breadcrumbs from extra to root level (backend expects them at root)
      List<Map<String, dynamic>>? breadcrumbs;
      Map<String, dynamic>? cleanExtra;
      if (extra != null) {
        cleanExtra = Map<String, dynamic>.from(extra);
        if (cleanExtra.containsKey('breadcrumbs')) {
          final rawBreadcrumbs = cleanExtra.remove('breadcrumbs');
          if (rawBreadcrumbs is List) {
            breadcrumbs = rawBreadcrumbs
                .map((b) => b is Map<String, dynamic>
                    ? b
                    : Map<String, dynamic>.from(b as Map))
                .toList();
          }
        }
      }

      final payload = {
        'message': message,
        'level': level,
        'platform': _platformHandler.getPlatform(),
        'environment': _config.environment,
        'release': _config.release,
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': _userId,
        if (breadcrumbs != null) 'breadcrumbs': breadcrumbs,
        if (cleanExtra != null && cleanExtra.isNotEmpty) 'extra': cleanExtra,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      };

      final url = '${_config.apiUrl}/api/messages';
      RiviumTraceLogger.debug('Sending message to $url - $message (level: $level)');

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _config.apiKey,
              'User-Agent': _platformHandler.getUserAgent(_config.release),
            },
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: _config.timeout));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        RiviumTraceLogger.debug(
          'Message sent successfully (${response.statusCode})',
        );
      } else {
        RiviumTraceLogger.warning(
          'Server responded with ${response.statusCode}: ${response.body}',
        );
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      RiviumTraceLogger.error('Failed to send message', e);
      return false;
    }
  }

  // === Performance Tracking Methods ===

  /// Report a performance span to RiviumTrace APM
  ///
  /// [span] - The performance span to report
  /// [callback] - Optional callback with success status
  static Future<void> reportPerformanceSpan(
    PerformanceSpan span, {
    void Function(bool success)? callback,
  }) async {
    if (!instance._isInitialized) {
      callback?.call(false);
      return;
    }

    try {
      final response = await instance._httpClient
          .post(
            Uri.parse('${instance._config.apiUrl}/api/performance/spans'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': instance._config.apiKey,
              'User-Agent': instance._platformHandler.getUserAgent(
                instance._config.release,
              ),
            },
            body: jsonEncode(span.toJson()),
          )
          .timeout(Duration(seconds: instance._config.timeout));

      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (success) {
        RiviumTraceLogger.debug('Performance span sent: ${span.operation}');
      } else {
        RiviumTraceLogger.warning('Failed to send span: ${response.statusCode}');
      }
      callback?.call(success);
    } catch (e) {
      RiviumTraceLogger.error('Failed to send performance span', e);
      callback?.call(false);
    }
  }

  /// Report multiple performance spans in a batch
  ///
  /// [spans] - Array of performance spans to report
  /// [callback] - Optional callback with success status
  static Future<void> reportPerformanceSpanBatch(
    List<PerformanceSpan> spans, {
    void Function(bool success)? callback,
  }) async {
    if (!instance._isInitialized || spans.isEmpty) {
      callback?.call(spans.isEmpty);
      return;
    }

    try {
      final response = await instance._httpClient
          .post(
            Uri.parse(
              '${instance._config.apiUrl}/api/performance/spans/batch',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': instance._config.apiKey,
              'User-Agent': instance._platformHandler.getUserAgent(
                instance._config.release,
              ),
            },
            body: jsonEncode({'spans': spans.map((s) => s.toJson()).toList()}),
          )
          .timeout(Duration(seconds: instance._config.timeout));

      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (success) {
        RiviumTraceLogger.debug(
          'Performance span batch sent: ${spans.length} spans',
        );
      } else {
        RiviumTraceLogger.warning(
          'Failed to send span batch: ${response.statusCode}',
        );
      }
      callback?.call(success);
    } catch (e) {
      RiviumTraceLogger.error('Failed to send performance span batch', e);
      callback?.call(false);
    }
  }

  /// Create a performance HTTP client with tracking enabled
  ///
  /// Usage:
  /// ```dart
  /// final client = RiviumTrace.createPerformanceClient();
  /// final response = await client.get(Uri.parse('https://api.example.com/data'));
  /// ```
  static PerformanceHttpClient createPerformanceClient({
    http.Client? inner,
    bool addBreadcrumbs = true,
    Set<String>? excludedHosts,
    double minDurationMs = 0,
  }) {
    return PerformanceHttpClient(
      apiKey: instance._config.apiKey,
      apiUrl: instance._config.apiUrl,
      environment: instance._config.environment,
      releaseVersion: instance._config.release,
      platform: instance._platformHandler.getPlatform(),
      inner: inner,
      addBreadcrumbs: addBreadcrumbs,
      excludedHosts: excludedHosts,
      minDurationMs: minDurationMs,
    );
  }

  /// Track an async operation with automatic timing
  ///
  /// Usage:
  /// ```dart
  /// final result = await RiviumTrace.trackOperation(
  ///   'fetchUserProfile',
  ///   () async => await api.fetchProfile(),
  /// );
  /// ```
  static Future<T> trackOperation<T>(
    String operation,
    Future<T> Function() block, {
    String operationType = 'custom',
  }) async {
    return PerformanceTracker.track(
      operation: operation,
      apiKey: instance._config.apiKey,
      apiUrl: instance._config.apiUrl,
      operationType: operationType,
      environment: instance._config.environment,
      releaseVersion: instance._config.release,
      platform: instance._platformHandler.getPlatform(),
      block: block,
    );
  }

  // === Breadcrumb Methods ===

  /// Add a breadcrumb
  static void addBreadcrumb(
    String message, {
    BreadcrumbType type = BreadcrumbType.info,
    Map<String, dynamic>? data,
  }) {
    RiviumTraceBreadcrumbs.add(message, type: type, data: data);
  }

  /// Add a navigation breadcrumb
  static void addNavigationBreadcrumb(String? from, String to) {
    RiviumTraceBreadcrumbs.addNavigation(from ?? 'unknown', to);
  }

  /// Add a user action breadcrumb
  static void addUserBreadcrumb(String action, {Map<String, dynamic>? data}) {
    RiviumTraceBreadcrumbs.addUser(action, data: data);
  }

  /// Add an HTTP request breadcrumb
  static void addHttpBreadcrumb(
    String method,
    String url, {
    int? statusCode,
    int? durationMs,
  }) {
    RiviumTraceBreadcrumbs.addHttp(method, url, statusCode);
  }

  /// Clear all breadcrumbs
  static void clearBreadcrumbs() {
    RiviumTraceBreadcrumbs.clear();
  }

  // === Private Methods ===

  void _setupErrorHandling() {
    // Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      String message = details.exception.toString();
      String stackTrace = details.stack?.toString() ?? '';

      // Handle cases where exception toString() returns "Uncaught"
      if (message.isEmpty || message == 'Uncaught' || message.trim().isEmpty) {
        message = 'Flutter Error: ${details.exception.runtimeType}';
        if (details.context != null) {
          message += ' in ${details.context}';
        }
      }

      // Enhanced context extraction
      Map<String, dynamic> extraInfo = {
        'context': details.context?.toString(),
        'library': details.library,
        'exception_type': details.exception.runtimeType.toString(),
        'breadcrumbs': RiviumTraceBreadcrumbs.getBreadcrumbsJson(),
        'user_id': _userId,
        'is_fatal': details.exception.runtimeType.toString().contains('Fatal'),
      };

      // Check if this is a PlatformException (from native code)
      if (details.exception.runtimeType.toString() == 'PlatformException') {
        extraInfo['is_platform_exception'] = true;
        extraInfo['platform_error'] = true;
        try {
          // Try to extract PlatformException details using dynamic access
          final dynamic exception = details.exception;
          extraInfo['platform_code'] = exception.code?.toString() ?? 'unknown';
          extraInfo['platform_message'] =
              exception.message?.toString() ?? 'No message';
          extraInfo['platform_details'] =
              exception.details?.toString() ?? 'No details';
        } catch (e) {
          extraInfo['platform_extraction_error'] = e.toString();
        }
      }

      // Add navigation context
      extraInfo.addAll(RiviumTraceNavigatorObserver.getNavigationContext());

      // Get widget tree information
      if (details.informationCollector != null) {
        try {
          final info = details.informationCollector!().join('\n');
          extraInfo['widget_tree'] = info;

          // Extract widget names from the tree
          final widgetNames = RegExp(r'([A-Z][a-zA-Z0-9_]*)\(')
              .allMatches(info)
              .map((m) => m.group(1))
              .where((name) => name != null)
              .toSet()
              .toList();
          if (widgetNames.isNotEmpty) {
            extraInfo['widgets_involved'] = widgetNames;
          }
        } catch (e) {
          extraInfo['widget_info_error'] = e.toString();
        }
      }

      // Enhanced stack trace with breadcrumbs
      if (stackTrace.isEmpty) {
        stackTrace =
            'No stack trace available\n'
            'Context: ${details.context?.toString() ?? 'Unknown'}\n'
            'Library: ${details.library ?? 'Unknown'}\n'
            'Current Route: ${RiviumTraceNavigatorObserver.currentRoute ?? 'Unknown'}';
        // REMOVED: Recent Breadcrumbs from here - they're already in extra
      }

      _captureError(
        RiviumTraceError(
          message: message,
          stackTrace: stackTrace,
          platform: _platformHandler.getPlatform(),
          environment: _config.environment,
          release: _config.release,
          timestamp: DateTime.now(),
          extra: extraInfo,
        ),
      );
    };

    // Platform-specific error handling
    _platformHandler.setupErrorHandling((error) {
      // Override empty/unhelpful messages
      String message = error.message;
      if (message.isEmpty || message == 'Uncaught' || message.trim().isEmpty) {
        message = 'Platform Error (${error.platform})';
      }

      // Add navigation context and breadcrumbs to platform errors too
      final enhancedExtra = Map<String, dynamic>.from(error.extra ?? {});
      enhancedExtra.addAll(RiviumTraceNavigatorObserver.getNavigationContext());
      enhancedExtra['breadcrumbs'] = RiviumTraceBreadcrumbs.getBreadcrumbsJson();
      enhancedExtra['user_id'] = _userId;

      final enhancedError = RiviumTraceError(
        message: message,
        stackTrace: error.stackTrace,
        platform: error.platform,
        environment: _config.environment,
        release: _config.release,
        timestamp: error.timestamp,
        extra: enhancedExtra,
      );

      _captureError(enhancedError);
    });
  }

  Future<bool> _captureError(RiviumTraceError error) async {
    if (!_config.enabled) return false;

    // Simple rate limiting - don't send the same error more than once per minute
    final errorKey = '${error.message}_${error.platform}';
    final now = DateTime.now();

    if (_lastErrorTimes.containsKey(errorKey)) {
      final lastTime = _lastErrorTimes[errorKey]!;
      if (now.difference(lastTime).inMinutes < 1) {
        RiviumTraceLogger.debug('Rate limiting - skipping duplicate error');
        return false;
      }
    }

    _lastErrorTimes[errorKey] = now;

    // Clean up old entries (keep only last 50 errors)
    if (_lastErrorTimes.length > 50) {
      final sortedEntries = _lastErrorTimes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _lastErrorTimes.clear();
      _lastErrorTimes.addAll(Map.fromEntries(sortedEntries.take(25)));
    }

    try {
      final payload = error.toJson();

      RiviumTraceLogger.debug('Capturing error - ${error.message}');

      final response = await _httpClient
          .post(
            Uri.parse('${_config.apiUrl}/api/errors'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _config.apiKey,
              'User-Agent': _platformHandler.getUserAgent(_config.release),
            },
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: _config.timeout));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        RiviumTraceLogger.debug(
          'Error sent successfully (${response.statusCode})',
        );
      } else {
        RiviumTraceLogger.warning(
          'Server responded with ${response.statusCode}: ${response.body}',
        );
      }

      // Handle specific response codes
      if (response.statusCode == 409) {
        // Duplicate error - this is expected and OK
        RiviumTraceLogger.debug('Duplicate error detected (expected behavior)');
        return true;
      } else if (response.statusCode >= 400) {
        RiviumTraceLogger.warning(
          'Server error ${response.statusCode}: ${response.body}',
        );
        return false;
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      RiviumTraceLogger.error('Failed to send error', e);

      // Store offline if enabled
      if (_config.enableOfflineStorage && !kIsWeb) {
        await OfflineStorageService.storeError(error);
        RiviumTraceLogger.debug('Error stored offline for later sending');
      }

      return false;
    }
  }

  /// Send stored offline errors
  Future<void> _sendStoredErrors() async {
    if (!_config.enableOfflineStorage || kIsWeb) return;

    try {
      final storedErrors = await OfflineStorageService.getStoredErrors();
      if (storedErrors.isEmpty) return;

      RiviumTraceLogger.info(
        'Sending ${storedErrors.length} stored offline errors',
      );

      for (var i = storedErrors.length - 1; i >= 0; i--) {
        try {
          final payload = storedErrors[i];

          final response = await _httpClient
              .post(
                Uri.parse('${_config.apiUrl}/api/errors'),
                headers: {
                  'Content-Type': 'application/json',
                  'X-API-Key': _config.apiKey,
                  'User-Agent': _platformHandler.getUserAgent(_config.release),
                },
                body: jsonEncode(payload),
              )
              .timeout(Duration(seconds: _config.timeout));

          if (response.statusCode >= 200 && response.statusCode < 300 ||
              response.statusCode == 409) {
            await OfflineStorageService.removeError(i);
            RiviumTraceLogger.debug('Stored error sent successfully');
          }
        } catch (e) {
          // Network still unavailable, stop trying
          RiviumTraceLogger.debug(
            'Failed to send stored error, will retry later',
          );
          break;
        }
      }
    } catch (e) {
      RiviumTraceLogger.warning('Error sending stored errors', e);
    }
  }

  /// Close the client and clean up resources
  static Future<void> close() async {
    RiviumTraceBreadcrumbs.addSystem('RiviumTrace SDK closed');

    // Flush any pending logs
    await _instance?._logService?.flush();
    _instance?._logService?.dispose();

    // Mark app as closed gracefully (for crash detection)
    if (!kIsWeb) {
      await CrashDetector.markAppClose();
    }

    _instance?._httpClient.close();
    _instance?._platformHandler.dispose();
    _instance = null;
  }

  // === Logging Methods ===

  /// Initialize the log service for app logging
  ///
  /// [sourceId] - Identifier for this log source (e.g., "my-flutter-app")
  /// [sourceName] - Human-readable name for this source
  /// [batchSize] - Number of logs to batch before sending (default: 50)
  /// [flushInterval] - How often to flush logs (default: 5 seconds)
  static void enableLogging({
    String? sourceId,
    String? sourceName,
    int batchSize = 50,
    Duration flushInterval = const Duration(seconds: 5),
  }) {
    if (!instance._isInitialized) return;

    instance._logService = LogService(
      apiKey: instance._config.apiKey,
      apiUrl: instance._config.apiUrl,
      sourceId: sourceId,
      sourceName: sourceName,
      platform: instance._platformHandler.getPlatform(),
      environment: instance._config.environment,
      release: instance._config.release,
      batchSize: batchSize,
      flushInterval: flushInterval,
    );

    RiviumTraceLogger.info('Logging enabled with sourceId: $sourceId');
  }

  /// Log a message with the specified level
  ///
  /// [message] - The log message
  /// [level] - Log level (trace, debug, info, warn, error, fatal)
  /// [metadata] - Additional metadata to attach to the log
  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    Map<String, dynamic>? metadata,
  }) {
    if (!instance._isInitialized) return;

    // Auto-enable logging if not already enabled
    if (instance._logService == null) {
      enableLogging();
    }

    instance._logService?.log(
      message,
      level: level,
      metadata: metadata,
      userId: instance._userId,
    );
  }

  /// Log a trace-level message
  static void trace(String message, {Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.trace, metadata: metadata);
  }

  /// Log a debug-level message
  static void debug(String message, {Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.debug, metadata: metadata);
  }

  /// Log an info-level message
  static void info(String message, {Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.info, metadata: metadata);
  }

  /// Log a warning-level message
  static void warn(String message, {Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.warn, metadata: metadata);
  }

  /// Log an error-level message (for non-exception errors)
  static void logError(String message, {Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.error, metadata: metadata);
  }

  /// Log a fatal-level message
  static void fatal(String message, {Map<String, dynamic>? metadata}) {
    log(message, level: LogLevel.fatal, metadata: metadata);
  }

  /// Flush all pending logs immediately
  static Future<bool> flushLogs() async {
    if (!instance._isInitialized || instance._logService == null) {
      return true;
    }
    return instance._logService!.flush();
  }

  /// Get the number of logs currently buffered
  static int get pendingLogCount => instance._logService?.bufferSize ?? 0;
}
