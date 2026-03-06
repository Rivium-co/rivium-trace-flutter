import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/src/models/breadcrumb.dart';

void main() {
  group('BreadcrumbType', () {
    test('has all expected types', () {
      expect(BreadcrumbType.values, containsAll([
        BreadcrumbType.navigation,
        BreadcrumbType.user,
        BreadcrumbType.http,
        BreadcrumbType.state,
        BreadcrumbType.error,
        BreadcrumbType.info,
        BreadcrumbType.system,
      ]));
    });
  });

  group('Breadcrumb', () {
    test('creates breadcrumb with required fields', () {
      final now = DateTime.now();
      final crumb = Breadcrumb(
        message: 'User clicked button',
        type: BreadcrumbType.user,
        timestamp: now,
      );

      expect(crumb.message, 'User clicked button');
      expect(crumb.type, BreadcrumbType.user);
      expect(crumb.timestamp, now);
      expect(crumb.data, isNull);
    });

    test('creates breadcrumb with data', () {
      final crumb = Breadcrumb(
        message: 'GET /api/data',
        type: BreadcrumbType.http,
        timestamp: DateTime.now(),
        data: {'status_code': 200, 'method': 'GET'},
      );

      expect(crumb.data, {'status_code': 200, 'method': 'GET'});
    });

    group('toJson', () {
      test('serializes required fields', () {
        final now = DateTime(2024, 6, 15, 12, 0, 0);
        final crumb = Breadcrumb(
          message: 'Test',
          type: BreadcrumbType.info,
          timestamp: now,
        );

        final json = crumb.toJson();
        expect(json['message'], 'Test');
        expect(json['type'], 'info');
        expect(json['timestamp'], now.toIso8601String());
        expect(json.containsKey('data'), isFalse);
      });

      test('includes data when present', () {
        final crumb = Breadcrumb(
          message: 'Nav',
          type: BreadcrumbType.navigation,
          timestamp: DateTime.now(),
          data: {'from': '/home', 'to': '/settings'},
        );

        final json = crumb.toJson();
        expect(json['data'], {'from': '/home', 'to': '/settings'});
      });
    });

    group('fromJson', () {
      test('deserializes from JSON', () {
        final json = {
          'message': 'Navigated',
          'type': 'navigation',
          'timestamp': '2024-06-15T12:00:00.000',
          'data': {'from': '/a', 'to': '/b'},
        };

        final crumb = Breadcrumb.fromJson(json);
        expect(crumb.message, 'Navigated');
        expect(crumb.type, BreadcrumbType.navigation);
        expect(crumb.timestamp, DateTime(2024, 6, 15, 12, 0, 0));
        expect(crumb.data, {'from': '/a', 'to': '/b'});
      });

      test('defaults to info type for unknown type', () {
        final json = {
          'message': 'Unknown type',
          'type': 'nonexistent',
          'timestamp': '2024-01-01T00:00:00.000',
        };

        final crumb = Breadcrumb.fromJson(json);
        expect(crumb.type, BreadcrumbType.info);
      });

      test('handles missing data field', () {
        final json = {
          'message': 'No data',
          'type': 'error',
          'timestamp': '2024-01-01T00:00:00.000',
        };

        final crumb = Breadcrumb.fromJson(json);
        expect(crumb.data, isNull);
      });
    });

    test('toString returns formatted string', () {
      final crumb = Breadcrumb(
        message: 'Click login',
        type: BreadcrumbType.user,
        timestamp: DateTime.now(),
      );

      expect(crumb.toString(), '[BreadcrumbType.user] Click login');
    });
  });
}
