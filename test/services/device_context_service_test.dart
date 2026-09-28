import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/src/constants/rivium_trace_constants.dart';
import 'package:rivium_trace_flutter_sdk/src/services/device_context_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(DeviceContextService.resetForTesting);
  tearDown(DeviceContextService.resetForTesting);

  test('sdkVersion constant equals the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(RiviumTraceConstants.sdkVersion, version);
  });

  test('_sdk carries sdk_version, dart_version, build_mode, flutter_platform', () async {
    DeviceContextService.deviceInfoLoaderOverride = () async => null;
    DeviceContextService.appInfoLoaderOverride = () async => null;
    DeviceContextService.start(collectDeviceInfo: true, platform: 'flutter_ios');

    final ctx = await DeviceContextService.snapshot();
    final sdk = ctx['_sdk'] as Map<String, dynamic>;
    expect(sdk['sdk_version'], RiviumTraceConstants.sdkVersion);
    expect(sdk['flutter_platform'], 'ios');
    expect(sdk['build_mode'], anyOf('debug', 'profile', 'release'));
    expect(sdk['dart_version'], matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  test('collects device_info (+ locale, timezone) and app_info once', () async {
    var deviceCalls = 0;
    var appCalls = 0;
    DeviceContextService.deviceInfoLoaderOverride = () async {
      deviceCalls++;
      return {'device_model': 'Pixel 8', 'os_version': '15', 'sdk_int': 35, 'empty': ''};
    };
    DeviceContextService.appInfoLoaderOverride = () async {
      appCalls++;
      return {'version': '2.0.1', 'build_number': '25', 'package_name': 'co.acme.app', 'app_name': 'Acme'};
    };
    DeviceContextService.start(collectDeviceInfo: true, platform: 'flutter_android');

    final a = await DeviceContextService.snapshot();
    final b = await DeviceContextService.snapshot();
    expect(deviceCalls, 1);
    expect(appCalls, 1);

    final di = a['device_info'] as Map<String, dynamic>;
    expect(di['device_model'], 'Pixel 8');
    expect(di['sdk_int'], 35);
    expect(di.containsKey('empty'), isFalse);
    expect(di['timezone'], contains('UTC'));
    expect(a['app_info'], {'version': '2.0.1', 'build_number': '25', 'package_name': 'co.acme.app', 'app_name': 'Acme'});
    expect(b['app_info'], a['app_info']);
  });

  test('a failing plugin lookup is skipped and retried later', () async {
    var calls = 0;
    DeviceContextService.deviceInfoLoaderOverride = () async {
      calls++;
      if (calls == 1) throw StateError('binding not ready');
      return {'device_model': 'iPhone 15 Pro'};
    };
    DeviceContextService.appInfoLoaderOverride = () async => {'version': '1.0.0'};
    DeviceContextService.start(collectDeviceInfo: true, platform: 'flutter_ios');

    final first = await DeviceContextService.snapshot();
    expect((first['device_info'] as Map).containsKey('device_model'), isFalse);
    expect(first['app_info'], {'version': '1.0.0'});

    final second = await DeviceContextService.snapshot();
    expect((second['device_info'] as Map)['device_model'], 'iPhone 15 Pro');
  });

  test('never waits longer than the bound for a slow lookup', () async {
    final never = Completer<Map<String, dynamic>?>();
    DeviceContextService.deviceInfoLoaderOverride = () => never.future;
    DeviceContextService.appInfoLoaderOverride = () => never.future;
    DeviceContextService.start(collectDeviceInfo: true, platform: 'flutter_android');

    final sw = Stopwatch()..start();
    final ctx = await DeviceContextService.snapshot(wait: const Duration(milliseconds: 50));
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(ctx['_sdk'], isNotNull);
    expect(ctx.containsKey('app_info'), isFalse);
  });

  test('collectDeviceInfo: false sends only _sdk', () async {
    var called = false;
    DeviceContextService.deviceInfoLoaderOverride = () async {
      called = true;
      return {'device_model': 'x'};
    };
    DeviceContextService.start(collectDeviceInfo: false, platform: 'flutter_android');
    final ctx = await DeviceContextService.snapshot();
    expect(called, isFalse);
    expect(ctx.keys, ['_sdk']);
  });

  test('mergeInto keeps caller values and existing extra', () {
    final merged = DeviceContextService.mergeInto(
      {
        'user_id': 'u1',
        'device_info': {'device_model': 'Custom'},
        '_sdk': {'build_mode': 'staging'},
      },
      {
        '_sdk': {'sdk_version': '0.2.1', 'build_mode': 'release'},
        'device_info': {'device_model': 'Pixel 8', 'os_version': '15'},
        'app_info': {'version': '2.0.1'},
      },
    );
    expect(merged['user_id'], 'u1');
    expect(merged['device_info'], {'device_model': 'Custom', 'os_version': '15'});
    expect(merged['_sdk'], {'sdk_version': '0.2.1', 'build_mode': 'staging'});
    expect(merged['app_info'], {'version': '2.0.1'});
  });
}
