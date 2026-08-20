package com.lubob.bilibili_kid_viewer

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kid_lock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockTask" -> result.success(
                        runCatching { startLockTask() }.isSuccess)
                    "stopLockTask" -> result.success(
                        runCatching { stopLockTask() }.isSuccess)
                    "isLocked" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val locked = if (Build.VERSION.SDK_INT >= 23) {
                            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                        } else {
                            @Suppress("DEPRECATION")
                            am.isInLockTaskMode
                        }
                        result.success(locked)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
