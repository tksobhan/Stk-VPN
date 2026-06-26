package com.tksobhan.v2ray_stk

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.gzip.GzipCompressorInputStream

class CoreInstaller(private val context: Context) {

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
        return data.split("\n").filter {
            it.startsWith("vless://") ||
            it.startsWith("vmess://") ||
            it.startsWith("trojan://") ||
            it.startsWith("ss://")
        }
    }

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

            if (name == "sing-box") {
                extractTarGz(archive, context.filesDir)
            } else {
                extractZip(archive, context.filesDir)
            }

            val extracted = findExtractedBinary(name)
            if (extracted != null && extracted.renameTo(binary)) {
                binary.setExecutable(true, false)
                archive.delete()
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

    private fun extractTarGz(archive: File, outputDir: File) {
        TarArchiveInputStream(GzipCompressorInputStream(FileInputStream(archive))).use { tar ->
            var entry = tar.nextEntry
            while (entry != null) {
                val outFile = File(outputDir, entry.name)
                if (entry.isDirectory) {
                    outFile.mkdirs()
                } else {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { out ->
                        tar.copyTo(out)
                    }
                }
                entry = tar.nextEntry
            }
        }
        archive.delete()
    }

    private fun extractZip(archive: File, outputDir: File) {
        ZipInputStream(FileInputStream(archive)).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val outFile = File(outputDir, entry.name)
                if (entry.isDirectory) {
                    outFile.mkdirs()
                } else {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { out ->
                        zis.copyTo(out)
                    }
                }
                entry = zis.nextEntry
            }
        }
        archive.delete()
    }

    // ✅ اصلاح شده: پیدا کردن باینری استخراج شده
    private fun findExtractedBinary(name: String): File? {
        return context.filesDir.listFiles()?.firstOrNull {
            it.isFile && it.name.contains(name) && !it.name.endsWith(".archive")
        }
    }
}
