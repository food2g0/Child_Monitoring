package com.example.child_moni

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.FrameLayout
import com.google.firebase.firestore.FirebaseFirestore

class AppBlockerService : AccessibilityService() {

    private var overlayContainer: FrameLayout? = null
    private val blockedApps = mutableListOf<String>()
    private val db = FirebaseFirestore.getInstance()

    // Replace with dynamic user/child IDs if necessary
    private val currentUserId = "JIXK9PEPxGfzKWY82FW10B65aai2"
    private val currentChildId = "oSCgkyLO5aKmKAVH0rG7"

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AppBlockerService", "Service connected")

        fetchBlockedApps()

        if (!Settings.canDrawOverlays(this)) {
            Log.e("AppBlockerService", "Overlay permission not granted. Cannot show block screen.")
        } else {
            Log.d("AppBlockerService", "Overlay permission granted.")
        }
    }


    private fun fetchBlockedApps() {
        val appsCollectionPath = "Parent/$currentUserId/Child/$currentChildId/InstalledApps"

        db.collection(appsCollectionPath)
            .whereEqualTo("isBlocked", true)
            .get()
            .addOnSuccessListener { documents ->
                blockedApps.clear()
                for (doc in documents) {
                    val packageName = doc.getString("packageName")
                    if (!packageName.isNullOrEmpty()) {
                        blockedApps.add(packageName)
                    } else {
                        Log.w("AppBlockerService", "Document ${doc.id} missing packageName field.")
                    }
                }
                Log.d("AppBlockerService", "Blocked apps updated: $blockedApps")
            }
            .addOnFailureListener { exception ->
                Log.e("AppBlockerService", "Failed to fetch blocked apps: ${exception.message}")
            }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: "Unknown"
        val eventType = when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "TYPE_WINDOW_STATE_CHANGED"
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "TYPE_WINDOW_CONTENT_CHANGED"
            else -> "OTHER_EVENT"
        }

        Log.d("AppBlockerService", "Event detected: $eventType, Package: $packageName")

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            if (isAppBlocked(packageName)) {
                Log.d("AppBlockerService", "Blocking app: $packageName")
                showBlockScreen()
            } else {
                Log.d("AppBlockerService", "App is not blocked: $packageName")
                removeOverlay()
            }
        } else {
            Log.d("AppBlockerService", "Ignored event type: ${event.eventType}, Package: $packageName")
        }
    }





    override fun onInterrupt() {
        Log.d("AppBlockerService", "Service Interrupted")
    }

    private fun isAppBlocked(packageName: String?): Boolean {
        if (packageName == null) return false

        val normalizedPackageName = packageName.trim().lowercase()
        val normalizedBlockedApps = blockedApps.map { it.trim().lowercase() }

        val isBlocked = normalizedBlockedApps.contains(normalizedPackageName)
        Log.d("AppBlockerService", "Checking if app is blocked: $packageName -> $isBlocked")
        return isBlocked
    }



    private fun showBlockScreen() {
        if (overlayContainer != null) {
            Log.d("AppBlockerService", "Overlay already displayed")
            return
        }

        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        overlayContainer = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            alpha = 0.8f
        }

        val okButton = Button(this).apply {
            text = "OK"
            setOnClickListener {
                removeOverlay()
                navigateToHome()
            }
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
        }

        overlayContainer?.addView(okButton)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager.addView(overlayContainer, params)
            Log.d("AppBlockerService", "Block screen displayed")
        } catch (e: Exception) {
            Log.e("AppBlockerService", "Error displaying overlay: ${e.message}")
        }
    }



    private fun removeOverlay() {
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        overlayContainer?.let {
            windowManager.removeView(it)
            overlayContainer = null
        }
        Log.d("AppBlockerService", "Block screen overlay removed")
    }

    private fun navigateToHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }
}
