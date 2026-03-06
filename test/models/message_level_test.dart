import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

void main() {
  group('MessageLevel', () {
    test('has correct string values', () {
      expect(MessageLevel.debug.value, 'debug');
      expect(MessageLevel.info.value, 'info');
      expect(MessageLevel.warning.value, 'warning');
      expect(MessageLevel.error.value, 'error');
    });

    test('has exactly four values', () {
      expect(MessageLevel.values.length, 4);
    });
  });
}
