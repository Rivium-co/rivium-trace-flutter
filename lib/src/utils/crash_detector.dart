import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import '../models/rivium_trace_error.dart';

/// Utility for detecting crashes from previous app sessions (mobile only)
///
/// How it works:
/// 1. On app start: Check if "clean exit" marker exists
/// 2. If NO clean exit marker → Previous session crashed
/// 3. Mark app as "running" (delete clean exit marker)
/// 4. On app pause/background: Create clean exit marker
/// 5. If app crashes, the clean exit marker won't exist on next launch
///
/// IMPORTANT: Crash detection is DISABLED in debug mode (kDebugMode) because
/// stopping the debugger in VS Code/Android Studio kills the app without
/// triggering lifecycle callbacks, causing false positive "crash" reports.
class CrashDetector with WidgetsBindingObserver {
  static const String _cleanExitFile = 'rivium_trace_clean_exit.txt';
  static const String _sessionFile = 'rivium_trace_session.txt';

  static CrashDetector? _instance;
  static bool _isObserving = false;

  CrashDetector._();

  /// Check if crash detection should be enabled
  /// Disabled in debug mode to avoid false positives from debugger stops
  static bool get _shouldDetectCrashes => !kDebugMode;

  /// Get the clean exit marker file
  static Future<File> _getCleanExitFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_cleanExitFile');
  }

  /// Get the session file (tracks when app started)
  static Future<File> _getSessionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_sessionFile');
  }

  /// Start observing app lifecycle to detect graceful exits
  static void startObserving() {
    // Skip crash detection in debug mode to avoid false positives
    if (!_shouldDetectCrashes) {
      if (kDebugMode) {
        print('RiviumTrace: Crash detection disabled in debug mode');
      }
      return;
    }

    if (_isObserving) return;

    _instance = CrashDetector._();
    WidgetsBinding.instance.addObserver(_instance!);
    _isObserving = true;

    if (kDebugMode) {
      print('RiviumTrace: Started lifecycle observer for crash detection');
    }
  }

  /// Stop observing app lifecycle
  static void stopObserving() {
    if (!_isObserving || _instance == null) return;

    WidgetsBinding.instance.removeObserver(_instance!);
    _instance = null;
    _isObserving = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (kDebugMode) {
      print('RiviumTrace: App lifecycle state changed to: $state');
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is going to background or being closed - mark as clean exit
        _markCleanExitSync();
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground - remove clean exit marker
        // (we're now "running" again)
        _removeCleanExitMarker();
        break;
      case AppLifecycleState.inactive:
        // Transitional state, do nothing
        break;
    }
  }

  /// Synchronous version for lifecycle callbacks (can't await in didChangeAppLifecycleState)
  static void _markCleanExitSync() {
    _markCleanExit().catchError((e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to mark clean exit - $e');
      }
    });
  }

  /// Mark that the app is exiting cleanly (going to background)
  static Future<void> _markCleanExit() async {
    try {
      final file = await _getCleanExitFile();
      await file.writeAsString(DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to mark clean exit - $e');
      }
    }
  }

  /// Remove clean exit marker (app is now running)
  static Future<void> _removeCleanExitMarker() async {
    try {
      final file = await _getCleanExitFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to remove clean exit marker - $e');
      }
    }
  }

  /// Mark that the app has started - records session start time
  /// and removes clean exit marker (we're now running)
  static Future<void> markAppStart() async {
    // Skip in debug mode
    if (!_shouldDetectCrashes) return;

    try {
      // Record session start time
      final sessionFile = await _getSessionFile();
      await sessionFile.writeAsString(DateTime.now().toIso8601String());

      // Remove clean exit marker since we're now running
      await _removeCleanExitMarker();

      // Start observing lifecycle
      startObserving();
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to mark app start - $e');
      }
    }
  }

  /// Mark that the app is closing gracefully
  /// Call this when the app is disposed properly (optional, lifecycle handles this)
  static Future<void> markAppClose() async {
    try {
      stopObserving();
      await _markCleanExit();

      // Clean up session file
      final sessionFile = await _getSessionFile();
      if (await sessionFile.exists()) {
        await sessionFile.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to mark app close - $e');
      }
    }
  }

  /// Check if the app crashed in the previous session
  /// Returns true if:
  /// 1. Session file exists (app was running)
  /// 2. Clean exit file does NOT exist (app didn't exit cleanly)
  ///
  /// Always returns false in debug mode to avoid false positives.
  static Future<bool> didCrashLastSession() async {
    // Never report crashes in debug mode - debugger stops cause false positives
    if (!_shouldDetectCrashes) {
      if (kDebugMode) {
        print('RiviumTrace: Crash detection skipped (debug mode)');
      }
      // Clean up any stale files from previous debug sessions
      await cleanup();
      return false;
    }

    try {
      final sessionFile = await _getSessionFile();
      final cleanExitFile = await _getCleanExitFile();

      final hadSession = await sessionFile.exists();
      final hadCleanExit = await cleanExitFile.exists();

      if (kDebugMode) {
        print('RiviumTrace: Crash check - hadSession: $hadSession, hadCleanExit: $hadCleanExit');
      }

      // Crash = had a session but didn't exit cleanly
      return hadSession && !hadCleanExit;
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to check crash status - $e');
      }
      return false;
    }
  }

  /// Get the timestamp of when the crash occurred (session start time)
  static Future<DateTime?> getLastCrashTime() async {
    try {
      final sessionFile = await _getSessionFile();
      if (await sessionFile.exists()) {
        final content = await sessionFile.readAsString();
        return DateTime.tryParse(content);
      }
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to get crash time - $e');
      }
    }
    return null;
  }

  /// Create a crash report for native crashes
  /// This will be sent on the next app launch
  static Future<RiviumTraceError?> getCrashReport(
    String platform,
    String environment,
    String? release,
  ) async {
    try {
      final crashTime = await getLastCrashTime();
      if (crashTime == null) return null;

      // Calculate how long the app ran before crashing
      final crashDuration = DateTime.now().difference(crashTime);

      return RiviumTraceError(
        message: 'Native crash detected from previous session',
        stackTrace: 'Native crash - No Dart stack trace available\n'
            'The app terminated unexpectedly without proper cleanup.\n'
            'This indicates a native crash (SIGABRT, SIGSEGV, etc.) or force-close.\n'
            'Session started at: ${crashTime.toIso8601String()}\n'
            'Time since session start: ${crashDuration.inSeconds} seconds',
        platform: platform,
        environment: environment,
        release: release,
        timestamp: crashTime,
        extra: {
          'error_type': 'native_crash',
          'crash_detected': true,
          'session_start_time': crashTime.toIso8601String(),
          'detected_time': DateTime.now().toIso8601String(),
          'session_duration_seconds': crashDuration.inSeconds,
          'is_previous_session': true,
          'notes':
              'This crash occurred in a previous app session. '
                  'Native crashes (SIGABRT, SIGSEGV, memory corruption) '
                  'or force-closes cannot be caught by Dart error handlers.',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to create crash report - $e');
      }
      return null;
    }
  }

  /// Clean up all crash detection files
  static Future<void> cleanup() async {
    try {
      stopObserving();

      final cleanExitFile = await _getCleanExitFile();
      final sessionFile = await _getSessionFile();

      if (await cleanExitFile.exists()) {
        await cleanExitFile.delete();
      }
      if (await sessionFile.exists()) {
        await sessionFile.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Failed to cleanup crash files - $e');
      }
    }
  }
}
