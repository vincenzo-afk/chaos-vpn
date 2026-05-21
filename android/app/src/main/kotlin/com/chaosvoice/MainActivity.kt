package com.chaosvoice

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.projection.MediaProjectionManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * MainActivity V3 — handles the full permission + service launch flow:
 *
 * 1. Runtime permissions (RECORD_AUDIO, POST_NOTIFICATIONS)
 * 2. VPN permission dialog (startActivityForResult → RESULT_VPN)
 * 3. MediaProjection permission dialog (RESULT_MEDIA_PROJECTION)
 * 4. Battery optimization exemption
 * 5. Start ChaosVpnService + ChaosProjectionService
 *
 * The MethodChannel exposes all these steps to Flutter.
 */
class MainActivity : AudioServiceActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val AUDIO_CHANNEL = "com.chaosvoice/audio"

        private const val REQUEST_PERMISSIONS     = 100
        private const val REQUEST_VPN             = 200
        private const val REQUEST_MEDIA_PROJECTION = 300
        private const val REQUEST_BATTERY_OPT     = 400
    }

    private var audioChannel: MethodChannel? = null

    // Pending Flutter results while waiting for system dialogs
    private var pendingVpnResult: MethodChannel.Result?       = null
    private var pendingProjectionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        audioChannel?.setMethodCallHandler { call, result ->
            when (call.method) {

                // ── V1/V2 compat ──────────────────────────────────────────────

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
                    ChaosProjectionService.stop(this)
                    result.success(true)
                }
                "isRunning" -> {
                    result.success(VirtualMicService.isRunning || ChaosProjectionService.isRunning)
                }
                "updateParams" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) VirtualMicService.applyParams(args)
                    result.success(null)
                }
                "setRoutingMode" -> {
                    val mode = call.argument<String>("mode") ?: "no-root"
                    val am = getSystemService(AUDIO_SERVICE) as AudioManager
                    am.mode = if (mode.lowercase() == "normal") AudioManager.MODE_NORMAL
                              else AudioManager.MODE_IN_COMMUNICATION
                    result.success(true)
                }
                "isDeviceRooted" -> result.success(checkDeviceRootedSafe())

                // ── V3 VPN ────────────────────────────────────────────────────

                "requestVpnPermission" -> {
                    val intent = VpnService.prepare(this)
                    if (intent == null) {
                        // Already granted
                        result.success(true)
                    } else {
                        pendingVpnResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQUEST_VPN)
                    }
                }
                "isVpnPermissionGranted" -> {
                    result.success(VpnService.prepare(this) == null)
                }
                "startVpnService" -> {
                    ChaosVpnService.start(this)
                    result.success(true)
                }
                "stopVpnService" -> {
                    ChaosVpnService.stop(this)
                    result.success(true)
                }
                "isVpnRunning" -> {
                    result.success(ChaosVpnService.isVpnRunning)
                }

                // ── V3 MediaProjection ────────────────────────────────────────

                "startForegroundServiceOnly" -> {
                    // Start the projection service in foreground-ONLY mode (no audio yet).
                    // MUST be called BEFORE showing the MediaProjection dialog.
                    // This satisfies the Android 14 requirement that a foreground service
                    // with foregroundServiceType=mediaProjection must already be running
                    // before getMediaProjection() is called.
                    ChaosProjectionService.startForegroundOnly(this)
                    result.success(true)
                }
                "requestMediaProjection" -> {
                    val projMgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    pendingProjectionResult = result
                    @Suppress("DEPRECATION")
                    startActivityForResult(projMgr.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
                }
                "startProjectionService" -> {
                    ChaosProjectionService.start(this)
                    result.success(true)
                }
                "stopProjectionService" -> {
                    ChaosProjectionService.stop(this)
                    result.success(true)
                }
                "isProjectionRunning" -> {
                    result.success(ChaosProjectionService.isRunning)
                }

                // ── Battery Optimization ──────────────────────────────────────

                "requestBatteryOptimizationExemption" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                        }
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQUEST_BATTERY_OPT)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isBatteryOptimizationExempted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(android.os.PowerManager::class.java)
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }

                // ── Earphone Detection ────────────────────────────────────────

                "isEarphoneConnected" -> {
                    val am = getSystemService(AUDIO_SERVICE) as AudioManager
                    val connected = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                        devices.any {
                            it.type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                            it.type == android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                            it.type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                            it.type == android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                            it.type == android.media.AudioDeviceInfo.TYPE_USB_HEADSET
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        am.isWiredHeadsetOn || am.isBluetoothScoOn || am.isBluetoothA2dpOn
                    }
                    result.success(connected)
                }

                // ── V3 Full Start (convenience method) ───────────────────────

                "startV3Engine" -> {
                    // Start VPN + Projection service together
                    ChaosVpnService.start(this)
                    ChaosProjectionService.start(this)
                    result.success(true)
                }
                "stopV3Engine" -> {
                    ChaosVpnService.stop(this)
                    ChaosProjectionService.stop(this)
                    VirtualMicService.stop(this)
                    result.success(true)
                }
                "isV3EngineRunning" -> {
                    result.success(ChaosProjectionService.isRunning || VirtualMicService.isRunning)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────── Activity Results ────────────────────────────────────

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_VPN -> {
                val granted = resultCode == Activity.RESULT_OK
                pendingVpnResult?.success(granted)
                pendingVpnResult = null
                if (granted) {
                    ChaosVpnService.start(this)
                } else {
                    android.widget.Toast.makeText(this, "VPN permission required", android.widget.Toast.LENGTH_LONG).show()
                }
            }
            REQUEST_MEDIA_PROJECTION -> {
                val granted = resultCode == Activity.RESULT_OK && data != null
                if (granted && data != null) {
                    // Pass projection data DIRECTLY to the service via Intent extras.
                    // This is the correct approach — avoids the companion-static race
                    // condition where the Intent becomes stale if the Activity is recreated.
                    // The service is already running in foreground (from startForegroundServiceOnly)
                    // so getMediaProjection() will succeed on Android 14.
                    ChaosProjectionService.startWithProjectionData(this, resultCode, data)
                    // Also update companion statics for legacy fallback path
                    ChaosProjectionService.projectionResultCode = resultCode
                    ChaosProjectionService.projectionData = data
                }
                pendingProjectionResult?.success(granted)
                pendingProjectionResult = null
            }
            REQUEST_BATTERY_OPT -> {
                // Battery opt result — no action needed, service is already running
            }
        }
    }

    // ─────────────────── Runtime Permissions ─────────────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PERMISSIONS) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                VirtualMicService.start(this)
            }
        }
    }

    private fun checkAndRequestPermissions(): Boolean {
        val perms = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (perms.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, perms.toTypedArray(), REQUEST_PERMISSIONS)
            return false
        }
        return true
    }

    // ─────────────────── Root Detection ──────────────────────────────────────

    private fun checkDeviceRootedSafe(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true
        val paths = arrayOf(
            "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su",
            "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su"
        )
        for (path in paths) if (File(path).exists()) return true
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val line = process.inputStream.bufferedReader().readLine()
            process.destroy()
            line != null
        } catch (e: Exception) { false }
    }

    override fun onDestroy() {
        audioChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
