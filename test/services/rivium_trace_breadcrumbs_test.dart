import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';
import 'package:rivium_trace_flutter_sdk/src/models/breadcrumb.dart';

void main() {
  group('RiviumTraceBreadcrumbs', () {
    setUp(() {
      RiviumTraceBreadcrumbs.clear();
      RiviumTraceBreadcrumbs.setMaxBreadcrumbs(20);
    });

    test('starts with empty breadcrumbs', () {
      expect(RiviumTraceBreadcrumbs.getBreadcrumbs(), isEmpty);
    });

    test('adds a breadcrumb', () {
      RiviumTraceBreadcrumbs.add('Test crumb');

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.length, 1);
      expect(crumbs.first.message, 'Test crumb');
      expect(crumbs.first.type, BreadcrumbType.info); // default type
    });

    test('adds breadcrumb with type and data', () {
      RiviumTraceBreadcrumbs.add(
        'Button pressed',
        type: BreadcrumbType.user,
        data: {'button': 'submit'},
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.user);
      expect(crumbs.first.data, {'button': 'submit'});
    });

    test('addNavigation creates navigation breadcrumb', () {
      RiviumTraceBreadcrumbs.addNavigation('/home', '/settings');

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.navigation);
      expect(crumbs.first.message, 'Navigated from /home to /settings');
      expect(crumbs.first.data, {'from': '/home', 'to': '/settings'});
    });

    test('addUser creates user breadcrumb', () {
      RiviumTraceBreadcrumbs.addUser('clicked login', data: {'page': 'auth'});

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.user);
      expect(crumbs.first.message, 'User clicked login');
      expect(crumbs.first.data, {'page': 'auth'});
    });

    test('addHttp creates HTTP breadcrumb', () {
      RiviumTraceBreadcrumbs.addHttp('GET', 'https://api.com/users', 200);

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.http);
      expect(crumbs.first.message, contains('GET'));
      expect(crumbs.first.message, contains('https://api.com/users'));
      expect(crumbs.first.data!['method'], 'GET');
      expect(crumbs.first.data!['status_code'], 200);
    });

    test('addHttp handles null statusCode', () {
      RiviumTraceBreadcrumbs.addHttp('POST', 'https://api.com/data', null);

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.data!.containsKey('status_code'), isFalse);
    });

    test('addState creates state breadcrumb', () {
      RiviumTraceBreadcrumbs.addState(
        'Auth state changed',
        data: {'authenticated': true},
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.state);
      expect(crumbs.first.message, 'State: Auth state changed');
    });

    test('addSystem creates system breadcrumb', () {
      RiviumTraceBreadcrumbs.addSystem(
        'SDK initialized',
        data: {'version': '1.0.0'},
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.system);
      expect(crumbs.first.message, 'SDK initialized');
    });

    test('addError creates error breadcrumb', () {
      RiviumTraceBreadcrumbs.addError(
        'Exception occurred',
        data: {'type': 'FormatException'},
      );

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.first.type, BreadcrumbType.error);
      expect(crumbs.first.message, 'Exception occurred');
    });

    test('respects max breadcrumbs limit', () {
      RiviumTraceBreadcrumbs.setMaxBreadcrumbs(3);

      RiviumTraceBreadcrumbs.add('first');
      RiviumTraceBreadcrumbs.add('second');
      RiviumTraceBreadcrumbs.add('third');
      RiviumTraceBreadcrumbs.add('fourth');

      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
      expect(crumbs.length, 3);
      // Oldest should be removed
      expect(crumbs[0].message, 'second');
      expect(crumbs[1].message, 'third');
      expect(crumbs[2].message, 'fourth');
    });

    test('setMaxBreadcrumbs trims existing breadcrumbs', () {
      for (var i = 0; i < 10; i++) {
        RiviumTraceBreadcrumbs.add('crumb $i');
      }

      expect(RiviumTraceBreadcrumbs.getBreadcrumbs().length, 10);

      RiviumTraceBreadcrumbs.setMaxBreadcrumbs(5);
      expect(RiviumTraceBreadcrumbs.getBreadcrumbs().length, 5);
      // Should keep the most recent 5
      expect(RiviumTraceBreadcrumbs.getBreadcrumbs().first.message, 'crumb 5');
    });

    test('clear removes all breadcrumbs', () {
      RiviumTraceBreadcrumbs.add('one');
      RiviumTraceBreadcrumbs.add('two');
      expect(RiviumTraceBreadcrumbs.getBreadcrumbs().length, 2);

      RiviumTraceBreadcrumbs.clear();
      expect(RiviumTraceBreadcrumbs.getBreadcrumbs(), isEmpty);
    });

    test('getBreadcrumbs returns unmodifiable list', () {
      RiviumTraceBreadcrumbs.add('test');
      final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();

      expect(
        () => crumbs.add(Breadcrumb(
          message: 'hack',
          type: BreadcrumbType.info,
          timestamp: DateTime.now(),
        )),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('getBreadcrumbsJson returns serialized breadcrumbs', () {
      RiviumTraceBreadcrumbs.add(
        'test crumb',
        type: BreadcrumbType.error,
        data: {'key': 'val'},
      );

      final json = RiviumTraceBreadcrumbs.getBreadcrumbsJson();
      expect(json.length, 1);
      expect(json[0]['message'], 'test crumb');
      expect(json[0]['type'], 'error');
      expect(json[0]['data'], {'key': 'val'});
      expect(json[0].containsKey('timestamp'), isTrue);
    });

    test('getBreadcrumbsString returns formatted debug string', () {
      RiviumTraceBreadcrumbs.add('crumb 1', type: BreadcrumbType.info);
      RiviumTraceBreadcrumbs.add('crumb 2', type: BreadcrumbType.error);

      final str = RiviumTraceBreadcrumbs.getBreadcrumbsString();
      expect(str, contains('[BreadcrumbType.info] crumb 1'));
      expect(str, contains('[BreadcrumbType.error] crumb 2'));
    });
  });
}
