package com.example.child_moni

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import com.google.firebase.auth.FirebaseAuth

import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import com.google.firebase.firestore.FirebaseFirestore

class AppBlockerService : AccessibilityService() {

    private var overlayContainer: FrameLayout? = null
    private val blockedApps = mutableListOf<String>()
    private val db = FirebaseFirestore.getInstance()
    private var isOverlayVisible = false
    private var currentBlockedApp: String? = null
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var sharedPreferences: SharedPreferences
    private var currentUserId: String? = null  // Now dynamic
    private var currentChildId: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AppBlockerService", "Service connected")

        sharedPreferences = getSharedPreferences("child_moni_prefs", Context.MODE_PRIVATE)
        currentChildId = sharedPreferences.getString("childDocId", null)

        Log.d("AppBlockerService", "Fetched childDocId: $currentChildId")

        // Fetch the dynamic current user ID
        currentUserId = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUserId == null) {
            Log.e("AppBlockerService", "No user is logged in.")
            return
        }

        Log.d("AppBlockerService", "Fetched currentUserId: $currentUserId")

        if (currentChildId.isNullOrEmpty()) {
            Log.e("AppBlockerService", "No childDocId found in SharedPreferences")
            waitForChildDocIdAndFetchApps()
        } else {
            Log.d("AppBlockerService", "Fetched childDocId: $currentChildId")
            fetchBlockedApps()
        }

        if (!Settings.canDrawOverlays(this)) {
            Log.e("AppBlockerService", "Overlay permission not granted. Cannot show block screen.")
        }
    }

    private fun waitForChildDocIdAndFetchApps() {
        if (currentChildId.isNullOrEmpty()) {
            Log.e("AppBlockerService", "Waiting for $currentChildId")
            handler.postDelayed({ waitForChildDocIdAndFetchApps() }, 1000)  // Retry every second
        } else {
            fetchBlockedApps()
        }
    }

    private fun fetchBlockedApps() {
        if (currentChildId.isNullOrEmpty() || currentUserId.isNullOrEmpty()) {
            Log.e("AppBlockerService", "Cannot fetch blocked apps, child ID or user ID is null.")
            return
        }

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

        val eventType = event.eventType

        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString()

            if (packageName == "com.example.child_moni") {
                Log.d("AppBlockerService", "Ignoring own app/service: $packageName")
                return
            }

            if (isAppBlocked(packageName)) {
                handler.removeCallbacksAndMessages(null)
                handler.postDelayed({
                    if (!isOverlayVisible || currentBlockedApp != packageName) {
                        Log.d("AppBlockerService", "Blocking app: $packageName")
                        currentBlockedApp = packageName
                        showBlockScreen()
                    }
                }, 300)
            } else if (currentBlockedApp != null && packageName != currentBlockedApp) {
                Log.d("AppBlockerService", "Unblocked app detected: $packageName")
                removeOverlay()
                currentBlockedApp = null
            }
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
        if (isOverlayVisible) {
            Log.d("AppBlockerService", "Overlay already displayed")
            return
        }

        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        overlayContainer = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            alpha = 0.8f
        }

        val blockedText = TextView(this).apply {
            text = "App is blocked"
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
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
                topMargin = 100
            }
        }

        overlayContainer?.addView(blockedText)
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
            isOverlayVisible = true
            Log.d("AppBlockerService", "Block screen displayed")
        } catch (e: Exception) {
            Log.e("AppBlockerService", "Error displaying overlay: ${e.message}")
        }
    }

    private fun removeOverlay() {
        if (!isOverlayVisible) return

        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        overlayContainer?.let {
            windowManager.removeView(it)
            overlayContainer = null
        }
        isOverlayVisible = false
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
