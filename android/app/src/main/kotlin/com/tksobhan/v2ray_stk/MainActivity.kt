package com.tksobhan.v2ray_stk

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "core_channel"
    private val VPN_REQUEST_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ✅ مرحله 1: درخواست مجوز VPN
        if (intent?.getBooleanExtra("vpn_request", false) == true) {
            val intent = VpnService.prepare(this)
            if (intent != null) {
                startActivityForResult(intent, VPN_REQUEST_CODE)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ مرحله 9: EventChannel برای لاگ
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "core_logs"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // لاگ‌ها به اینجا می‌رسند
            }
            override fun onCancel(arguments: Any?) {}
        })

        // ✅ مرحله 9: EventChannel برای ترافیک
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "core_traffic"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // ترافیک به اینجا می‌رسد
            }
            override fun onCancel(arguments: Any?) {}
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

                "fetchSubscription" -> {
                    val url = call.argument<String>("url") ?: ""
                    val installer = CoreInstaller(this)
                    val data = installer.fetchSubscription(url)
                    val nodes = installer.parseSubscription(data)
                    result.success(nodes.joinToString("\n"))
                }

                "getStatus" -> {
                    result.success("OK")
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            Log.d("CORE", "✅ مجوز VPN دریافت شد")
            val intent = Intent(this, CoreService::class.java)
            startService(intent)
        }
    }
}
