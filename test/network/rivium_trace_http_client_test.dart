import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';
import 'package:rivium_trace_flutter_sdk/src/models/breadcrumb.dart';

void main() {
  group('RiviumTraceHttpClient', () {
    setUp(() {
      RiviumTraceBreadcrumbs.clear();
    });

    test('forwards requests to inner client', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('{"ok": true}', 200);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      final response = await client.get(
        Uri.parse('https://api.example.com/data'),
      );

      expect(response.statusCode, 200);
      expect(response.body, '{"ok": true}');

      client.close();
    });

    test('adds HTTP breadcrumb on successful request', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('ok', 200);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.get(Uri.parse('https://api.example.com/users'));

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.length, 1);
      expect(crumbs.first.type, BreadcrumbType.http);
      expect(crumbs.first.message, contains('GET'));
      expect(crumbs.first.data!['method'], 'GET');
      expect(crumbs.first.data!['status_code'], 200);

      client.close();
    });

    test('adds error breadcrumb on 4xx response', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('not found', 404);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.get(Uri.parse('https://api.example.com/missing'));

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      // Should have HTTP breadcrumb + error breadcrumb
      expect(crumbs.length, 2);
      final errorCrumb = crumbs.firstWhere((c) => c.type == BreadcrumbType.error);
      expect(errorCrumb.message, contains('Client Error'));
      expect(errorCrumb.data!['status_code'], 404);

      client.close();
    });

    test('adds error breadcrumb on 5xx response', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('server error', 500);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.get(Uri.parse('https://api.example.com/broken'));

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      final errorCrumb = crumbs.firstWhere((c) => c.type == BreadcrumbType.error);
      expect(errorCrumb.message, contains('Server Error'));
      expect(errorCrumb.data!['status_code'], 500);

      client.close();
    });

    test('does not add error breadcrumb when captureErrors is false', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('error', 500);
      });

      final client = RiviumTraceHttpClient(
        inner: mockClient,
        captureErrors: false,
      );
      await client.get(Uri.parse('https://api.example.com/broken'));

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      // Only HTTP breadcrumb, no error breadcrumb
      expect(crumbs.length, 1);
      expect(crumbs.first.type, BreadcrumbType.http);

      client.close();
    });

    test('skips tracking for excluded hosts', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('ok', 200);
      });

      final client = RiviumTraceHttpClient(
        inner: mockClient,
        excludedHosts: {'internal.api.com'},
      );
      await client.get(Uri.parse('https://internal.api.com/health'));

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs, isEmpty);

      client.close();
    });

    test('skips tracking for rivium API calls', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('ok', 200);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.get(Uri.parse('https://trace.rivium.co/api/errors'));

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs, isEmpty);

      client.close();
    });

    test('adds error breadcrumb on network failure', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('No internet connection');
      });

      final client = RiviumTraceHttpClient(inner: mockClient);

      expect(
        () => client.get(Uri.parse('https://api.example.com/data')),
        throwsA(isA<Exception>()),
      );

      // Wait for the error handling to complete
      try {
        await client.get(Uri.parse('https://api.example.com/data'));
      } catch (_) {}

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.isNotEmpty, isTrue);
      final errorCrumb = crumbs.firstWhere((c) => c.type == BreadcrumbType.error);
      expect(errorCrumb.message, contains('HTTP Request Failed'));

      client.close();
    });

    test('sanitizes sensitive query parameters', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('ok', 200);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.get(
        Uri.parse('https://api.example.com/data?token=secret123&page=1'),
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      final url = crumbs.first.data!['url'] as String;
      // [REDACTED] gets URL-encoded to %5BREDACTED%5D by Uri.replace
      expect(url, isNot(contains('secret123')));
      expect(url, contains('page=1'));

      client.close();
    });

    test('sanitizes multiple sensitive params', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('ok', 200);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.get(
        Uri.parse(
          'https://api.example.com/auth?api_key=key123&password=pass&name=john',
        ),
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      final url = crumbs.first.data!['url'] as String;
      expect(url, isNot(contains('key123')));
      // Check that the password value is redacted (not the literal string)
      expect(url, isNot(contains('password=pass&')));
      expect(url, contains('name=john'));

      client.close();
    });

    test('handles POST requests', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('created', 201);
      });

      final client = RiviumTraceHttpClient(inner: mockClient);
      await client.post(
        Uri.parse('https://api.example.com/users'),
        body: jsonEncode({'name': 'John'}),
        headers: {'Content-Type': 'application/json'},
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.data!['method'], 'POST');
      expect(crumbs.first.data!['status_code'], 201);

      client.close();
    });
  });

  group('RiviumTraceHttpClientExtension', () {
    test('withRiviumTrace wraps existing client', () {
      final inner = http.Client();
      final wrapped = inner.withRiviumTrace();

      expect(wrapped, isA<RiviumTraceHttpClient>());

      wrapped.close();
    });

    test('withRiviumTrace passes options', () {
      final inner = http.Client();
      final wrapped = inner.withRiviumTrace(
        captureErrors: false,
        excludedHosts: {'test.com'},
      );

      expect(wrapped, isA<RiviumTraceHttpClient>());

      wrapped.close();
    });
  });
}
