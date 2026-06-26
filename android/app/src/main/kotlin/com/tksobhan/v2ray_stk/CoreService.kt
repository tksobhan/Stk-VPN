package com.tksobhan.v2ray_stk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.TrafficStats
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.lang.Process

class CoreService : VpnService() {

    companion object {
        private const val CHANNEL_ID = "vpn_pro"
        private const val NOTIFICATION_ID = 1001
    }

    private var currentProcess: Process? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    private val watchdog = Handler(Looper.getMainLooper())

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        val type = intent?.getStringExtra("type") ?: "singbox"
        val config = intent?.getStringExtra("config") ?: ""

        startVpnForeground()

        if (config.isBlank()) {
            Log.e("VPN", "config empty")
            return START_STICKY
        }

        // ✅ FIX 1: ذخیره کانفیگ در فایل و ارسال مسیر
        val configFile = File(filesDir, "config.json")
        configFile.writeText(config)

        when (type.lowercase()) {
            "singbox" -> startSingBox(configFile.absolutePath)
            "xray" -> startXray(configFile.absolutePath)
        }

        startWatchdog()

        return START_STICKY
    }

    private fun startVpnForeground() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN PRO",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val notification: Notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("VPN Running")
                .setContentText("Connected")
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startVpn(): ParcelFileDescriptor? {
        return Builder()
            .setSession("STK-VPN")
            .addAddress("172.19.0.1", 30)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("1.1.1.1")
            .setMtu(1500)
            .establish()
    }

    private fun resetVpn() {
        vpnInterface?.close()
        vpnInterface = null
        try {
            Thread.sleep(300)
        } catch (_: InterruptedException) {}
        vpnInterface = startVpn()
        Log.d("VPN", "TUN reset done (fd: ${vpnInterface?.fd})")
    }

    // ✅ FIX 1: ارسال مسیر فایل به sing-box
    private fun startSingBox(configPath: String) {

        stopCore()
        resetVpn()

        val binary = File(filesDir, "sing-box")

        if (!binary.exists()) {
            Log.e("VPN", "sing-box missing")
            return
        }

        if (!binary.canExecute()) {
            binary.setExecutable(true)
        }

        currentProcess = Runtime.getRuntime().exec(
            arrayOf(
                binary.absolutePath,
                "run",
                "-c",
                configPath
            )
        )

        readProcessOutput()
        Log.d("VPN", "sing-box started with config file: $configPath")
    }

    // ✅ FIX 1: ارسال مسیر فایل به xray
    private fun startXray(configPath: String) {

        stopCore()

        val binary = File(filesDir, "xray")

        if (!binary.exists()) {
            Log.e("VPN", "xray missing")
            return
        }

        if (!binary.canExecute()) {
            binary.setExecutable(true)
        }

        currentProcess = Runtime.getRuntime().exec(
            arrayOf(
                binary.absolutePath,
                "-config",
                configPath
            )
        )

        readProcessOutput()
        Log.d("VPN", "xray started with config file: $configPath")
    }

    private fun readProcessOutput() {
        val proc = currentProcess ?: return

        Thread {
            try {
                proc.inputStream.bufferedReader().forEachLine { line ->
                    Log.d("CORE_OUT", line)
                    MainActivity.logSink?.success(line)
                }
            } catch (e: Exception) {
                Log.e("CORE", "inputStream error", e)
            }
        }.start()

        Thread {
            try {
                proc.errorStream.bufferedReader().forEachLine { line ->
                    Log.e("CORE_ERR", line)
                    MainActivity.logSink?.success("[ERR] $line")
                }
            } catch (e: Exception) {
                Log.e("CORE", "errorStream error", e)
            }
        }.start()
    }

    private fun startWatchdog() {

        watchdog.postDelayed(
            object : Runnable {

                override fun run() {

                    try {

                        if (currentProcess == null) {
                            Log.e("VPN", "core crashed")
                        }

                    } finally {

                        watchdog.postDelayed(
                            this,
                            5000
                        )
                    }
                }
            },
            5000
        )
    }

    private fun stopCore() {
        currentProcess?.destroyForcibly()
        currentProcess = null
    }

    // ✅ FIX 3: اعتبارسنجی باینری (برای CoreInstaller)
    private fun isValidBinary(file: File): Boolean {
        return file.exists() &&
                file.length() > 2_000_000 &&
                file.canExecute()
    }

    private fun getTrafficStats(): String {
        val uid = android.os.Process.myUid()
        val rx = TrafficStats.getUidRxBytes(uid)
        val tx = TrafficStats.getUidTxBytes(uid)
        return "$tx|$rx"
    }

    override fun onDestroy() {

        stopCore()
        vpnInterface?.close()
        vpnInterface = null

        watchdog.removeCallbacksAndMessages(null)

        super.onDestroy()
    }

    override fun onBind(
        intent: Intent?
    ) = null
}
