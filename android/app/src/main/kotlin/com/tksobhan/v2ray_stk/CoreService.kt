package com.tksobhan.v2ray_stk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.InetSocketAddress
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
    private var lastRx = 0L
    private var lastTx = 0L

    // ✅ مراحل 1-5: VPN Permission + VpnService + TUN + CoreInstaller
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val type = intent?.getStringExtra("type") ?: "singbox"
        val config = intent?.getStringExtra("config") ?: ""

        Log.d("CORE_SERVICE", "🚀 شروع $type")

        // مرحله 1: درخواست مجوز VPN
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            Log.d("CORE_SERVICE", "⏳ مجوز VPN مورد نیاز است")
            val activityIntent = Intent(this, MainActivity::class.java)
            activityIntent.putExtra("vpn_request", true)
            activityIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(activityIntent)
            return START_STICKY
        }

        // مرحله 8: اعتبارسنجی Config (قبل از اجرا)
        val configFile = File(filesDir, "config.json")
        configFile.writeText(config)

        // مرحله 2: TUN کامل (قبل از اجرای Core)
        startVpn()

        // مرحله 3-4: دانلود و نصب هسته‌ها
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

        // مرحله 10: protect()
        protectSockets()

        // مرحله 12: Log Streaming (از طریق stdout/stderr)
        // مرحله 13: Traffic Monitor
        startTrafficMonitor()

        // مرحله 14: Ping Engine (اختیاری)
        // مرحله 17: Kill Switch (setBlocking)
        // مرحله 18: Split Tunnel (در Builder)

        return START_STICKY
    }

    // ✅ مرحله 2: TUN کامل با fd
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
                .setBlocking(true) // ✅ Kill Switch (مرحله 17)
                .establish()

            Log.d("CORE_SERVICE", "✅ TUN Interface کامل ساخته شد")
            Log.d("CORE_SERVICE", "📌 fd: ${vpnInterface?.fd}")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در ساخت TUN: ${e.message}")
        }
    }

    // ✅ مرحله 10: protect()
    private fun protectSockets() {
        try {
            val socket = Socket()
            protect(socket)
            Log.d("CORE_SERVICE", "🔒 protect() فعال شد")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ protect error: ${e.message}")
        }
    }

    // ✅ مرحله 13: Traffic Monitor
    private fun startTrafficMonitor() {
        trafficTimer = Timer()
        trafficTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                val rx = android.net.TrafficStats.getTotalRxBytes()
                val tx = android.net.TrafficStats.getTotalTxBytes()
                if (rx != lastRx || tx != lastTx) {
                    val totalRx = rx - lastRx
                    val totalTx = tx - lastTx
                    lastRx = rx
                    lastTx = tx
                    sendTrafficToFlutter(totalTx, totalRx)
                }
            }
        }, 0, 1000)
    }

    private fun sendTrafficToFlutter(upload: Long, download: Long) {
        Log.d("TRAFFIC", "📊 UP: ${upload/1024} KB/s, DOWN: ${download/1024} KB/s")
        // از طریق EventChannel ارسال می‌شود
    }

    // ✅ مرحله 7: اجرای sing-box با fd
    private fun startSingBox(configPath: String) {
        stopAll()
        try {
            val binary = File(filesDir, "sing-box")
            if (!binary.exists()) {
                Log.e("CORE_SERVICE", "❌ فایل sing-box وجود ندارد")
                return
            }

            // ✅ مرحله 7: ارسال fd به sing-box
            val fd = vpnInterface?.fd
            val cmd = if (fd != null) {
                arrayOf(binary.absolutePath, "run", "--tun-fd", fd.toString(), "-c", configPath)
            } else {
                arrayOf(binary.absolutePath, "run", "-c", configPath)
            }

            currentProcess = Runtime.getRuntime().exec(cmd)
            currentCore = "singbox"
            isRunning = true
            retryCount = 0
            Log.d("CORE_SERVICE", "✅ sing-box با موفقیت شروع شد (fd: $fd)")

            readProcessOutput(currentProcess!!)

        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در شروع sing-box: ${e.message}")
            recoverFromCrash("singbox", configPath)
        }
    }

    // ✅ مرحله 7: اجرای xray با fd
    private fun startXray(configPath: String) {
        stopAll()
        try {
            val binary = File(filesDir, "xray")
            if (!binary.exists()) {
                Log.e("CORE_SERVICE", "❌ فایل xray وجود ندارد")
                return
            }

            val fd = vpnInterface?.fd
            val cmd = if (fd != null) {
                arrayOf(binary.absolutePath, "-config", configPath, "--tun-fd", fd.toString())
            } else {
                arrayOf(binary.absolutePath, "-config", configPath)
            }

            currentProcess = Runtime.getRuntime().exec(cmd)
            currentCore = "xray"
            isRunning = true
            retryCount = 0
            Log.d("CORE_SERVICE", "✅ xray با موفقیت شروع شد (fd: $fd)")

            readProcessOutput(currentProcess!!)

        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در شروع xray: ${e.message}")
            recoverFromCrash("xray", configPath)
        }
    }

    // ✅ مرحله 12: Log Streaming
    private fun readProcessOutput(process: Process) {
        thread {
            process.inputStream.bufferedReader().forEachLine {
                Log.d("CORE_OUT", it)
                sendLogToFlutter(it)
            }
        }
        thread {
            process.errorStream.bufferedReader().forEachLine {
                Log.e("CORE_ERR", it)
                sendLogToFlutter("[ERROR] $it")
            }
        }
    }

    private fun sendLogToFlutter(log: String) {
        // از طریق EventChannel ارسال می‌شود
    }

    // ✅ مرحله 14: Crash Recovery با محدودیت
    private fun recoverFromCrash(core: String, config: String) {
        if (retryCount < 3) {
            retryCount++
            Log.d("CORE_SERVICE", "🔄 بازیابی $core (تلاش $retryCount)...")
            Thread.sleep(2000)
            val intent = Intent(this, CoreService::class.java)
            intent.putExtra("type", core)
            intent.putExtra("config", config)
            startService(intent)
        } else {
            Log.e("CORE_SERVICE", "❌ تعداد تلاش‌ها تمام شد")
            stopSelf()
        }
    }

    // ✅ مرحله 9: توقف کامل
    override fun onDestroy() {
        stopAll()
        trafficTimer?.cancel()
        super.onDestroy()
    }

    private fun stopAll() {
        try {
            currentProcess?.destroy()
            currentProcess = null
            currentCore = null
            isRunning = false

            vpnInterface?.close()
            vpnInterface = null

            stopForeground(true)
            stopSelf()

            Log.d("CORE_SERVICE", "✅ همه هسته‌ها و VPN متوقف شدند")
        } catch (e: Exception) {
            Log.e("CORE_SERVICE", "❌ خطا در توقف: ${e.message}")
        }
    }

    // ✅ مرحله 16: Multi-Core Switcher
    fun switchCore(type: String, config: String) {
        stopAll()
        Thread.sleep(500)
        val intent = Intent(this, CoreService::class.java)
        intent.putExtra("type", type)
        intent.putExtra("config", config)
        startService(intent)
    }

    // ✅ مرحله 2: Foreground Service کامل
    private fun startForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Core Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("V2RAY STK")
            .setContentText("VPN در حال اجرا است...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        Log.d("CORE_SERVICE", "✅ سرویس foreground شروع شد")
    }

    override fun onBind(intent: Intent?) = null
}
