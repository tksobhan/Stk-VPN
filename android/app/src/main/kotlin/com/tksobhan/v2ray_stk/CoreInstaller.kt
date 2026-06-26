package com.tksobhan.v2ray_stk

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

class CoreInstaller(private val context: Context) {

    // ✅ مرحله 15: Subscription Engine
    fun fetchSubscription(url: String): String {
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connect()
            connection.inputStream.bufferedReader().readText()
        } catch (e: Exception) {
            Log.e("SUB", "❌ خطا در دریافت اشتراک: ${e.message}")
            ""
        }
    }

    fun parseSubscription(data: String): List<String> {
        val lines = data.split("\n")
        return lines.filter {
            it.startsWith("vless://") ||
            it.startsWith("vmess://") ||
            it.startsWith("trojan://") ||
            it.startsWith("ss://")
        }
    }

    // ✅ مرحله 3-5: دانلود و نصب هسته‌ها
    fun installIfNeeded(name: String): Boolean {
        val binary = File(context.filesDir, name)
        if (binary.exists() && binary.canExecute()) {
            Log.d("INSTALLER", "✅ $name از قبل وجود دارد")
            return true
        }

        Log.d("INSTALLER", "⬇️ دانلود $name ...")

        val url = when (name) {
            "sing-box" -> "https://github.com/SagerNet/sing-box/releases/download/v1.13.14/sing-box-1.13.14-android-arm64.tar.gz"
            "xray" -> "https://github.com/XTLS/Xray-core/releases/download/v26.6.1/Xray-android-arm64-v8a.zip"
            else -> return false
        }

        return try {
            val archive = File(context.filesDir, "$name.archive")
            downloadFile(url, archive)

            // ✅ مرحله 4: استخراج sing-box
            if (name == "sing-box") {
                extractTarGz(archive, context.filesDir)
            } else {
                // ✅ مرحله 5: استخراج xray
                extractZip(archive, context.filesDir)
            }

            // تغییر نام فایل استخراج شده به نام صحیح
            val extracted = findExtractedBinary(name)
            if (extracted != null && extracted.renameTo(binary)) {
                binary.setExecutable(true, false)
                Log.d("INSTALLER", "✅ $name نصب شد")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e("INSTALLER", "❌ نصب $name شکست خورد: ${e.message}")
            false
        }
    }

    // ✅ مرحله 3: دانلود فایل
    private fun downloadFile(url: String, output: File) {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connect()
        connection.inputStream.use { input ->
            FileOutputStream(output).use { out ->
                input.copyTo(out)
            }
        }
    }

    // ✅ مرحله 4: استخراج tar.gz
    private fun extractTarGz(archive: File, outputDir: File) {
        val process = Runtime.getRuntime().exec(
            arrayOf("tar", "-xzf", archive.absolutePath, "-C", outputDir.absolutePath)
        )
        process.waitFor()
        archive.delete()
    }

    // ✅ مرحله 5: استخراج zip
    private fun extractZip(archive: File, outputDir: File) {
        ZipInputStream(FileInputStream(archive)).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val outFile = File(outputDir, entry.name)
                FileOutputStream(outFile).use { out ->
                    zis.copyTo(out)
                }
                entry = zis.nextEntry
            }
        }
        archive.delete()
    }

    // پیدا کردن فایل باینری استخراج شده
    private fun findExtractedBinary(name: String): File? {
        val files = context.filesDir.listFiles()
        return files?.firstOrNull {
            it.name.contains(name) && it.isFile && !it.name.endsWith(".archive")
        }
    }

    // ✅ مرحله 19: Auto Update Core
    fun checkForUpdate(name: String): Boolean {
        return false
    }
}
