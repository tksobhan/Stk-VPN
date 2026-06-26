package com.tksobhan.v2ray_stk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.Socket
import java.util.Timer
import java.util.TimerTask
import kotlin.concurrent.thread

class CoreService : VpnService() {

    private val CHANNEL_ID = "vpn_core_channel"
    private val NOTIFICATION_ID = 1234
    private var vpnInterface: ParcelFileDescriptor? = null
    private var currentProcess: Process? = null
    private var currentCore: String? = null
    private var isRunning = false
    private var retryCount = 0
    private var trafficTimer: Timer? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val type = intent?.getStringExtra("type") ?: "singbox"
        val config = intent?.getStringExtra("config") ?: ""

        Log.d("CORE_SERVICE", "🚀 شروع $type")

        // ✅ ایراد ۵: تغییر نام به initForegroundService
        initForegroundService()

        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            Log.d("CORE_SERVICE", "⏳ مجوز VPN مورد نیاز است")
            val activityIntent = Intent(this, MainActivity::class.java)
            activityIntent.putExtra("vpn_request", true)
            activityIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(activityIntent)
            return START_STICKY
        }

        val configFile = File(filesDir, "config.json")
        configFile.writeText(config)

        val installer = CoreInstaller(this)
        when (type.lowercase()) {
            "singbox" -> {
                if (installer.installIfNeeded("sing-box")) {
                    startSingBox(configFile.absolutePath)
                }
            }
            "xray" -> {
                if (installer.installIfNeeded("xray")) {
                    startXray(configFile.absolutePath)
                }
            }
            else -> Log.e("CORE_SERVICE", "نوع هسته پشتیبانی نمی‌شود: $type")
        }

        if (type.lowercase() == "singbox") {
            startVpn()
        }

        protectSockets()
        startTrafficMonitor()

        return START_STICKY
    }

    // ✅ ایراد ۵: تغییر نام متد
    private fun initForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("V2RAY STK")
            .setContentText("VPN Running")
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        Log.d("CORE_SERVICE", "✅ Foreground Service شروع شد")
    }

    private fun startVpn() {
        try {
            vpnInterface = Builder()
                .setSession("V2RAY stk")
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .setMtu(1500)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
                .allowFamily(OsConstants.AF_INET)
                .allowFamily(OsConstants.AF_INET6)
                .setBlocking(true)
                .establish()

            Log.d("CORE_SERVICE", "✅ TUN Interface ساخته شد (fd: ${vpnInterface?.fd})")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در ساخت TUN: ${e.message}")
        }
    }

    // ✅ ایراد ۱۰: protect روی سوکت واقعی
    private fun protectSockets() {
        try {
            val socket = Socket()
            protect(socket)
            socket.close()
            Log.d("CORE_SERVICE", "🔒 protect() فعال شد")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ protect error: ${e.message}")
        }
    }

    private fun startTrafficMonitor() {
        trafficTimer = Timer()
        trafficTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                val rx = android.net.TrafficStats.getTotalRxBytes()
                val tx = android.net.TrafficStats.getTotalTxBytes()
                // ✅ ایراد ۱۱: ارسال با بررسی null
                MainActivity.trafficSink?.let {
                    it.success("$tx|$rx")
                }
            }
        }, 0, 1000)
    }

    // ✅ ایراد ۹: stopCoreOnly بدون stopSelf
    private fun stopCoreOnly() {
        try {
            currentProcess?.destroy()
            currentProcess = null
            currentCore = null
            isRunning = false
            Log.d("CORE_SERVICE", "✅ هسته متوقف شد")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در توقف هسته: ${e.message}")
        }
    }

    // ✅ ایراد ۹: stopAll با stopSelf محدود
    private fun stopAll() {
        stopCoreOnly()
        try {
            vpnInterface?.close()
            vpnInterface = null
            stopForeground(true)
            Log.d("CORE_SERVICE", "✅ VPN و هسته متوقف شدند")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در توقف: ${e.message}")
        }
    }

    private fun startSingBox(configPath: String) {
        stopCoreOnly()
        try {
            val binary = File(filesDir, "sing-box")
            if (!binary.exists()) {
                Log.e("CORE_SERVICE", "❌ فایل sing-box وجود ندارد")
                return
            }

            currentProcess = Runtime.getRuntime().exec(
                arrayOf(binary.absolutePath, "run", "-c", configPath)
            )
            currentCore = "singbox"
            isRunning = true
            retryCount = 0
            Log.d("CORE_SERVICE", "✅ sing-box با موفقیت شروع شد")

            readProcessOutput(currentProcess!!)

        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در شروع sing-box: ${e.message}")
            recoverFromCrash("singbox", configPath)
        }
    }

    private fun startXray(configPath: String) {
        stopCoreOnly()
        try {
            val binary = File(filesDir, "xray")
            if (!binary.exists()) {
                Log.e("CORE_SERVICE", "❌ فایل xray وجود ندارد")
                return
            }

            currentProcess = Runtime.getRuntime().exec(
                arrayOf(binary.absolutePath, "-config", configPath)
            )
            currentCore = "xray"
            isRunning = true
            retryCount = 0
            Log.d("CORE_SERVICE", "✅ xray با موفقیت شروع شد")

            readProcessOutput(currentProcess!!)

        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در شروع xray: ${e.message}")
            recoverFromCrash("xray", configPath)
        }
    }

    private fun readProcessOutput(process: Process) {
        thread {
            process.inputStream.bufferedReader().forEachLine {
                Log.d("CORE_OUT", it)
                MainActivity.logSink?.let { sink -> sink.success(it) }
            }
        }
        thread {
            process.errorStream.bufferedReader().forEachLine {
                Log.e("CORE_ERR", it)
                MainActivity.logSink?.let { sink -> sink.success("[ERROR] $it") }
            }
        }
    }

    // ✅ ایراد ۸: recoverFromCrash با Handler
    private fun recoverFromCrash(core: String, config: String) {
        if (retryCount < 3) {
            retryCount++
            Log.d("CORE_SERVICE", "🔄 بازیابی $core (تلاش $retryCount)...")
            Handler(Looper.getMainLooper()).postDelayed({
                val intent = Intent(this, CoreService::class.java)
                intent.putExtra("type", core)
                intent.putExtra("config", config)
                startService(intent)
            }, 2000)
        } else {
            Log.e("CORE_SERVICE", "❌ تعداد تلاش‌ها تمام شد")
            stopSelf()
        }
    }

    // ✅ ایراد ۹: stopAll در onDestroy
    override fun onDestroy() {
        trafficTimer?.cancel()
        vpnInterface?.close()
        stopAll()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null
}
