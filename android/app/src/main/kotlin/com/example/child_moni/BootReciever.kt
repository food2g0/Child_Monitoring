import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.child_moni.AppBlockerService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            val serviceIntent = Intent(context, AppBlockerService::class.java)
            context?.startService(serviceIntent)
        }
    }
}
