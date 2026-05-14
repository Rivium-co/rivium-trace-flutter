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
