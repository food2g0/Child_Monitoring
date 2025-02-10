package com.example.child_moni

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import com.google.firebase.auth.FirebaseAuth
import android.os.CountDownTimer
import android.os.Handler
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.os.Build
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
    private val appTimeLimits = mutableMapOf<String, Int>() // Stores time limits for each app
    private val db = FirebaseFirestore.getInstance()
    private var isOverlayVisible = false
    private var currentBlockedApp: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private val appTimers = mutableMapOf<String, CountDownTimer?>() // Allow null values for timers

    private lateinit var sharedPreferences: SharedPreferences
    private var currentUserId: String? = null  // Now dynamic
    private var currentChildId: String? = null
    private var currentForegroundApp: String? = null // Track the currently foreground app
    private val packageNameOfThisApp = "com.example.child_moni"


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

            listenForAppUpdates()
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
            fetchAppsAndStartTimerIfNeeded()
        }
    }

    private fun fetchAppsAndStartTimerIfNeeded() {
        if (currentChildId.isNullOrEmpty() || currentUserId.isNullOrEmpty()) {
            Log.e("AppBlockerService", "Cannot fetch apps, child ID or user ID is null.")
            return
        }

        val appsCollectionPath = "Parent/$currentUserId/Child/$currentChildId/InstalledApps"

        // Fetch all apps with a timeLimit greater than 0
        db.collection(appsCollectionPath)
            .get()
            .addOnSuccessListener { documents ->
                blockedApps.clear()
                appTimeLimits.clear()

                for (doc in documents) {
                    val packageName = doc.getString("packageName")
                    val timeLimit = doc.getLong("timeLimit")?.toInt() ?: 0
                    val isBlocked = doc.getBoolean("isBlocked") ?: false

                    if (!packageName.isNullOrEmpty()) {
                        // Add the app to the time limits map
                        if (timeLimit > 0) {
                            appTimeLimits[packageName] = timeLimit
                        }

                        // If the app is blocked, add to the blocked list
                        if (isBlocked) {
                            blockedApps.add(packageName)
                        }

                        // Immediately trigger the timer if the app is in the foreground
                        if (isAppInForeground(packageName)) {
                            startAppTimer(packageName, timeLimit)
                        }
                    }
                }
            }
            .addOnFailureListener { exception ->
                Log.e("AppBlockerService", "Failed to fetch apps: ${exception.message}")
            }
    }


    private fun isDontBlock(packageName: String): Boolean {
        // Here, you can check the database or your app's configuration
        // For example, check if the app has the "dontBlock" field set to "yes"
        return packageName == "com.example.child_moni"
    }


    private fun handleBlockedApps(packageName: String?) {
        if (packageName.isNullOrEmpty()) return

        // Skip blocking logic if the app is child_moni or marked as don't block
        if (packageName == packageNameOfThisApp || isDontBlock(packageName)) {
            Log.d("AppBlockerService", "$packageName is not blocked (dontBlock is true or it's child_moni)")
            return
        }

        // Check if the app is in the blocked list
        if (isAppBlocked(packageName)) {
            // If blocked, show the block screen immediately
            showBlockScreen()
        }
    }


    private fun handleTimeLimitApps(packageName: String?) {
        if (packageName.isNullOrEmpty()) return

        // Check if the app has a time limit in the database
        val appTimeLimit = appTimeLimits[packageName]

        if (appTimeLimit != null) {
            // If the app has a time limit, start a countdown timer immediately
            if (isAppInForeground(packageName)) {
                startAppTimer(packageName, appTimeLimit)
            }
        } else {
            Log.d("AppBlockerService", "No time limit for app: $packageName")
        }
    }

    private fun isAppInForeground(packageName: String): Boolean {
        // Compare the packageName with the app in the foreground
        return currentForegroundApp == packageName
    }

    private fun isAppBlocked(packageName: String?): Boolean {
        if (packageName == null) return false
        val normalizedPackageName = packageName.trim().lowercase()
        val normalizedBlockedApps = blockedApps.map { it.trim().lowercase() }
        val isBlocked = normalizedBlockedApps.contains(normalizedPackageName)
        Log.d("AppBlockerService", "Checking if app is blocked: $packageName -> $isBlocked")
        return isBlocked
    }

    private fun startAppTimer(packageName: String, timeLimit: Int) {
        // If the app is already blocked, do not start the timer
        if (isAppBlocked(packageName)) {
            Log.d("AppBlockerService", "Skipping timer for $packageName as it is already blocked")
            return
        }

        // Only restart the timer if it has already finished or if the time limit has changed
        val existingTimer = appTimers[packageName]
        if (existingTimer != null) {
            // Timer is already running, don't restart it
            return
        }

        // If there's already a timer for this app, cancel it before starting a new one
        appTimers[packageName]?.cancel()

        // Create a new timer
        val timer = object : CountDownTimer((timeLimit * 1000).toLong(), 1000) {
            override fun onTick(millisUntilFinished: Long) {
                // Update the time limit every second
                appTimeLimits[packageName] = (millisUntilFinished / 1000).toInt()
                Log.d("AppBlockerService", "Time left for $packageName: ${appTimeLimits[packageName]} seconds")
            }

            override fun onFinish() {
                Log.d("AppBlockerService", "Time's up for $packageName. Blocking app.")
                currentBlockedApp = packageName
                showBlockScreen()

                // Update the database to set isBlocked = true
                updateAppBlockedStatus(packageName)

                // Reset the timer reference for the app
                appTimers[packageName] = null // Set to null to avoid restarting
            }
        }

        // Start the countdown timer
        timer.start()
        appTimers[packageName] = timer
    }
    // Function to update the "isBlocked" field in Firestore
    private fun updateAppBlockedStatus(packageName: String) {
        if (currentChildId.isNullOrEmpty() || currentUserId.isNullOrEmpty()) {
            Log.e("AppBlockerService", "Cannot update app status, child ID or user ID is null.")
            return
        }

        val appsCollectionPath = "Parent/$currentUserId/Child/$currentChildId/InstalledApps"

        // Update the isBlocked field in Firestore for the app
        db.collection(appsCollectionPath)
            .whereEqualTo("packageName", packageName)
            .get()
            .addOnSuccessListener { documents ->
                if (!documents.isEmpty) {
                    for (document in documents) {
                        document.reference.update("isBlocked", true)
                            .addOnSuccessListener {
                                Log.d("AppBlockerService", "Successfully updated isBlocked for $packageName")
                            }
                            .addOnFailureListener { exception ->
                                Log.e("AppBlockerService", "Failed to update isBlocked for $packageName: ${exception.message}")
                            }
                    }
                } else {
                    Log.e("AppBlockerService", "No app found with packageName: $packageName")
                }
            }
            .addOnFailureListener { exception ->
                Log.e("AppBlockerService", "Failed to find app: ${exception.message}")
            }
    }





    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType

        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName: String? = event.packageName?.toString()

            if (packageName != null) {
                // Set the currentForegroundApp whenever the window state changes
                currentForegroundApp = packageName


                if (!isAppInForegrounds(packageName)) {
                    stopAppTimer(packageName)
                } else {
                    // If the app is in the foreground, handle it accordingly
                    handleBlockedApps(packageName)
                    handleTimeLimitApps(packageName)
                }
            }
        }
    }

    // Method to stop the app timer when it is no longer in the foreground
    private fun stopAppTimer(packageName: String) {
        val existingTimer = appTimers[packageName]
        if (existingTimer != null) {
            // Cancel the timer if it exists
            existingTimer.cancel()
            appTimers[packageName] = null // Set the timer to null after canceling
            Log.d("AppBlockerService", "Timer stopped for $packageName")
        }
    }

    // Update the isAppInForeground method to check the current foreground app
    private fun isAppInForegrounds(packageName: String): Boolean {
        return currentForegroundApp == packageName
    }

    private fun listenForAppUpdates() {
        if (currentChildId.isNullOrEmpty() || currentUserId.isNullOrEmpty()) {
            Log.e("AppBlockerService", "Cannot listen for app updates, child ID or user ID is null.")
            return
        }

        val appsCollectionPath = "Parent/$currentUserId/Child/$currentChildId/InstalledApps"

        db.collection(appsCollectionPath)
            .addSnapshotListener { snapshots, error ->
                if (error != null) {
                    Log.e("AppBlockerService", "Error listening for updates: ${error.message}")
                    return@addSnapshotListener
                }

                if (snapshots != null) {
                    blockedApps.clear()
                    appTimeLimits.clear()

                    for (doc in snapshots.documents) {
                        val packageName = doc.getString("packageName")
                        val timeLimit = doc.getLong("timeLimit")?.toInt() ?: 0
                        val isBlocked = doc.getBoolean("isBlocked") ?: false

                        if (!packageName.isNullOrEmpty()) {
                            if (timeLimit > 0) {
                                appTimeLimits[packageName] = timeLimit
                            }
                            if (isBlocked) {
                                blockedApps.add(packageName)
                            }

                            // Start the timer immediately if the app is in the foreground
                            if (isAppInForeground(packageName)) {
                                startAppTimer(packageName, timeLimit)
                            }
                        }
                    }

                    Log.d("AppBlockerService", "Updated app list and timers in real-time")
                }
            }
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
        if (overlayContainer != null) {
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            windowManager.removeView(overlayContainer)
            overlayContainer = null
            isOverlayVisible = false
            Log.d("AppBlockerService", "Block screen removed")
        }
    }

    private fun navigateToHome() {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    override fun onInterrupt() {
        // Handle the case when the service is interrupted (e.g., when the user disables it)
        Log.d("AppBlockerService", "Service interrupted")
    }


}