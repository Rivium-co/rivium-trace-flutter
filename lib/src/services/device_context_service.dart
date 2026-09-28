import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/rivium_trace_constants.dart';
import '../platform/runtime_info_stub.dart'
    if (dart.library.io) '../platform/runtime_info_io.dart' as runtime;
import 'rivium_trace_logger.dart';

/// Loads the platform's device facts as a `device_info` map (or null).
typedef DeviceInfoLoader = Future<Map<String, dynamic>?> Function();

/// Loads the host app's facts as an `app_info` map (or null).
typedef AppInfoLoader = Future<Map<String, dynamic>?> Function();

/// Device, OS and app context attached to every error and message.
///
/// Collected ONCE (the plugin lookups are cached) and never allowed to hold
/// up an error: [snapshot] waits at most [maxWait] for the first collection,
/// then sends whatever is known. Every lookup is wrapped — a missing plugin
/// (`MissingPluginException`), a binding that isn't up yet, or an unknown
/// platform just leaves that part out.
///
/// Keys match the Android/iOS native RiviumTrace SDKs (`device_info.device_model`,
/// `device_manufacturer`, `device_brand`, `os_version`, `sdk_int`,
/// `supported_abis`, `locale`, `timezone`) so the Console reads them the same.
///
/// Privacy: never collects the device name, IDFV / Android ID, serial,
/// hostname, user name or IP address.
class DeviceContextService {
  DeviceContextService._();

  static const Duration maxWait = Duration(milliseconds: 500);
  static const int _maxAttempts = 3;

  static bool _collectDeviceInfo = true;
  static String _platform = 'flutter_unknown';

  static Map<String, dynamic>? _deviceInfo;
  static Map<String, dynamic>? _appInfo;
  static Future<void>? _pending;
  static bool _done = false;
  static int _attempts = 0;

  @visibleForTesting
  static DeviceInfoLoader? deviceInfoLoaderOverride;
  @visibleForTesting
  static AppInfoLoader? appInfoLoaderOverride;

  /// Configure and kick off collection in the background (no await needed).
  static void start({required bool collectDeviceInfo, required String platform}) {
    _collectDeviceInfo = collectDeviceInfo;
    _platform = platform;
    _ensureStarted();
  }

  /// Build mode of the host app: 'release' | 'profile' | 'debug'.
  static String get buildMode =>
      kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');

  /// `_sdk` facts the backend merges into its own SDK metadata.
  static Map<String, dynamic> sdkMetadata() {
    final dart = runtime.dartVersion();
    return <String, dynamic>{
      'sdk_version': RiviumTraceConstants.sdkVersion,
      if (dart != null) 'dart_version': dart,
      'build_mode': buildMode,
      'flutter_platform': _platform.startsWith('flutter_')
          ? _platform.substring('flutter_'.length)
          : _platform,
    };
  }

  /// The context to attach: `_sdk` always; `device_info` / `app_info` when
  /// collection is on and has produced something. Waits at most [wait].
  static Future<Map<String, dynamic>> snapshot({Duration wait = maxWait}) async {
    if (_collectDeviceInfo) {
      _ensureStarted();
      final pending = _pending;
      if (!_done && pending != null) {
        try {
          await pending.timeout(wait);
        } catch (_) {
          // Timed out or failed: send what we have, never block the error.
        }
      }
    }
    return <String, dynamic>{
      '_sdk': sdkMetadata(),
      if (_collectDeviceInfo) 'device_info': _deviceInfoWithLocale(),
      if (_collectDeviceInfo && _appInfo != null && _appInfo!.isNotEmpty)
        'app_info': Map<String, dynamic>.from(_appInfo!),
    };
  }

  /// Merge [context] into [extra]: an existing `device_info` / `app_info`
  /// wins key by key, and `_sdk` keys already in [extra] are kept.
  static Map<String, dynamic> mergeInto(
    Map<String, dynamic>? extra,
    Map<String, dynamic> context,
  ) {
    final out = <String, dynamic>{...?extra};
    for (final key in const ['_sdk', 'device_info', 'app_info']) {
      final ours = context[key];
      if (ours is! Map || ours.isEmpty) continue;
      final theirs = out[key];
      out[key] = theirs is Map
          ? <String, dynamic>{...Map<String, dynamic>.from(ours), ...Map<String, dynamic>.from(theirs)}
          : Map<String, dynamic>.from(ours);
    }
    return out;
  }

  @visibleForTesting
  static void resetForTesting() {
    _collectDeviceInfo = true;
    _platform = 'flutter_unknown';
    _deviceInfo = null;
    _appInfo = null;
    _pending = null;
    _done = false;
    _attempts = 0;
    deviceInfoLoaderOverride = null;
    appInfoLoaderOverride = null;
  }

  // ── internals ─────────────────────────────────────────────────────────────

  static void _ensureStarted() {
    if (!_collectDeviceInfo || _done || _pending != null) return;
    if (_attempts >= _maxAttempts) return;
    _attempts++;
    _pending = _collect().whenComplete(() => _pending = null);
  }

  static Future<void> _collect() async {
    final results = await Future.wait<Map<String, dynamic>?>([
      _safe(deviceInfoLoaderOverride ?? _loadDeviceInfo),
      _safe(appInfoLoaderOverride ?? _loadAppInfo),
    ]);
    if (results[0] != null) _deviceInfo = results[0];
    if (results[1] != null) _appInfo = results[1];
    // Web skips the plugins by design; elsewhere retry later (e.g. the
    // binding wasn't up yet) until both came back or attempts run out.
    _done = kIsWeb || (_deviceInfo != null && _appInfo != null);
  }

  static Future<Map<String, dynamic>?> _safe(Future<Map<String, dynamic>?> Function() load) async {
    try {
      final m = await load();
      if (m == null) return null;
      m.removeWhere((_, v) => v == null || (v is String && v.trim().isEmpty));
      return m.isEmpty ? null : m;
    } catch (e) {
      RiviumTraceLogger.debug('Device context lookup skipped: $e');
      return null;
    }
  }

  static Map<String, dynamic> _deviceInfoWithLocale() {
    final out = <String, dynamic>{...?_deviceInfo};
    try {
      final tag = PlatformDispatcher.instance.locale.toLanguageTag();
      if (tag.isNotEmpty && tag != 'und') out['locale'] = tag;
    } catch (_) {}
    try {
      out['timezone'] = _timezone(DateTime.now());
    } catch (_) {}
    return out;
  }

  /// "CET (UTC+01:00)".
  static String _timezone(DateTime now) {
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hh = abs.inHours.toString().padLeft(2, '0');
    final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    final name = now.timeZoneName;
    final utc = 'UTC$sign$hh:$mm';
    return name.isEmpty || name == utc ? utc : '$name ($utc)';
  }

  static Future<Map<String, dynamic>?> _loadDeviceInfo() async {
    if (kIsWeb) return null; // the browser user agent already says this
    final plugin = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await plugin.androidInfo;
        return <String, dynamic>{
          'device_model': a.model,
          'device_manufacturer': a.manufacturer,
          'device_brand': a.brand,
          'os_name': 'Android',
          'os_version': a.version.release,
          'sdk_int': a.version.sdkInt,
          'supported_abis': a.supportedAbis,
          'is_physical_device': a.isPhysicalDevice,
          if (a.physicalRamSize > 0) 'total_memory_mb': a.physicalRamSize,
        };
      case TargetPlatform.iOS:
        final i = await plugin.iosInfo;
        return <String, dynamic>{
          // "iPhone 15 Pro"; falls back to the hardware identifier.
          'device_model': i.modelName.isNotEmpty ? i.modelName : i.utsname.machine,
          'machine': i.utsname.machine, // "iPhone16,1"
          'device_type': i.model, // "iPhone" / "iPad"
          'os_name': i.systemName,
          'system_name': i.systemName,
          'os_version': i.systemVersion,
          'is_physical_device': i.isPhysicalDevice,
          if (i.physicalRamSize > 0) 'total_memory_mb': i.physicalRamSize,
        };
      case TargetPlatform.macOS:
        final m = await plugin.macOsInfo;
        return <String, dynamic>{
          'device_model': m.modelName.isNotEmpty ? m.modelName : m.model,
          'machine': m.model,
          'os_name': 'macOS',
          'os_version': '${m.majorVersion}.${m.minorVersion}.${m.patchVersion}',
          'arch': m.arch,
          if (m.memorySize > 0) 'total_memory_mb': m.memorySize ~/ (1024 * 1024),
        };
      case TargetPlatform.windows:
        final w = await plugin.windowsInfo;
        return <String, dynamic>{
          'os_name': w.productName.isNotEmpty ? w.productName : 'Windows',
          'os_version': w.displayVersion,
          'os_build': '${w.buildNumber}',
          if (w.systemMemoryInMegabytes > 0) 'total_memory_mb': w.systemMemoryInMegabytes,
        };
      case TargetPlatform.linux:
        final l = await plugin.linuxInfo;
        return <String, dynamic>{
          'os_name': l.name,
          'os_version': l.versionId ?? l.version,
        };
      default:
        return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadAppInfo() async {
    if (kIsWeb) return null; // would cost an extra fetch of version.json
    final p = await PackageInfo.fromPlatform();
    return <String, dynamic>{
      'version': p.version,
      'build_number': p.buildNumber,
      'package_name': p.packageName,
      'app_name': p.appName,
    };
  }
}
