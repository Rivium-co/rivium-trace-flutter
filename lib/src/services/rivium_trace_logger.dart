import 'dart:developer' as developer;

/// Log level for RiviumTrace SDK
enum RiviumTraceLogLevel {
  debug,
  info,
  warning,
  error,
}

/// Callback type for custom log handlers
typedef RiviumTraceLogCallback = void Function(
  RiviumTraceLogLevel level,
  String message,
  Object? error,
  StackTrace? stackTrace,
);

/// Internal logger for RiviumTrace SDK
///
/// This logger:
/// - Uses dart:developer log() which works in both debug and release
/// - Respects the SDK's debug flag
/// - Allows developers to add custom log handlers
/// - Doesn't cause Flutter analyzer warnings like print()
class RiviumTraceLogger {
  RiviumTraceLogger._();

  static bool _isEnabled = false;
  static RiviumTraceLogCallback? _customLogHandler;

  /// Enable or disable logging
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Set a custom log handler to receive all SDK logs
  ///
  /// This allows developers to:
  /// - Forward logs to their own logging system
  /// - Display logs in a debug console
  /// - Store logs for debugging
  ///
  /// Example:
  /// ```dart
  /// RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
  ///   // Forward to your logging system
  ///   myLogger.log(level.name, message);
  /// });
  /// ```
  static void setLogHandler(RiviumTraceLogCallback? handler) {
    _customLogHandler = handler;
  }

  /// Log a debug message
  static void debug(String message) {
    _log(RiviumTraceLogLevel.debug, message);
  }

  /// Log an info message
  static void info(String message) {
    _log(RiviumTraceLogLevel.info, message);
  }

  /// Log a warning message
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(RiviumTraceLogLevel.warning, message, error, stackTrace);
  }

  /// Log an error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(RiviumTraceLogLevel.error, message, error, stackTrace);
  }

  static void _log(
    RiviumTraceLogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Only log when debug is enabled
    if (!_isEnabled) {
      return;
    }

    final formattedMessage = 'RiviumTrace: $message';

    // Call custom handler if set
    _customLogHandler?.call(level, message, error, stackTrace);

    // Use dart:developer log which works in both debug and release
    // and can be viewed in DevTools
    developer.log(
      formattedMessage,
      name: 'RiviumTrace',
      level: _levelToInt(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _levelToInt(RiviumTraceLogLevel level) {
    switch (level) {
      case RiviumTraceLogLevel.debug:
        return 500; // FINE
      case RiviumTraceLogLevel.info:
        return 800; // INFO
      case RiviumTraceLogLevel.warning:
        return 900; // WARNING
      case RiviumTraceLogLevel.error:
        return 1000; // SEVERE
    }
  }
}
