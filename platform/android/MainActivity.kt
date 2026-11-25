package com.aurel.aurel

import android.os.Environment
import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val DEVICE_STORAGE_CHANNEL = "com.aurel.aurel/device_storage"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_STORAGE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceStorage" -> {
                    try {
                        val stats = StatFs(Environment.getExternalStorageDirectory().absolutePath)
                        result.success(
                            mapOf(
                                "totalBytes" to stats.totalBytes,
                                "availableBytes" to stats.availableBytes
                            )
                        )
                    } catch (error: Exception) {
                        result.error(
                            "DEVICE_STORAGE_UNAVAILABLE",
                            error.message ?: "Could not read device storage.",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
