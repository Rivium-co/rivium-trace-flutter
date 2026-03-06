import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() {
  group('RiviumTraceError', () {
    test('creates error with required fields', () {
      final now = DateTime.now();
      final error = RiviumTraceError(
        message: 'Test error',
        stackTrace: 'stack trace here',
        platform: 'flutter_ios',
        environment: 'production',
        timestamp: now,
      );

      expect(error.message, 'Test error');
      expect(error.stackTrace, 'stack trace here');
      expect(error.platform, 'flutter_ios');
      expect(error.environment, 'production');
      expect(error.timestamp, now);
      expect(error.release, isNull);
      expect(error.extra, isNull);
      expect(error.tags, isNull);
      expect(error.url, isNull);
    });

    test('creates error with all optional fields', () {
      final now = DateTime.now();
      final error = RiviumTraceError(
        message: 'Full error',
        stackTrace: 'stack',
        platform: 'flutter_android',
        environment: 'staging',
        timestamp: now,
        release: '1.0.0',
        extra: {'key': 'value'},
        tags: {'tag1': 'val1'},
        url: 'https://example.com/page',
      );

      expect(error.release, '1.0.0');
      expect(error.extra, {'key': 'value'});
      expect(error.tags, {'tag1': 'val1'});
      expect(error.url, 'https://example.com/page');
    });

    group('toJson', () {
      test('includes required fields', () {
        final now = DateTime(2024, 1, 15, 10, 30, 0);
        final error = RiviumTraceError(
          message: 'Test error',
          stackTrace: 'stack trace',
          platform: 'flutter_ios',
          environment: 'production',
          timestamp: now,
        );

        final json = error.toJson();

        expect(json['message'], 'Test error');
        expect(json['stack_trace'], 'stack trace');
        expect(json['platform'], 'flutter_ios');
        expect(json['environment'], 'production');
        expect(json['timestamp'], now.toIso8601String());
      });

      test('includes release_version when set', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_ios',
          environment: 'prod',
          timestamp: DateTime.now(),
          release: '2.0.0',
        );

        final json = error.toJson();
        expect(json['release_version'], '2.0.0');
      });

      test('does not include release_version when null', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_ios',
          environment: 'prod',
          timestamp: DateTime.now(),
        );

        final json = error.toJson();
        expect(json.containsKey('release_version'), isFalse);
      });

      test('includes tags when present', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_ios',
          environment: 'prod',
          timestamp: DateTime.now(),
          tags: {'severity': 'high', 'module': 'auth'},
        );

        final json = error.toJson();
        expect(json['tags'], {'severity': 'high', 'module': 'auth'});
      });

      test('does not include tags when empty', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_ios',
          environment: 'prod',
          timestamp: DateTime.now(),
          tags: {},
        );

        final json = error.toJson();
        expect(json.containsKey('tags'), isFalse);
      });

      test('extracts breadcrumbs from extra to root level', () {
        final breadcrumbs = [
          {'message': 'crumb1', 'type': 'info'},
          {'message': 'crumb2', 'type': 'error'},
        ];
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_ios',
          environment: 'prod',
          timestamp: DateTime.now(),
          extra: {
            'breadcrumbs': breadcrumbs,
            'other_key': 'other_value',
          },
        );

        final json = error.toJson();
        expect(json['breadcrumbs'], breadcrumbs);
        expect((json['extra'] as Map)['other_key'], 'other_value');
        expect((json['extra'] as Map).containsKey('breadcrumbs'), isFalse);
      });

      test('extracts url from extra to root level when url field is null', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_web',
          environment: 'prod',
          timestamp: DateTime.now(),
          extra: {
            'url': 'https://app.example.com/dashboard',
            'other': 'data',
          },
        );

        final json = error.toJson();
        expect(json['url'], 'https://app.example.com/dashboard');
        expect((json['extra'] as Map).containsKey('url'), isFalse);
      });

      test('keeps url field over extra url', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_web',
          environment: 'prod',
          timestamp: DateTime.now(),
          url: 'https://main-url.com',
          extra: {
            'url': 'https://extra-url.com',
          },
        );

        final json = error.toJson();
        expect(json['url'], 'https://main-url.com');
      });

      test('omits extra when empty after extraction', () {
        final error = RiviumTraceError(
          message: 'err',
          stackTrace: 'st',
          platform: 'flutter_ios',
          environment: 'prod',
          timestamp: DateTime.now(),
          extra: {
            'breadcrumbs': [
              {'message': 'crumb'}
            ],
          },
        );

        final json = error.toJson();
        expect(json.containsKey('extra'), isFalse);
        expect(json['breadcrumbs'], isNotNull);
      });
    });

    test('toString returns formatted string', () {
      final error = RiviumTraceError(
        message: 'Test',
        stackTrace: 'st',
        platform: 'flutter_ios',
        environment: 'production',
        timestamp: DateTime.now(),
      );

      expect(
        error.toString(),
        'RiviumTraceError(message: Test, platform: flutter_ios, environment: production)',
      );
    });
  });
}
