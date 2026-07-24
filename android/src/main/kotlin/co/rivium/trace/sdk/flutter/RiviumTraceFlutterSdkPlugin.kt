package co.rivium.trace.sdk.flutter

import android.content.Context
import co.rivium.trace.sdk.RiviumTrace
import co.rivium.trace.sdk.RiviumTraceConfig
import co.rivium.trace.sdk.models.BreadcrumbType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin entry point bridging Dart -> Android RiviumTrace SDK.
 *
 * The native SDK source is vendored under
 * `src/main/kotlin/co/rivium/trace/sdk/` so this plugin can be consumed
 * without the standalone Maven artifact being published. When the
 * artifact is published, the vendored sources will be removed and the
 * imports above will resolve to the published library instead — no
 * changes needed in this file.
 */
class RiviumTraceFlutterSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "drainPendingCrashReports" -> result.success(emptyList<Map<String, Any?>>())
            "setUserId" -> handleSetUserId(call, result)
            "addBreadcrumb" -> handleAddBreadcrumb(call, result)
            "captureException" -> handleCaptureException(call, result)
            "close" -> {
                RiviumTrace.close()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        val apiKey = call.argument<String>("apiKey")
        if (apiKey.isNullOrBlank()) {
            result.error("invalid_args", "apiKey required", null)
            return
        }

        val config = RiviumTraceConfig(
            apiKey = apiKey,
            environment = call.argument<String>("environment") ?: "production",
            release = call.argument<String>("release"),
            debug = call.argument<Boolean>("debug") ?: false,
            enabled = call.argument<Boolean>("enabled") ?: true,
            captureUncaughtExceptions = call.argument<Boolean>("captureUncaughtExceptions") ?: true,
            captureSignalCrashes = call.argument<Boolean>("captureSignalCrashes") ?: true,
            captureAnr = call.argument<Boolean>("captureAnr") ?: true,
            anrTimeoutMs = (call.argument<Int>("anrTimeoutMs") ?: 5000).toLong(),
            maxBreadcrumbs = call.argument<Int>("maxBreadcrumbs") ?: 20,
            enableOfflineStorage = call.argument<Boolean>("enableOfflineStorage") ?: true,
            sampleRate = (call.argument<Double>("sampleRate") ?: 1.0).toFloat(),
            apiUrl = call.argument<String>("apiUrl") ?: "https://trace.rivium.co"
        )

        RiviumTrace.init(applicationContext, config)
        result.success(null)
    }

    private fun handleSetUserId(call: MethodCall, result: MethodChannel.Result) {
        RiviumTrace.setUserId(call.argument<String>("userId"))
        result.success(null)
    }

    private fun handleAddBreadcrumb(call: MethodCall, result: MethodChannel.Result) {
        val message = call.argument<String>("message") ?: ""
        val typeRaw = call.argument<String>("type") ?: "info"
        val data = call.argument<Map<String, Any?>>("data") ?: emptyMap()
        val type = runCatching {
            BreadcrumbType.valueOf(typeRaw.uppercase())
        }.getOrDefault(BreadcrumbType.INFO)
        RiviumTrace.addBreadcrumb(message, type, data)
        result.success(null)
    }

    private fun handleCaptureException(call: MethodCall, result: MethodChannel.Result) {
        val message = call.argument<String>("message") ?: "Dart error"
        val stackTrace = call.argument<String>("stackTrace") ?: ""
        val extra = call.argument<Map<String, Any?>>("extra") ?: emptyMap()
        val tags = call.argument<Map<String, String>>("tags") ?: emptyMap()

        val throwable = RuntimeException("$message\n$stackTrace")
        RiviumTrace.captureException(throwable, message, extra, tags) { ok, _ ->
            result.success(ok)
        }
    }

    companion object {
        private const val CHANNEL_NAME = "co.rivium.trace/flutter_sdk"
    }
}
