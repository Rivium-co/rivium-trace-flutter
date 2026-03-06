import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';
import 'platform_handler.dart';
import '../models/rivium_trace_error.dart';
import '../constants/rivium_trace_constants.dart';

// Factory function for web platform
PlatformHandler createPlatformHandler() {
  return WebHandler();
}

/// Web-specific platform handler
class WebHandler extends BasePlatformHandler {
  @override
  String getPlatform() {
    try {
      final userAgent = web.window.navigator.userAgent;
      if (userAgent.contains('Chrome')) {
        // Check if it's a Chrome extension by looking for extension-specific properties
        if (web.window.location.protocol == 'chrome-extension:') {
          return 'flutter_web_chrome_extension';
        }
        return 'flutter_web_chrome';
      } else if (userAgent.contains('Firefox')) {
        return 'flutter_web_firefox';
      } else if (userAgent.contains('Safari')) {
        return 'flutter_web_safari';
      }
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Could not detect browser type - $e');
      }
    }
    return 'flutter_web';
  }

  @override
  String getUserAgent(String? release) {
    try {
      return web.window.navigator.userAgent;
    } catch (e) {
      return 'RiviumTrace-SDK/${RiviumTraceConstants.sdkVersion} (flutter_web; ${release ?? 'unknown'})';
    }
  }

  @override
  void setupErrorHandling(Function(RiviumTraceError) onError) {
    try {
      // Handle JavaScript errors
      web.window.addEventListener(
        'error',
        (web.Event event) {
          // Use proper JS interop type checking
          if (event.isA<web.ErrorEvent>()) {
            final errorEvent = event as web.ErrorEvent;

            // Extract error details more carefully
            String message = 'Unknown JavaScript error';
            String stackTrace = '';

            try {
              message = errorEvent.message;
              if (message.isEmpty || message == 'Script error.') {
                message =
                    'JavaScript error at ${errorEvent.filename}:${errorEvent.lineno}:${errorEvent.colno}';
              }
            } catch (e) {
              message = 'Error extracting error message: $e';
            }

            try {
              // Extract the actual error message first
              var actualErrorMessage = message;

              // Check if we have additional error details from the error object
              if (errorEvent.error != null) {
                final errorObj = errorEvent.error!;

                // Try to get more detailed error information
                try {
                  final errorStr = errorObj.dartify();
                  if (errorStr != null && errorStr.toString().isNotEmpty) {
                    final errorDetails = errorStr.toString();
                    if (errorDetails != 'Uncaught' &&
                        errorDetails.length > message.length) {
                      actualErrorMessage = errorDetails;
                    }
                  }
                } catch (_) {
                  // Try basic toString
                  try {
                    final errorDetails = errorObj.toString();
                    if (errorDetails != 'Uncaught' &&
                        errorDetails.length > message.length) {
                      actualErrorMessage = errorDetails;
                    }
                  } catch (_) {}
                }
              }

              // Build a proper stack trace format for source map processing
              // If we don't have a proper JavaScript stack trace, create one
              if (stackTrace.isEmpty ||
                  stackTrace == 'Uncaught' ||
                  !stackTrace.contains('at ') ||
                  !RegExp(r'at .+ \(.+\.js:\d+:\d+\)').hasMatch(stackTrace)) {
                // Construct a JavaScript-style stack trace with the REAL error message
                final filename = errorEvent.filename;
                final line = errorEvent.lineno;
                final col = errorEvent.colno;

                // Use the actual error message, not just "Uncaught"
                stackTrace =
                    '''$actualErrorMessage
    at Error ($filename:$line:$col)
    at Object.throw_ ($filename:$line:$col)
    at Function.main ($filename:$line:$col)''';

                // Also update the message to be the actual error
                message = actualErrorMessage;

                if (kDebugMode) {
                  print(
                    'RiviumTrace: Created synthetic stack trace for source map processing',
                  );
                  print(
                    'RiviumTrace: Using actual error message: $actualErrorMessage',
                  );
                }
              }
            } catch (e) {
              // Fallback: create a minimal stack trace with location info
              final filename = errorEvent.filename;
              final line = errorEvent.lineno;
              final col = errorEvent.colno;

              stackTrace = '''$message
    at Error ($filename:$line:$col)''';
            }

            onError(
              RiviumTraceError(
                message: message,
                stackTrace: stackTrace,
                platform: getPlatform(),
                environment: 'production', // Will be overridden by config
                release: null, // Will be overridden by config
                timestamp: DateTime.now(),
                extra: {
                  'filename': errorEvent.filename,
                  'lineno': errorEvent.lineno,
                  'colno': errorEvent.colno,
                  'url': web.window.location.href,
                  'error_type': 'javascript_error',
                  'user_agent': web.window.navigator.userAgent,
                },
              ),
            );
          } else {
            // Handle generic events that aren't ErrorEvent
            onError(
              RiviumTraceError(
                message: 'Generic web error: ${event.type}',
                stackTrace: StackTrace.current.toString(),
                platform: getPlatform(),
                environment: 'production', // Will be overridden by config
                release: null, // Will be overridden by config
                timestamp: DateTime.now(),
                extra: {
                  'url': web.window.location.href,
                  'error_type': 'generic_web_error',
                  'event_type': event.type,
                },
              ),
            );
          }
        }.toJS,
      );

      // Handle unhandled promise rejections
      web.window.addEventListener(
        'unhandledrejection',
        (web.Event event) {
          String message = 'Unhandled Promise Rejection';
          String details = 'No details available';

          try {
            // Try to extract rejection reason
            details = event.toString();
            if (details.isNotEmpty && details != 'Uncaught') {
              message = 'Unhandled Promise Rejection: $details';
            }
          } catch (e) {
            details = 'Error extracting rejection details: $e';
          }

          onError(
            RiviumTraceError(
              message: message,
              stackTrace:
                  '${StackTrace.current}\n\nRejection details: $details',
              platform: getPlatform(),
              environment: 'production', // Will be overridden by config
              release: null, // Will be overridden by config
              timestamp: DateTime.now(),
              extra: {
                'url': web.window.location.href,
                'error_type': 'unhandled_rejection',
                'rejection_details': details,
                'user_agent': web.window.navigator.userAgent,
              },
            ),
          );
        }.toJS,
      );
    } catch (e) {
      if (kDebugMode) {
        print('RiviumTrace: Could not set up web error handling - $e');
      }
    }
  }
}
