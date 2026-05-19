package com.chaosvoice

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val AUDIO_CHANNEL = "com.chaosvoice/audio"
        private const val PERMISSION_REQUEST_CODE = 100
    }

    private var audioChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        )

        audioChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    if (checkAndRequestPermissions()) {
                        val started = VirtualMicService.start(this)
                        result.success(started)
                    } else {
                        result.success(false)
                    }
                }
                "stopService" -> {
                    VirtualMicService.stop(this)
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
                    // Pass the mode string to VirtualMicService
                    val mode = (call.argument<String>("mode")) ?: "no-root"
                    val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                    when (mode.lowercase()) {
                        "root" -> audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        "no-root", "auto-detect" -> audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        else -> audioManager.mode = AudioManager.MODE_NORMAL
                    }
                    result.success(true)
                }
                "isDeviceRooted" -> {
                    val rooted = try {
                        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
                        val reader = process.inputStream.bufferedReader()
                        val line = reader.readLine()
                        process.destroy()
                        line?.contains("uid=0") == true
                    } catch (_: Exception) {
                        false
                    }
                    result.success(rooted)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                VirtualMicService.start(this)
            }
        }
    }

    private fun checkAndRequestPermissions(): Boolean {
        val permissions = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(Manifest.permission.RECORD_AUDIO)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
            return false
        }

        return true
    }

    override fun onDestroy() {
        audioChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
