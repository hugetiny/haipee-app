package com.example.haipee

import android.content.Intent
import android.os.Build
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import com.ryanheise.audioservice.AudioServiceActivity
import com.gopeed.libgopeed.Libgopeed
import com.gopeed.libgopeed.InvokeResultListener
import com.gopeed.libgopeed.TaskEventListener

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.hugetiny.haipee/intent"
    private val LIBGOPEED_CHANNEL = "gopeed.com/libgopeed"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Gopeed download engine channel
        val libgopeedTaskQueue = flutterEngine.dartExecutor.binaryMessenger.makeBackgroundTaskQueue()
        val libgopeedChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LIBGOPEED_CHANNEL,
            StandardMethodCodec.INSTANCE,
            libgopeedTaskQueue,
        )
        libgopeedChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        val cfg = call.argument<String>("cfg") ?: ""
                        result.success(Libgopeed.start(cfg))
                    } catch (error: Exception) {
                        result.error("ERROR", error.message, null)
                    }
                }
                "stop" -> {
                    Libgopeed.stop()
                    result.success(null)
                }
                "getApiServerState" -> result.success(Libgopeed.getAPIServerState())
                "startApiServer" -> result.success(Libgopeed.startAPIServer())
                "stopApiServer" -> result.success(Libgopeed.stopAPIServer())
                "restartApiServer" -> result.success(Libgopeed.restartAPIServer())
                "invoke" -> {
                    try {
                        Libgopeed.invokeAsync(
                            call.argument<String>("method") ?: "",
                            call.argument<String>("path") ?: "",
                            call.argument<String>("query") ?: "",
                            call.argument<String>("body") ?: "",
                            call.argument<Number>("requestID")?.toLong() ?: 0L,
                            object : InvokeResultListener {
                                override fun onResult(requestID: Long, success: Boolean, payload: String?) {
                                    runOnUiThread {
                                        if (success) {
                                            result.success(payload ?: "")
                                        } else {
                                            result.error("ERROR", payload ?: "InvokeAsync failed", null)
                                        }
                                    }
                                }
                            },
                        )
                    } catch (error: Exception) {
                        result.error("ERROR", error.message, null)
                    }
                }
                "subscribeTaskEvents" -> {
                    val mask = call.argument<Number>("mask")?.toLong() ?: 0L
                    if (mask == 0L) {
                        Libgopeed.subscribeTaskEvents(0L, null)
                    } else {
                        Libgopeed.subscribeTaskEvents(
                            mask,
                            object : TaskEventListener {
                                override fun onTaskEvent(payload: String?) {
                                    runOnUiThread {
                                        libgopeedChannel.invokeMethod("taskEvent", payload ?: "")
                                    }
                                }
                            },
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

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
                return@setMethodCallHandler
            }
            if (call.method == "isFirebaseTestLab") {
                val testLabSetting = android.provider.Settings.System.getString(contentResolver, "firebase.test.lab")
                result.success("true" == testLabSetting)
                return@setMethodCallHandler
            }
            if (call.method == "logNative") {
                val tag = call.argument<String>("tag") ?: "haipee"
                val level = call.argument<String>("level") ?: "I"
                val message = call.argument<String>("message") ?: ""
                when (level) {
                    "E" -> android.util.Log.e(tag, message)
                    "W" -> android.util.Log.w(tag, message)
                    "D" -> android.util.Log.d(tag, message)
                    else -> android.util.Log.i(tag, message)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            result.notImplemented()
        }
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
