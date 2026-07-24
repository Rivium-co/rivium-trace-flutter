import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // Example-only channel that talks to a native crash helper on the iOS side.
  // Kept in the example (not the plugin) so consumers of the SDK don't inherit
  // an intentional-crash surface. Mirrors the Android MethodChannel at
  // MainActivity.kt#configureFlutterEngine.
  private static let crashChannelName = "co.rivium.trace.example/crash_helper"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.crashChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "crashNative" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let kind = (args["kind"] as? String) ?? "signal"
      // Return before crashing so the MethodChannel reply doesn't hang.
      result(nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        switch kind {
        case "abort":
          abort()
        case "anr":
          // iOS "ANR" analog — block the main thread. The iOS watchdog kills
          // apps that block the main thread for ~20s (varies by state).
          Thread.sleep(forTimeInterval: 25)
        default:
          // SIGSEGV via null pointer store. Swift's `UnsafeMutablePointer
          // .init(bitPattern:)` traps at address 0, so we cast an
          // OpaquePointer to a raw pointer (Swift doesn't sanity-check that
          // path) and write through it. debuggerd catches the resulting
          // SIGSEGV and PLCrashReporter records it on next launch.
          let raw = UnsafeMutableRawPointer(bitPattern: 0x1)!
          raw.storeBytes(of: Int(42), as: Int.self)
        }
      }
    }
  }
}
