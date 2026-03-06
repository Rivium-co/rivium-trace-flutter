import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';
import 'package:rivium_trace_flutter_sdk/src/services/rivium_trace_logger.dart';

void main() {
  group('RiviumTraceLogger', () {
    setUp(() {
      RiviumTraceLogger.setEnabled(false);
      RiviumTraceLogger.setLogHandler(null);
    });

    test('does not call handler when disabled', () {
      var called = false;
      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        called = true;
      });

      RiviumTraceLogger.setEnabled(false);
      RiviumTraceLogger.info('test');

      expect(called, isFalse);
    });

    test('calls custom handler when enabled', () {
      RiviumTraceLogLevel? capturedLevel;
      String? capturedMessage;

      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        capturedLevel = level;
        capturedMessage = message;
      });
      RiviumTraceLogger.setEnabled(true);

      RiviumTraceLogger.info('Test message');

      expect(capturedLevel, RiviumTraceLogLevel.info);
      expect(capturedMessage, 'Test message');
    });

    test('debug logs with debug level', () {
      RiviumTraceLogLevel? capturedLevel;
      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        capturedLevel = level;
      });
      RiviumTraceLogger.setEnabled(true);

      RiviumTraceLogger.debug('debug msg');
      expect(capturedLevel, RiviumTraceLogLevel.debug);
    });

    test('warning logs with warning level and optional error', () {
      RiviumTraceLogLevel? capturedLevel;
      Object? capturedError;

      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        capturedLevel = level;
        capturedError = error;
      });
      RiviumTraceLogger.setEnabled(true);

      final testError = Exception('test error');
      RiviumTraceLogger.warning('warn msg', testError);

      expect(capturedLevel, RiviumTraceLogLevel.warning);
      expect(capturedError, testError);
    });

    test('error logs with error level, error, and stack trace', () {
      RiviumTraceLogLevel? capturedLevel;
      Object? capturedError;
      StackTrace? capturedStack;

      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        capturedLevel = level;
        capturedError = error;
        capturedStack = stackTrace;
      });
      RiviumTraceLogger.setEnabled(true);

      final testError = Exception('critical');
      final testStack = StackTrace.current;
      RiviumTraceLogger.error('error msg', testError, testStack);

      expect(capturedLevel, RiviumTraceLogLevel.error);
      expect(capturedError, testError);
      expect(capturedStack, testStack);
    });

    test('multiple log calls are captured', () {
      final messages = <String>[];
      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        messages.add(message);
      });
      RiviumTraceLogger.setEnabled(true);

      RiviumTraceLogger.debug('msg1');
      RiviumTraceLogger.info('msg2');
      RiviumTraceLogger.warning('msg3');
      RiviumTraceLogger.error('msg4');

      expect(messages, ['msg1', 'msg2', 'msg3', 'msg4']);
    });

    test('setting handler to null removes it', () {
      var callCount = 0;
      RiviumTraceLogger.setLogHandler((level, message, error, stackTrace) {
        callCount++;
      });
      RiviumTraceLogger.setEnabled(true);

      RiviumTraceLogger.info('before');
      expect(callCount, 1);

      RiviumTraceLogger.setLogHandler(null);
      RiviumTraceLogger.info('after');
      // No error thrown, handler just not called
      expect(callCount, 1);
    });
  });

  group('RiviumTraceLogLevel', () {
    test('has all expected levels', () {
      expect(RiviumTraceLogLevel.values, containsAll([
        RiviumTraceLogLevel.debug,
        RiviumTraceLogLevel.info,
        RiviumTraceLogLevel.warning,
        RiviumTraceLogLevel.error,
      ]));
    });
  });
}
