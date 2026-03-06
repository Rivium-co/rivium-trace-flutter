import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() {
  group('RiviumTraceConfig', () {
    test('creates config with required apiKey and defaults', () {
      const config = RiviumTraceConfig(apiKey: 'rv_test_abc123');

      expect(config.apiKey, 'rv_test_abc123');
      expect(config.environment, 'production');
      expect(config.release, isNull);
      expect(config.captureUncaughtErrors, isTrue);
      expect(config.enabled, isTrue);
      expect(config.debug, isFalse);
      expect(config.timeout, 30);
      expect(config.maxBreadcrumbs, 20);
      expect(config.sampleRate, 1.0);
      expect(config.enableOfflineStorage, isTrue);
      expect(config.logHandler, isNull);
    });

    test('creates config with all custom values', () {
      const config = RiviumTraceConfig(
        apiKey: 'rv_live_xyz789',
        environment: 'staging',
        release: '2.0.0',
        captureUncaughtErrors: false,
        enabled: false,
        debug: true,
        timeout: 10,
        maxBreadcrumbs: 50,
        sampleRate: 0.5,
        enableOfflineStorage: false,
      );

      expect(config.apiKey, 'rv_live_xyz789');
      expect(config.environment, 'staging');
      expect(config.release, '2.0.0');
      expect(config.captureUncaughtErrors, isFalse);
      expect(config.enabled, isFalse);
      expect(config.debug, isTrue);
      expect(config.timeout, 10);
      expect(config.maxBreadcrumbs, 50);
      expect(config.sampleRate, 0.5);
      expect(config.enableOfflineStorage, isFalse);
    });

    test('simple factory creates config with just apiKey', () {
      final config = RiviumTraceConfig.simple('rv_test_simple');

      expect(config.apiKey, 'rv_test_simple');
      expect(config.environment, 'production');
      expect(config.enabled, isTrue);
    });

    group('copyWith', () {
      test('copies config with modified values', () {
        const original = RiviumTraceConfig(
          apiKey: 'rv_test_original',
          environment: 'production',
          debug: false,
        );

        final copied = original.copyWith(
          environment: 'staging',
          debug: true,
          release: '1.0.0',
        );

        expect(copied.apiKey, 'rv_test_original'); // unchanged
        expect(copied.environment, 'staging'); // changed
        expect(copied.debug, isTrue); // changed
        expect(copied.release, '1.0.0'); // changed
        expect(copied.enabled, isTrue); // unchanged
      });

      test('returns identical config when no overrides provided', () {
        const original = RiviumTraceConfig(
          apiKey: 'rv_test_key',
          environment: 'dev',
          timeout: 15,
          sampleRate: 0.75,
        );

        final copied = original.copyWith();

        expect(copied.apiKey, original.apiKey);
        expect(copied.environment, original.environment);
        expect(copied.timeout, original.timeout);
        expect(copied.sampleRate, original.sampleRate);
      });
    });

    test('toString contains key info', () {
      const config = RiviumTraceConfig(
        apiKey: 'rv_test_1234567890abcdef',
        environment: 'production',
        sampleRate: 0.5,
      );

      final str = config.toString();
      expect(str, contains('rv_test_12'));
      expect(str, contains('production'));
      expect(str, contains('0.5'));
    });
  });
}
