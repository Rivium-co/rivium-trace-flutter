## 0.2.0

* **Breaking — un-vendor: the plugin now depends on the published
  standalone SDKs** (`co.rivium.trace:rivium-trace-android-sdk:0.2.0` on
  Maven Central + `RiviumTrace ~> 0.2.0` on CocoaPods / SPM). The vendored
  Kotlin + Swift SDK sources and the `CrashReporter.xcframework` are removed
  from this package. Consumers must run `pod install` on iOS and a clean
  Gradle build on Android.
* Native tombstones are now parsed into a Sentry-shape structured event on
  device (both platforms) and posted in `resolved_stack_trace`. The Rivium
  Trace dashboard renders them frame-by-frame with signal metadata, a
  thread selector, register dump, and per-frame image + instruction
  address.
* **Breaking — real native crash capture.** The package is now a federated
  Flutter plugin instead of a pure-Dart package. iOS native crashes
  (SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGFPE, SIGTRAP, Mach exceptions)
  are captured via PLCrashReporter 1.12.0 (MIT, transitively provided by
  the RiviumTrace pod). Android crashes are captured via
  `Thread.setDefaultUncaughtExceptionHandler` (in-process, all API levels)
  and `ApplicationExitInfo` (API 30+).
* **Breaking — false-positive `CrashDetector` removed.** The previous
  lifecycle-marker heuristic reported any non-graceful close as a
  "native crash" with no stack trace. It was the source of the
  "Native crash - No Dart stack trace available" reports flooding
  customer dashboards. It is deleted along with its public export.
  If your app imported `CrashDetector` directly (the previous Sareban
  workaround), remove those calls.
* The native iOS and Android RiviumTrace SDK sources are vendored
  inside this plugin for the current release so the plugin can be
  consumed before the standalone SDKs are published. A follow-up
  release will replace the vendored copies with versioned CocoaPods /
  Maven dependencies; no Dart-side API changes.

## 0.1.3

* **New**: Auto-capture user taps as breadcrumbs across all platforms (Web, Android, iOS, macOS, Windows, Linux). Enable with `RiviumTrace.enableGestureBreadcrumbs()` after init. Each breadcrumb captures widget type, label, optional `ValueKey`, current route, and tap coordinates.
* Walks the hit-test path and ancestor tree to identify the most specific interactive widget — prefers concrete buttons (`ElevatedButton`, `IconButton`, `Switch`, etc.) over generic wrappers (`InkWell`, `GestureDetector`).
* Hooks `PointerDownEvent` rather than `PointerUpEvent` so taps on synchronous handlers that throw are still logged.
* Fix: `RiviumTraceConstants.sdkVersion` was stuck at `0.1.1` in init breadcrumbs. Now reflects the actual package version.

## 0.1.2

* Add self-hosted server URL support — pass a custom `apiUrl` in `RiviumTraceConfig` to send errors to your own RiviumTrace deployment instead of `trace.rivium.co`.
* Documentation: README updated with self-hosting setup.

## 0.1.1

* Add homepage, repository, and documentation URLs to package metadata

## 0.1.0

* Initial release
* Error tracking with automatic uncaught exception capture
* Multi-platform support: Web, Android, iOS, macOS, Windows, Linux, Chrome Extensions
* Manual error and message capture
* Breadcrumb tracking (in-memory)
* Native crash detection via marker file (mobile/desktop)
* Performance monitoring with HTTP client wrapper
* Navigation observer for route tracking
* Configurable API key, environment, and release
* Offline error storage with retry
* Log batching service
