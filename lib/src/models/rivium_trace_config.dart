import '../constants/rivium_trace_constants.dart';
import '../services/rivium_trace_logger.dart';

/// Configuration options for RiviumTrace SDK
class RiviumTraceConfig {
  /// API Key from Rivium Console (rv_live_xxx or rv_test_xxx)
  final String apiKey;

  /// Custom API URL for self-hosted RiviumTrace instances
  /// Defaults to the official RiviumTrace cloud service
  final String apiUrl;

  /// Environment name (e.g., 'production', 'staging', 'development')
  final String environment;

  /// Release version
  final String? release;

  /// Whether to capture uncaught errors automatically
  final bool captureUncaughtErrors;

  /// Whether RiviumTrace is enabled
  final bool enabled;

  /// Enable debug logging
  /// When true, SDK logs are sent to dart:developer and can be viewed in DevTools
  final bool debug;

  /// Request timeout in seconds
  final int timeout;

  /// Maximum number of breadcrumbs to keep (default: 20)
  final int maxBreadcrumbs;

  /// Sample rate for error capture (0.0 to 1.0, default: 1.0)
  /// 1.0 means all errors are captured, 0.5 means 50% of errors
  final double sampleRate;

  /// Enable offline storage for errors when network is unavailable
  final bool enableOfflineStorage;

  /// Attach device, OS and app context to errors and messages (default: true).
  ///
  /// Collected once at init via `device_info_plus` / `package_info_plus`:
  /// device model and manufacturer, OS name and version, Android API level
  /// and ABIs, total RAM, physical-vs-emulator, locale, time zone, and the
  /// app's version, build number, package / bundle id and name. Never the
  /// device name, advertising / vendor ids, Android ID, serial or IP.
  /// Set to false to send none of it (the SDK version, Dart version and
  /// build mode are still sent).
  final bool collectDeviceInfo;

  /// Custom log handler to receive SDK logs
  ///
  /// Use this to forward logs to your own logging system or display them
  /// in a custom debug console. Works in both debug and release modes.
  ///
  /// Example:
  /// ```dart
  /// RiviumTraceConfig(
  ///   apiKey: 'your-api-key',
  ///   debug: true,
  ///   logHandler: (level, message, error, stackTrace) {
  ///     print('[$level] $message');
  ///   },
  /// )
  /// ```
  final RiviumTraceLogCallback? logHandler;

  const RiviumTraceConfig({
    required this.apiKey,
    String? apiUrl,
    this.environment = 'production',
    this.release,
    this.captureUncaughtErrors = true,
    this.enabled = true,
    this.debug = false,
    this.timeout = 30,
    this.maxBreadcrumbs = 20,
    this.sampleRate = 1.0,
    this.enableOfflineStorage = true,
    this.collectDeviceInfo = true,
    this.logHandler,
  }) : apiUrl = apiUrl ?? RiviumTraceConstants.apiUrl;

  /// Create a simple configuration with just an API key
  factory RiviumTraceConfig.simple(String apiKey) {
    return RiviumTraceConfig(apiKey: apiKey);
  }

  /// Create a copy with modified values
  RiviumTraceConfig copyWith({
    String? apiKey,
    String? apiUrl,
    String? environment,
    String? release,
    bool? captureUncaughtErrors,
    bool? enabled,
    bool? debug,
    int? timeout,
    int? maxBreadcrumbs,
    double? sampleRate,
    bool? enableOfflineStorage,
    bool? collectDeviceInfo,
    RiviumTraceLogCallback? logHandler,
  }) {
    return RiviumTraceConfig(
      apiKey: apiKey ?? this.apiKey,
      apiUrl: apiUrl ?? this.apiUrl,
      environment: environment ?? this.environment,
      release: release ?? this.release,
      captureUncaughtErrors:
          captureUncaughtErrors ?? this.captureUncaughtErrors,
      enabled: enabled ?? this.enabled,
      debug: debug ?? this.debug,
      timeout: timeout ?? this.timeout,
      maxBreadcrumbs: maxBreadcrumbs ?? this.maxBreadcrumbs,
      sampleRate: sampleRate ?? this.sampleRate,
      enableOfflineStorage: enableOfflineStorage ?? this.enableOfflineStorage,
      collectDeviceInfo: collectDeviceInfo ?? this.collectDeviceInfo,
      logHandler: logHandler ?? this.logHandler,
    );
  }

  @override
  String toString() {
    return 'RiviumTraceConfig(apiKey: ${apiKey.substring(0, 10)}..., environment: $environment, enabled: $enabled, sampleRate: $sampleRate)';
  }
}
