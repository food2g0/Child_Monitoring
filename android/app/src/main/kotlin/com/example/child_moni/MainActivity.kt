package com.example.child_moni

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/foreground"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getForegroundApp" -> {
                    val foregroundApp = getForegroundApp()
                    if (foregroundApp != null) {
                        result.success(foregroundApp)
                    } else {
                        result.error("UNAVAILABLE", "Foreground app not available", null)
                    }
                }
                "requestUsageAccess" -> {
                    requestUsageAccessPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getForegroundApp(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (!hasUsageAccessPermission()) {
                return null
            }
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                currentTime - 1000 * 60, // Last 1 minute
                currentTime
            )
            if (stats != null && stats.isNotEmpty()) {
                val sortedStats = stats.sortedByDescending { it.lastTimeUsed }
                return sortedStats.firstOrNull()?.packageName
            }
        }
        return null
    }


    private fun requestUsageAccessPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            startActivity(intent)
        }
    }
    private fun hasUsageAccessPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            val mode = appOpsManager.checkOpNoThrow(
                "android:get_usage_stats",
                android.os.Process.myUid(),
                packageName
            )
            return mode == android.app.AppOpsManager.MODE_ALLOWED
        }
        return false
    }

}
