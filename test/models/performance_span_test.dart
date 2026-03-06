import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() {
  group('PerformanceSpan', () {
    test('creates span with required fields', () {
      final startTime = DateTime.now();
      final span = PerformanceSpan(
        operation: 'fetchUsers',
        durationMs: 150.0,
        startTime: startTime,
      );

      expect(span.operation, 'fetchUsers');
      expect(span.durationMs, 150.0);
      expect(span.startTime, startTime);
      expect(span.operationType, 'http'); // default
      expect(span.status, 'ok'); // default
    });

    group('fromHttpRequest', () {
      test('creates span from HTTP request', () {
        final startTime = DateTime.now();
        final span = PerformanceSpan.fromHttpRequest(
          method: 'GET',
          url: 'https://api.example.com/users?page=1',
          startTime: startTime,
          durationMs: 200.0,
          statusCode: 200,
        );

        expect(span.operation, 'GET /users');
        expect(span.operationType, 'http');
        expect(span.httpMethod, 'GET');
        expect(span.httpUrl, 'https://api.example.com/users?page=1');
        expect(span.httpStatusCode, 200);
        expect(span.httpHost, 'api.example.com');
        expect(span.durationMs, 200.0);
        expect(span.status, 'ok');
      });

      test('sets error status for 4xx status codes', () {
        final span = PerformanceSpan.fromHttpRequest(
          method: 'POST',
          url: 'https://api.example.com/login',
          startTime: DateTime.now(),
          durationMs: 50.0,
          statusCode: 401,
        );

        expect(span.status, 'error');
      });

      test('sets error status for 5xx status codes', () {
        final span = PerformanceSpan.fromHttpRequest(
          method: 'GET',
          url: 'https://api.example.com/data',
          startTime: DateTime.now(),
          durationMs: 5000.0,
          statusCode: 500,
        );

        expect(span.status, 'error');
      });

      test('sets error status when errorMessage is provided', () {
        final span = PerformanceSpan.fromHttpRequest(
          method: 'GET',
          url: 'https://api.example.com/data',
          startTime: DateTime.now(),
          durationMs: 100.0,
          errorMessage: 'Connection timeout',
        );

        expect(span.status, 'error');
        expect(span.errorMessage, 'Connection timeout');
      });
    });

    group('forDbQuery', () {
      test('creates span for database query', () {
        final startTime = DateTime.now();
        final span = PerformanceSpan.forDbQuery(
          queryType: 'SELECT',
          tableName: 'users',
          startTime: startTime,
          durationMs: 25.0,
        );

        expect(span.operation, 'SELECT users');
        expect(span.operationType, 'db');
        expect(span.durationMs, 25.0);
        expect(span.status, 'ok');
      });

      test('creates span without table name', () {
        final span = PerformanceSpan.forDbQuery(
          queryType: 'VACUUM',
          startTime: DateTime.now(),
          durationMs: 1000.0,
        );

        expect(span.operation, 'VACUUM');
      });

      test('includes rows affected in metadata', () {
        final span = PerformanceSpan.forDbQuery(
          queryType: 'DELETE',
          tableName: 'sessions',
          startTime: DateTime.now(),
          durationMs: 15.0,
          rowsAffected: 42,
        );

        expect(span.metadata, {'rows_affected': 42});
      });

      test('sets error status with error message', () {
        final span = PerformanceSpan.forDbQuery(
          queryType: 'INSERT',
          tableName: 'users',
          startTime: DateTime.now(),
          durationMs: 5.0,
          errorMessage: 'Unique constraint violation',
        );

        expect(span.status, 'error');
        expect(span.errorMessage, 'Unique constraint violation');
      });
    });

    group('custom', () {
      test('creates custom span', () {
        final startTime = DateTime.now();
        final span = PerformanceSpan.custom(
          operation: 'processImages',
          startTime: startTime,
          durationMs: 500.0,
          tags: {'batch': 'true'},
          metadata: {'imageCount': 10},
        );

        expect(span.operation, 'processImages');
        expect(span.operationType, 'custom');
        expect(span.durationMs, 500.0);
        expect(span.tags, {'batch': 'true'});
        expect(span.metadata, {'imageCount': 10});
        expect(span.status, 'ok');
      });
    });

    group('toJson', () {
      test('includes required fields', () {
        final startTime = DateTime(2024, 1, 15, 10, 0, 0);
        final span = PerformanceSpan(
          operation: 'test_op',
          durationMs: 100.0,
          startTime: startTime,
          status: 'ok',
        );

        final json = span.toJson();
        expect(json['operation'], 'test_op');
        expect(json['operation_type'], 'http');
        expect(json['duration_ms'], 100.0);
        expect(json['start_time'], startTime.toUtc().toIso8601String());
        expect(json['status'], 'ok');
      });

      test('includes optional fields when present', () {
        final span = PerformanceSpan(
          traceId: 'trace-123',
          spanId: 'span-456',
          parentSpanId: 'parent-789',
          operation: 'GET /api',
          operationType: 'http',
          httpMethod: 'GET',
          httpUrl: 'https://api.com/data',
          httpStatusCode: 200,
          httpHost: 'api.com',
          durationMs: 150.0,
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          platform: 'flutter_ios',
          environment: 'production',
          releaseVersion: '1.0.0',
          tags: {'key': 'val'},
          metadata: {'info': 'data'},
          status: 'ok',
          errorMessage: null,
        );

        final json = span.toJson();
        expect(json['trace_id'], 'trace-123');
        expect(json['span_id'], 'span-456');
        expect(json['parent_span_id'], 'parent-789');
        expect(json['http_method'], 'GET');
        expect(json['http_url'], 'https://api.com/data');
        expect(json['http_status_code'], 200);
        expect(json['http_host'], 'api.com');
        expect(json['platform'], 'flutter_ios');
        expect(json['environment'], 'production');
        expect(json['release_version'], '1.0.0');
        expect(json['tags'], {'key': 'val'});
        expect(json['metadata'], {'info': 'data'});
      });

      test('excludes null optional fields', () {
        final span = PerformanceSpan(
          operation: 'test',
          durationMs: 10.0,
          startTime: DateTime.now(),
        );

        final json = span.toJson();
        expect(json.containsKey('trace_id'), isFalse);
        expect(json.containsKey('span_id'), isFalse);
        expect(json.containsKey('http_method'), isFalse);
        expect(json.containsKey('error_message'), isFalse);
        expect(json.containsKey('tags'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    test('toString returns formatted string', () {
      final span = PerformanceSpan(
        operation: 'GET /api/users',
        operationType: 'http',
        durationMs: 150.0,
        startTime: DateTime.now(),
      );

      final str = span.toString();
      expect(str, contains('GET /api/users'));
      expect(str, contains('http'));
      expect(str, contains('150.0'));
      expect(str, contains('ok'));
    });
  });
}
