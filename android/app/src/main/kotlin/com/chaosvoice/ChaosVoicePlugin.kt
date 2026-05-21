package com.chaosvoice

import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

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
            "setRoutingMode" -> {
                result.success(true)
            }
            "isDeviceRooted" -> {
                val rooted = checkDeviceRootedSafe()
                result.success(rooted)
            }
            else -> result.notImplemented()
        }
    }

    private fun checkDeviceRootedSafe(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) {
                return true
            }
        }
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = process.inputStream.bufferedReader()
            val line = reader.readLine()
            process.destroy()
            line != null
        } catch (e: Exception) {
            false
        }
    }
}
