import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() {
  group('LogLevel', () {
    test('has correct string values', () {
      expect(LogLevel.trace.value, 'trace');
      expect(LogLevel.debug.value, 'debug');
      expect(LogLevel.info.value, 'info');
      expect(LogLevel.warn.value, 'warn');
      expect(LogLevel.error.value, 'error');
      expect(LogLevel.fatal.value, 'fatal');
    });
  });

  group('LogEntry', () {
    test('creates entry with required message', () {
      final entry = LogEntry(message: 'Hello world');

      expect(entry.message, 'Hello world');
      expect(entry.level, LogLevel.info); // default
      expect(entry.timestamp, isNull);
      expect(entry.metadata, isNull);
      expect(entry.userId, isNull);
    });

    test('creates entry with all fields', () {
      final now = DateTime.now();
      final entry = LogEntry(
        message: 'User logged in',
        level: LogLevel.warn,
        timestamp: now,
        metadata: {'ip': '192.168.1.1'},
        userId: 'user-123',
      );

      expect(entry.message, 'User logged in');
      expect(entry.level, LogLevel.warn);
      expect(entry.timestamp, now);
      expect(entry.metadata, {'ip': '192.168.1.1'});
      expect(entry.userId, 'user-123');
    });

    group('toJson', () {
      test('includes message and level', () {
        final entry = LogEntry(message: 'Test', level: LogLevel.error);

        final json = entry.toJson();
        expect(json['message'], 'Test');
        expect(json['level'], 'error');
      });

      test('includes timestamp when present', () {
        final now = DateTime(2024, 3, 1, 8, 0, 0);
        final entry = LogEntry(message: 'Test', timestamp: now);

        final json = entry.toJson();
        expect(json['timestamp'], now.toIso8601String());
      });

      test('excludes null optional fields', () {
        final entry = LogEntry(message: 'Test');

        final json = entry.toJson();
        expect(json.containsKey('timestamp'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
        expect(json.containsKey('userId'), isFalse);
      });

      test('includes metadata and userId when present', () {
        final entry = LogEntry(
          message: 'Test',
          metadata: {'key': 'val'},
          userId: 'u-1',
        );

        final json = entry.toJson();
        expect(json['metadata'], {'key': 'val'});
        expect(json['userId'], 'u-1');
      });
    });
  });
}
