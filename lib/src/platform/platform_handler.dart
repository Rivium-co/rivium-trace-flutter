import 'package:flutter/foundation.dart';          // for kIsWeb
import 'package:universal_platform/universal_platform.dart'; // for UniversalPlatform

import 'platform_handler_stub.dart'
if (dart.library.html) 'platform_handler_web.dart'
if (dart.library.io) 'platform_handler_mobile.dart';

import '../models/rivium_trace_error.dart';

abstract class PlatformHandler {
  String getPlatform();
  String getUserAgent(String? release);
  void setupErrorHandling(Function(RiviumTraceError) onError);
  void dispose();

  factory PlatformHandler.create() => createPlatformHandler();
}

abstract class BasePlatformHandler implements PlatformHandler {
  @override
  String getPlatform() {
    if (kIsWeb) {
      return 'flutter_web';
    } else if (UniversalPlatform.isAndroid) {
      return 'flutter_android';
    } else if (UniversalPlatform.isIOS) {
      return 'flutter_ios';
    } else if (UniversalPlatform.isMacOS) {
      return 'flutter_macos';
    } else if (UniversalPlatform.isWindows) {
      return 'flutter_windows';
    } else if (UniversalPlatform.isLinux) {
      return 'flutter_linux';
    }
    return 'flutter_unknown';
  }

  @override
  void dispose() {
    // Override in implementations if needed
  }
}
