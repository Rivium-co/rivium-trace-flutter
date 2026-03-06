import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'platform_handler.dart';
import '../models/rivium_trace_error.dart';
import '../constants/rivium_trace_constants.dart';

// Factory function for mobile platform
PlatformHandler createPlatformHandler() {
  return MobileHandler();
}

/// Mobile/Desktop platform handler
class MobileHandler extends BasePlatformHandler {
  RawReceivePort? _errorPort;

  @override
  String getUserAgent(String? release) {
    return 'RiviumTrace-SDK/${RiviumTraceConstants.sdkVersion} (${getPlatform()}; ${release ?? 'unknown'})';
  }

  @override
  void setupErrorHandling(Function(RiviumTraceError) onError) {
    try {
      // Handle isolate errors
      _errorPort = RawReceivePort((dynamic pair) async {
        try {
          if (pair is List<dynamic> && pair.length >= 2) {
            final List<dynamic> errorAndStacktrace = pair;
            onError(
              RiviumTraceError(
                message: errorAndStacktrace.first.toString(),
                stackTrace: errorAndStacktrace.last.toString(),
                platform: getPlatform(),
                environment: 'production', // Will be overridden by config
                release: null, // Will be overridden by config
                timestamp: DateTime.now(),
                extra: {'error_type': 'isolate_error'},
              ),
            );
          } else {
            // Handle cases where the error format is unexpected
            onError(
              RiviumTraceError(
                message: 'Isolate error: ${pair.toString()}',
                stackTrace: StackTrace.current.toString(),
                platform: getPlatform(),
                environment: 'production',
                release: null,
                timestamp: DateTime.now(),
                extra: {
                  'error_type': 'isolate_error_unexpected_format',
                  'raw_error': pair.toString(),
                },
              ),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('RiviumTrace: Error processing isolate error - $e');
          }
        }
      });

      Isolate.current.addErrorListener(_errorPort!.sendPort);
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Could not set up isolate error handling - $e');
      }
    }
  }

  @override
  void dispose() {
    _errorPort?.close();
    _errorPort = null;
  }
}
