package com.example.example

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "crashNative") {
                    val kind = call.argument<String>("kind") ?: "signal"
                    result.success(null)
                    Handler(Looper.getMainLooper()).postDelayed({
                        when (kind) {
                            "anr" -> Thread.sleep(15_000)
                            "abort" -> CrashHelper.nativeAbort()
                            "jvm" -> throw RuntimeException("Intentional JVM crash for testing")
                            else -> CrashHelper.nativeSigsegv()
                        }
                    }, 50)
                } else {
                    result.notImplemented()
                }
            }
    }

    companion object {
        private const val CHANNEL = "co.rivium.trace.example/crash_helper"
    }
}
