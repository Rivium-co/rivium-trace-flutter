import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/rivium_trace_config.dart';
import '../services/rivium_trace_logger.dart';

/// Dart-side bridge to the native RiviumTrace SDKs.
///
/// All calls are no-ops on web. On iOS the native side is backed by
/// PLCrashReporter (real signal + Mach exception capture). On Android the
/// native side polls `ApplicationExitInfo` (API 30+) plus installs an
/// in-process uncaught exception handler.
class RiviumTraceNativePlugin {
  RiviumTraceNativePlugin._();

  static const MethodChannel _channel = MethodChannel(
    'co.rivium.trace/flutter_sdk',
  );

  static bool get _supported => !kIsWeb;

  /// Initialize the native SDK. Installs native crash handlers and drains
  /// any pending native crash report from the previous session (the native
  /// side POSTs it directly).
  static Future<void> init(RiviumTraceConfig config) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('init', <String, Object?>{
        'apiKey': config.apiKey,
        'environment': config.environment,
        'release': config.release,
        'debug': config.debug,
        'enabled': config.enabled,
        'captureUncaughtExceptions': config.captureUncaughtErrors,
        'captureSignalCrashes': true,
        'captureAnr': true,
        'maxBreadcrumbs': config.maxBreadcrumbs,
        'httpTimeoutSeconds': config.timeout,
        'enableOfflineStorage': config.enableOfflineStorage,
        'sampleRate': config.sampleRate,
        'apiUrl': config.apiUrl,
      });
    } on PlatformException catch (e) {
      RiviumTraceLogger.warning('Native init failed', e);
    } on MissingPluginException {
      // Plugin not embedded in host app (e.g. tests). Silent.
    }
  }

  /// Returns any pending native crash reports that the native side has
  /// staged but not yet handed back to Dart. In 2.0.0 the native side
  /// POSTs the crash itself and returns an empty list here; this method
  /// is kept as the long-term hook so a future SDK can let Dart own the
  /// send.
  static Future<List<Map<String, dynamic>>> drainPendingCrashReports() async {
    if (!_supported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'drainPendingCrashReports',
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    } on PlatformException catch (e) {
      RiviumTraceLogger.warning('drainPendingCrashReports failed', e);
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<void> setUserId(String? userId) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setUserId', <String, Object?>{
        'userId': userId,
      });
    } on PlatformException {
      // Silent — context propagation failure is not fatal.
    } on MissingPluginException {
      // Plugin not embedded (e.g. tests).
    }
  }

  static Future<void> addBreadcrumb(
    String message, {
    String type = 'info',
    Map<String, dynamic>? data,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('addBreadcrumb', <String, Object?>{
        'message': message,
        'type': type,
        'data': data ?? const <String, dynamic>{},
      });
    } on PlatformException {
      // Breadcrumb sync failure is not fatal.
    } on MissingPluginException {
      // Plugin not embedded (e.g. tests).
    }
  }

  static Future<void> close() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException {
      // Best-effort close.
    } on MissingPluginException {
      // Plugin not embedded (e.g. tests).
    }
  }
}
