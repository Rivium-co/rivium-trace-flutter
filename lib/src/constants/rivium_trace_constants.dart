/// RiviumTrace SDK constants
class RiviumTraceConstants {
  /// Official RiviumTrace API URL
  static const String apiUrl = 'https://trace.rivium.co';

  /// SDK version. Must equal `version:` in pubspec.yaml (a test checks it);
  /// sent as `_sdk.sdk_version` and in the `User-Agent` header.
  static const String sdkVersion = '0.2.4';

  RiviumTraceConstants._(); // Private constructor to prevent instantiation
}
