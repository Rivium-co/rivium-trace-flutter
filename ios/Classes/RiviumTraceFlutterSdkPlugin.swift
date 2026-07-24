import Flutter
import UIKit
import RiviumTrace

/// Flutter plugin entry point bridging Dart -> iOS RiviumTrace SDK.
/// The native SDK lives in the standalone `RiviumTrace` pod (see podspec).
public class RiviumTraceFlutterSdkPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "co.rivium.trace/flutter_sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = RiviumTraceFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            handleInit(call.arguments as? [String: Any] ?? [:], result: result)
        case "drainPendingCrashReports":
            handleDrainPendingCrashReports(result: result)
        case "setUserId":
            handleSetUserId(call.arguments as? [String: Any] ?? [:], result: result)
        case "addBreadcrumb":
            handleAddBreadcrumb(call.arguments as? [String: Any] ?? [:], result: result)
        case "captureException":
            handleCaptureException(call.arguments as? [String: Any] ?? [:], result: result)
        case "close":
            RiviumTrace.shared.close()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - init

    private func handleInit(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let apiKey = args["apiKey"] as? String, !apiKey.isEmpty else {
            result(FlutterError(code: "invalid_args", message: "apiKey required", details: nil))
            return
        }

        let config = RiviumTraceConfig(
            apiKey: apiKey,
            environment: (args["environment"] as? String) ?? "production",
            release: args["release"] as? String,
            debug: (args["debug"] as? Bool) ?? false,
            enabled: (args["enabled"] as? Bool) ?? true,
            captureUncaughtExceptions: (args["captureUncaughtExceptions"] as? Bool) ?? true,
            captureSignalCrashes: (args["captureSignalCrashes"] as? Bool) ?? true,
            captureAnr: (args["captureAnr"] as? Bool) ?? true,
            anrTimeoutMs: Int64((args["anrTimeoutMs"] as? Int) ?? 5000),
            maxBreadcrumbs: (args["maxBreadcrumbs"] as? Int) ?? 20,
            httpTimeout: TimeInterval((args["httpTimeoutSeconds"] as? Int) ?? 30),
            enableOfflineStorage: (args["enableOfflineStorage"] as? Bool) ?? true,
            sampleRate: (args["sampleRate"] as? Double) ?? 1.0,
            apiUrl: (args["apiUrl"] as? String) ?? "https://trace.rivium.co"
        )

        RiviumTrace.shared.initialize(config: config)
        result(nil)
    }

    // MARK: - drain pending crashes

    /// Drains any pending native crash captured by PLCrashReporter on the
    /// previous launch and returns it to Dart as a list of dictionaries.
    /// The iOS SDK already POSTs the crash to the backend synchronously on
    /// init; this method exists so the Dart side can also surface the same
    /// crash through its own pipeline (offline retry, breadcrumb merging).
    ///
    /// For v2.0.0 the iOS SDK owns the network call. We return an empty
    /// list here. A follow-up can split the iOS SDK so it stages the crash
    /// payload without auto-sending, returns it here, and Dart owns the
    /// send.
    private func handleDrainPendingCrashReports(result: @escaping FlutterResult) {
        result([])
    }

    // MARK: - context propagation

    private func handleSetUserId(_ args: [String: Any], result: @escaping FlutterResult) {
        let userId = args["userId"] as? String
        RiviumTrace.shared.setUserId(userId)
        result(nil)
    }

    private func handleAddBreadcrumb(_ args: [String: Any], result: @escaping FlutterResult) {
        let message = (args["message"] as? String) ?? ""
        let typeRaw = (args["type"] as? String) ?? "info"
        let type = BreadcrumbType(rawValue: typeRaw) ?? .info
        let data = (args["data"] as? [String: Any]) ?? [:]
        RiviumTrace.shared.addBreadcrumb(message, type: type, data: data)
        result(nil)
    }

    private func handleCaptureException(_ args: [String: Any], result: @escaping FlutterResult) {
        let message = (args["message"] as? String) ?? "Dart error"
        let stackTrace = args["stackTrace"] as? String
        let extra = (args["extra"] as? [String: Any]) ?? [:]
        let tags = (args["tags"] as? [String: String]) ?? [:]

        let error = NSError(
            domain: "co.rivium.trace.dart",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "stack_trace": stackTrace ?? ""
            ]
        )

        RiviumTrace.shared.captureError(error, message: message, extra: extra, tags: tags) { ok in
            result(ok)
        }
    }
}
