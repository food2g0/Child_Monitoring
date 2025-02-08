package com.example.child_moni

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.app/foreground"
    private val APP_BLOCKER_CHANNEL = "com.example.child_moni/app_blocker"
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1000
    private val CHANNEL_CHILD = "com.example.app/childId"
    private val OVERLAY_CHANNEL = "com.example.app/overlay"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check overlay permission
        if (!Settings.canDrawOverlays(this)) {
            requestOverlayPermission()
        }

        // Check accessibility service
        if (!isAccessibilityServiceEnabled(AppBlockerService::class.java)) {
            openAccessibilitySettings()
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Foreground app retrieval & App closing
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getForegroundApp" -> result.success(getForegroundApp())
                "closeApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        closeApp(packageName)
                        result.success("App closed: $packageName")
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // App Blocker Service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_BLOCKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAppBlockerService" -> {
                    startAppBlockerService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Overlay Permission Check
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Child ID Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CHILD).setMethodCallHandler { call, result ->
            if (call.method == "sendCurrentChildId") {
                val childDocId = call.argument<String>("childDocId")
                if (childDocId != null) {
                    val sharedPreferences = getSharedPreferences("child_moni_prefs", Context.MODE_PRIVATE)
                    val editor = sharedPreferences.edit()
                    editor.putString("childDocId", childDocId)
                    editor.apply()

                    val intent = Intent("com.example.child_moni.UPDATE_CHILD_DOC_ID")
                    intent.putExtra("childDocId", childDocId)
                    sendBroadcast(intent)

                    Log.d("ChildHome", "Received childDocId: $childDocId")
                    result.success(null)
                } else {
                    result.error("UNAVAILABLE", "ChildDocId not provided", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun requestOverlayPermission() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        Toast.makeText(this, "Please enable the AppBlockerService", Toast.LENGTH_LONG).show()
    }

    private fun isAccessibilityServiceEnabled(service: Class<out AccessibilityService>): Boolean {
        val expectedComponentName = ComponentName(this, service)
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (ComponentName.unflattenFromString(componentName) == expectedComponentName) {
                return true
            }
        }
        return false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            if (Settings.canDrawOverlays(this)) {
                Toast.makeText(this, "Overlay permission granted", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Overlay permission denied", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun getForegroundApp(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            if (!hasUsageAccessPermission()) {
                return null
            }
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val currentTime = System.currentTimeMillis()
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                currentTime - 1000 * 60,
                currentTime
            )
            return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
        } else {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.runningAppProcesses?.forEach { appProcess ->
                if (appProcess.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                    return appProcess.processName
                }
            }
        }
        return null
    }

    private fun hasUsageAccessPermission(): Boolean {
        val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOpsManager.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun closeApp(packageName: String) {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val tasks = activityManager.appTasks
            for (task in tasks) {
                if (task.taskInfo.topActivity?.packageName == packageName) {
                    task.finishAndRemoveTask()
                    break
                }
            }
        }
    }

    private fun startAppBlockerService() {
        val intent = Intent(this, AppBlockerService::class.java)
        startService(intent)
    }
}
