import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_trace_flutter_sdk/rivium_trace_flutter_sdk.dart';

/// Offline storage needs the Flutter binding (it asks the platform for a folder). In the documented initWithZone
/// order the binding only exists once the app's own code runs WidgetsFlutterBinding.ensureInitialized(), so nothing
/// may touch offline storage before that — and an error stored early must still be kept.
///
/// No binding exists at the start of this file on purpose (each test file runs in its own isolate).
void main() {
  late Directory dir;
  final printed = <String>[];
  final originalDebugPrint = debugPrint;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rivium_trace_offline_');
    printed.clear();
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
    OfflineStorageService.resetForTesting();
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    OfflineStorageService.resetForTesting();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  void bindingWithDocumentsFolder() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  }

  RiviumTraceError anError(String message) => RiviumTraceError(
        message: message,
        stackTrace: 'at main',
        platform: 'flutter',
        environment: 'test',
        timestamp: DateTime.now(),
      );

  test('initWithZone with ensureInitialized as the first line of the app (the documented order) prints no offline-storage warning', () async {
    await RiviumTrace.initWithZone(
      const RiviumTraceConfig(apiKey: 'rv_live_test', enableOfflineStorage: true),
      () async => bindingWithDocumentsFolder(),
    );
    expect(printed.where((m) => m.contains('Failed to initialize offline storage')), isEmpty);
    // Offline storage is ready once the app has started.
    expect(await OfflineStorageService.getStoredErrors(), isEmpty);
    await OfflineStorageService.storeError(anError('after start'));
    expect(await OfflineStorageService.getStoredErrors(), hasLength(1));
  });

  test('an error stored before offline storage was set up is still kept (it sets itself up on first use)', () async {
    bindingWithDocumentsFolder();
    await OfflineStorageService.storeError(anError('during app start'));
    final stored = await OfflineStorageService.getStoredErrors();
    expect(stored, hasLength(1));
    expect(stored.single['message'], 'during app start');
  });

  test('set up once, however many callers ask at the same time', () async {
    bindingWithDocumentsFolder();
    var folderLookups = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        folderLookups++;
        return dir.path;
      },
    );
    await Future.wait([
      OfflineStorageService.initialize(),
      OfflineStorageService.initialize(),
      OfflineStorageService.storeError(anError('a')),
      OfflineStorageService.storeError(anError('b')),
    ]);
    expect(folderLookups, 1);
    expect(await OfflineStorageService.getStoredErrors(), hasLength(2));
  });
}
