import 'dart:io' show Platform;

/// Dart VM version, e.g. "3.5.0" (the first token of [Platform.version]).
String? dartVersion() {
  try {
    final v = Platform.version.trim();
    if (v.isEmpty) return null;
    return v.split(' ').first;
  } catch (_) {
    return null;
  }
}
