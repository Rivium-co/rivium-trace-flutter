import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';
import 'package:rivium_trace_flutter_sdk/src/services/rivium_trace_logger.dart';

void main() {
  group('RiviumTrace', () {
    setUp(() async {
      // Reset state between tests
      RiviumTraceBreadcrumbs.clear();
      RiviumTraceNavigatorObserver.reset();
      RiviumTraceLogger.setEnabled(false);
      RiviumTraceLogger.setLogHandler(null);

      // Close any existing instance
      try {
        if (RiviumTrace.isInitialized()) {
          await RiviumTrace.close();
        }
      } catch (_) {}
    });

    tearDown(() async {
      try {
        if (RiviumTrace.isInitialized()) {
          await RiviumTrace.close();
        }
      } catch (_) {}
    });

    group('initialization', () {
      test('isInitialized returns false before init', () {
        expect(RiviumTrace.isInitialized(), isFalse);
      });

      test('instance throws before init', () {
        expect(
          () => RiviumTrace.instance,
          throwsA(isA<StateError>()),
        );
      });

      test('init creates an initialized instance', () async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
          debug: false,
        ));

        expect(RiviumTrace.isInitialized(), isTrue);
      });

      test('getPlatform returns non-null after init', () async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));

        expect(RiviumTrace.getPlatform(), isNotNull);
      });
    });

    group('user management', () {
      setUp(() async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));
      });

      test('setUserId and getUserId', () {
        RiviumTrace.setUserId('user-123');
        expect(RiviumTrace.getUserId(), 'user-123');
      });

      test('getUserId returns null before setting', () {
        expect(RiviumTrace.getUserId(), isNull);
      });

      test('getSessionId returns non-null after init', () {
        expect(RiviumTrace.getSessionId(), isNotNull);
        expect(RiviumTrace.getSessionId()!.length, 32); // 16 bytes hex = 32 chars
      });
    });

    group('extra context', () {
      setUp(() async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));
      });

      test('setExtra and getExtra', () {
        RiviumTrace.setExtra('app_version', '2.0.0');
        expect(RiviumTrace.getExtra('app_version'), '2.0.0');
      });

      test('setExtras sets multiple values', () {
        RiviumTrace.setExtras({
          'device': 'iPhone 15',
          'os': 'iOS 17',
        });
        expect(RiviumTrace.getExtra('device'), 'iPhone 15');
        expect(RiviumTrace.getExtra('os'), 'iOS 17');
      });

      test('getExtras returns all extra context', () {
        RiviumTrace.setExtra('key1', 'val1');
        RiviumTrace.setExtra('key2', 'val2');

        final extras = RiviumTrace.getExtras();
        expect(extras, isNotNull);
        expect(extras!['key1'], 'val1');
        expect(extras['key2'], 'val2');
      });

      test('clearExtras removes all context', () {
        RiviumTrace.setExtra('key', 'val');
        RiviumTrace.clearExtras();

        expect(RiviumTrace.getExtra('key'), isNull);
      });
    });

    group('tags', () {
      setUp(() async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));
      });

      test('setTag and getTag', () {
        RiviumTrace.setTag('module', 'auth');
        expect(RiviumTrace.getTag('module'), 'auth');
      });

      test('setTags sets multiple tags', () {
        RiviumTrace.setTags({'env': 'test', 'region': 'us-east'});
        expect(RiviumTrace.getTag('env'), 'test');
        expect(RiviumTrace.getTag('region'), 'us-east');
      });

      test('getTags returns all tags', () {
        RiviumTrace.setTag('a', '1');
        RiviumTrace.setTag('b', '2');

        final tags = RiviumTrace.getTags();
        expect(tags, {'a': '1', 'b': '2'});
      });

      test('clearTags removes all tags', () {
        RiviumTrace.setTag('key', 'val');
        RiviumTrace.clearTags();
        expect(RiviumTrace.getTag('key'), isNull);
      });
    });

    group('breadcrumb methods', () {
      setUp(() async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));
        RiviumTraceBreadcrumbs.clear();
      });

      test('addBreadcrumb adds a breadcrumb', () {
        RiviumTrace.addBreadcrumb('test', data: {'key': 'val'});

        final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
        expect(crumbs.length, 1);
        expect(crumbs.first.message, 'test');
      });

      test('addNavigationBreadcrumb adds navigation crumb', () {
        RiviumTrace.addNavigationBreadcrumb('/home', '/settings');

        final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
        expect(crumbs.first.type, BreadcrumbType.navigation);
      });

      test('addUserBreadcrumb adds user action crumb', () {
        RiviumTrace.addUserBreadcrumb('tapped button');

        final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
        expect(crumbs.first.type, BreadcrumbType.user);
      });

      test('addHttpBreadcrumb adds HTTP crumb', () {
        RiviumTrace.addHttpBreadcrumb('POST', 'https://api.com', statusCode: 201);

        final crumbs = RiviumTraceBreadcrumbs.getBreadcrumbs();
        expect(crumbs.first.type, BreadcrumbType.http);
      });

      test('clearBreadcrumbs clears all', () {
        RiviumTrace.addBreadcrumb('one');
        RiviumTrace.addBreadcrumb('two');
        RiviumTrace.clearBreadcrumbs();

        expect(RiviumTraceBreadcrumbs.getBreadcrumbs(), isEmpty);
      });
    });

    group('captureException', () {
      setUp(() async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));
      });

      test('calls callback with false when SDK is disabled', () async {
        await RiviumTrace.close();
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
          enabled: false,
        ));

        bool? result;
        await RiviumTrace.captureException(
          Exception('test'),
          callback: (success) => result = success,
        );

        expect(result, isFalse);
      });
    });

    group('captureMessage', () {
      setUp(() async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));
      });

      test('calls callback with false when SDK is disabled', () async {
        await RiviumTrace.close();
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
          enabled: false,
        ));

        bool? result;
        await RiviumTrace.captureMessage(
          'test message',
          callback: (success) => result = success,
        );

        expect(result, isFalse);
      });
    });

    group('close', () {
      test('resets state after close', () async {
        await RiviumTrace.init(const RiviumTraceConfig(
          apiKey: 'rv_test_1234567890',
          captureUncaughtErrors: false,
          enableOfflineStorage: false,
        ));

        expect(RiviumTrace.isInitialized(), isTrue);

        await RiviumTrace.close();

        expect(RiviumTrace.isInitialized(), isFalse);
      });
    });
  });
}
