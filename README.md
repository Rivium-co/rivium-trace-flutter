# RiviumTrace Flutter SDK

[![pub package](https://img.shields.io/pub/v/rivium_trace_flutter_sdk.svg)](https://pub.dev/packages/rivium_trace_flutter_sdk)

Flutter SDK for RiviumTrace error tracking platform. Supports Flutter Web, Mobile, and Chrome Extensions.

## Features

- **Simple Setup** - Initialize with just a few lines of code
- **Multi-Platform** - Works on Web, Android, iOS, and Chrome Extensions
- **Automatic Error Capture** - Catches uncaught errors automatically
- **Manual Error Reporting** - Capture custom errors and messages
- **Platform Detection** - Automatically detects the running platform
- **Configurable** - Flexible configuration options
- **Rich Context** - Add custom data and context to errors

## Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Flutter Web | Supported | Full support with JavaScript error catching |
| Chrome Extension | Supported | Optimized for extension environment |
| Android | Supported | Mobile error tracking |
| iOS | Supported | Mobile error tracking |
| Desktop | Supported | Windows, macOS, Linux |

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  rivium_trace_flutter_sdk: ^0.1.0
```

Run:
```bash
flutter pub get
```

## Quick Start

### 1. Initialize RiviumTrace (Basic)

```dart
import 'package:flutter/material.dart';
import 'package:rivium_trace_flutter/rivium_trace.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RiviumTrace
  await RiviumTrace.init(RiviumTraceConfig(
    apiKey: 'rv_live_your_api_key_here',
    environment: 'production',
    release: '0.1.0',
  ));

  runApp(MyApp());
}
```

### 1b. Initialize RiviumTrace (Recommended - Better Error Catching)

```dart
import 'package:flutter/material.dart';
import 'package:rivium_trace_flutter/rivium_trace.dart';

void main() async {
  // IMPORTANT: Initialize RiviumTrace FIRST, before WidgetsFlutterBinding
  await RiviumTrace.initWithZone(
    RiviumTraceConfig(
      apiKey: 'rv_live_your_api_key_here',
      environment: 'production',
      release: '0.1.0',
      captureUncaughtErrors: true,
    ),
    () async {
      // Move all initialization inside this callback
      WidgetsFlutterBinding.ensureInitialized();

      // Any other async initialization goes here
      // await Firebase.initializeApp();
      // await setupDatabase();

      runApp(MyApp());
    },
  );
}
```

### 2. Capture Errors Manually

```dart
// Capture an exception
try {
  riskyOperation();
} catch (e, stackTrace) {
  await RiviumTrace.captureException(
    e,
    stackTrace: stackTrace,
    message: 'Failed to perform risky operation',
    extra: {'user_id': 'user123'},
  );
}

// Capture a custom message
await RiviumTrace.captureMessage(
  'User completed onboarding',
  extra: {'step': 'welcome_screen'},
);
```

## Configuration Options

```dart
RiviumTraceConfig(
  apiKey: 'rv_live_xxx',                            // Required (from RiviumTrace Console)
  environment: 'production',                        // Default: 'production'
  release: '0.1.0',                                 // Optional
  captureUncaughtErrors: true,                      // Default: true
  enabled: true,                                    // Default: true
  debug: false,                                     // Default: false
  timeout: 30,                                      // Default: 30 seconds
)
```

**Note:** The SDK automatically uses `https://trace.rivium.co` as the API endpoint. Get your API key from the RiviumTrace Console (format: `rv_live_xxx` or `rv_test_xxx`).

## Platform-Specific Usage

### Chrome Extension

```dart
void main() async {
  await RiviumTrace.init(RiviumTraceConfig(
    apiKey: 'rv_live_your_api_key',
    environment: 'production',
    debug: false, // Disable in production extensions
  ));

  runApp(MyExtensionApp());
}
```

### Mobile App

```dart
void main() async {
  await RiviumTrace.init(RiviumTraceConfig(
    apiKey: 'rv_live_your_api_key',
    environment: 'production',
    captureUncaughtErrors: true, // Recommended for mobile
  ));

  runApp(MyMobileApp());
}
```

### Web App

```dart
void main() async {
  await RiviumTrace.init(RiviumTraceConfig(
    apiKey: 'rv_live_your_api_key',
    environment: 'production',
    debug: kDebugMode, // Enable debug in development
  ));

  runApp(MyWebApp());
}
```

## Advanced Usage

### Custom Error Context

```dart
await RiviumTrace.captureException(
  exception,
  extra: {
    'user_id': 'user123',
    'feature': 'shopping_cart',
    'action': 'checkout',
    'cart_items': 5,
    'total_amount': 99.99,
  },
);
```

### Conditional Error Reporting

```dart
// Only report errors in production
if (kReleaseMode) {
  await RiviumTrace.captureException(error);
}
```

### Cleanup (Important for Crash Detection)

```dart
@override
void dispose() {
  RiviumTrace.close(); // Clean up resources and mark app as closed gracefully
  super.dispose();
}
```

**Note**: Calling `RiviumTrace.close()` is important for native crash detection. It marks the app as closing gracefully. If the app crashes without calling this, RiviumTrace will detect it on the next launch.

## Error Information Captured

The SDK automatically captures:

- **Error Message** - Exception message or custom message
- **Stack Trace** - Full stack trace for debugging
- **Platform** - Detected platform (flutter_web, flutter_android, etc.)
- **Environment** - Environment name (production, development, etc.)
- **Release** - App version/release identifier
- **Timestamp** - When the error occurred
- **User Agent** - Browser/device information (web only)
- **URL** - Current page URL (web only)
- **Custom Context** - Any additional data you provide

## Best Practices

### 1. Initialize Early
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiviumTrace.init(config); // Initialize before runApp
  runApp(MyApp());
}
```

### 2. Use Environments
```dart
RiviumTraceConfig(
  apiKey: 'rv_live_your_api_key',
  environment: kDebugMode ? 'development' : 'production',
  debug: kDebugMode,
)
```

### 3. Add Context to Errors
```dart
await RiviumTrace.captureException(
  error,
  extra: {
    'user_id': currentUser.id,
    'screen': 'checkout',
    'timestamp': DateTime.now().toIso8601String(),
  },
);
```

### 4. Handle Network Errors Gracefully
```dart
try {
  await apiCall();
} catch (e) {
  if (e is SocketException) {
    // Handle network errors differently
    await RiviumTrace.captureMessage('Network error occurred', extra: {
      'error_type': 'network',
      'endpoint': '/api/data',
    });
  } else {
    await RiviumTrace.captureException(e);
  }
}
```

## Crash Handling

### Universal Error Coverage for ALL Apps

RiviumTrace provides **comprehensive error detection for any Flutter app**, regardless of what libraries or native code you use. **Works for all companies, all apps, all use cases.**

### Types of Errors Captured

1. **Dart Exceptions** - Captured in real-time
   - Unhandled exceptions
   - Flutter framework errors
   - Widget build errors

2. **Async Errors** - Captured in real-time (with `initWithZone`)
   - Uncaught async exceptions
   - Future rejections

3. **Platform Exceptions** - Captured in real-time
   - Errors from native platform channels
   - Method channel errors

4. **Native Crashes** - **Detected on next app launch** (Universal)
   - **ANY database** (SQLite, ObjectBox, Realm, Hive, Drift, etc.)
   - **ANY plugin** (Camera, Location, Firebase, Maps, etc.)
   - **ANY native library** (C/C++/Kotlin/Swift/Rust code)
   - **System crashes** (SIGABRT, SIGSEGV, SIGILL, SIGFPE, OOM)
   - **All platforms** (Android, iOS, macOS, Windows, Linux)

### Native Crash Detection (Works for ANY Crash Source)

Native crashes from **any library or source** cannot be caught in real-time because they kill the entire process immediately. However, RiviumTrace **universally detects them on the next app launch**:

1. When your app starts, RiviumTrace creates a crash marker file
2. If the app closes gracefully (via `RiviumTrace.close()`), the marker is removed
3. If the app crashes, the marker remains
4. On next launch, RiviumTrace detects the marker and sends a crash report

**Example crash report**:
```json
{
  "message": "Native crash detected from previous session",
  "platform": "flutter_android",
  "crash_time": "2025-11-12T03:24:20.000Z",
  "extra": {
    "error_type": "native_crash",
    "time_since_crash_seconds": 293
  }
}
```

### For Detailed Crash Handling Guide

See [CRASH_HANDLING.md](CRASH_HANDLING.md) for comprehensive documentation on:
- How crash detection works
- Best practices for maximum coverage
- Debugging native crashes
- Manual crash detection APIs

## Development

To contribute to this SDK:

1. Fork the repository
2. Create your feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Documentation**: [RiviumTrace Docs](https://docs.rivium.co)
- **Issues**: [GitHub Issues](https://github.com/Rivium-co/rivium-trace-flutter/issues)
- **Email**: support@rivium.co
