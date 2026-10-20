package com.example.kazumi

import android.content.Intent
import android.os.Build;
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File
import java.io.FileOutputStream
import java.io.FileNotFoundException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.predidit.kazumi/intent"
    private val ARIA2_CHANNEL = "com.predidit.kazumi/aria2"
    private var aria2Process: Process? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Existing intent channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openWithMime") {
                val url = call.argument<String>("url")
                val mimeType = call.argument<String>("mimeType")
                if (url != null && mimeType != null) {
                    openWithMime(url, mimeType)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL and MIME type required", null)
                }
            }
            if (call.method == "checkIfInMultiWindowMode") {
                val isInMultiWindow = checkIfInMultiWindowMode()
                result.success(isInMultiWindow)
            }
            result.notImplemented()
        }
        
        // New aria2 channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ARIA2_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAria2" -> {
                    coroutineScope.launch {
                        try {
                            val args = call.argument<List<String>>("args") ?: emptyList()
                            val success = startAria2(args)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("START_ERROR", e.message, null)
                        }
                    }
                }
                "stopAria2" -> {
                    try {
                        stopAria2()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "isAria2Running" -> {
                    result.success(isAria2Running())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private suspend fun startAria2(args: List<String>): Boolean = withContext(Dispatchers.IO) {
        try {
            // Stop existing process if running
            stopAria2()
            
            // Extract aria2c binary from assets
            val aria2Binary = extractAria2Binary()
            if (aria2Binary == null || !aria2Binary.exists()) {
                return@withContext false
            }
            
            // Make sure it's executable
            aria2Binary.setExecutable(true, false)
            
            // Build command
            val command = mutableListOf(aria2Binary.absolutePath)
            command.addAll(args)
            
            // Start the process
            val processBuilder = ProcessBuilder(command)
            processBuilder.redirectErrorStream(true)
            aria2Process = processBuilder.start()
            
            // Monitor process in background
            coroutineScope.launch(Dispatchers.IO) {
                try {
                    aria2Process?.inputStream?.bufferedReader()?.useLines { lines ->
                        lines.forEach { line ->
                            android.util.Log.d("Aria2", line)
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("Aria2", "Error reading process output", e)
                }
            }
            
            true
        } catch (e: Exception) {
            android.util.Log.e("Aria2", "Failed to start aria2", e)
            false
        }
    }
    
    private fun stopAria2() {
        aria2Process?.let { process ->
            try {
                process.destroy()
                // Give it a moment to terminate gracefully
                Thread.sleep(500)
                if (process.isAlive) {
                    process.destroyForcibly()
                }
            } catch (e: Exception) {
                android.util.Log.e("Aria2", "Error stopping aria2", e)
            }
        }
        aria2Process = null
    }
    
    private fun isAria2Running(): Boolean {
        return aria2Process?.isAlive ?: false
    }
    
    private fun extractAria2Binary(): File? {
        try {
            val binaryName = "aria2c"
            val outputDir = File(applicationContext.filesDir, "bin")
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }
            
            val outputFile = File(outputDir, binaryName)
            
            // Only extract if not already present or if asset is newer
            if (!outputFile.exists()) {
                try {
                    assets.open(binaryName).use { input ->
                        FileOutputStream(outputFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    outputFile.setExecutable(true, false)
                } catch (fnf: FileNotFoundException) {
                    android.util.Log.i("Aria2", "aria2c asset is not bundled in APK assets; skipped local extraction.")
                    return null
                }
            }
            
            return outputFile
        } catch (e: Exception) {
            android.util.Log.e("Aria2", "Failed to extract aria2 binary", e)
            return null
        }
    }

    override fun onDestroy() {
        stopAria2()
        super.onDestroy()
    }

    private fun openWithMime(url: String, mimeType: String) {
        val intent = Intent()
        intent.action = Intent.ACTION_VIEW
        intent.setDataAndType(Uri.parse(url), mimeType)
        startActivity(intent)
    }

    private fun checkIfInMultiWindowMode(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            this.isInMultiWindowMode 
        } else {
            false 
        }
    }
}
