package com.chaosvoice

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin that bridges Dart calls to the native VirtualMicService.
 *
 * NOTE: This plugin registers a SECOND channel listener as a fallback.
 * The primary channel is registered by MainActivity.configureFlutterEngine().
 * Only one handler will receive calls — MainActivity takes precedence.
 * This class exists for future plugin-based registration via the
 * Flutter plugin system when ChaosVoice is distributed as a plugin.
 * For now, all MethodChannel calls are handled by MainActivity.
 */
class ChaosVoicePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // Channel is registered by MainActivity; this plugin is a fallback.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No-op: channel is managed by MainActivity
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // This handler is only reached if MainActivity is not the active handler.
        when (call.method) {
            "startService" -> {
                VirtualMicService.start(context)
                result.success(true)
            }
            "stopService" -> {
                VirtualMicService.stop(context)
                result.success(true)
            }
            "isRunning" -> {
                result.success(VirtualMicService.isRunning)
            }
            "updateParams" -> {
                val args = call.arguments as? Map<String, Any>
                if (args != null) {
                    VirtualMicService.applyParams(args)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
