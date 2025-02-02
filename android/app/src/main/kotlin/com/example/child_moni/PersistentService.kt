package com.example.child_moni

import android.app.Service
import android.content.Intent
import android.os.IBinder

class PersistentService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val restartIntent = Intent(applicationContext, AppBlockerService::class.java)
        startService(restartIntent)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
