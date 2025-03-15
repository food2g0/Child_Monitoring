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
import android.os.IBinder
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
import android.app.PendingIntent

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

        createNotificationChannel()

        val notificationIntent = Intent(this, BlockScreenActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(this, "AppBlockerServiceChannel")
            .setContentTitle("App Blocker Service")
            .setContentText("Monitoring apps in the background")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(1, notification)

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
    private fun showOverlay() {
        val overlayIntent = Intent(this, BlockScreenActivity::class.java)
        overlayIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(overlayIntent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                "AppBlockerServiceChannel",
                "App Blocker Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
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
                        if (timeLimit > 0) {
                            appTimeLimits[packageName] = timeLimit
                        }
                        if (isBlocked) {
                            blockedApps.add(packageName)
                        }

                        Log.d("AppBlockerService", "Fetched app: $packageName, timeLimit: $timeLimit, isBlocked: $isBlocked")

                        // Ensure the app is in the foreground before starting the timer
                        if (isAppInForeground(packageName)) {
                            Log.d("AppBlockerService", "Starting timer for $packageName with $timeLimit seconds")
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
        if (packageName.isNullOrEmpty()) return;

        // Ensure child_moni is never blocked
        if (packageName == packageNameOfThisApp) {
            Log.d("AppBlockerService", "$packageName is the monitoring app and will not be blocked");
            return;
        }

        if (isAppBlocked(packageName)) {
            showBlockScreen();
        }
    }


    private fun handleTimeLimitApps(packageName: String?) {
        if (packageName.isNullOrEmpty()) return

        // Check if the app has a time limit and is in the foreground
        val appTimeLimit = appTimeLimits[packageName]

        if (appTimeLimit != null && appTimeLimit > 0 && isAppInForeground(packageName)) {
            startAppTimer(packageName, appTimeLimit)
        } else {
            Log.d("AppBlockerService", "App $packageName has no time limit or is not in foreground")
        }
    }


    private fun isAppInForeground(packageName: String): Boolean {
        // Compare the packageName with the app in the foreground
        return currentForegroundApp == packageName
    }

    private fun isAppBlocked(packageName: String?): Boolean {
        if (packageName == null) return false;

        // Ensure child_moni is never considered blocked
        if (packageName == packageNameOfThisApp) {
            Log.d("AppBlockerService", "$packageName is the monitoring app and will not be blocked");
            return false;
        }

        val normalizedPackageName = packageName.trim().lowercase();
        val normalizedBlockedApps = blockedApps.map { it.trim().lowercase() };
        val isBlocked = normalizedBlockedApps.contains(normalizedPackageName);
        Log.d("AppBlockerService", "Checking if app is blocked: $packageName -> $isBlocked");
        return isBlocked;
    }


    private fun startAppTimer(packageName: String, timeLimit: Int) {
        if (isAppBlocked(packageName)) {
            Log.d("AppBlockerService", "Skipping timer for $packageName as it is already blocked")
            return
        }

        // If there's already a timer for this app, do not restart
        if (appTimers.containsKey(packageName)) {
            Log.d("AppBlockerService", "Timer already running for $packageName, skipping restart")
            return
        }

        Log.d("AppBlockerService", "Starting timer for $packageName with $timeLimit seconds")

        val timer = object : CountDownTimer((timeLimit * 1000).toLong(), 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsRemaining = (millisUntilFinished / 1000).toInt()
                appTimeLimits[packageName] = secondsRemaining
                Log.d("AppBlockerService", "Time left for $packageName: $secondsRemaining seconds")
            }

            override fun onFinish() {
                Log.d("AppBlockerService", "Time's up for $packageName. Blocking app.")
                currentBlockedApp = packageName
                showBlockScreen()
                updateAppBlockedStatus(packageName)
                appTimers.remove(packageName) // Ensure it can restart later
            }
        }

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

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString()

            if (!packageName.isNullOrEmpty()) {
                currentForegroundApp = packageName
                Log.d("AppBlockerService", "Current foreground app: $currentForegroundApp")

                if (!isAppInForegrounds(packageName)) {
                    stopAppTimer(packageName)
                } else {
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


                    if (isAppBlocked(currentForegroundApp) && !isOverlayVisible) {
                        Log.e("AppBlockerService", "Blocking ${currentForegroundApp} due to database update!")
                        showBlockScreen()
                    }
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