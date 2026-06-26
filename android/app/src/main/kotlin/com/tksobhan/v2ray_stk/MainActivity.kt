package com.tksobhan.v2ray_stk

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "core_channel"
    private val VPN_REQUEST_CODE = 1001

    companion object {
        var logSink: EventChannel.EventSink? = null
        var trafficSink: EventChannel.EventSink? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ✅ ایراد ۵: درخواست مجوز POST_NOTIFICATIONS برای Android 13+
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1002)
            }
        }

        if (intent?.getBooleanExtra("vpn_request", false) == true) {
            val intent = VpnService.prepare(this)
            if (intent != null) {
                startActivityForResult(intent, VPN_REQUEST_CODE)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "core_logs"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                logSink = events
                Log.d("EVENT", "✅ Log listener active")
            }
            override fun onCancel(arguments: Any?) {
                logSink = null
                Log.d("EVENT", "❌ Log listener cancelled")
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "core_traffic"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                trafficSink = events
                Log.d("EVENT", "✅ Traffic listener active")
            }
            override fun onCancel(arguments: Any?) {
                trafficSink = null
                Log.d("EVENT", "❌ Traffic listener cancelled")
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startCore" -> {
                    val type = call.argument<String>("type") ?: "singbox"
                    val config = call.argument<String>("config") ?: ""

                    Log.d("CORE", "startCore called - type: $type")

                    val intent = Intent(this, CoreService::class.java)
                    intent.putExtra("type", type)
                    intent.putExtra("config", config)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }

                    result.success("Core Started")
                }

                "stopCore" -> {
                    Log.d("CORE", "stopCore called")
                    stopService(Intent(this, CoreService::class.java))
                    result.success("Core Stopped")
                }

                "switchCore" -> {
                    val type = call.argument<String>("type") ?: "xray"
                    val config = call.argument<String>("config") ?: ""

                    Log.d("CORE", "switchCore called - type: $type")

                    val intent = Intent(this, CoreService::class.java)
                    intent.putExtra("type", type)
                    intent.putExtra("config", config)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }

                    result.success("Core Switched")
                }

                // ✅ ایراد ۴: Base64 decode
                "fetchSubscription" -> {
                    val url = call.argument<String>("url") ?: ""
                    val installer = CoreInstaller(this)
                    val raw = installer.fetchSubscription(url)
                    val decoded = try {
                        String(Base64.decode(raw, Base64.DEFAULT))
                    } catch (e: Exception) {
                        raw
                    }
                    val nodes = installer.parseSubscription(decoded)
                    result.success(nodes.joinToString("\n"))
                }

                "getStatus" -> {
                    result.success("OK")
                }

                else -> result.notImplemented()
            }
        }
    }

    // ✅ ایراد ۴: onActivityResult
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            Log.d("CORE", "✅ مجوز VPN دریافت شد")
            val intent = Intent(this, CoreService::class.java)
            startService(intent)
        }
    }
}
